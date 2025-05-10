local lg, lfs = love.graphics, love.filesystem

local audioManager = require("util.audioManager")
local settings = require("util.settings")
local logger = require("util.logger")
local cursor = require("util.cursor")
local assets = require("util.assets")
local input = require("util.input")
local flux = require("libs.flux")
local ui = require("util.ui")

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

local base = assets["game.workstation.base"]
base:setWrap("clamp")
local bw, bh = base:getDimensions()
local baseQuads = {
  baseQuadLeft = lg.newQuad(0,0, 1,bh, base),
  baseQuadRight = lg.newQuad(bw-1,0, 1,bh, base),
}

local spriteSheet = assets["game.workstation.spritesheet"]
-- filter is handled in the draw; as it changes dependant on scale
spriteSheet:setFilter("nearest", "nearest")
local closeQuad = lg.newQuad(3179, 395, 40, 110, spriteSheet)
local doorLeft = lg.newQuad(1491, 466, 136, 515, spriteSheet)
local doorRight = lg.newQuad(1639, 466, 69, 515, spriteSheet)
local doorBackground = lg.newQuad(1216, 462, 212, 530, spriteSheet)
local leaves = lg.newQuad(926, 695, 236, 273, spriteSheet)
local crystalBG = lg.newQuad(1769, 512, 1223, 618, spriteSheet)
local darkBG = lg.newQuad(1360, 1151, 1223, 618, spriteSheet)
local darkBGLeft = lg.newQuad(965, 1147, 159, 618, spriteSheet)
local darkBGRight = lg.newQuad(1152, 1147, 160, 618, spriteSheet)
local darkBGCenterSquare = lg.newQuad(528, 1365, 391, 391, spriteSheet)

local numOne = lg.newQuad(581, 848, 65, 87, spriteSheet)
local numTwo = lg.newQuad(581, 1029, 65, 87, spriteSheet)
local numThree = lg.newQuad(581, 1210, 65, 87, spriteSheet)

local numOneSlot = lg.newQuad(722, 847, 112, 112, spriteSheet)
local numTwoSlot = lg.newQuad(722, 1021, 112, 112, spriteSheet)
local numThreeSlot = lg.newQuad(722, 1198, 112, 112, spriteSheet)

local numberedSlotQuad = lg.newQuad(3000/2-1200, 3000/2-1200, 100*12, 100*12, 3000, 3000)

local inventorySlot = lg.newQuad(1533, 233, 60, 58, spriteSheet)
local inventorySlotActive = lg.newQuad(1600, 233, 60, 58, spriteSheet)

local textBadge = lg.newQuad(1231, 1040, 243, 76, spriteSheet)
local arrowQuads = {
  arrowLeft = lg.newQuad(1517, 1021, 105, 122, spriteSheet),
  arrowRight = lg.newQuad(1639, 1023, 105, 122, spriteSheet),
}

local arrowButtons = {
  left = {
    offsetX = 0,
  },
  right = {
    offsetX = 0,
  }
}

local correctTick = lg.newQuad(725, 4, 554, 438, spriteSheet)
local sewingMachineHead = lg.newQuad(1406, 68, 394, 149, spriteSheet)

local inventoryButtons = {
  {
    quad = lg.newQuad(1520, 314, 47, 52, spriteSheet),
    quadActive = lg.newQuad(1520, 377, 47, 52, spriteSheet),
    x = 180, offsetY = 0,
    active = false,
  },
  {
    quad = lg.newQuad(1630, 314, 47, 52, spriteSheet),
    quadActive = lg.newQuad(1630, 377, 47, 52, spriteSheet),
    x = 235, offsetY = 0,
    active = false,
  },
  {
    quad = lg.newQuad(1576, 314, 47, 52, spriteSheet),
    quadActive = lg.newQuad(1576, 377, 47, 52, spriteSheet),
    x = 289, offsetY = 0,
    active = false,
  },
}

local fakeInventoryButton = function(button)
  if button.tween then
    button.tween:stop()
    button.active = false
    button.offsetY = 0
  end

  button.tween = flux.to(button, .1, { offsetY = 5 }):ease("linear")
    :oncomplete(function()
      button.active = true
      audioManager.play("audio.ui.click")
    end)
    :after(.2, { offsetY = 0 }):ease("linear")
    :oncomplete(function()
      button.active = false
      button.tween = nil
    end)
end

