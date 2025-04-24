local lfs = love.filesystem

local logger = require("util.logger")
local file = require("util.file")

local inventory = require("src.inventory")

local dialogue = { }
dialogue.__index = dialogue

dialogue.next = function(self)
  self.index = self.index + 1
  if self.index > #self.definition then
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
  end
  logger.warn("Unrecognised commandType:", commandType, ", in dialogue["..self.dirName.."@"..self.index.."]")
  return self:next()
end

dialogue.reset = function(self)
  self.index = 0
  self.isFinished = false
  self.speaker = nil
end

local dialogueManager = {
  dialogue = { }
}

dialogueManager.parse = function(definition, dirName)
  local parsedDialogue = {
    definition = definition,
    dirName = dirName,
    tagLookup = { },
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

  for index, command in ipairs(definition) do

  end

  return parsedDialogue
end

dialogueManager.load = function(dir)
  for _, item in ipairs(lfs.getDirectoryItems(dir)) do
    local path = dir .. "/" .. item
    local name = file.getFileName(item)
    local chunk, errorMessage = lfs.load(path)
    if not chunk then
      error("Error loading dialogue: ", path, "\nError Message: ", errorMessage)
      return
    end
    local definition = chunk()
    dialogueManager.dialogue[name] = dialogueManager.parse(definition, path)
  end
end

return dialogueManager