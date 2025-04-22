local animation = { }

animation.new = function(definition)
  local a = {
    sequences = definition.sequences
  }

  local maxDuration = 0
  for _, sequence in ipairs(a.sequence) do
    local duration = 0
    for _, tween in ipairs(sequence.tweens) do
      duration = duration + tween.length
    end
    sequence.duration = duration
    if duration > maxDuration then
      maxDuration = duration
    end
  end
  a.duration = maxDuration

  return setmetatable(a, animation)
end

animation.applyToCharacter = function(character)

end

return animation