local settings = require("util.settings")
local logger = require("util.logger")

local audioManager = {
  audio = { },
  volume = settings.client.volume,
}

for index, v in pairs(audioManager.volume) do
  if v > 1 then
    audioManager[index] = 1
    logger.warn("Audio manager limited", index, "to 100%")
  end
  if v < 0 then
    audioManager[index] = 0
    logger.warn("Audio manager limited", index, "to 0%")
  end
end

audioManager.register = function(assetKey, audioType, mergedKey, volume)
  local key = mergedKey or assetKey
  local audioInfo = audioManager.audio[key]
  if not audioInfo then
    audioInfo = {
      audioType = audioType,
    }
    audioManager.audio[key] = audioInfo
  else
    if mergedKey and audioInfo.audioType ~= audioType then
      logger.warn("Audio type miss match for key:", assetKey, "expected", audio.audioType, "for merged key:", mergedKey)
    end
  end

  local found = false
  for index, source in ipairs(audioInfo) do
    if source.assetKey == assetKey then
      found = source
      break
    end
  end
  if found then
    logger.warn("Tried to register the same audio source again! Will ignore attempt! Key:", assetKey)
    return
  end

  if mergedKey and mergedKey ~= assetKey then
    audioManager.audio[assetKey] = mergedKey
  end

  table.insert(audioInfo, {
    assetKey = assetKey,
    volume = volume or 1,
  })
end

audioManager.release = function(assetKey)
  local audioInfo = audioManager.audio[assetKey]
  if type(audioInfo) == "string" then
    audioInfo = audioManager.audio[audioInfo]
  end
  if audioInfo then
    for index, source in ipairs(audioInfo) do
      if source.assetKey == assetKey then
        source.asset = nil
        break
      end
    end
  end
end

audioManager.getMergedAssets = function(assetKey)
  local audioInfo = audioManager.audio[assetKey]
  if not audioInfo then
    return nil
  end
  local keys = { }
  for _, source in ipairs(audioInfo) do
    table.insert(keys, source.assetKey)
  end
  return keys
end

audioManager.play = function(assetKey)
  local audioInfo = audioManager.audio[assetKey]
  if not audioInfo then
    logger.warn("Tried to play", assetKey, "but that asset hasn't been registered with the audio manager!")
    return
  end
  if audioInfo.audioType == "ui" or audioInfo.audioType == "sfx" then
    local s = audioInfo[love.math.random(1, #audioInfo)]
    s.asset:play()
    s.asset = s.asset:clone()
  elseif audioInfo.audioType == "music" then
    local s = audioInfo[1]
    s.asset:play()
    return s.asset
  else
    logger.error("Add", audioInfo.audioType, "audioType to audiomanager.play")
    return audioInfo[1]
  end
end

audioManager.setVolumeAll = function()
  for _, audioInfo in pairs(audioManager.audio) do
    if type(audioInfo) == "table" then
      local level = audioManager.volume.master * audioManager.volume[audioInfo.audioType]
      for _, source in ipairs(audioInfo) do
        if source.asset then
          source.asset:setVolume(level * source.volume)
        end
      end
    end
  end
end

audioManager.setSource = function(assetKey, source)
  local audioInfo = audioManager.audio[assetKey]
  if type(audioInfo) == "string" then
    audioInfo = audioManager.audio[audioInfo]
  end
  for _, s in ipairs(audioInfo) do
    if s.assetKey == assetKey then
      s.asset = source
      source:setVolume(audioManager.volume.master * audioManager.volume[audioInfo.audioType] * s.volume)
    end
  end
end

return setmetatable(audioManager, audioManager)