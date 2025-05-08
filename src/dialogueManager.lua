local lfs = love.filesystem

local audioManager = require("util.audioManager")
local logger = require("util.logger")
local file = require("util.file")
local flux = require("libs.flux")

local characterManager = require("src.characterManager")
local worldManager = require("src.worldManager")
local inventory = require("src.inventory")

local dialogue = { }
dialogue.__index = dialogue

local _ignoreCommand = function(self)
  return self:next()
end

local commandLookup = {
  ["end"] = function(self)
    self.ready = true
    self.isFinished = true
    return nil
  end,
  ["setCharacter"] = function(self, commandTbl)
    self.speaker = commandTbl[2]
    return self:next()
  end,
  ["if_true"] = function(self, commandTbl)
    local condition = commandTbl[2]
    if type(condition) == "function" then
      if condition() then
        local gt = commandTbl[3]
        local newIndex = self.tagLookup[tostring(gt)]
        if newIndex then
          self.index = newIndex -- this jumps straight to the next commandTbl; ignoring the tag index
          return self:next()
        else
          logger.warn("Dialogue["..self.dirName.."@"..self.index.."] could not find tag:", tostring(gt))
        end
      end
      return self:next()
    end
    error("2nd arg should be a function")
  end,
  ["goto"] = function(self, commandTbl)
    local gt = commandTbl[2]
    local newIndex = self.tagLookup[tostring(gt)]
    if newIndex then
      self.index = newIndex -- this jumps straight to the next commandTbl; ignoring the tag index
      if commandTbl[3] == "forced" then
        return nil
      end
      return self:next()
    end
    logger.warn("Dialogue["..self.dirName.."@"..self.index.."] could not find tag:", tostring(gt))
    if commandTbl[3] == "forced" then
      return nil
    end
    return self:next()
  end,
  ["tag"] = _ignoreCommand,
  ["setState"] = function(self, commandTbl)
    self.currentState = commandTbl[2]
    return self:next()
  end,
  ["setObjective"] = function(self, commandTbl)
    self.quest.objective = commandTbl[2]
    return self:next()
  end,
  ["setQuestNPC"] = function(self, commandTbl)
    self.quest.npc = commandTbl[2]
    return self:next()
  end,
  ["questFinished"] = function(self)
    self.quest:finish()
    return self:next()
  end,
  ["teleportToDoor"] = function(self, commandTbl, commandType)
    local character = characterManager.get(commandTbl[2])
    if not character then
      logger.warn("Dialogue["..self.dirName.."@"..self.index.."]: Couldn't find character to", commandType, ", gave character ID:", commandTbl[2])
      return self:next()
    end
    local door = worldManager.getDoor(commandTbl[3])
    if not door then
      logger.warn("Dialogue["..self.dirName.."@"..self.index.."]: Couldn't find door to", commandType, ", gave door ID:", commandTbl[3])
      return self:next()
    end
    local world, x, z, flip
    if door.worldA == commandTbl[4] then
      world = door.worldA
      x, z, flip = unpack(door.entryA)
    elseif door.worldB == commandTbl[5] then
      world = door.worldB
      x, z, flip = unpack(door.entryB)
    end
    if not world then
      logger.warn("Dialogue["..self.dirName.."@"..self.index.."]: Given door[", commandTbl[3], "] doesn't have matching door in world:", commandTbl[3])
      return self:next()
    end
    character:setWorld(world, x, z, flip)
    return self:next()
  end,
  ["useDoor"] = function(self, commandTbl, commandType)
    local character = characterManager.get(commandTbl[2])
    if not character then
      logger.warn("Dialogue["..self.dirName.."@"..self.index.."]: Couldn't find character to", commandType, ", gave character ID:", commandTbl[2])
      return self:next()
    end
    local door = worldManager.getDoor(commandTbl[3])
    if not door then
      logger.warn("Dialogue["..self.dirName.."@"..self.index.."]: Couldn't find door to", commandType, ", gave door ID:", commandTbl[3])
      return self:next()
    end
    local world, x, z, flip
    if door.worldA == character.world then
      world = door.worldB
      x, z, flip = unpack(door.entryB)
    elseif door.worldB == character.world then
      world = door.worldA
      x, z, flip = unpack(door.entryA)
    end
    if not world then
      logger.warn("Dialogue["..self.dirName.."@"..self.index.."]: Given door[", commandTbl[3], "] doesn't have matching world that character is in:", character.world)
      return self:next()
    end
    local tween = door:use(character)
    self.ready = false
    tween:oncomplete(function()
      self.ready = true
    end)
    return nil
  end,
  ["moveX"] = function(self, commandTbl, commandType)
    local character = characterManager.get(commandTbl[2])
    if not character then
      logger.warn("Dialogue["..self.dirName.."@"..self.index.."]: Couldn't find character to", commandType, ", gave character ID:", commandTbl[2])
      return self:next()
    end
    local preX = character.x
    local totalTime = math.abs(commandTbl[3] / (character.speedX * (commandTbl[2] ~= "player" and 0.8 or 1)))
    character:moveX(0)
    local previous = 0
    local tween
    tween = flux.to({}, totalTime, {})
      :onupdate(function()
          local current = commandTbl[3] * tween.progress 
          local delta = current - previous
          previous = current
          character:moveX(delta)
        end)
      :oncomplete(function()
        self.ready = true
        character:moveX(0)
      end)
    self.ready = false
    return nil
  end,
  ["moveZ"] = function(self, commandTbl, commandType)
    local character = characterManager.get(commandTbl[2])
    if not character then
      logger.warn("Dialogue["..self.dirName.."@"..self.index.."]: Couldn't find character to", commandType, ", gave character ID:", commandTbl[2])
      return self:next()
    end
    if character.zTween and character.zTween.progress < 1 then
      logger.warn("Dialogue["..self.dirName.."@"..self.index.."]: Tried to moveZ character while already in motion. Character:", commandTbl[2])
      -- As we neither are finished, we cannot skip; we must await for the character to no longer be Ztweening
      self.index = self.index - 1
      return nil
    end
    character:moveZ(commandTbl[3])
    self.ready = false
    character.zTween:oncomplete(function()
      self.ready = true
    end)
    return nil
  end,
  ["freeze"] = function(self, commandTbl, commandType)
    local character = characterManager.get(commandTbl[2])
    if not character then
      logger.warn("Dialogue["..self.dirName.."@"..self.index.."]: Couldn't find character to", commandType, ", gave character ID:", commandTbl[2])
      return self:next()
    end
    character.canMove = false
    character:moveX(0)
    logger.info("Dialogue: Froze character,", commandTbl[2])
    return self:next()
  end,
  ["unfreeze"] = function(self, commandTbl, commandType)
    local character = characterManager.get(commandTbl[2])
    if not character then
      logger.warn("Dialogue["..self.dirName.."@"..self.index.."]: Couldn't find character to", commandType, ", gave character ID:", commandTbl[2])
      return self:next()
    end
    character.canMove = true
    character:moveX(0)
    logger.info("Dialogue: Unfroze character,", commandTbl[2])
    return self:next()
  end,
  ["addItem"] = function(self, commandTbl)
    for _, item in ipairs(commandTbl[2]) do
      inventory.addItem(item)
    end
    return self:next()
  end,
  ["choice"] = function(self, commandTbl)
    self.waitForChoice = true
    self.choice = commandTbl[2]
    return nil
  end,
  ["print"] = function(self, commandTbl)
    print(commandTbl[2])
    return self:next()
  end
}

