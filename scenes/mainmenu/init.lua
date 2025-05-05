local lg = love.graphics

local audioManager = require("util.audioManager")
local assetManager = require("util.assetManager")
local settings = require("util.settings")
local logger = require("util.logger")
local cursor = require("util.cursor")
local input = require("util.input")
local lang = require("util.lang")
local flux = require("libs.flux")
local suit = require("libs.suit").new()
local ui = require("util.ui")

local settingsMenu = require("ui.menu.settings")
settingsMenu.set(suit)

suit.theme = require("ui.theme.menu")

local scene = { }

scene.preload = function()
  settingsMenu.preload()
end

local musicRef
scene.load = function()
  suit:gamepadMode(true)
  cursor.setType(settings.client.systemCursor and "system" or "custom")

  scene.menu = "prompt"
  settingsMenu.load()

  musicRef = audioManager.play("audio.music.menu")
end

scene.unload = function()
  cursor.switch(nil)
  settingsMenu.unload()

  local startingVolume = musicRef:getVolume()
  local tweenRef
  tweenRef = flux.to({ }, 2, { })
    :ease("linear")
    :onupdate(function()
      musicRef:setVolume(startingVolume * (1- tweenRef.progress))
    end)
    :oncomplete(function()
      musicRef:stop()
      musicRef:seek(0)
      musicRef:setVolume(startingVolume)
    end)
end

scene.langchanged = function()
  scene.prompt = require("libs.sysl-text").new("left", { 
    color = { 1,1,1,1 },
  })
  scene.prompt:send(lang.getText("menu.prompt"), nil, true)
end

scene.resize = function(w, h)
  -- Update settings
  settings.client.resize(w, h)

-- Scale scene
  local wsize = settings._default.client.windowSize
  local tw, th = wsize.width, wsize.height
  local sw, sh = w / tw, h / th
  scene.scale = sw < sh and sw or sh

  -- scale UI
  suit.scale = scene.scale
  suit.theme.scale = scene.scale

  -- scale Text
  local font = ui.getFont(18, "fonts.regular.bold", scene.scale)
  lg.setFont(font)

  scene.prompt.default_font = font

  -- scale Cursor
  cursor.setScale(scene.scale)
end

local inputTimer, inputTimeout = 0, 0
local inputType = nil
scene.update = function(dt)
  if scene.menu == "main" then
    if not suit.gamepadActive then
      if input.baton:pressed("menuNavUp") or input.baton:pressed("menuNavDown") then
        suit:gamepadMode(true)
      end
    end
    if suit.gamepadActive then
      if not inputType then
        local menuUp = input.baton:pressed("menuNavUp") and 1 or 0
        local menuDown = input.baton:pressed("menuNavDown") and 1 or 0
        local pos = menuUp - menuDown
        if pos ~= 0 then
          inputType = pos == 1 and "menuNavUp" or "menuNavDown"
          inputTimer = 0
          inputTimeout = .5
        end

        suit:adjustGamepadPosition(pos)
      else
        if input.baton:released(inputType) then
          inputType = nil
        else
          inputTimer = inputTimer + dt
          while inputTimer > inputTimeout do
            inputTimer = inputTimer - inputTimeout
            inputTimeout = .1
            suit:adjustGamepadPosition(inputType == "menuNavUp" and 1 or -1)
          end
        end
      end

      if input.baton:pressed("accept") then
        suit:setHit(suit.hovered)
      end
      if input.baton:pressed("reject") then
        suit:setGamepadPosition(1) -- jump to exit button
      end
    end
  end

  if suit.gamepadActive then
    love.mouse.setRelativeMode(true)
    love.mouse.setVisible(false)
  else
    love.mouse.setRelativeMode(false)
    love.mouse.setVisible(true)
  end

  if scene.menu == "settings" then
    settingsMenu.update(dt)
  end

  scene.prompt:update(dt)
end

local maxOffsetW = 30

