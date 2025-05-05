local lfs, lg = love.filesystem, love.graphics

local syslText = require("libs.sysl-text")
local logger = require("util.logger")
local cursor = require("util.cursor")
local input = require("util.input")
local lang = require("util.lang")
local file = require("util.file")
local ui = require("util.ui")

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

questManager.parse = function(definition, dirName)
  local newQuest = setmetatable(definition, quest)

  if not newQuest.dialogue then
    logger.warn("Found quest without any dialogue. ID:", newQuest.id)
  else
    newQuest.dialogue = dialogueManager.parse(newQuest.dialogue, dirName)
    newQuest.dialogue.quest = newQuest
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
    questManager.locked[name] = questManager.parse(definition, item)
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
  return true, quest
end

questManager.unlockQuest = function(questId)
  transitionQuest(questId, "locked", "unlocked")
  table.insert(questManager.questOrder, questId)
  logger.info("QuestManager: Unlocked quest,", questId)
end

questManager.activateQuest = function(questId, execute)
  local _, quest = transitionQuest(questId, "unlocked", "active")
  logger.info("QuestManager: Activated quest,", questId)

  if execute then
    if questManager.activeQuestScene then
      logger.warn("QuestManager: Tried to activate & execute quest; but a quest is already actively running. Conflict:", questId, ", currently running:", questManager.activeQuestScene)
      return
    end
    questManager.activeQuestScene = quest
  end
end

questManager.finishQuest = function(questId)
  transitionQuest(questId, "active", "finished")
  logger.info("QuestManager: Finished quest,", questId)
end

local progress, flip = 0, true
local speaker = nil
local choiceIndex = nil

questManager.resize = function(w, h, scale)
  local text, timer, pausedTimer, printTimer, currentCharacter, wait
  if questManager.box then
    text = questManager.box.__ogText
    timer = questManager.box.timer_animation
    pausedTimer = questManager.box.timer_pause
    printTimer = questManager.box.timer_print
    currentCharacter = questManager.box.current_character
    wait = questManager.box.waitforinput
  end
  local font, size = ui.getFont(20, "fonts.regular", scale)
  questManager.box = syslText.new("center", {
    autotags = "",
    font = font,
    color = { 0, 0, 0, 1 },
    shadow_color = { 1, 1, 1, 1 },
    print_speed = 0.02,
    adjust_line_height = -1,
    default_strikethrough_position = 0,
    default_underline_position = 0,
    character_sound = false,
    sound_number = 0,
    sound_every = 2,
    default_warble = 3,
  })
  if text then
    questManager.displayText(speaker, text, scale)
  end
  if timer then
    questManager.box.timer_animation = timer
    questManager.box.timer_pause = pausedTimer
    questManager.box.timer_print = printTimer
    questManager.box.current_character = currentCharacter
    questManager.box.waitforinput = wait
    questManager.box:update(0)
  end
end

local settings = require("util.settings")
questManager.displayText = function(sp, text, scale)
  speaker = sp or nil
  if type(speaker) ~= "string" or #speaker == 0 then
    speaker = nil
  end

  questManager.box.__ogText = text
  text = text .. "[waitforinput]"

  local wsize = settings._default.client.windowSize
  local w = (wsize.width-20) * scale
  questManager.box:send(text, w)

  progress, flip = 0, true
end

questManager.skipText = function()
  local box = questManager.box
  box.current_character = #box.table_string
end

questManager.clearText = function()
  local box = questManager.box
  box:send("")
  box.__ogText = nil
  speaker = nil
end

local inside = false

