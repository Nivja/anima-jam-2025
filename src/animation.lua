local flux = require("libs.flux")

local animation = { }
animation.__index = animation

animation.new = function(definition)
  local a = {
    sequences = definition.sequences
  }

  local maxDuration = 0
  for _, sequence in ipairs(a.sequences) do
    local duration = 0
    for index, tween in ipairs(sequence.tweens) do
      tween.next = sequence.tweens[index + 1]
      if not tween.delay then
        duration = duration + tween.length
        if tween.transform then
          -- Append "a" for animation for the part
          local transform = { }
          for key, value in pairs(tween.transform) do
            transform["a" .. key] = value
          end
          tween.transform = transform
        end
      end
    end
    sequence.duration = duration
    if duration > maxDuration then
      maxDuration = duration
    end
  end
  a.duration = maxDuration

  return setmetatable(a, animation)
end

animation.applyToCharacter = function(self, character, finishCallback)
  local count, tweenCount = 0, 0
  local finished
  finished = function()
    count = count + 1
    if count == tweenCount then
      if type(finishCallback) == "function" then
        finishCallback()
      end
    end
  end

  for _, sequence in ipairs(self.sequences) do
    local tween = sequence.tweens[1]

    local part = character.partLookup[sequence.part]
    if part then
      tweenCount = tweenCount + 1
      local delay, fluxTween = nil, nil
      if tween.delay then
        delay = tween.delay
      else
        fluxTween = flux.to(part, tween.length or 0, tween.transform or { }):ease(tween.ease or "linear")
      end
      tween = tween.next
      while tween ~= nil do
        if tween.delay then
          delay = tween.delay
        else
          if not fluxTween then
            fluxTween = flux.to(part, tween.length or 0, tween.transform or { }):ease(tween.ease or "linear")
          else
            fluxTween = fluxTween:after(part, tween.length or 0, tween.transform or { }):ease(tween.ease or "linear")
          end
          if delay then
            fluxTween:delay(delay)
            delay = nil
          end
        end

        tween = tween.next
      end

      fluxTween:oncomplete(finished)
    end
  end
end

return animation