local currentActive
local sideButtons = {
  {
    quad = lg.newQuad(3041,  219, 103, 117, spriteSheet),
    quadActive = lg.newQuad(3041,  821, 103, 117, spriteSheet),
    y = 226, offsetY = 10,
    active = true,
  },
  {
    quad = lg.newQuad(3041,  364, 103, 117, spriteSheet),
    quadActive = lg.newQuad(3041,  966, 103, 117, spriteSheet),
    y = 371, offsetY = 0,
  },
  {
    quad = lg.newQuad(3041,  512, 103, 117, spriteSheet),
    quadActive = lg.newQuad(3041, 1114, 103, 117, spriteSheet),
    y = 519, offsetY = 0,
  },
  {
    quad = lg.newQuad(3041,  662, 103, 117, spriteSheet),
    quadActive = lg.newQuad(3041, 1264, 103, 117, spriteSheet),
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
  switchTween = flux.to({}, .1, {})
    :oncomplete(function() audioManager.play("audio.ui.spring") end)
    :after(.1, {})
    :oncomplete(function()
      currentActive = newButton
      oldButton.active = false
      newButton.active = true
      newButton.activateTime = love.timer.getTime()
      switchTween = nil
      audioManager.play("audio.ui.click")
    end)
end

local fabricBackground = lg.newQuad(1831, 288, 1175, 172, spriteSheet)
local fabricShadow = lg.newQuad(2854, 94, 61, 165, spriteSheet)
local fabricArrow = lg.newQuad(1981, 94, 61, 165, spriteSheet)
local fabricTextures = { -- magic number is +83
  silly_1    = { quad = lg.newQuad(1850, 94, 61, 165, spriteSheet), x =  -1, name = "Silly" },
  neutral_1  = { quad = lg.newQuad(2098, 94, 61, 165, spriteSheet), x = 248, name = "Neutral" },
  fancy_1    = { quad = lg.newQuad(2265, 94, 61, 165, spriteSheet), x = 413, name = "Fancy" },
  neutral_2  = { quad = lg.newQuad(2346, 94, 61, 165, spriteSheet), x = 496, name = "Neutral" },
  heirloom_1 = { quad = lg.newQuad(2429, 94, 61, 165, spriteSheet), x = 579, name = "Heirloom" },
  heirloom_2 = { quad = lg.newQuad(2514, 94, 61, 165, spriteSheet), x = 662, name = "Heirloom" },
  neutral_3  = { quad = lg.newQuad(2680, 94, 61, 165, spriteSheet), x = 828, name = "Neutral" },
  neutral_4  = { quad = lg.newQuad(2762, 94, 61, 165, spriteSheet), x = 911, name = "Neutral" },
}

for key, fabric in pairs(fabricTextures) do
  if assets.getReferenceCount("fabric."..key) > 0 then
    fabric.texture = assets["fabric."..key]
  else
    logger.error("Fabric texture has not been loaded!", key)
  end
end

local fabricTexturesOrder = {
  "silly_1", "neutral_1", "fancy_1", "neutral_2",
  "heirloom_1", "heirloom_2", "neutral_3", "neutral_4",
}

local sashikoSpriteSheet = assets["game.workstation.sashiko"]

local sashikoArrowQuads = {
  up = lg.newQuad(146, 92, 127, 126, sashikoSpriteSheet),
  left = lg.newQuad(1115, 91, 124, 126, sashikoSpriteSheet),
  up_red = lg.newQuad(523, 93, 127, 124, sashikoSpriteSheet),
  left_red = lg.newQuad(733, 91, 124, 126, sashikoSpriteSheet),
}

local inventorySlotSelected = 1
local fabricArrowPosition = 0

local moveFabricArrowPosition = function(delta)
  local found, first, last = nil, nil, nil
  for index, key in ipairs(fabricTexturesOrder) do
    local fabricAmount = inventory.fabric[key]
    if fabricAmount and fabricAmount > 0 then
      if found and delta == 1 then
        -- logger.warn("1Was", fabricArrowPosition, "Now", index)
        fabricArrowPosition = index
        return
      end
      if index == fabricArrowPosition then
          found = true
      end
      if found and delta == -1 then
        if last then
          -- logger.warn("2Was", fabricArrowPosition, "Now", last)
          fabricArrowPosition = last
          return
        else
          found = false
        end
      end
      if not first then first = index end
      last = index
    end
  end
  if first and delta == 1 then
    -- logger.warn("3Was", fabricArrowPosition, "Now", first)
    fabricArrowPosition = first
    return
  end
  if last and delta == -1 then
    -- logger.warn("4Was", fabricArrowPosition, "Now", first)
    fabricArrowPosition = last
    return
  end
  logger.warn("Shouldn't hit this; moveFabricArrowPosition call", found, first, last)
end

local isDraggingCloseButton, closeDragOffset, closeDragOffsetY, closeInside = false, 0, 0, false
local sideButtonInside, inventoryButtonInside, insideArrowButtons, insideFabricAccept = false, false, false, false
local textBadgePatchInside = false
local tearFabricPosition, tearFabricPositionBlink = { 0, 0 }, false
local patchItems, patchItemsIndex, patchLevel = nil, 1, 1
local closeTimer, closeTimeMax, closeMouseTimer = 0, 2.5, 0
local leavesX, leavesY, leavesFlipX, leavesFlipY = 0, 0, true, false
local blinkTimer, patchLevelTwoTimer = 0, 0
local sashikoArrows, sashikoArrowIndex, sashikoArrowTimer, sashikoArrowTimerStart = { }, 1, 0, 0
workstation.update = function(dt, scale, isGamepadActive)
  local inputConsumed = false

  if not workstation.show then
    return inputConsumed
  end

  blinkTimer = blinkTimer + dt
  while blinkTimer >= 0.3 do
    tearFabricPositionBlink = not tearFabricPositionBlink
    blinkTimer = blinkTimer - 0.3
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
    local interactSFX = assets["audio.ui.exit_minigame.interact.1"]
    if love.mouse.isDown(1) then
      local previousOffset = closeDragOffset
      closeDragOffset = my / textureScale - 390 - closeDragOffsetY
      if previousOffset ~= closeDragOffset then
        interactSFX:setPitch(1.25)
        if not interactSFX:isPlaying() then
          interactSFX:play()
        end
      end
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
        audioManager.play("audio.ui.exit_minigame")
        canMovePlayer(true)
        if closeInside then
          cursor.switch("arrow")
          closeInside = false
        end
      end
    end
  end

  if not isDraggingCloseButton then
    local interactSFX = assets["audio.ui.exit_minigame.interact.1"]
    if input.baton:down("reject") then
      closeTimer = closeTimer + 2 *dt
      if not interactSFX:isPlaying() then
        interactSFX:play()
      end
      interactSFX:setPitch(1.0)
    elseif closeTimer > 0 then
      local slowDownFactor = math.min(1, math.max(0.05, closeTimer / (closeTimeMax/8)))
      closeTimer = closeTimer - 1 * dt * slowDownFactor
      interactSFX:setPitch(0.75)
      if closeTimer < 0 then
        closeTimer = 0
        if interactSFX:isPlaying() then
          interactSFX:stop()
        end
      elseif not interactSFX:isPlaying() then
        interactSFX:play()
      end
    end
    if closeTimer >= closeTimeMax then
      closeTimer = 0
      workstation.show = false
      audioManager.play("audio.ui.exit_minigame")
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
        if sashikoArrowTimerStart ~= 0 then
          sashikoArrowTimerStart = 1
        end
        if patchLevel == 4 then
          patchLevel = 1
        end
      elseif input.baton:pressed("rightBumper") then
        inputConsumed = true
        switchSideButtons(1)
        if sashikoArrowTimerStart ~= 0 then
          sashikoArrowTimerStart = 1
        end
        if patchLevel == 4 then
          patchLevel = 1
        end
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
        if sashikoArrowTimerStart ~= 0 then
          sashikoArrowTimerStart = 1
        end
        if patchLevel == 4 then
          patchLevel = 1
        end
        if sideButtonInside then
          sideButtonInside = false
          cursor.switch("arrow")
        end
      end
    end
  end

  if not inputConsumed and not isDraggingCloseButton then
    if isGamepadActive then
      if inventoryButtonInside then
        inventoryButtonInside = false
        cursor.switch("arrow")
      end
    else
      local buttonY = 313 * textureScale
      local _, _, buttonD, _ = inventoryButtons[1].quad:getViewport()
      buttonD = buttonD * textureScale
      local found = false
      if my >= buttonY and my <= buttonY + buttonD then -- early out
        for _, button in ipairs(inventoryButtons) do
          local buttonX = button.x * textureScale + translateX
          if mx >= buttonX and mx <= buttonX + buttonD then
            found = button
            if not inventoryButtonInside then
              inventoryButtonInside = true
              cursor.switch("hand")
            end
            break
          end
        end
      end
      if not found and inventoryButtonInside then
        inventoryButtonInside = false
        cursor.switch("arrow")
      end
      if found and input.baton:pressed("accept") then
        inputConsumed = true
        fakeInventoryButton(found)
      end
    end
  end

  if sideButtons[1].active then
    if patchLevel == 1 then
      if not inputConsumed and not isDraggingCloseButton then
        if isGamepadActive then
          if insideArrowButtons then
            insideArrowButtons = false
            cursor.switch("arrow")
          end

          local nav = 0
          if input.baton:pressed("menuNavLeft") then
            nav = nav - 1
            inputConsumed = true
          end
          if input.baton:pressed("menuNavRight") then
            nav = nav + 1
            inputConsumed = true
          end
          if nav ~= 0 then
            moveFabricArrowPosition(nav)
            inputConsumed = true
          end
        else
          local buttonY = (347+618/2.5-122/2) * textureScale
          local _, _, buttonD, _ = arrowQuads.arrowLeft:getViewport()
          buttonD = buttonD * textureScale
          local found
          if my >= buttonY and my <= buttonY + buttonD then -- early out
            local buttonX = (429+1223/2-391) * textureScale + translateX
            if mx >= buttonX and mx <= buttonX + buttonD then
              found = "left"
              if not insideArrowButtons then
                insideArrowButtons = true
                cursor.switch("hand")
              end
            end
          end
          local buttonX = (429+1223/2+391/4*3) * textureScale + translateX
          if mx >= buttonX and mx <= buttonX + buttonD then
            found = "right"
            if not insideArrowButtons then
              insideArrowButtons = true
              cursor.switch("hand")
            end
          end
          if not found and insideArrowButtons then
            insideArrowButtons = false
            cursor.switch("arrow")
          end
          if found and input.baton:pressed("accept") then
            inputConsumed = true
            local tbl
            if found == "left" then
              tbl = arrowButtons.left
              moveFabricArrowPosition(-1)
            elseif found == "right" then
              tbl = arrowButtons.right
              moveFabricArrowPosition(1)
            end
            flux.to(tbl, 0.1, { offsetX = 5 })
            :ease("linear")
            :after(0.1, { offsetX = 0 }):ease("linear")
            audioManager.play("audio.ui.click")
          end
        end
      end

      -- To stop simple skipping
      local button = sideButtons[1]
      local offsetXFactor = 1 - math.min(1, love.timer.getTime()-button.activateTime)
      if not inputConsumed and not isDraggingCloseButton and offsetXFactor == 0 then
        if isGamepadActive then
          if textBadgePatchInside then
            textBadgePatchInside = false
            cursor.switch("arrow")
          end

          if input.baton:pressed("accept") then
            patchLevel = 2
            local r = love.math.random() > 0.5 and 1 or -1
            tearFabricPosition = { love.math.random(250, 500)*r, 0--[[love.math.random(-250, 250)]] }
          end
        else
          local buttonX = 920 * textureScale + translateX
          local buttonY = (850-76/2) * textureScale
          local _, _, width, height = textBadge:getViewport()
          width, height = width * textureScale, height * textureScale
          if mx >= buttonX and mx <= buttonX + width and
             my >= buttonY and my <= buttonY + height then
            if not textBadgePatchInside then
              textBadgePatchInside = true
              cursor.switch("hand")
            end
            if input.baton:pressed("accept") then
              patchLevel = 2
              local r = love.math.random() > 0.5 and 1 or -1
              tearFabricPosition = { love.math.random(150, 350)*r, 0--[[love.math.random(-250, 250)]] }
              if textBadgePatchInside then
                textBadgePatchInside = false
                cursor.switch("arrow")
              end
            end
          else
            if textBadgePatchInside then
              textBadgePatchInside = false
              cursor.switch("arrow")
            end
          end
        end
      end
    elseif patchLevel == 2 then
      if not inputConsumed and not isDraggingCloseButton then
        local dx, dy = input.baton:get("move")
        tearFabricPosition[1] = tearFabricPosition[1] + 10 * dx *-1
        if math.abs(tearFabricPosition[1]) <= 20 then
          patchLevelTwoTimer = patchLevelTwoTimer + 1.0 * dt
          if patchLevelTwoTimer >= 3 then
            patchLevel = 3
            sashikoArrows = { }
            for n = 1, 15 do
              local arrow = { rotation = 0 }
              local r = love.math.random(1, 4)
              if r == 1 then
                arrow.dir = "up"
                arrow.quad = sashikoArrowQuads.up
                arrow.red = sashikoArrowQuads.up_red
                arrow.key = "menuNavUpN"
              elseif r == 2 then
                arrow.dir = "right"
                arrow.quad = sashikoArrowQuads.left
                arrow.red = sashikoArrowQuads.left_red
                arrow.rotation = math.rad(180)
                arrow.key = "menuNavRightN"
              elseif r == 3 then
                arrow.dir = "down"
                arrow.quad = sashikoArrowQuads.up
                arrow.red = sashikoArrowQuads.up_red
                arrow.rotation = math.rad(180)
                arrow.key = "menuNavDownN"
              else
                arrow.dir = "left"
                arrow.quad = sashikoArrowQuads.left
                arrow.red = sashikoArrowQuads.left_red
                arrow.key = "menuNavLeftN"
              end
              table.insert(sashikoArrows, arrow)
            end
            sashikoArrowIndex = 1
            sashikoArrowTimer = 0
            sashikoArrowTimerStart = 0
          end
        else
          patchLevelTwoTimer = patchLevelTwoTimer - 0.5 * dt
          if patchLevelTwoTimer < 0 then patchLevelTwoTimer = 0 end
        end
      end
    elseif patchLevel == 3 then
      sashikoArrowTimerStart = sashikoArrowTimerStart + dt
      if sashikoArrowTimerStart > 2 then
        sashikoArrowTimer = sashikoArrowTimer + dt
        if not inputConsumed and not isDraggingCloseButton then
          local currentArrow, index
          for i, arrow in ipairs(sashikoArrows) do
            if not arrow.passed and not arrow.noShow then
              currentArrow = arrow
              index = i
              break
            end
          end
          if currentArrow then
            local speed, distBetween = 250, 250
            local n = 500 + sashikoArrowTimer*-speed + distBetween * (index-1)
            if input.baton:pressed(currentArrow.key) then
              if n <= 260 then
                currentArrow.noShow = true
                audioManager.play("audio.ui.click")
              else
                currentArrow.passed = true -- too early
                audioManager.play("audio.ui.select")
              end
              inputConsumed = true
            end
          else
            -- end of minigame
            local hit, missed = 0, 0
            for _, a in ipairs(sashikoArrows) do
              if a.noShow then
                hit = hit + 1
              elseif a.passed then
                missed = missed + 1
              end
            end
            logger.info("Hit:", hit, ". Missed:", missed, "todo; implement failing")
            patchLevel = 4
            -- hard coded, oops - we don't have a working inventory so who cares
            local patchTag = "patch."
            local key = fabricTexturesOrder[fabricArrowPosition]
            if key then
            local fabric = fabricTextures[key]
            if fabric then
              patchTag = patchTag .. fabric.name:lower()
            end
            end
            patchItems[1].tags = {
              "clothing",
              patchItems[1].tags[2],
              patchItems[1].tags[3],
              patchTag,
              "patched",
            }
            -- Should remove from patch items; but it's done with the below
            
            flux.to({}, 3, {}):oncomplete(function()
              patchItems = inventory.getPatchItems() or { }
              patchItemsIndex = 1
              patchLevel = 1
              inventorySlotSelected = 1
              fabricArrowPosition = 1
              tearFabricPosition = { 0, 0 }
              patchLevelTwoTimer = 0
              sashikoArrows = { }
              sashikoArrowIndex = 1
            end)
          end
        end
      end
    end
  end


  return inputConsumed
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
    sideButtons[1].activateTime = love.timer.getTime()
    patchItems = inventory.getPatchItems() or { }
    patchItemsIndex = 1
    patchLevel = 1
    inventorySlotSelected = 1
    fabricArrowPosition = 1
    tearFabricPosition = { 0, 0 }
    patchLevelTwoTimer = 0
    sashikoArrows = { }
    sashikoArrowIndex = 1
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

workstation.draw = function(playerX, playerZ)
  if not workstation.show and workstation.interactZ - (zRange+.5) <= playerZ and workstation.interactZ + (zRange+.5) >= playerZ and
    workstation.interactX - (xRange+.5) <= playerX and workstation.interactX + (xRange+.5) >= playerX then
      if workstation.interactX - xRange <= playerX and
      workstation.interactX + xRange >= playerX and
      workstation.interactZ - zRange <= playerZ and
      workstation.interactZ + zRange >= playerZ then
      lg.setColor(0,0,0,1)
    else
      lg.setColor(.2,.2,.2,.7)
    end
    lg.push("all")
    lg.setDepthMode("always", false)
    interactSign:draw()
    lg.pop()
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
      lg.draw(base, baseQuads.baseQuadLeft)
    lg.pop()
    -- Right
    lg.push()
      lg.translate(scaledWidth+tw/2-scaledWidth/2-5, 0)
      lg.scale(tw/2-scaledWidth/2+10, textureScale)
      lg.draw(base, baseQuads.baseQuadRight)
    lg.pop()
    lg.pop()
  end

    lg.setColor(1,1,1,1)
    lg.translate(translateX, 0)
    lg.scale(textureScale)
    if textureScale > 1 then
      spriteSheet:setFilter("linear")
      base:setFilter("nearest")
    else
      spriteSheet:setFilter("nearest")
      base:setFilter("linear")
    end

    lg.setColorMask(false)
    lg.setStencilState("replace", "always", 1)
    lg.rectangle("fill", 0,0, bw, bh)
    lg.setStencilState("keep", "greater", 0)
    lg.setColorMask(true)

    if sideButtons[1].active and (patchLevel == 1 and #patchItems ~= 0 or patchLevel ~= 1) then -- Patch
      local button = sideButtons[1]
      lg.draw(spriteSheet, darkBG, 429, 347)

      if patchLevel >= 2 and patchLevel <= 3 then
        lg.push()
        lg.translate(429+100, 348)
        local key = fabricTexturesOrder[fabricArrowPosition]
        if key then
        local fabric = fabricTextures[key]
        if fabric then
          local tw, th = fabric.texture:getDimensions()
          lg.draw(fabric.texture, 0,0, 0, 1000/tw)
        end
        end
        local item = patchItems[1]
        local _, asset = item:getTagStartingWith("patch.")
        local tear = assets["damage."..asset]
        local tearW, tearH = tear:getDimensions()
        local tearScale = 1200/tearW
        lg.push()
        lg.translate(530-tearW*tearScale/2, 330-tearH*tearScale/2)
        lg.scale(tearScale)
        lg.draw(tear)
        local outline = assets["damage."..asset..".outline"]
        if patchLevel == 2 then
          lg.setColor(1,.6,0,.8)
          if tearFabricPositionBlink then
            lg.setColor(1,.6,0,.4)
          end
          lg.draw(outline, 0, 0)
        end
        lg.setColor(1,1,1,1)
        lg.draw(outline, tearFabricPosition[1], tearFabricPosition[2])
        lg.pop()
        lg.push()
        if patchLevel == 2 and patchLevelTwoTimer > 0 then  -- progress bar
          local width = 400
          lg.translate(1200/2-width/4*3, 35)
          lg.setColor(1,1,1,0.6)
          lg.rectangle("fill", 0, 0, width, 30)
          lg.setColor(1,1,1,1)
          lg.rectangle("fill", 0, 0, width*(patchLevelTwoTimer/3), 30)
          lg.rectangle("line", -5, -5, width+10, 40)
        end
        lg.pop()
        lg.pop()
      end
      if patchLevel == 3 then
        local _, _, smw, smh = sewingMachineHead:getViewport()
        lg.push()
        lg.translate(429+100, 348)
        lg.setColor(0,0,0,0.6)
        lg.rectangle("fill", -200,-200,1223+200, 618+200)
        lg.setColor(1,1,1,1)
        lg.translate(1200/2-smw, 0)
        lg.setColor(1,1,1,0.1)
        lg.rectangle("fill", -4, 0, 7, 618) -- target line
        lg.setColor(1,1,1,1)
        lg.draw(spriteSheet, sewingMachineHead, -smw/2)
        lg.pop()
        lg.push()
        lg.translate(429+100+500, 348+(618)/2)
        local speed, distBetween = 250, 250
        lg.translate(sashikoArrowTimer*-speed, 0)
        for i, arrow in ipairs(sashikoArrows) do
          if not arrow.noShow then
            local _, _, w, h = arrow.quad:getViewport()
            local n = 500 + sashikoArrowTimer*-speed + distBetween * (i-1)
            if arrow.passed or n <= 160 then
              arrow.passed = true
              lg.setColor(1,1,1,0.4)
              lg.draw(sashikoSpriteSheet, arrow.red, 0,0,arrow.rotation, 1/2, 1/2, w/2, h/2)
              lg.setColor(1,1,1,1)
            else
              lg.draw(sashikoSpriteSheet, arrow.quad, 0,0,arrow.rotation, 1/2, 1/2, w/2, h/2)
            end
          end
          lg.translate(distBetween, 0)
        end
        lg.pop()
      end

      local offsetXFactor = 1 - math.min(1, love.timer.getTime()-button.activateTime)
      lg.push()
      lg.translate(offsetXFactor*-159, 0)
      lg.draw(spriteSheet, darkBGLeft, 429, 347)
      lg.push()
      local _y = 618/3
      local f = spriteSheet:getFilter()
      spriteSheet:setFilter("linear")
      lg.translate(429+159/2-65/2, 335-_y/1.5)
      if patchLevel ~= 1 then lg.setColor(.5,.5,.5,1) else lg.setColor(1,1,1,1) end
      lg.draw(spriteSheet, numOne, 0, _y*1)
      if patchLevel ~= 2 then lg.setColor(.5,.5,.5,1) else lg.setColor(1,1,1,1) end
      lg.draw(spriteSheet, numTwo, 0, _y*2)
      if patchLevel ~= 3 then lg.setColor(.5,.5,.5,1) else lg.setColor(1,1,1,1) end
      lg.draw(spriteSheet, numThree, 0, _y*3)
      lg.setColor(1,1,1,1)
      lg.pop()
      lg.pop()
      lg.push()
      lg.translate(offsetXFactor*160, 0)
      lg.draw(spriteSheet, darkBGRight, 1493, 347)
      lg.push()
      lg.translate(1649-158/2-112/2, 315-_y/1.5)
      lg.draw(spriteSheet, numOneSlot, 0, _y*1)
      if patchLevel >= 2 then
        local key = fabricTexturesOrder[fabricArrowPosition]
        if key then
        local fabric = fabricTextures[key]
        if fabric then
          lg.draw(fabric.texture, numberedSlotQuad, 6, 6+_y*1, 0, 1/12)
        end
        end
      end
      lg.draw(spriteSheet, numTwoSlot, 0, _y*2)
      if patchLevel >= 3 then
        local _, _, sw, sh = numTwoSlot:getViewport()
        local _, _, ctw, cth = correctTick:getViewport()
        lg.draw(spriteSheet, correctTick,  6, 6+_y*2, 0, (sw-12)/ctw, (sh-12)/cth)
      end
      lg.draw(spriteSheet, numThreeSlot, 0, _y*3)
      if patchLevel >= 4 then
        local _, _, sw, sh = numTwoSlot:getViewport()
        local _, _, ctw, cth = correctTick:getViewport()
        lg.draw(spriteSheet, correctTick,  6, 6+_y*3, 0, (sw-12)/ctw, (sh-12)/cth)
      end
      spriteSheet:setFilter(f)
      lg.pop()
      lg.pop()
      if patchLevel == 1 then
        lg.push()
        local ____n = arrowButtons.left.offsetX - arrowButtons.right.offsetX
        lg.draw(spriteSheet, textBadge, 920+____n, 850-76/2-math.abs(____n))
        lg.push()
        lg.translate(429+1223/2, 347+618/2.5)
        lg.draw(spriteSheet, darkBGCenterSquare, -391/2, -391/2)
        lg.pop()
        lg.push()
        lg.translate(429+1223/2, 347+618/2.5)
        lg.draw(spriteSheet, arrowQuads.arrowLeft, -391+arrowButtons.left.offsetX, -122/2)
        lg.draw(spriteSheet, arrowQuads.arrowRight, 391/4*3+arrowButtons.right.offsetX, -122/2)
        lg.pop()
        lg.push() -- Breaks sprite batching
        lg.translate(429+1223/2, 347+618/2.5)
          local key = fabricTexturesOrder[fabricArrowPosition]
          if key then
          local fabric = fabricTextures[key]
          if fabric then
            local _, _, w, h = darkBGCenterSquare:getViewport()
            local tw, th = fabric.texture:getDimensions()
            w, h = w - 20, h - 20
            lg.draw(fabric.texture, -391/2+10, -391/2+10, 0, w/tw, h/th)
          end
          end
        lg.pop()
        lg.pop()
      elseif patchLevel == 4 then
        -- draw above sides
        lg.push()
        lg.translate(429+1223/2, 347+618/2.5)
        local _, _, w, h = correctTick:getViewport()
        lg.draw(spriteSheet, correctTick, -w/2, -h/2)
        lg.pop()
      end
    else
      lg.draw(spriteSheet, crystalBG, 429, 347)
    end

    lg.draw(spriteSheet, doorBackground, 146, 452)
    lg.draw(spriteSheet, doorLeft, 151, 466)
    lg.draw(spriteSheet, doorRight, 285, 466)

    local fabricOffsetX, fabricOffsetY = 491, 77
    lg.draw(spriteSheet, fabricBackground, fabricOffsetX, fabricOffsetY)
    fabricOffsetX = fabricOffsetX + 21
    fabricOffsetY = fabricOffsetY + 18

    --   Fabric
    for index, fabricType in ipairs(fabricTexturesOrder) do
      local fabricAmount = inventory.fabric[fabricType]
      if fabricAmount and fabricAmount > 0 then -- draw
        local fabricTex = fabricTextures[fabricType]
        if not fabricTex then logger.error("Couldn't find texture for type:", fabricType) end
        lg.draw(spriteSheet, fabricShadow, fabricOffsetX + fabricTex.x, fabricOffsetY)
        lg.draw(spriteSheet, fabricTex.quad, fabricOffsetX + fabricTex.x, fabricOffsetY)
        if index == fabricArrowPosition then
          lg.draw(spriteSheet, fabricArrow, fabricOffsetX + fabricTex.x, fabricOffsetY)
        end
      end
    end

    lg.draw(base)

    lg.draw(spriteSheet, leaves, 19 + leavesX * scale, 811 + leavesY * scale)

    -- Side buttons
    for _, button in ipairs(sideButtons) do
      local quad = button.active and button.quadActive or button.quad
      lg.draw(spriteSheet, quad, 1700, button.y + button.offsetY)
    end

    -- Inventory buttons
    for _, button in ipairs(inventoryButtons) do
      local quad = button.active and button.quadActive or button.quad
      lg.draw(spriteSheet, quad, button.x, 313 + button.offsetY)
    end

    do
    lg.push()
    lg.translate(155, 125)
    local _, _, w, h = inventorySlot:getViewport()
    for iy = 0, 2-1 do
    for ix = 0, 4-1 do
      local index = iy * 4 + ix + 1
      local item
      if sideButtons[1].active or sideButtons[3].active then item = patchItems[index] end
      if not item then
        lg.setColor(.5,.5,.5, 1)
      else
        lg.setColor(1,1,1,1)
      end
      quad = inventorySlotSelected == index and inventorySlotActive or inventorySlot
      lg.draw(spriteSheet, quad, ix*(w+5), iy*(h+15))
    end
    end
    lg.setColor(1,1,1,1)
    -- Two loops for sprite batching
    for iy = 0, 2-1 do
    for ix = 0, 4-1 do
      local item = patchItems[(iy * 4 + ix)+1]
      if item and item.texture then
        local tw, th = item.texture:getDimensions()
        lg.draw(item.texture, ix*(w+5)+60/2-tw/2, iy*(h+15)+58/2-th/2)
      end
    end
    end
    lg.setColor(1,1,1,1)
    lg.pop()
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
  lg.push("all")
    lg.setColor(194/255, 234/255, 73/255, 1)
    lg.push()
      lg.translate(tw/2+80*textureScale, bh*textureScale)
      local font = ui.getFont(18, "fonts.abel", scale)
      local str = "UNKNOWN"
      if sideButtons[1].active then 
        str = "Patching"
        if love.timer.getTime() - sideButtons[1].activateTime >= 1.25 then
          if patchLevel == 1 then
            str = "Pick Fabric..."
          elseif patchLevel == 2 then
            str = "Align..."
          elseif patchLevel == 3 then
            str = "Stitch Fabric..."
          end
        end
      end
      if sideButtons[2].active then str = "Layered Patch" end
      if sideButtons[3].active then str = "Eco Print" end
      if sideButtons[4].active then str = "Create" end
      lg.print(str, font, -font:getWidth(str)/2, -font:getHeight()/2-105*textureScale)
    lg.pop()
    lg.push()
      lg.translate(1580*textureScale+translateX, 100*textureScale)
      local font = ui.getFont(16, "fonts.abel", scale)
      local str = "Fabric"
      lg.print(str, font, -font:getWidth(str)/2, -font:getHeight()/2)
    lg.pop()
    lg.push()
      lg.setColor(0,0,0,1)
      if sideButtons[1].active and patchLevel == 1 and #patchItems ~= 0 then -- Patch 1 choose fabric
        local key = fabricTexturesOrder[fabricArrowPosition]
        if key then
        local fabric = fabricTextures[key]
        if fabric then
          lg.translate(tw/2+80*textureScale, 850*textureScale)
          local str = "Pick " .. fabric.name
          lg.print(str, font, -font:getWidth(str)/2, -font:getHeight()/2)
        end
        end
      end
    lg.pop()
  lg.pop()
  lg.setStencilMode() -- clear stencil
end

return workstation