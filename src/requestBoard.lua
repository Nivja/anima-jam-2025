local lg = love.graphics

local cursor = require("util.cursor")
local input = require("util.input")

local createPlaneForQuad = require("src.createPlaneForQuad")
local questManager = require("src.questManager")

local slice = require("ui.nineSlice").new("assets/UI/panel_brown_corners_a.png", 57, 70, 57, 70)
slice.texture:setFilter("nearest")

local requestBoard = {
  name = "request board",
  show = false,
}

table.insert(require("src.worldManager").interactable, requestBoard)

local canMovePlayer = function(boolean)
  local playerChar = require("src.characterManager").get("player")
  playerChar.canMove = boolean
  playerChar:moveX(0)
end

local index = nil

local xRange = 1.4
requestBoard.interact = function(_, x, z)
  if not requestBoard.show and
     requestBoard.interactX - xRange < x and
     requestBoard.interactX + xRange > x and
     math.abs(z - requestBoard.interactZ) < 0.1 then
    canMovePlayer(false)
    requestBoard.show = true
    index = nil
    return true -- consume the event
  end
  return false
end

local cw, ch = 2*500, 0.25*500

local interactSign
requestBoard.set = function(x, z, interactX, interactZ)
  interactSign:setTranslation(x or 0, 2.1 + (ch/1000), z or 0)

  requestBoard.interactX = interactX or x or 0
  requestBoard.interactZ = interactZ or z or 0
end

local signCanvas = lg.newCanvas(cw, ch)
lg.push("all")
  lg.setCanvas(signCanvas)
  lg.clear(0,0,0,0)
  local font = require("util.ui").getFont(100, "fonts.regular.bold", 1)
  lg.setColor(1,1,1,1)
  local str = "Press   /  /  "
  lg.translate(cw/2-(font:getWidth(str)/2), 0)
  lg.print(str, font)
  local t = lg.newImage("assets/UI/input/pc/keyboard_space_icon_outline.png")
  x = font:getWidth("Press ")
  local w = font:getWidth(" ")
  x = x
  lg.draw(t, x, 0, 0, 2)
  local t = lg.newImage("assets/UI/input/pc/keyboard_return_outline.png")
  x = x + w * 3
  lg.draw(t, x, 0, 0, 2)
  local t = lg.newImage("assets/UI/input/steamdeck/steamdeck_button_a_outline.png")
  x = x + w * 3
  lg.draw(t, x, 0, 0, 2)
  t = nil
lg.pop()

interactSign = createPlaneForQuad(0, 0, cw, ch, signCanvas)

requestBoard.draw = function(playerX, playerZ)
  if requestBoard.interactX - xRange < playerX and requestBoard.interactX + xRange > playerX and requestBoard.interactZ - 1 <= playerZ then
    if math.abs(playerZ - requestBoard.interactZ) < 0.1 then
      lg.setColor(0,0,0,1)
    else
      lg.setColor(.2,.2,.2,.7)
    end
    interactSign:draw()
  end
  lg.setColor(1,1,1,1)
end

local closeButton = lg.newImage("assets/UI/checkbox_grey_cross.png")
-- closeButton:setFilter("nearest")

