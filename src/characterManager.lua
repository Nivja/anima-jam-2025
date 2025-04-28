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
    local success, characterDefinition
    if lfs.getInfo(characterDirectory, "directory") and lfs.getInfo(characterJson) then
      success, characterDefinition = json.decode(characterJson)
      if success then
        characterManager.characters[characterName] = character.new(characterDirectory, characterName, characterDefinition)
        logger.info("Added character:", characterName)
      else
        logger.warn("Could not decode character json:", characterJson, ". Reason:", characterDefinition)
      end
    else
      success, characterDefinition = json.decode(dir .. "player/character.json")
      if success then
        characterManager.characters[characterName] = character.new(characterDirectory, characterName, characterDefinition, dir .. "player")
        logger.warn("Added character; given player texture due to missing character.json:", characterName)
      else
        logger.warn("Could not add character; couldn't decode default character(player) json. Reason:", characterDefinition)
      end
    end
  end
end

local initCharacterState = function()
  for _, character in pairs(characterManager.characters) do
    character:applyAnimation("idle")
    character.isPlayer = character.dirName == "player"
  end
end

characterManager.load = function(animationDir, characterDir)
  characterManager.unload()
  logger.info("Loading Animations")
  loadAnimations(animationDir)
  logger.info("Loading Characters")
  loadCharacters(characterDir)
  initCharacterState()
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

characterManager.get = function(id)
  return characterManager.characters[id]
end

characterManager.getCharactersInWorld = function(world, outCharacters)
  world = type(world) == "table" and world.name or world
  outCharacters = outCharacters or { }
  for _, character in pairs(characterManager.characters) do
    if character.world == world then
      table.insert(outCharacters, character)
    end
  end
end

return characterManager