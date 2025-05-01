local lg = love.graphics

local cursor = require("util.cursor")
local input = require("util.input")

local createPlaneForQuad = require("src.createPlaneForQuad")

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

local xRange = 1.4
requestBoard.interact = function(_, x, z)
  if not requestBoard.show and
     requestBoard.interactX - xRange < x and
     requestBoard.interactX + xRange > x and
     math.abs(z - requestBoard.interactZ) < 0.1 then
    canMovePlayer(false)
    requestBoard.show = true
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

local inside = false
local closeButtonX, closeButtonY = 0, 0
requestBoard.update = function(dt, scale)
  if not requestBoard.show then
    return
  end

  if input.baton:pressed("accept") and not love.mouse.isDown(1) then
    requestBoard.show = false
    canMovePlayer(true)
    cursor.switch("arrow")
    inside = false
  end

  local mx, my = love.mouse.getPosition()
  local dx = mx - closeButtonX
  local dy = my - closeButtonY

  if (dx^2+dy^2) <= ((closeButton:getWidth() * scale)/2)^2 then
    inside = true
    cursor.switch("hand")
    if input.baton:pressed("accept") then
      requestBoard.show = false
      canMovePlayer(true)
      cursor.switch("arrow")
      inside = false
    end
  elseif inside == true then
    cursor.switch("arrow")
    inside = false
  end

end

requestBoard.drawUI = function(scale)
  if requestBoard.show then
    lg.push()
    local tw, th = lg.getDimensions()
    local w, h = 350 * scale, 400 * scale
    lg.translate(tw/2-w/2, th/2-h/2)
    slice:draw(w, h)
    local bw, bh = closeButton:getDimensions()
    lg.translate(w/2, h)
    lg.draw(closeButton, 0, 0, 0, scale, scale, bw/2, bh/2)
    closeButtonX, closeButtonY = lg.transformPoint(0, 0)
    lg.pop()
  end
end

return requestBoard