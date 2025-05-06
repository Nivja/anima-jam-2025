local lg = love.graphics

local settings = require("util.settings")
local cursor = require("util.cursor")
local input = require("util.input")
local flux = require("libs.flux")

local inventory = require("src.inventory")

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
-- filter is handled in the draw; as it changes dependant on scale
spriteSheet:setFilter("nearest", "nearest")
local closeQuad = lg.newQuad(3179, 395, 40, 110, spriteSheet)
local doorLeft = lg.newQuad(1491, 466, 136, 515, spriteSheet)
local doorRight = lg.newQuad(1639, 466, 69, 515, spriteSheet)
local doorBackground = lg.newQuad(1216, 462, 212, 530, spriteSheet)
local leaves = lg.newQuad(926, 695, 236, 273, spriteSheet)
local crystalBG = lg.newQuad(1769, 512, 1223, 618, spriteSheet)

local buttonPatch        = lg.newQuad(3041,  219, 103, 117, spriteSheet)
local buttonPatchActive  = lg.newQuad(3041,  821, 103, 117, spriteSheet)
local buttonCreate       = lg.newQuad(3041,  364, 103, 117, spriteSheet)
local buttonCreateActive = lg.newQuad(3041,  966, 103, 117, spriteSheet)
local buttonSteam        = lg.newQuad(3041,  512, 103, 117, spriteSheet)
local buttonSteamActive  = lg.newQuad(3041, 1114, 103, 117, spriteSheet)
local buttonAdd          = lg.newQuad(3041,  662, 103, 117, spriteSheet)
local buttonAddActive    = lg.newQuad(3041, 1264, 103, 117, spriteSheet)

local currentActive
local sideButtons = {
  {
    quad = buttonPatch,
    quadActive = buttonPatchActive,
    y = 226, offsetY = 10,
    active = true,
  },
  {
    quad = buttonCreate,
    quadActive = buttonCreateActive,
    y = 371, offsetY = 0,
  },
  {
    quad = buttonSteam,
    quadActive = buttonSteamActive,
    y = 519, offsetY = 0,
  },
  {
    quad = buttonAdd,
    quadActive = buttonAddActive,
    y = 669, offsetY = 0,
  }
}
currentActive = sideButtons[1]

local oldTween, newTween, switchTween
local switchSideButtons = function(switchTo)
  if oldTween then
    oldTween._oncomplete()
  end
  if newTween then
    newTween._oncomplete()
  end
  if switchTween then
    switchTween._oncomplete()
  end

  if type(switchTo) == "number" then
    local currentIndex
    for index, b in ipairs(sideButtons) do
      if b == currentActive then
        currentIndex = index
        break
      end
    end
    if not currentIndex then currentIndex = 1 end
    local index = currentIndex + switchTo
    if index > #sideButtons then index = 1 end
    if index < 1 then index = #sideButtons end
    switchTo = sideButtons[index]
  end

  local oldButton, newButton = currentActive, switchTo
  
  oldTween = flux.to(oldButton, .5, { offsetY = 0 }):ease("elasticinout")
  :oncomplete(function()
      oldButton.offsetY = 0
      oldTween = nil
    end)
  newTween = flux.to(newButton, .5, { offsetY = 10 }):ease("elasticout")
    :oncomplete(function()
      newButton.offsetY = 10
      newTween = nil
    end):delay(.1)
  switchTween = flux.to({ }, .2, { })
    :oncomplete(function()
      currentActive = newButton
      oldButton.active = false
      newButton.active = true
      switchTween = nil
    end)
end

local fabricBackground = lg.newQuad(1831, 288, 1175, 172, spriteSheet)
local fabricShadow = lg.newQuad(2854, 94, 61, 165, spriteSheet)
local fabricArrow = lg.newQuad(1981, 94, 61, 165, spriteSheet)
local fabricTextures = { -- magic number is +83
  silly_1    = { quad = lg.newQuad(1850, 94, 61, 165, spriteSheet), x = -1, },
  neutral_1  = { quad = lg.newQuad(2098, 94, 61, 165, spriteSheet), x = 248, },
  fancy_1    = { quad = lg.newQuad(2265, 94, 61, 165, spriteSheet), x = 413, },
  neutral_2  = { quad = lg.newQuad(2346, 94, 61, 165, spriteSheet), x = 496, },
  heirloom_1 = { quad = lg.newQuad(2429, 94, 61, 165, spriteSheet), x = 579, },
  heirloom_2 = { quad = lg.newQuad(2514, 94, 61, 165, spriteSheet), x = 662, },
  neutral_3  = { quad = lg.newQuad(2680, 94, 61, 165, spriteSheet), x = 828, },
  neutral_4  = { quad = lg.newQuad(2762, 94, 61, 165, spriteSheet), x = 911, },
}

