local lfs = love.filesystem

local logger = require("util.logger")
local file = require("util.file")
local flux = require("libs.flux")

local characterManager = require("src.characterManager")
local inventory = require("src.inventory")

local dialogue = { }
dialogue.__index = dialogue

dialogue.next = function(self)
  if not self.ready then
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
  if commandType == "end" then
    self.ready = true
    self.isFinished = true
    return nil
  elseif commandType == "setCharacter" then
    self.speaker = commandTbl[2]
    return self:next()
  elseif commandType == "if_true" then
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
  elseif commandType == "goto" then
    local gt = commandTbl[2]
    local newIndex = self.tagLookup(tostring(gt))
    if newIndex then
      self.index = newIndex -- this jumps straight to the next commandTbl; ignoring the tag index
      return self:next()
    end
    logger.warn("Dialogue["..self.dirName.."@"..self.index.."] could not find tag:", tostring(gt))
    return self:next()
  -- Command Types that can be ignored
  elseif commandType == "tag" then 
    return self:next()
  elseif commandType == "setState" then
    self.currentState = commandTbl[2]
    return self:next()
  elseif commandType == "setObjective" then
    self.quest.objective = commandTbl[2]
    return self:next()
  elseif commandType == "setQuestNPC" then
    self.quest.npc = commandTbl[2]
    return self:next()
  elseif commandType == "questFinished" then
    self.quest:finish()
    return self:next()
  elseif commandType == "teleportToDoor" then
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
  elseif commandTbl == "useDoor" then
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
  elseif commandType == "moveX" then
    local character = characterManager.get(commandTbl[2])
    if not character then
      logger.warn("Dialogue["..self.dirName.."@"..self.index.."]: Couldn't find character to", commandType, ", gave character ID:", commandTbl[2])
      return self:next()
    end
    local preX = character.x
    local totalTime = commandTbl[3] / character.speedX
    character:moveX(0)
    local tween
    tween = flux.to({}, totalTime, {})
      :onupdate(function()
          local delta = tween.progress 
          character:moveX(delta)
        end)
      :oncomplete(function()
        self.ready = true
        -- character.x = preX + commandTbl[3]
        character:moveX(0)
      end)
    self.ready = false
    return nil
  elseif commandType == "moveZ" then
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
  end
  logger.warn("Unrecognised commandType:", commandType, ", in dialogue["..self.dirName.."@"..self.index.."]")
  return self:next()
end

dialogue.hasFinished = function(self)
  return self.isFinished == true and self.ready == true
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
  else
    self:reset()
  end
end

dialogue.reset = function(self)
  self.index = 0
  self.isFinished = false
  self.speaker = nil
  self.currentState = nil
  self.ready = true
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