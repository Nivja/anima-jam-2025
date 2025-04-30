local logger = require("util.logger")

local quest = { }
quest.__index = quest

quest.finish = function()
  logger.warn("todo quest.finish")
end

local dialogueManager = require("src.dialogueManager")

local questManager = { }

questManager.parse = function(definition)
  local newQuest = setmetatable(definition, quest)

  if not newQuad.dialogue then
    logger.warn("Found quest without any dialogue. ID:", newQuad.id)
  else
    newQuest.dialogue = dialogueManager.parse(newQuest.dialogue)
  end

  return newQuad
end

questManager.load = function(dir)
  for _, item in ipairs(lfs.getDirectoryItems(dir)) do
    local path = dir .. "/" .. item
    local name = file.getFileName(item)
    local chunk, errorMessage = lfs.load(path)
    if not chunk then
      error("Error loading quest: "..path.."\nError Message: "..tostring(errorMessage))
      return
    end
    local definition = chunk()
    definition.id = definition.id or name
    questManager.quests[name] = questManager.parse(definition)
  end
end

questManager.unlockQuest = function(questId)
  logger.warn("TODO unlock quest")
end

return questManager