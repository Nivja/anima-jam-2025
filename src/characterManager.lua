local lfs = love.filesystem
local lg = love.graphics

local logger = require("util.logger")
local json = require("util.json")
local file = require("util.file")

local animation = require("src.animation")
local character = require("src.character")

local characterManager = { }

local loadAnimations = function(dir)
  for _, animationName in ipairs(lfs.getDirectoryItems(dir)) do
    local animationPath = dir .. "/" .. animationName
    if lfs.getInfo(animationPath, "file") then
      local success, animationDefinition = json.decode(animationPath)
      if success then
        local name = file.getFileName(animationName)
        characterManager.animations[name] = animation.new(animationDefinition, name)
        logger.info("Added animation:", name)
      else
        logger.warn("Could not decode animation json:", animationPath, ". Reason:", animationDefinition)
      end
    else
      logger.warn("Found invalid animation path:", animationPath)
    end
  end
end

local loadCharacters = function(dir)
  for _, characterName in ipairs(lfs.getDirectoryItems(dir)) do
    local characterDirectory = dir .. characterName
    local characterJson = characterDirectory .. "/character.json"
    if lfs.getInfo(characterDirectory, "directory") and lfs.getInfo(characterJson) then
      local success, characterDefinition = json.decode(characterJson)
      if success then
        characterManager.characters[characterName] = character.new(characterDirectory, characterName, characterDefinition)
        logger.info("Added character:", characterName)
      else
        logger.warn("Could not decode character json:", characterJson, ". Reason:", characterDefinition)
      end
    else
      logger.warn("Found invalid character:", characterDirectory)
    end
  end
end

local initState = function()
  for _, character in pairs(characterManager.characters) do
    anim = characterManager.animations[character.state or ""]
    if anim then
      anim:apply(character)
    else
      logger.warn("Character[", character.dirName,"] Couldn't find animation for state:", character.state, "[type:".. type(character.state) .. "]")
    end
  end
end

characterManager.load = function(animationDir, characterDir)
  characterManager.unload()
  loadAnimations(animationDir)
  loadCharacters(characterDir)

  initState()
end

characterManager.unload = function()
  characterManager.animations = { }
  characterManager.characters = { }
end

characterManager.update = function(dt)
  for _, character in pairs(characterManager.characters) do
    character:update(dt)
  end
end

characterManager.draw = function()
  -- debug, pick a random first one
  for index, character in pairs(characterManager.characters) do
    if index == "player" then
      character:draw()
      break
    end
  end
end

return characterManager