local drawMenuButton = function(text, opt, x, y, w, h)
  local slice3 = assetManager["ui.3slice.basic"]

  if opt.entered then
    if opt.flux then opt.flux:stop() end
    opt.flux = flux.to(opt, .5, {
      offsetW = maxOffsetW
    }):ease("elasticout")
  end
  if opt.left then
    if opt.flux then opt.flux:stop() end
    opt.flux = flux.to(opt, .2, {
      offsetW = 0
    }):ease("quadout")
  end
  if not opt.hovered and opt.flux and opt.flux.progress >= 1 then
    opt.flux:stop()
    opt.flux = nil
    opt.offsetW = 0
  end

  lg.push()
  lg.origin()
  lg.translate(x, y)
    lg.push() 
    if opt.hovered then
      lg.setColor(1,1,1,1)
    else
      lg.setColor(1,1,1,1)
    end
    slice3:draw(lg.getFont():getWidth(text) + (slice3.offset*2 + opt.offsetW) * scene.scale, h)
    lg.pop()
  lg.setColor(.1,.1,.1,1)
  if opt.hovered then
    text = " "..text
  end
  lg.print(text, slice3.offset * scene.scale, 0)
  lg.setColor(1,1,1,1)
  lg.pop()
end

local changeMenu = function(target)
  scene.menu = target
  cursor.switch(nil)
end

local menuButton = function(button, font, height)
  local str = lang.getText(button.id)
  local slice3 = assetManager["ui.3slice.basic"]
  local slice3Width = slice3:getLength(font:getWidth(str), height)
  local width = slice3Width + maxOffsetW * scene.scale
  local b = suit:Button(str, button, suit.layout:up(width, nil))
  if b.hit and type(button.hitCB) == "function" then
    audioManager.play("audio.ui.click")
    button.hitCB()
    return
  end
  cursor.switchIf(b.hovered, "hand")
  cursor.switchIf(b.left, nil)

  if b.entered then
    audioManager.play("audio.ui.select")
  end
end

local mainButtonFactory = function(langKey, callback)
  return {
    id = langKey,
    hitCB = callback,
    noScaleX = true,
    draw = drawMenuButton,
    gamepadOption = true,
    offsetW = 0,
  }
end

local mainButtons = {
  mainButtonFactory("menu.exit", function()
      love.event.quit()
    end),
  mainButtonFactory("menu.settings", function()
      changeMenu("settings")
      suit:setGamepadPosition(1)
    end),
  mainButtonFactory("menu.new_game", function()
      --changeMenu("game")
      require("util.sceneManager").changeScene("scenes.game", suit.gamepadActive)
    end),
}

if false then
  logger.warn("TODO load button conditional show")
  table.insert(mainButtons,
    mainButtonFactory("menu.load", function()
      logger.warn("TODO load game button")
    end))
  table.insert(mainButtons,
    mainButtonFactory("menu.continue", function()
      logger.warn("TODO continue game button")
    end))
end

scene.updateui = function()
  suit:enterFrame()
  local font = lg.getFont()
  local fontHeight = font:getHeight()
  local buttonHeight = fontHeight / scene.scale

  local windowHeightScaled = lg.getHeight() / scene.scale
  suit.layout:reset(fontHeight*1.5, windowHeightScaled - buttonHeight*0.5, 0, 10)
  suit.layout:up(0, buttonHeight)
  suit.layout:up(0, buttonHeight)

  if scene.menu == "main" then
    for _, button in ipairs(mainButtons) do
      menuButton(button, font, buttonHeight)
    end
  elseif scene.menu == "settings" then
    if settingsMenu.updateui() then
      changeMenu("main")
    end
  end
end

scene.draw = function()
  lg.clear(201/255, 118/255, 34/255)
  if scene.menu == "prompt" then
    local windowW, windowH = lg.getDimensions()
    local offset = windowH/10
    scene.prompt:draw(offset, windowH - offset - scene.prompt.get.height)
  elseif scene.menu == "settings" then
    settingsMenu.draw()
  end
  suit:draw(1)
end

scene.textedited = function(...)
  suit:textedited(...)
end

scene.textinput = function(...)
  suit:textinput(...)
end

local inputDetected = function(inputType)
  if scene.menu == "prompt" then
    flux.to(scene.prompt.current_color, .2, { [4] = 0 }):ease("linear"):oncomplete(function()
      changeMenu("main")
    end)
    if inputType == "mouse" then
      suit:gamepadMode(false)
    end
  end
end

scene.keypressed = function(...)
  suit:keypressed(...)
  inputDetected()
end

scene.mousepressed = function()
  inputDetected("mouse")
  suit:gamepadMode(false)
end
scene.touchpressed = scene.mousepressed

scene.mousemoved = function()
  if scene.menu ~= "prompt" then
    suit:gamepadMode(false)
  end
end

scene.wheelmoved = function(...)
  suit:updateWheel(...)
  inputDetected()
end

scene.gamepadpressed = function()
  inputDetected()
  suit:gamepadMode(true)
end
scene.joystickpressed = scene.gamepadpressed
scene.joystickaxis = scene.gamepadpressed

return scene