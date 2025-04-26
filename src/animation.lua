local logger = require("util.logger")

local flux = require("libs.flux")

local animation = { }
animation.__index = animation

animation.new = function(definition, name)
  local self = {
    -- TODO don't forget to add more part.a<num><var> if you want more track s
    track = definition.track or 0,
    start = definition.start,
    loop = definition.loop,
    finish = definition.finish,
    name = name,
  }

  if not self.loop then
    error("Animation must have a loop sequence")
  end
  if not self.finish then
    error("Animation must have a finish sequence")
  end

  for _, seq_name in ipairs({"start", "loop", "finish" }) do
    local sequences = self[seq_name]
    if sequences then
      if type(sequences) ~= "table" then
        error("Animation '" .. name .. "' sequence '" .. seq_name .. "' must be a table")
      end
      for i, sequence in ipairs(sequences) do
        if type(sequence) ~= "table" or not sequence.part or not sequence.tweens then
          error("Animation '" .. name .. "' sequence '" .. seq_name .. "' item " .. i .. " is malformed")
        end
        if type(sequence.tweens) ~= "table" then
          error("Animation '" .. name .. "' sequence '" .. seq_name .. "' item " .. i .. "'s tweens must be a table")
        end
        for j, tween in ipairs(sequence.tweens) do
          if type(tween) ~= "table" then
              error("Animation '" .. name .. "' sequence '" .. seq_name .. "' item " .. i .. "'s tween " .. j .. " is malformed")
          end
          if tween.transform then
            if type(tween.transform) ~= "table" then
              error("Animation '" .. name .. "' sequence '" .. seq_name .. "' item " .. i .. "'s tween " .. j .. "'s transform must be a table")
            else
              local transform = { }
              for _, key in ipairs({ "x", "y", "r", "scale" }) do
                local value = tween.transform[key]
                if type(value) == "number" then
                  -- TODO don't forget to add more part.a<track><var> if you want more track s
                  local newKey = "a" .. tostring(self.track) .. tostring(key)
                  transform[newKey] = value
                end
              end
              tween.transform = transform
            end
          end
        end
      end
    end
  end

  return setmetatable(self, animation)
end

local stopTrackTweens = function(trackState)
  if trackState and trackState.tweens then
    for _, tween in ipairs(trackState.tweens) do
      tween:stop()
    end
    trackState.tweens = nil
  end
end

local blankFinishCB = function() end
local runSequences = function(sequences, partLookup, finishCB)
  local tweens = { }
  local tweenCount = 0
  local completedCount = 0
  
  if not sequences or #sequences == 0 then
    if finishCB then
      finishCB()
    end
    return tweens, 0
  end

  local onTweenComplete = not finishCB and blankFinishCB or function()
    completedCount = completedCount + 1
    if completedCount == tweenCount then
      if finishCB then
        finishCB()
      end
    end
  end

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
        fluxTween:oncomplete(onTweenComplete)
      end
    end
  end

  if tweenCount == 0 then
    if finishCB then
      finishCB()
    end
  end

  return tweens
end

local processTrackRequestQueue

local startFinishPhase = function(self, character)
  local trackState = character.animationTrackState[self.track]

  if trackState.animation ~= self or trackState.phase ~= "looping" then
    processTrackRequestQueue(character, self.track)
    return
  end

  trackState.phase = "finishing"
  stopTrackTweens(trackState)

  trackState.tweens = runSequences(self.finish, character.partLookup, function()
    trackState.phase = "idle"
    trackState.animation = nil
    stopTrackTweens(trackState)
    processTrackRequestQueue(character, self.track)
  end)
end

local startLoopPhase = function(self, character)
  local trackState = character.animationTrackState[self.track]

  if trackState.animation ~= self or trackState.phase ~= "starting" then
    processTrackRequestQueue(character, self.track)
    return
  end

  trackState.phase = "looping"
  if self.loop then
    local onLoopIterationComplete
    onLoopIterationComplete = function()
      if trackState.animation ~= self or trackState.phase ~= "looping" then
        return
      end
      stopTrackTweens(trackState) -- stop any old tweens laying around
      trackState.tweens = runSequences(self.loop, character.partLookup, onLoopIterationComplete)
    end
    onLoopIterationComplete()
  else
    startFinishPhase(self, character)
  end
end

local startStartPhase = function(self, character)
  local trackState = character.animationTrackState[self.track]

  if trackState.animation ~= self or trackState.phase ~= "idle" then
    processTrackRequestQueue(character, self.track)
    return
  end

  trackState.phase = "starting"

  if animation.start then
    trackState.tweens = runSequences(animation.start, character.partLookup, function()
      if trackState.animation == self and trackState.phase == "starting" then
        startLoopPhase(self, character)
      end
    end)
  else -- If this animation doesn't have a start sequence; skip to loop
    startLoopPhase(self, character)
  end
end

processTrackRequestQueue = function(character, track)
  local trackState = character.animationTrackState[track]
  local nextAnimation = character.animationRequestQueue[track]

  if not nextAnimation or trackState.phase == "starting" or trackState.phase == "finishing" then
    return -- Nothing to process
  end

  local currentAnimation = trackState.animation
  if trackState.phase == "looping" and currentAnimation ~= nextAnimation then
    startFinishPhase(currentAnimation, character, function()
      processTrackRequestQueue(character, track)
    end)
    return
  end

  if trackState.phase == "idle" then
    character.animationRequestQueue[track] = nil
    trackState.animation = nextAnimation
    stopTrackTweens(trackState) -- Ensure any old tweens are stopped
    startStartPhase(nextAnimation, character)
    return
  end

  logger.warn("ProcessTrackRequestQueue reached where it shouldn't. The trackState phase was:", trackState.phase)
end

animation.apply = function(self, character)
  local trackState = character.animationTrackState[self.track]

  if not trackState then
    trackState = {
      phase = "idle",
      animation = nil,
      tweens = nil,
    }
    character.animationTrackState[self.track] = trackState
  end

  if trackState.animation == self and (trackState.phase == "starting" or trackState.phase == "looping") then
    logger.warn("Tried to apply the same animation that is already playing:", self, "on track", self.track)
    return
  end

  if character.animationRequestQueue[self.track] == self then
    logger.warn("Tried to apply the same animation that is already requested:", self, "on track", self.track)
    return
  end

  character.animationRequestQueue[self.track] = self

  processTrackRequestQueue(character, self.track)
end

return animation