local logger = require("util.logger")

local lily = require("libs.lily")
logger.info("Using", lily.getThreadCount(), "threads for loading assets.")

local audioManager = require("util.audioManager")
local assets = require("util.assets")
local file = require("util.file")

local extensions = {
    png  = "newImage",
    jpg  = "newImage",
    jpeg = "newImage",
    bmp  = "newImage",
    mp3  = "newSource",
    ogg  = "newSource",
    wav  = "newSource",
    txt  = "read",
    ttf  = "newFont",
    otf  = "newFont",
    fnt  = "newFont",
  }

local types = {
  newImage = "Image",
  newSource = "Source",
  read = "string",
  newFont = "Font",
}

local assetManager = {
  info = { },
  queue = { },
}

assetManager.register = function(directory)
  local assetInfos = require(directory:gsub("/", ".") .. "assets")
  local n = 0
  local startTime = love.timer.getTime()
  for _, assetInfo in ipairs(assetInfos) do
    local location = directory..assetInfo.path
    if not love.filesystem.isFused() and not love.filesystem.getInfo(location, "file") then
      logger.error("Could find file for", assetInfo.name, "Gave path:", assetInfo.path)
    end
    local ext = file.getFileExtension(assetInfo.path)
    local loadFunction = ext and extensions[ext:lower()] or error("Could not find load functions for "..tostring(ext).." extension from file "..tostring(assetInfo.path))
    if loadFunction == "newFont" then
      assets.newFont(assetInfo.name, location)
    else
      assert(type(assetInfo.onLoad) == "function" or assetInfo.onLoad == nil, "OnLoad function for asset "..tostring(assetInfo.name).." isn't a function or nil!")

      if loadFunction == "newSource" then
        audioManager.register(assetInfo.name, assetInfo.audioType, assetInfo.key, assetInfo.volume)
      end

      local onLoad = assetInfo.onLoad
      if onLoad and assetInfo[1] then
        onLoad = {
          onLoad = assetInfo.onLoad,
          unpack(assetInfo, 1)
        }
      end

      assetManager.info[assetInfo.name] = {
        loadFunction,
        location,
        (loadFunction == "newSource" and assetInfo.sourceType or nil),
        name = assetInfo.name,
        type = types[loadFunction],
        onLoadTbl = onLoad,
      }
    end
    n = n + 1
  end
  local endTime = love.timer.getTime()
  logger.info("Registered", n, "assets! Took", (endTime-startTime)*1000, "ms")
end

local onLilyError = function(userdata, errorMessage)
  logger.error("Could not load", userdata.name, ":", errorMessage)
  assets.removeReference(userdata.name, true)
end

local onMultililyError = function(userdata, _, errorMessage)
  onLilyError(userdata, errorMessage)
end

local onLilyLoad = function(userdata, asset)
  if userdata.type == "Source" then
    audioManager.setSource(userdata.name, asset)
  end
  local onLoadTbl = userdata.onLoadTbl
  if onLoadTbl then
    if type(onLoadTbl) == "function" then
      asset = onLoadTbl(asset) or asset
    else
      asset = onLoadTbl.onLoad(asset, unpack(onLoadTbl, 1)) or asset
    end
  end
  assets[userdata.name] = asset
end

local onMultililyLoad = function(userdata, _, ...)
  return onLilyLoad(userdata, ...)
end

local onMultililyComplete = function(startTime, lilyValues)
  local endTime = love.timer.getTime()
  logger.info("Loaded", #lilyValues, "assets! Took", (endTime - startTime) * 1000, "ms frame dependant")
end

local addToQueueReference = function(assetKey, assetInfo, queue)
  if assets.getReferenceCount(assetKey) == 0 then
    table.insert(queue, assetInfo)
  end
  assets.addReference(assetKey, assetInfo.type)
end

assetManager.load = function(assetList)
  local lilyObject
  if type(assetList) == "string" then
    if assets.getReferenceCount(assetList) == 0 then
      local assetInfo = assetManager.info[name]
      assets.addReference(assetList, assetInfo.type)
      lilyObject = lily[assetInfo[1]](assetInfo[2], assetInfo[3])
        :onError(onLilyError)
        :onComplete(onLilyLoad)
    end
  else
    local queue = { }
    for _, name in ipairs(assetList) do
      local assetInfo = assetManager.info[name]
      if not assetInfo then
        for _, assetKey in ipairs(audioManager.getMergedAssets(name) or { }) do
          addToQueueReference(assetKey, assetManager.info[assetKey], queue)
        end
      else
        addToQueueReference(name, assetInfo, queue)
      end
    end
    if #queue ~= 0 then
      lilyObject = lily.loadMulti(queue)
        :onError(onMultililyError)
        :onLoaded(onMultililyLoad)
        :onComplete(onMultililyComplete)
        :setUserData(love.timer.getTime())
    end
  end
  if lilyObject then
    logger.info("Requested", lilyObject:getCount(), "assets to be loaded!")
  end
  return lilyObject
end

assetManager.unload = function(assetList)
  if type(assetList) == "string" then
    assets.removeReference(assetList)
  else
    local n = 0
    for _, name in ipairs(assetList) do
      if not assetManager.info[name] then
        for _, assetKey in ipairs(audioManager.getMergedAssets(name) or { }) do
          if assets.removeReference(assetKey) then
            audioManager.release(assetKey)
            n = n + 1
          end
        end
      else
        if assets.removeReference(name) then
          n = n + 1
        end
      end
    end
    logger.info("Unloaded", n, "assets!")
  end
end

assetManager.lowMemory = assets.lowMemory()

assetManager.__index = function(_, key)
  local value = rawget(assetManager, key)
  if value then
    return value
  end
  return assets[key]
end

return setmetatable(assetManager, assetManager)