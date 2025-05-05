local lg = love.graphics

local settings = require("util.settings")
local cursor = require("util.cursor")
local input = require("util.input")

local workstation = {
  world = "workshop",
  show = false,
}

table.insert(require("src.worldManager").interactable, workstation)

local canMovePlayer = function(boolean)
  local playerChar = require("src.characterManager").get("player")
  playerChar.canMove = boolean
  playerChar:moveX(0)
end

local xRange, zRange = 1, 0.5
workstation.interact = function(_, x, z)
  if not workstation.show and
    workstation.interactX - xRange < x and
    workstation.interactX + xRange > x and
    workstation.interactZ - zRange <= z and
    workstation.interactZ + zRange >= z then
    canMovePlayer(false)
    workstation.show = true
    return true -- consumed
  end
  return false
end

local interactSign = require("src.interactSign")()
workstation.set = function(x, z, interactX, interactZ)
  interactSign:setTranslation(x or 0, 2.1 + (0.25*500/1000), z or 0)

  workstation.interactX = interactX or 0
  workstation.interactZ = interactZ or 0
end

local base = lg.newImage("assets/UI/workstation_base.png")
base:setWrap("clamp")
local bw, bh = base:getDimensions()
local baseQuadLeft = lg.newQuad(0,0, 1,bh, base)
local baseQuadRight = lg.newQuad(bw-1,0, 1,bh, base)

local spriteSheet = lg.newImage("assets/UI/workstation_base_ss.png")
-- spriteSheet:setFilter("nearest")
local closeQuad = lg.newQuad(3179, 395, 40, 110, spriteSheet)
local doorLeft = lg.newQuad(1491, 466, 136, 515, spriteSheet)
local doorRight = lg.newQuad(1639, 466, 69, 515, spriteSheet)
local doorBackground = lg.newQuad(1216, 462, 212, 530, spriteSheet)
local leaves = lg.newQuad(926, 695, 236, 273, spriteSheet)

local isDraggingCloseButton, closeDragOffset, closeDragOffsetY, closeInside = false, 0, 0, false
local closeTimer, closeTimeMax, closeMouseTimer = 0, 2.5, 0
local leavesX, leavesY, leavesFlipX, leavesFlipY = 0, 0, true, false
workstation.update = function(dt, scale, isGamepadActive)
  local inputConsumed = false

  if not workstation.show then
    return inputConsumed
  end

  do -- leaves animation
    if leavesFlipX then
      leavesX = leavesX + 1.5 * dt
      if leavesX >= 3 then
        leavesX = 3
        leavesFlipX = false
      end
    else
      leavesX = leavesX - 1.5 * dt
      if leavesX <= -3 then
        leavesX = -3
        leavesFlipX = true
      end
    end
    if leavesFlipY then
      leavesY = leavesY + 0.3 * dt
      if leavesY >= 3 then
        leavesY = 3
        leavesFlipY = false
      end
    else
      leavesY = leavesY - 0.4 * dt
      if leavesY <= -1 then
        leavesY = -1
        leavesFlipY = true
      end
    end
  end

  local tw, th = lg.getDimensions()
  local wsize = settings._default.client.windowSize
  local ww, wh = wsize.width, wsize.height
  local textureScale = th / bh
  local scaledWidth = bw * textureScale
  local translateX = (tw - scaledWidth) / 2

  local mx, my = love.mouse.getPosition()
  if not isDraggingCloseButton then
    local _, _, cw, ch = closeQuad:getViewport()
    local closeX = 1841*textureScale + translateX
    local closeY =  390*textureScale
    if mx >= closeX and mx <= closeX + cw * textureScale and
       my >= closeY and my <= closeY + ch * textureScale then
      if not closeInside then
        cursor.switch("hand")
        closeInside = true
      end
    else
      if closeInside then
        cursor.switch("arrow")
        closeInside = false
      end
    end
    if closeInside and love.mouse.isDown(1) then
      closeDragOffsetY = my / textureScale - 390
      isDraggingCloseButton = true
    end
  end
  if isDraggingCloseButton then
    if love.mouse.isDown(1) then
      closeDragOffset = my / textureScale - 390 - closeDragOffsetY
      if closeDragOffset < 0 then
        closeDragOffset = 0
      end
      if closeDragOffset > 456 then
        closeDragOffset = 456
      end
    else
      isDraggingCloseButton = false
      closeDragOffset = 0
      closeDragOffsetY = 0
    end
    if closeDragOffset >= 456 then
      closeMouseTimer = closeMouseTimer + dt
      if closeMouseTimer >= 0.3 then
        closeMouseTimer = 0
        closeDragOffset = 0
        closeDragOffsetY = 0
        workstation.show = false
        canMovePlayer(true)
        if closeInside then
          cursor.switch("arrow")
          closeInside = false
        end
      end
    end
  end

  if not isDraggingCloseButton then
    if input.baton:down("reject") then
      closeTimer = closeTimer + 2 *dt
    elseif closeTimer > 0 then
      closeTimer = closeTimer - 1 * dt
      if closeTimer < 0 then
        closeTimer = 0
      end
    end
    if closeTimer >= closeTimeMax then
      closeTimer = 0
      workstation.show = false
      canMovePlayer(true)
      inputConsumed = true
    end
  else
    closeTimer = 0
  end

  return inputConsumed
