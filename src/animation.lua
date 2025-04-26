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
              -- TODO don't forget to add more part.a<track><var> if you want more tracks
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
  local tweens, tweenCount = { }, 0
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
          else
            fluxTween = fluxTween:after(tweenLength, tweenTransform):ease(tweenEase)
          end
          table.insert(tweens, fluxTween)
          if accumulatedDelay then
            fluxTween:delay(accumulatedDelay)
            accumulatedDelay = nil
          end
        end
      end
      if fluxTween then
        tweenCount = tweenCount + 1
      end
      if fluxTween and finishCB then
        fluxTween:oncomplete(finishCB)
      end
    end
  end
  return tweens, tweenCount
end

animation.applyLoop = function(self, character)local cb
  if character.animations[self.name] then
    character.animations[self.name] = false
    return -- it's already currently playing
  end
  local count, tweenCount = 0, 0
  cb = function()
    count = count + 1
    if count ~= tweenCount then
      return
    end
    if character.animations[self.name] then
      character.animations[self.name] = false
      print("BROKE LOOP", self.name)
      return -- break loop
    end
    character.animationTweens[self.track], tweenCount = runSequences(self.loop, character.partLookup, cb)
    count = 0
  end
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
  character.animationTweens[self.track], tweenCount = runSequences(self.finish, character.partLookup, finished)
end

animation.apply = function(self, character)
  if character.animations[self.track] then
    local currentAnim = character.animations[self.track]
    if currentAnim == self then
      logger.warn("Tried to apply the same animation twice", self.name)
      return
    end
    if currentAnim.finish then
      currentAnim:applyFinish(character, function()
        print("Finished", currentAnim.name, "->", self.name)
        local currentAnim = character.animations[self.track]
        character.animations[self.track] = nil
        currentAnim:apply(character)
      end)
      print("SET2", self.name)
      character.animations[self.track] = self
      return
    else
      -- Let the current Animation's loop end
      character.animations[currentAnim.name] = true
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
    character.animationTweens[self.track], tweenCount = runSequences(self.start, character.partLookup, finished)
  else
    self:applyLoop(character)
  end
  print("SET", self.name)
  character.animations[self.track] = self
end

return animation