local checkTime = 0.2 -- How often to check
questManager.update = function(dt, scale, isGamepadActive)
  local consumedInput = false

  if flip then
    progress = progress + dt * 2
    if progress >= 1 then
      progress = 1
      flip = false
    end
  else
    progress = progress - dt * 2
    if progress <= 0 then
      progress = 0
      flip = true
    end
  end

  if not questManager.activeQuestScene then
    for _, quest in pairs(questManager.active) do
      if quest.repeatCheck and love.timer.getTime() - quest.lastCheck > checkTime then
        if quest.dialogue:canContinue() then
          print("TODO quest Manager repeat check")
          quest.dialogue:continue()
          questManager.activeQuestScene = quest
          break
        end
      end
    end
  else
    -- activeQuestScene; handle dialogue until finished
    local quest = questManager.activeQuestScene
    local box = questManager.box

    -- if quest.dialogue:canContinue() then
    if box:is_finished() and not box.waitforinput and not quest.dialogue.waitForChoice then
      local text = quest.dialogue:next()
      if text ~= nil then
        questManager.displayText(quest.dialogue.speaker, text, scale)
      elseif not text and quest.dialogue.waitForChoice then
        -- do nothing; handled else where
      elseif not text and quest.dialogue:hasFinished() then
        questManager.activeQuestScene = nil
        questManager.clearText()
      end
    end
  
    if not quest.dialogue.waitForChoice then
      if input.baton:pressed("accept") then
        if not box:is_finished() then
          questManager.skipText()
          consumedInput = true
        elseif box:is_finished() and box.waitforinput then
          questManager.box:continue()
          consumedInput = true
        end
      end
    else
      if isGamepadActive == true and choiceIndex == nil then
        local menuUp = input.baton:pressed("menuNavUp") and 1 or 0
        local menuDown = input.baton:pressed("menuNavDown") and 1 or 0
        local menuDelta = menuUp - menuDown
        if menuDelta == -1 then
          choiceIndex = #quest.dialogue.choice
        else
          choiceIndex = 1
        end
      elseif isGamepadActive == true and choiceIndex ~= nil then
        local menuUp = input.baton:pressed("menuNavUp") and 1 or 0
        local menuDown = input.baton:pressed("menuNavDown") and 1 or 0
        local menuDelta = menuUp - menuDown
        if menuDelta ~= 0 then
          choiceIndex = choiceIndex + menuDelta
          if choiceIndex <= 0 then
            choiceIndex = #quest.dialogue.choice
          elseif choiceIndex > #quest.dialogue.choice then
            choiceIndex = 1
          end
        end

        if choiceIndex ~= nil and input.baton:pressed("accept") then
          quest.dialogue:makeChoice(choiceIndex)
          consumedInput = true
        end
      elseif not isGamepadActive then
        local w, _ = lg.getDimensions()
        local mx, my = love.mouse.getPosition()

        local font = ui.getFont(24, "fonts.regular.bold", scale)
        local choiceFont = ui.getFont(18, "fonts.regular", scale)
        local choiceFontHeight = choiceFont:getHeight()

        local y = box.get.height+80*scale
        y = y + font:getHeight()+10*scale

        local found = false
        for index, choice in ipairs(quest.dialogue.choice) do
          local textWidth = choiceFont:getWidth(choice[1])
          local x = w/2-textWidth/2
          local marginX = 5*scale
          if mx > x-marginX and mx < x + textWidth + marginX * 2 and
            my > y and my < y + choiceFontHeight then
            choiceIndex = index
            found = true
            inside = true
            cursor.switch("hand")
            break
          end
          y = y + choiceFontHeight+10*scale
        end
        if not found then
          choiceIndex = nil
          if inside then
            inside = false
            cursor.switch("arrow")
          end
        end

        if choiceIndex ~= nil and input.baton:pressed("accept") then
          quest.dialogue:makeChoice(choiceIndex)
          consumedInput = true
          if inside then
            cursor.switch("arrow")
            inside = false
          end
        end
      end
    end
  end

  questManager.box:update(dt)

  return consumedInput
end