local inside = false, nil
local closeButtonX, closeButtonY = 0, 0
requestBoard.update = function(dt, scale, isGamepadActive)
  if not requestBoard.show then
    return
  end

  if isGamepadActive == true and index == nil then
    for _, questId in ipairs(questManager.questOrder) do
      local quest = questManager.unlocked[questId]
      if quest then
        index = questId
        break
      end
    end
  end

  local mx, my = love.mouse.getPosition()

  if isGamepadActive == true and index ~= nil then
    local menuUp = input.baton:pressed("menuNavUp") and 1 or 0
    local menuDown = input.baton:pressed("menuNavDown") and 1 or 0
    local menuDelta = menuUp - menuDown
    if menuDelta ~= 0 then
      local first, previous, found = nil, nil, false
      for i, questId in ipairs(questManager.questOrder) do
        local quest = questManager.unlocked[questId]
        if quest then
          if not first then
            first = questId
          end
          if menuDelta == -1 and previous == index then
            index = questId
            found = true
            break
          end
          if menuDelta == 1 and questId == index and previous ~= nil then
            index = previous
            found = true
            break
          end
          previous = questId
        end
      end
      if not found then
        if previous == index then
          index = first
        elseif first == index then
          index = previous
        end
      end
    end
  elseif not isGamepadActive then
    local tw, th = lg.getDimensions()
    local w, h = 350, 400
    local x, y = tw/2-(w*scale)/2, th/2-(h*scale)/2
    x, y = x + slice.width[1]*scale/2, y + slice.height[1]*scale/1.3

    local questWidth = (w - slice.width[1]/2 - slice.width[3]/2) * scale

    local titleFont = require("util.ui").getFont(20, "fonts.regular.bold", scale)
    local height = titleFont:getHeight() * 3

    local found = false
    for _, questId in ipairs(questManager.questOrder) do
      local quest = questManager.unlocked[questId]
      if quest then
        if mx + 5 > x and mx < x + questWidth - 10 and
           my + 5 > y and my < y + height - 10 then
          index = questId
          found = true
          cursor.switch("hand")
          break
        end
        y = y + height
      end
    end
    if not found then
      index = nil
      if not inside then
        cursor.switch("arrow")
      end
    end
  end

  if input.baton:pressed("reject") and not love.mouse.isDown(1) then
    requestBoard.show = false
    canMovePlayer(true)
    cursor.switch("arrow")
    inside = false
    index = nil
  end

  local dx = mx - closeButtonX
  local dy = my - closeButtonY

  if index ~= nil and input.baton:pressed("accept") then
    questManager.activateQuest(index)
    index = nil
    return
  end

  if (dx^2+dy^2) <= ((closeButton:getWidth() * scale)/2)^2 then
    inside = true
    cursor.switch("hand")
    if input.baton:pressed("reject") or love.mouse.isDown(1) then
      requestBoard.show = false
      canMovePlayer(true)
      cursor.switch("arrow")
      inside = false
      index = nil
    end
  elseif inside == true then
    cursor.switch("arrow")
    inside = false
  end

end

local drawQuest = function(quest, width, scale, isActive)
  local titleFont = require("util.ui").getFont(20, "fonts.regular.bold", scale)
  local subtitleFont = require("util.ui").getFont(12, "fonts.regular", scale)
  local height = titleFont:getHeight() * 3
  lg.push("all")
  if index~= nil and index == quest.id then
    lg.setColor(1,.5,0,1)
    lg.rectangle("fill", 0, 0, width, height)
  end
  lg.setColor(.9,.85,.72)
  if isActive then
    lg.setColor(.8,.9,.62)
  end
  lg.rectangle("fill", 5, 5, width-10, height-10)
  lg.setColor(0,0,0,1)
  if isActive then
    lg.setColor(.1,.1,.1,1)
  end
  local title = quest.title or "UNKNOWN"
  local description = quest.description or "UNKNOWN"
  lg.print(title, titleFont, (width-10)/2-titleFont:getWidth(title)/2, ((height-10)/4)*1-titleFont:getHeight()/2)
  lg.print(description, subtitleFont, (width-10)/2-subtitleFont:getWidth(description)/2, ((height-10)/4)*3-subtitleFont:getHeight()/2)
  lg.pop()
  return height
end

requestBoard.drawUI = function(scale)
  if requestBoard.show then
    lg.push()
    local tw, th = lg.getDimensions()
    local w, h = 350, 400
    lg.translate(tw/2-(w*scale)/2, th/2-(h*scale)/2)
    lg.push()
    lg.scale(scale)
    slice:draw(w, h)
    lg.pop()

    lg.push("all")
    lg.translate(slice.width[1]*scale/2, slice.height[1]*scale/1.3)

    local questWidth = (w - slice.width[1]/2 - slice.width[3]/2) * scale

    for _, questId in ipairs(questManager.questOrder) do
      local quest = questManager.unlocked[questId]
      if quest then
        local h = drawQuest(quest, questWidth, scale)
        lg.translate(0, h)
      end
    end
    for _, questId in ipairs(questManager.questOrder) do
      local quest = questManager.active[questId]
      if quest then
        local h = drawQuest(quest, questWidth, scale, true)
        lg.translate(0, h)
      end
    end
    lg.pop()

    local bw, bh = closeButton:getDimensions()
    lg.translate(w*scale/2, h*scale)
    lg.draw(closeButton, 0, 0, 0, scale, scale, bw/2, bh/2)
    closeButtonX, closeButtonY = lg.transformPoint(0, 0)
    lg.pop()
  end
end

return requestBoard