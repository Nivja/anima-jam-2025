local logger = require("util.logger")

local flux = require("libs.flux")

local animation = { }
animation.__index = animation

animation.new = function(definition, name)
  local a = {
    -- TODO don't forget to add more part.a<num><var> if you want more tracks
    track = definition.track or 0,
    start = definition.start,
    loop = definition.loop,
    finish = definition.finish,
    name = name,
  }

  if not a.loop then
    error("Animation must have a loop sequence")
  end

  for index, sequences in pairs(a) do
    if type(sequences) == "table" then
      for _, sequence in ipairs(sequences) do
        for index, tween in ipairs(sequence.tweens) do
          if not tween.delay and tween.transform then
            -- Append "a" for animation for the part
            local transform = { }
            for key, value in pairs(tween.transform) do
              -- TODO don't forget to add more part.a<num><var> if you want more tracks
              local newKey = "a" .. tostring(a.track) .. key
              transform[newKey] = value
            end
            tween.transform = transform
          end
        end
      end
    end
  end

  return setmetatable(a, animation)
end

local runSequences = function(sequences, partLookup, finishCB)
  local tweens = { } -- list of first tweens
  for _, sequence in ipairs(sequences) do
    local part = partLookup[sequence.part]
    if part then
      local fluxTween = nil
      local accumulatedDelay = nil
      for _, tween in ipairs(sequence.tweens) do
        if tween.delay then
          if accumulatedDelay then
            accumulatedDelay = accumulatedDelay + tween.delay
          else
            accumulatedDelay = tween.delay
          end
        else
          local tweenTransform = tween.transform or { }
          local tweenLength = tween.length or 0
          local tweenEase = tween.ease or "linear"
          if not fluxTween then
            fluxTween = flux.to(part, tweenLength, tweenTransform):ease(tweenEase)
            table.insert(tweens, fluxTween)
          else
            fluxTween = fluxTween:after(tweenLength, tweenTransform):ease(tweenEase)
          end
          if accumulatedDelay then
            fluxTween:delay(accumulatedDelay)
            accumulatedDelay = nil
          end
        end
      end
      if fluxTween and finishCB then
        fluxTween:oncomplete(finishCB)
      end
    end
  end
  return tweens
end

animation.applyLoop = function(self, character)local cb
  local count, tweenCount = 0, 0
  cb = function()
    count = count + 1
    if count ~= tweenCount then
      return
    end
    if character.animations[self.name] then
      character.animations[self.name] = false
      print("BROKE LOOP")
      return -- break loop
    end
    character.animationTweens[self.track] = runSequences(self.loop, character.partLookup, cb)
    tweenCount = #character.animationTweens[self.track]
    count = 0
  end
  character.animations[self.name] = false
  tweenCount = 1 -- so we can call cb directly to start it
  cb()
end

animation.applyFinish = function(self, character, callback)
  for _, tween in ipairs(character.animationTweens[self.track]) do
    tween:stop() -- stops tween mid-transition; doesn't call complete callback
  end
  local count, tweenCount = 0, 0
  local finished = function()
    count = count + 1
    if count == tweenCount then
      callback()
    end
  end
  character.animationTweens[self.track] = runSequences(self.finish, character.partLookup, finish)
  tweenCount = #character.animationTweens[self.track]
end

animation.apply = function(self, character)
  if character.animations[self.track] then
    local currentAnim = character.animations[self.track]
    if currentAnim == self then
      logger.warn("Tried to apply the same animation twice")
      return
    end
    if currentAnim.finish then
      currentAnim:applyFinish(character, function()
        character.animations[self.track] = nil
        self:apply(character)
      end)
      return
    else
      character.animations[self.name] = true
      character.animations[self.track] = nil
    end
  end
  if self.start then
    local count, tweenCount = 0, 0
    local finished = function()
      count = count + 1
      if count == tweenCount then
        self:applyLoop(character)
      end
    end
    character.animationTweens[self.track] = runSequences(self.start, character.partLookup, finished)
    tweenCount = #character.animationTweens[self.track]
  else
    self:applyLoop(character)
  end
  character.animations[self.track] = self
end

return animation