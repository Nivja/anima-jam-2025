local lfs = love.filesystem

local logger = require("util.logger")
local file = require("util.file")

local dialogueManager = require("src.dialogueManager")

local questManager = {
  locked = { },
  unlocked = { },
  active = { },
  finished = { },
  activeQuestScene = nil,
  questOrder = { },
}

local quest = { }
quest.__index = quest

quest.finish = function(self)
  questManager.finishQuest(self)
end

questManager.parse = function(definition)
  local newQuest = setmetatable(definition, quest)

  if not newQuest.dialogue then
    logger.warn("Found quest without any dialogue. ID:", newQuest.id)
  else
    newQuest.dialogue = dialogueManager.parse(newQuest.dialogue)
  end

  return newQuest
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
    questManager.locked[name] = questManager.parse(definition)
  end
end

-- Returns quest, and it's state [quest, state]
questManager.get = function(questId)
  for _, state in ipairs({ "locked", "unlocked", "active", "finished" }) do
    for id, quest in pairs(questManager[state]) do
      if id == questId then
        return quest, state
      end
    end
  end
  return nil, nil
end

local transitionQuest = function(questId, fromState, toState)
  local fromStateTbl = questManager[fromState]
  local toStateTbl = questManager[toState]

  local quest = fromStateTbl[questId]
  if not quest then
    logger.warn("QuestManager: Failed to transition quest '"..tostring(questId).."'. Couldn't be found in state: '"..tostring(fromState).."'")
    return false
  end
  fromStateTbl[questId] = nil
  toStateTbl[questId] = quest
  return true
end

questManager.unlockQuest = function(questId)
  transitionQuest(questId, "locked", "unlocked")
  table.insert(questManager.questOrder, questId)
end

questManager.activateQuest = function(questId)
  transitionQuest(questId, "unlocked", "active")
end

questManager.finishQuest = function(questId)
  transitionQuest(questId, "active", "finished")
end

local checkTime = 0.2 -- How often to check
questManager.update = function(dt)
  if not questManager.activeQuestScene then
    for _, quest in pairs(questManager.active) do
      if quest.repeatCheck and love.timer.getTime() - quest.lastCheck > checkTime then
        if quest.dialogue:canContinue() then
          local text = quest.dialogue:next()
          -- send to dialogue system; but handle rest elsewhere
          questManager.activeQuestScene = quest
          break
        end
      end
    end
  else
    -- activeQuestScene; handle dialogue until finished 
  end
end

questManager.draw = function()

end

return questManager