questManager.drawUI = function(scale)
  local w, h = lg.getDimensions()
  if not questManager.box then
    questManager.resize(w, h, scale)
  end
  local box = questManager.box
  lg.push("all")
  if speaker then
    local text = lang.getText("speaker."..speaker)
    if text then
      local font = ui.getFont(24, "fonts.regular.bold", scale)
      lg.push()
      local textWidth, textHeight = font:getWidth(text), font:getHeight()
      lg.translate(w/2-textWidth/2, 10*scale)
      local r, padding = 5*scale, 5*scale
      lg.setColor(.2,.2,.2,1)
      lg.rectangle("fill", 0-padding, 3*scale-padding, textWidth+padding*2, textHeight+padding*2, r)
      lg.rectangle("fill", 0-padding, 5*scale-padding, textWidth+padding*2, textHeight-r+padding*2)
      lg.setColor(.3,.3,.3,1)
      lg.rectangle("fill", -20*scale, 25*scale, textWidth+40*scale, textHeight, r)
      lg.setColor(1,1,1,1)
      lg.print(text, font, 0, -7*scale)
      lg.pop()
    end
  end
  local bw, bh = box.get.width, box.get.height
  if bw ~= 0 and bh ~= 0 then
    lg.push()
    lg.translate(w/2-bw/2, 40*scale)
    lg.setColor(.3,.3,.3,1)
    lg.rectangle("fill", -2*scale, -2*scale, bw+4*scale, bh+4*scale, 5*scale)
    lg.setColor(1,1,1,1)
    lg.rectangle("fill", 0, 0, bw, bh, 5*scale)
    box:draw(0,0)
    if box:is_finished() and box.waitforinput then
      lg.push()
      lg.translate(bw/2, bh+(10*scale)+(progress*3*scale))
      if questManager.activeQuestScene and not questManager.activeQuestScene.dialogue.waitForChoice then
        lg.setColor(.1,.1,.1,1)
        lg.rotate(math.rad(90))
        lg.circle("fill", 0, 0, 10*scale, 3)
      end
      lg.pop()
    end
    lg.pop()
  end
  lg.push()
  if questManager.activeQuestScene then
    local quest = questManager.activeQuestScene
    if quest.dialogue.waitForChoice then
      lg.translate(0, bh+80*scale)
      local text = "Reply"
      local font = ui.getFont(24, "fonts.regular.bold", scale)
      local choiceFont = ui.getFont(18, "fonts.regular", scale)
      local textWidth, textHeight = font:getWidth(text), font:getHeight()
      lg.push()
      local bgWidth = ((textWidth+25*scale)/3)*2
      lg.setColor(.2,.2,.2,.7)
      lg.rectangle("fill", w/2-bgWidth/2, 0, bgWidth, textHeight+10*scale+(choiceFont:getHeight()+10*scale)*#quest.dialogue.choice, 10*scale)
      lg.pop()
      lg.push()
      lg.setColor(.3,.3,.3,1)
      lg.rectangle("fill", w/2-(textWidth+200*scale)/2, textHeight/2-5*scale, textWidth+200*scale, 10*scale, 5*scale)
      lg.rectangle("fill", w/2-(textWidth+50*scale)/2, 0, textWidth+50*scale, textHeight, 5*scale)
      lg.setColor(1,1,1,1)
      local antiPadding = 2*scale
      lg.rectangle("fill", w/2-(textWidth+50*scale)/2+antiPadding, antiPadding, textWidth+50*scale-antiPadding*2, textHeight-antiPadding*2, 5*scale)
      lg.setColor(0,0,0,1)
      lg.print(text, font, w/2-textWidth/2, 0)
      lg.pop()
      lg.translate(0, textHeight+10*scale)
      for index, choice in ipairs(quest.dialogue.choice) do
        local text = choice[1]
        lg.push()
        local choiceFont = ui.getFont(18, "fonts.regular", scale)
        local textWidth, textHeight = choiceFont:getWidth(text), choiceFont:getHeight()
        lg.translate(w/2-textWidth/2, 0)
        lg.setColor(.3,.3,.3,1)
        local padding, marginX = 2*scale, 5*scale
        if index == choiceIndex then
          padding = 4 * scale
          lg.setColor(1,.5,0,1)
        end
        lg.rectangle("fill", -padding-marginX, -padding, textWidth+padding*2+marginX*2, textHeight+padding*2, 5*scale)
        lg.setColor(1,1,1,1)
        lg.rectangle("fill", -marginX, 0, textWidth+marginX*2, textHeight, 5*scale)
        lg.setColor(0,0,0,1)
        lg.print(text, choiceFont)
        lg.pop()
        lg.translate(0, textHeight+10*scale)
      end
    end
  end
  lg.pop()
  lg.pop()
  lg.setColor(1,1,1,1)
end

return questManager