dialogue.next = function(self)
  self.ran = true
  if not self.ready or self.waitForChoice then
    return nil
  end

  self.index = self.index + 1
  if self.index > #self.definition then
    self.index = #self.definition
    self.isFinished = true
    return nil
  end
  local commandTbl = self.definition[self.index]
  if type(commandTbl) == "string" then
    return commandTbl -- implied "text" command
  end
  if type(commandTbl) ~= "table" then
    logger.warn("Hit non-string, non-table value in dialogue["..self.dirName.."@"..self.index.."]. Found type:", type(command))
    return self:next()
  end
  local commandType = commandTbl[1]
  if type(commandType) ~= "string" then
    logger.warn("Hit non-string commandType in dialogue["..self.dirName.."@"..self.index.."]. Found type:", type(commandType))
    return self:next()
  end
  local func = commandLookup[commandType]
  if func then
    return func(self, commandTbl, commandType)
  end
  logger.warn("Unrecognised commandType:", commandType, ", in dialogue["..self.dirName.."@"..self.index.."]")
  return self:next()
end

dialogue.makeChoice = function(self, index)
  if not (index >= 1 and index <= #self.choice) then
    logger.warn("Dialogue choice: Tried to pick invalid choice. Index:", index)
    return -- invalid
  end
  self.waitForChoice = false
  local tag = self.choice[index][2]
  self.choice = nil
  commandLookup["goto"](self, { "goto", tag, "forced" })
  audioManager.play("audio.ui.click")
end

dialogue.hasFinished = function(self)
  return self.isFinished == true and self.ready == true and self.waitForChoice == false
end

dialogue.canContinue = function(self)
  return self:hasFinished() and self.currentState ~= nil and self.tagLookup[self.currentState] ~= nil
end

dialogue.continue = function(self)
  if self:canContinue() then
    local index = self.tagLookup[self.currentState]
    if index then
      self.index = index
    else
      logger.warn("Dialogue["..self.dirName.."@"..self.index.."]: Cannot find tag for currentState:", self.currentState)
    end
    self.isFinished = false
  elseif self.ran then
    self:reset()
  end
end

dialogue.reset = function(self)
  self.index = 0
  self.isFinished = false
  self.speaker = nil
  self.currentState = nil
  self.ready = true
  self.waitForChoice = false
  self.ran = false
end

local dialogueManager = {
  dialogue = { }
}

dialogueManager.parse = function(definition, dirName)
  local parsedDialogue = {
    definition = definition,
    dirName = dirName,
    tagLookup = { },
    currentState = nil,
    ready = true,
    waitForChoice = false,
    ran = false,
  }
  setmetatable(parsedDialogue, dialogue)
  parsedDialogue:reset() -- set defaults

  local actualIndex = 0
  for index, command in ipairs(definition) do
    if type(command) == "table" then
      if command[1] == "tag" then
        parsedDialogue.tagLookup[command[2]] = index
      elseif command[1] == "if" then
        local func
        if command[2] == "item" then
          func = function()
            local item = inventory.get(command[3])
            return item ~= nil and item[command[4]](item, unpack(command, 5, #command-1))
          end
        end
        if type(func) == "function" then
          definition[index] = {
            "if_true",
            func,
            command[#command], -- goto tag
          }
        end
      end
    end
  end

  return parsedDialogue
end

return dialogueManager