local lfs = love.filesystem
local lg = love.graphics

local logger = require("util.logger")
local json = require("util.json")

local character = require("src.character")

local characterManager = {
  characters = { }
}

characterManager.load = function(dir)
  for _, characterName in ipairs(lfs.getDirectoryItems(dir)) do
    local characterDirectory = dir .. characterName
    local characterJson = characterDirectory .. "/character.json"
    if lfs.getInfo(characterDirectory, "directory") and lfs.getInfo(characterJson) then
      local success, characterDefinition = json.decode(characterJson)
      if success then
        local c = character.new(characterDirectory, characterName, characterDefinition)
        characterManager.characters[characterName] = c
        logger.info("Added character:", characterName)
      else
        logger.warn("Could not decode character json:", characterJson, ". Reason:", characterDefinition)
      end
    else
      logger.warn("Found invalid character:", characterDirectory)
    end
  end
end

characterManager.unload = function()
  characterManager.characters = nil
end

characterManager.update = function(dt)
  for _, character in pairs(characterManager.characters) do
    character:update(dt)
  end
end

characterManager.draw = function()
  -- debug, pick a random first one
  for _, character in pairs(characterManager.characters) do
    character:draw()
    break
  end
end

return characterManager