local fabricTexturesOrder = {
  "silly_1", "neutral_1", "fancy_1", "neutral_2",
  "heirloom_1", "heirloom_2", "neutral_3", "neutral_4",
}

local fabricArrowPosition = 0

local isDraggingCloseButton, closeDragOffset, closeDragOffsetY, closeInside = false, 0, 0, false
local sideButtonInside = false
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
      local slowDownFactor = math.min(1, math.max(0.05, closeTimer / (closeTimeMax/8)))
      closeTimer = closeTimer - 1 * dt * slowDownFactor
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

  if not inputConsumed and not isDraggingCloseButton then
    if isGamepadActive then
      if sideButtonInside then
        sideButtonInside = false
        cursor.switch("arrow")
      end

      if input.baton:pressed("leftBumper") then
        inputConsumed = true
        switchSideButtons(-1)
      elseif input.baton:pressed("rightBumper") then
        inputConsumed = true
        switchSideButtons(1)
      end
    else
      local buttonX = 1700 * textureScale + translateX
      local _, _, buttonD, _ = sideButtons[1].quad:getViewport()
      buttonD = buttonD * textureScale
      local found = false
      if mx >= buttonX and mx <= buttonX + buttonD then -- early out
        for _, button in ipairs(sideButtons) do
          local buttonY = button.y * textureScale
          if not button.active and my >= buttonY and my <= buttonY + buttonD then
            found = button
            if not sideButtonInside then
              sideButtonInside = true
              cursor.switch("hand")
            end
            break
          end
        end
      end
      if not found and sideButtonInside then
        sideButtonInside = false
        cursor.switch("arrow")
      end
      -- process input
      if found and input.baton:pressed("accept") then
        inputConsumed = true
        switchSideButtons(found)
        if sideButtonInside then
          sideButtonInside = false
          cursor.switch("arrow")
        end
      end
    end
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
    if textureScale > 1 then
      spriteSheet:setFilter("linear")
    else
      spriteSheet:setFilter("nearest")
    end

    lg.setColorMask(false)
    lg.setStencilState("replace", "always", 1)
    lg.rectangle("fill", 0,0, bw, bh)
    lg.setStencilState("keep", "greater", 0)
    lg.setColorMask(true)

    lg.draw(spriteSheet, doorBackground, 146, 452)
    lg.draw(spriteSheet, doorLeft, 151, 466)
    lg.draw(spriteSheet, doorRight, 285, 466)
    lg.draw(spriteSheet, crystalBG, 429, 347)

    local fabricOffsetX, fabricOffsetY = 491, 77
    lg.draw(spriteSheet, fabricBackground, fabricOffsetX, fabricOffsetY)
    fabricOffsetX = fabricOffsetX + 21
    fabricOffsetY = fabricOffsetY + 18

    --   Fabric
    for _, fabricType in ipairs(fabricTexturesOrder) do
      local fabricAmount = inventory.fabric[fabricType]
      if fabricAmount and fabricAmount > 0 then -- draw
        local fabricTex = fabricTextures[fabricType]
        if not fabricTex then logger.error("Couldn't find texture for type:", fabricType) end
        lg.draw(spriteSheet, fabricShadow, fabricOffsetX + fabricTex.x, fabricOffsetY)
        lg.draw(spriteSheet, fabricTex.quad, fabricOffsetX + fabricTex.x, fabricOffsetY)
      end
    end

    lg.draw(base)

    lg.draw(spriteSheet, leaves, 19 + leavesX * scale, 811 + leavesY * scale)

    for _, button in ipairs(sideButtons) do
      local quad = button.active and button.quadActive or button.quad
      lg.draw(spriteSheet, quad, 1700, button.y + button.offsetY)
    end

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