end

workstation.draw = function(playerX, playerZ)
  if not workstation.show and workstation.interactZ - (zRange+.5) <= playerZ and workstation.interactZ + (zRange+.5) >= playerZ and
    workstation.interactX - (xRange+.5) <= playerX and workstation.interactX + (xRange+.5) >= playerX then
    if workstation.interactX - xRange <= playerX and
      workstation.interactX + xRange >= playerX and
      workstation.interactZ - zRange <= playerZ and
      workstation.interactZ + zRange >= playerZ then
      lg.setColor(1,1,1,1)
    else
      lg.setColor(.5,.5,.5,.7)
    end
    interactSign:draw()
    lg.setColor(1,1,1,1)
  end
end

workstation.drawUI = function(scale)
  if not workstation.show then
    return
  end
  local tw, th = lg.getDimensions()
  lg.push("all")
    -- Set background to black
    lg.setColor(0,0,0,1)
    lg.rectangle("fill", 0, 0, tw, th)
    lg.setColor(1,1,1,1)
  lg.push()
    local wsize = settings._default.client.windowSize
    local ww, wh = wsize.width, wsize.height
    local textureScale = th / bh
    local scaledWidth = bw * textureScale
    local translateX = (tw - scaledWidth) / 2

  do -- Sides
    lg.push("all")
    local c = .75
    lg.setColor(c,c,c,1)
    -- Left
    lg.push()
      lg.scale(tw/2-scaledWidth/2+5, textureScale)
      lg.draw(base, baseQuadLeft)
    lg.pop()
    -- Right
    lg.push()
      lg.translate(scaledWidth+tw/2-scaledWidth/2-5, 0)
      lg.scale(tw/2-scaledWidth/2+10, textureScale)
      lg.draw(base, baseQuadRight)
    lg.pop()
    lg.pop()
  end

    lg.setColor(1,1,1,1)
    lg.translate(translateX, 0)
    lg.scale(textureScale)

    lg.setColorMask(false)
    lg.setStencilState("replace", "always", 1)
    lg.rectangle("fill", 0,0, bw, bh)
    lg.setStencilState("keep", "greater", 0)
    lg.setColorMask(true)

    lg.draw(spriteSheet, doorBackground, 146, 452)
    lg.draw(spriteSheet, doorLeft, 151, 466)
    lg.draw(spriteSheet, doorRight, 285, 466)

    lg.draw(base)

    lg.draw(spriteSheet, leaves, 19 + leavesX * scale, 811 + leavesY * scale)

    -- Taken from flux#L22; sine out easing
    local p = 0
    if isDraggingCloseButton then
      p = closeDragOffset / 456
    else
      p = (closeTimer/closeTimeMax)
    end
    p = 1 - p
    p = 1 - p^2

    local intensity = 2
    local wobbleOffset = (love.math.simplexNoise(p * 7) * intensity) - intensity/2

    if isDraggingCloseButton then
      lg.draw(spriteSheet, closeQuad, 1841 + wobbleOffset * scale, 390+closeDragOffset)
    else
      lg.draw(spriteSheet, closeQuad, 1841 + wobbleOffset * scale, 390+456*p)
    end
  lg.pop()
  lg.pop()
  lg.setStencilMode() -- clear stencil
end

return workstation