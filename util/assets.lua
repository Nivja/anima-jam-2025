-- Table is filled by assetManager.lua
local logger = require("util.logger")

local lt = love.timer

local unloadTime = 30 --seconds

local meta = { }
local assets = { }
local assetsIndexed = { }

local missingTexture = love.graphics.newImage("util/missingTexture.png")
missingTexture:setFilter("nearest")
missingTexture:setWrap("repeat")

meta.__newindex = function(_, key, value)
  local assetInfo = assets[key]
  if not assetInfo then
    assetInfo = meta.addReference(key)
  end
  assetInfo.type = type(value) == "table" and "table" or value:type()
  assetInfo.asset = value
  assetInfo.lastAccessed = lt.getTime()
end

meta.__index = function(_, key)
  local get = rawget(meta, key)
  if get then
    return get
  end

  local assetInfo = assets[key]
  if type(assetInfo) ~= "table" then
    return assetInfo
  end
  assetInfo.time = lt.getTime()
  if not assetInfo.asset and assetInfo.type == "Image" then
    require("assetManager").load(key)
    return assetInfo.mipmap or missingTexture
  end
  return assetInfo.asset
end

meta.lowMemory = function()
  for _, assetInfo in ipairs(assetsIndexed) do
    if assetInfo.type == "Image" and assetInfo.asset ~= nil and lt.getTime() - assetInfo.time > unloadTime then
      assetInfo.asset = nil
    end
  end
end

meta.newFont = function(key, path)
  assets[key] = path
end

meta.addReference = function(key)
  local assetInfo = assets[key]
  if not assetInfo then
    assetInfo = {
      references = 0,
    }

    assets[key] = assetInfo
    table.insert(assetsIndexed, assetInfo)
  end
  assetInfo.references = assetInfo.references + 1
  assetInfo.lastAccessed = lt.getTime()

  return assetInfo
end

meta.removeReference = function(key, forceRemove)
  local assetInfo = assets[key]
  if not assetInfo then
    logger.warn("Tried to remove reference to asset with no created info:", key)
    return false
  end
  assetInfo.references = assetInfo.references - 1
  if assetInfo.references <= 0 or forceRemove then
    assetInfo.references = 0
    assetInfo.asset = nil
    return true
  end
  return false
end

meta.getReferenceCount = function(key)
  local assetInfo = assets[key]
  return assetInfo and assetInfo.references or 0
end

return setmetatable(meta, meta)