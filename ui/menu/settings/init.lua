local lg = love.graphics

local audioManager = require("util.audioManager")
local assetManager = require("util.assetManager")
local settings = require("util.settings")
local logger = require("util.logger")
local cursor = require("util.cursor")
local input = require("util.input")
local lang = require("util.lang")
local flux = require("libs.flux")
local ui = require("util.ui")

local assetList = require("ui.menu.settings.assets")

local settingsMenu = {
  tab = "settings.display",
  loaded = false,
  backButtonMaxOffsetW = 30,
  backButtonOffset, -- calculated on show
  backButton = {
    id = "menu.back",
    noScaleX  = true,
    offsetW = 0
  },
}

local settingsOptionSelectorFactory = function(langKey, options, set, get)
  options.langKey = langKey
  options.set = set
  options.get = get
  options.index = -1
  options.type = "option"
  options[options.index] = "NULL"
  return options
end

local loadOptions = function(path)
  path = "ui/menu/settings/" .. path
  local chunk, errmsg = love.filesystem.load(path)
  if errmsg then
    logger.fatal(nil, errmsg)
  end
  return chunk()(settingsOptionSelectorFactory)
end

settingsMenu.displayOptions = loadOptions("displayOptions.lua")
settingsMenu.accessibilityOptions = loadOptions("accessibilityOptions.lua")

local setOption = function(option)
  option.index = option.get()
  option.set(option[option.index])
end

local audioSliderFactory = function(audioType)
  local langKey = "settings.audio."..audioType
  return {
    id = langKey .. ".slider",
    langKey = langKey,
    audioType = audioType,
    value = settings.client.volume[audioType],
    min = 0,
    max = 1,
    step = 0.05,
    type = "audio"
  }
end

settingsMenu.triggers = { }

settingsMenu.load = function()
  if not settingsMenu.loaded then
    settingsMenu.loaded = true
    settingsMenu.lily = assetManager.load(assetList)
    settingsMenu.tab = "settings.display"

    -- Display
    setOption(settingsMenu.displayOptions.mode)
    setOption(settingsMenu.displayOptions.display)
    setOption(settingsMenu.displayOptions.resolution)
    setOption(settingsMenu.displayOptions.msaa)
    setOption(settingsMenu.displayOptions.vsync)
    setOption(settingsMenu.displayOptions.maxFPS)
    setOption(settingsMenu.displayOptions.mouselock)

    -- Audio
    settingsMenu.audioOptions = {
      audioSliderFactory("master"),
      audioSliderFactory("music"),
      audioSliderFactory("ui"),
      audioSliderFactory("sfx"),
    }

    -- Accessibility
    setOption(settingsMenu.accessibilityOptions.systemMouse)

    return settingsMenu.lily
  end
end

settingsMenu.unload = function()
  if settingsMenu.loaded then
    settingsMenu.loaded = false
    assetManager.unload(assetList)

    settingsMenu.triggers = { }
  end
end

settingsMenu.getTabIndex = function(id)
  local index = 0
  id = id or settingsMenu.tab
  for i, tab in ipairs(settingsMenu.tabs) do
    if tab.id == id then
      index = i
      break
    end
  end
  return index
end

local inputTimer, inputTimeout = 0, 0
local inputType = nil
local optionHovered
settingsMenu.update = function(dt)
  local suit = settingsMenu.suit

  if not settingsMenu.triggers.left then
    settingsMenu.triggers.left = assetManager["input.xbox.lefttrigger"]
    settingsMenu.triggers.right = assetManager["input.xbox.righttrigger"]
  end

  if input.baton:pressed("settingsMenuLeft") then
    settingsMenu.triggers.left = assetManager["input.xbox.lefttrigger.highlight"]
    flux.to(settingsMenu.triggers.left, .07, {}):oncomplete(function()
      settingsMenu.triggers.left = assetManager["input.xbox.lefttrigger"]
    end)

    local index = settingsMenu.getTabIndex()
    index = index - 1
    if index == 0 then index = #settingsMenu.tabs end

    audioManager.play("audio.ui.click")
    settingsMenu.tab = settingsMenu.tabs[index].id
    suit:setGamepadPosition(1)
  end

  if input.baton:pressed("settingsMenuRight") then
    settingsMenu.triggers.right = assetManager["input.xbox.righttrigger.highlight"]
    flux.to(settingsMenu.triggers.left, .07, {}):oncomplete(function()
      settingsMenu.triggers.right = assetManager["input.xbox.righttrigger"]
    end)

    local index = settingsMenu.getTabIndex()
    index = index + 1
    if index == #settingsMenu.tabs+1 then index = 1 end

    audioManager.play("audio.ui.click")
    settingsMenu.tab = settingsMenu.tabs[index].id
    suit:setGamepadPosition(1)
  end

  if not suit.gamepadActive then
    if input.baton:pressed("menuNavUp") or input.baton:pressed("menuNavDown") then
      suit:gamepadMode(true)
    end
  end
  if suit.gamepadActive then
    if input.baton:pressed("reject") then
      settingsMenu.backButton.forcedHit = true
    end
    if not inputType then
      local menuUp = input.baton:pressed("menuNavUp") and 1 or 0
      local menuDown = input.baton:pressed("menuNavDown") and 1 or 0
      local pos = menuUp - menuDown
      if pos ~= 0 then
        inputType = pos == 1 and "menuNavUp" or "menuNavDown"
        inputTimer = 0
        inputTimeout = .5
      end

      suit:adjustGamepadPosition(-pos)
    else
      if input.baton:released(inputType) then
        inputType = nil
      else
        inputTimer = inputTimer + dt
        while inputTimer > inputTimeout do
          inputTimer = inputTimer - inputTimeout
          inputTimeout = .1
          suit:adjustGamepadPosition(inputType == "menuNavUp" and -1 or 1)
        end
      end
    end
    if not inputType and optionHovered then
      local o = optionHovered
      if input.baton:pressed("menuNavLeft") then
        if o.type == "option" then
          audioManager.play("audio.ui.click")
          o.index = math.max(o.index - 1, 1)
          o.set(o[o.index])
        elseif o.type == "audio" then
          audioManager.play("audio.ui.click")
          o.value = math.max(o.value - o.step * 2, o.min)
          settings.client.volume[o.audioType] = o.value
          audioManager:setVolumeAll()
        end
      end
      if input.baton:pressed("menuNavRight") then
        if o.type == "option" then
          audioManager.play("audio.ui.click")
          o.index = math.min(o.index + 1, #o)
          o.set(o[o.index])
        elseif o.type == "audio" then
          audioManager.play("audio.ui.click")
          o.value = math.min(o.value + o.step * 2, o.max)
          settings.client.volume[o.audioType] = o.value
          audioManager:setVolumeAll()
        end
      end
    end
  end
end

settingsMenu.backButton.draw = function(text, opt, x, y, w, h)
  local suit = settingsMenu.suit
  local slice3 = assetManager["ui.3slice.basic"]

  if opt.entered then
    if opt.flux then opt.flux:stop() end
    opt.flux = flux.to(opt, .5, {
      offsetW = settingsMenu.backButtonMaxOffsetW
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

  local w = lg.getFont():getWidth(text)
  local button = assetManager["input.xbox.b"]

  lg.push()
  lg.translate(x, y)
    lg.push()
    lg.setColor(1,1,1,1)
    slice3:draw(w + (settingsMenu.backButtonOffset + opt.offsetW) * suit.scale, h)
    lg.pop()
  lg.setColor(.1,.1,.1,1)
  lg.print(text, slice3.offset * suit.scale, 0)
  if suit.gamepadActive and button then
    lg.setColor(1,1,1,1)
    local bw, bh = button:getDimensions()
    lg.draw(button, w + (slice3.offset+2) * suit.scale, 0, 0, (25/bw)*suit.scale, (25/bh)*suit.scale)
  end
  lg.pop()
end

local tabAnimation = { t = 1 }

local drawTabButton = function(text, opt, x, y, w, h)
  local slice3 = assetManager["ui.3slice.tab2"]
  local font = lg.getFont()
  local textWidth = font:getWidth(text)

  if opt.hit then
    if tabAnimation.flux then tabAnimation.flux:stop() end
    tabAnimation.t = .5
    tabAnimation.flux = flux.to(tabAnimation, .2, {
      t = 1,
    }):ease("cubicout")
  end

  lg.push()
  lg.translate(x, y)
  if settingsMenu.tab == opt.id then
    lg.push()
    lg.translate(w/2 - textWidth/2 - slice3.offset*settingsMenu.suit.scale, h/4)
    lg.scale(1, tabAnimation.t)
    slice3:draw(textWidth, h/2)
    lg.pop()
  end
  lg.translate(w/2-textWidth/2, h/2-font:getHeight()/2)
  if settingsMenu.tab ~= opt.id then
    lg.setColor(.7,.7,.7,1)
  else
    lg.setColor(.2,.2,.2,1)
  end
  lg.print(text)
  lg.setColor(1,1,1,1)
  lg.pop()
end

local tabButtonFactory = function(langKey)
  return {
    id = langKey,
    draw = drawTabButton,
  }
end

settingsMenu.tabs = {
  tabButtonFactory("settings.display"),
  tabButtonFactory("settings.audio"),
  --tabButtonFactory("settings.gameplay"),
  --tabButtonFactory("settings.controls"),
  tabButtonFactory("settings.accessibility"),
}

settingsMenu.controlsTabs = {
  tabButtonFactory("settings.controls.keyboard"),
  tabButtonFactory("settings.controls.gamepad"),
}

settingsMenu.set = function(suit)
  settingsMenu.suit = suit
end

local backButton = function(font)
  local str = lang.getText(settingsMenu.backButton.id)
  local width = font:getWidth(str) + (settingsMenu.backButtonOffset + settingsMenu.backButtonMaxOffsetW) * settingsMenu.suit.scale
  settingsMenu.backButton.font = font
  local b = settingsMenu.suit:Button(str, settingsMenu.backButton, settingsMenu.suit.layout:up(width, nil))
  if b.hit or settingsMenu.backButton.forcedHit then
    settingsMenu.backButton.forcedHit = false
    audioManager.play("audio.ui.click")
    return true
  end
  cursor.switchIf(b.hovered, "hand")
  cursor.switchIf(b.left, nil)

  if b.entered then
    audioManager.play("audio.ui.select")
  end
end

local tabButton = function(tab, font)
  local str = lang.getText(tab.id)
  tab.font = font
  local b = settingsMenu.suit:Button(str, tab, settingsMenu.suit.layout:right())
  if b.hit then
    audioManager.play("audio.ui.click")
    settingsMenu.tab = tab.id
    return true
  end
  cursor.switchIf(b.hovered, "hand")
  cursor.switchIf(b.left, nil)
end

local bgShapeCount = 0
local bgShapeOpt = { r = 0, hitbox = false, gamepadOption = true }
local bgShapeColor, bgShapeColorTrans = { .7,.7,1,.05 }, {1,1,1,0}
local bgShapeColorHighlight = { 1,1,1,.1 }
local backgroundShape = function(width, option)
  local suit = settingsMenu.suit
  local layout = suit.layout
  local id = "bgShape."..bgShapeCount

  local x, y, w, h = layout._x-10, layout._y, width+20, layout._h

  if option and (type(option) == "string" or option.type == "option") then
    x = x - layout._w
  end

  local isHovered
  if suit.gamepadActive then
    isHovered = suit:wasHovered(id)
    if isHovered then
      optionHovered = option
    end
  else
    isHovered = suit:mouseInRect(x * suit.scale, y * suit.scale, w * suit.scale, h * suit.scale, suit.mouse_x, suit.mouse_y)
  end
  local c = isHovered and bgShapeColorHighlight or bgShapeCount % 2 == 0 and bgShapeColorTrans or bgShapeColor

  bgShapeOpt.gamepadOption = not suit:isHovered(settingsMenu.backButton.id)
  suit:Shape(id, c, bgShapeOpt, x, y, w, h)
  bgShapeCount = bgShapeCount + 1
end

local buttonOptions = { }
local getButtonOptionsByID = function(id)
  if not buttonOptions[id] then
    buttonOptions[id] = { noBox = true, id = id }
  end
  return buttonOptions[id]
end

local optionSelectorButtonAnimation = { offset = 0 }
local frame1, frame2
frame1 = function()
  flux.to(optionSelectorButtonAnimation, .8, { offset = 8 }):ease("linear"):oncomplete(frame2):delay(.2)
end
frame2 = function()
  flux.to(optionSelectorButtonAnimation, .8, { offset = 0 }):ease("linear"):oncomplete(frame1):delay(.2)
end
frame1()

local disabledColor = { .5, .5, .5, 1 }
local optionSelector = function(option, totalWidth, x, y, w, h)
  local suit = settingsMenu.suit

  backgroundShape(totalWidth, option)

  -- button left
  if type(option) ~= "string" then
    local west = getButtonOptionsByID((option.buttonID or option.langKey) .. "west")
    west.c = option.index == 1 and disabledColor or nil
    local westX = west.c and x or x - optionSelectorButtonAnimation.offset
    local b = suit:Button(assetManager["ui.cursor.navigation.west"], west, westX, y, h, h)
    cursor.switchIf(b.hovered, "hand")
    cursor.switchIf(b.left, nil)
    if b.hit then
      audioManager.play("audio.ui.click")
      option.index = math.max(option.index - 1, 1)
      option.set(option[option.index])
    end
  end
  -- label
  local text, opt = nil, { align = "center" }
  if type(option) == "string" then
    text = lang.getText(option)
    opt.color = disabledColor
  elseif option.langKey == "NULL" then
    text = lang.getText(option[option.index])
  else
    text = lang.getText(option.langKey .. option[option.index])
  end
  suit:Label(text, opt, x+h, y, w-h*2, h)

  -- button right
  if type(option) ~= "string" then
    local east = getButtonOptionsByID((option.buttonID or option.langKey) .. "east")
    east.c = option.index == #option and disabledColor or nil
    local eastX = east.c and x+w-h or x+w-h + optionSelectorButtonAnimation.offset
    local b = suit:Button(assetManager["ui.cursor.navigation.east"], east, eastX, y, h, h)
    cursor.switchIf(b.hovered, "hand")
    cursor.switchIf(b.left, nil)
    if b.hit then
      audioManager.play("audio.ui.click")
      option.index = math.min(option.index + 1, #option)
      option.set(option[option.index])
    end
  end
end

settingsMenu.updateui = function()
  bgShapeCount = 0

  if not settingsMenu.backButtonOffset then
    local slice3 = assetManager["ui.3slice.basic"]
    if not slice3 then
      logger.warn("Settings menu assets not loaded!")
      return
    end
    settingsMenu.backButtonOffset = slice3.offset + slice3.offset2
  end

  local suit = settingsMenu.suit
  local font = ui.getFont(18, "fonts.regular.bold", suit.scale)
  local fontHeight = font:getHeight()
  local buttonHeight = fontHeight / suit.scale

  local windowHeightScaled = lg.getHeight() / suit.scale
  suit.layout:reset(fontHeight*1.5, windowHeightScaled - buttonHeight*0.5, 0, 0)
  suit.layout:up(0, buttonHeight)

  if backButton(font) then
    settingsMenu.tab = settingsMenu.tabs[1].id
    settingsMenu.displayOptions.execute()
    audioManager.setVolumeAll()
    settingsMenu.accessibilityOptions.execute()
    return true
  end

  -- tab buttons

  local windowSize = settings._default.client.windowSize
  local buttonWidth = math.floor(windowSize.width / (#settingsMenu.tabs + 1))
  local buttonHeight = math.floor(windowSize.height / 8)

  local offsetWidth = math.floor((lg.getWidth()/suit.scale - windowSize.width) / 2)

  do
    suit.layout:reset(buttonHeight/2, 0, 0, 0)
    local font = ui.getFont(26, "fonts.medium", suit.scale)
    suit:Label(lang.getText("settings.title"), { font = font }, suit.layout:down(windowSize.width/2, buttonHeight))
  end

  local x, y = -math.floor(buttonWidth/2) + offsetWidth -5*(#settingsMenu.tabs-1), buttonHeight/1.5
  suit.layout:reset(x, y, 5, 0)
  suit.layout:right(buttonWidth, buttonHeight)

  for _, tab in ipairs(settingsMenu.tabs) do
    tabButton(tab, font)
  end

  -- l i n e
  suit.layout:reset(buttonHeight + offsetWidth, buttonHeight/0.6)
  local underlineWidth = windowSize.width-buttonHeight*2
  suit:Shape("underline", suit.color.white, suit.layout:right(underlineWidth, 1.5))

  -- gamepad buttons
  if suit.gamepadActive then
    if settingsMenu.triggers.left then
      suit.layout:reset(buttonHeight + offsetWidth-20, 55)
      suit:Image("settings.gamepad.lefttrigger", settingsMenu.triggers.left, suit.layout:right(40, 40))
    end
    if settingsMenu.triggers.right then
      suit.layout:reset(buttonHeight + offsetWidth + underlineWidth-20, 55)
      suit:Image("settings.gamepad.righttrigger", settingsMenu.triggers.right, suit.layout:left(40, 40))
    end
  end

  -- Tabs
  suit.layout:reset(buttonHeight + offsetWidth + 50, buttonHeight/0.6 + tabAnimation.t*20)
  local _tempX, _tempY = 300, 35
  if settingsMenu.tab == "settings.display" then
    -- Window Mode
    suit:Label(lang.getText("settings.display.displayMode"), suit.layout:down(_tempX,_tempY))
    optionSelector(settingsMenu.displayOptions.mode, _tempX*2, suit.layout:right(_tempX,_tempY))
    suit.layout:translate(-_tempX, 0)
    
    local windowMode = settingsMenu.displayOptions.mode[settingsMenu.displayOptions.mode.index]
    -- Display/Monitor
    suit:Label(lang.getText("settings.display.display"), suit.layout:down(_tempX,_tempY))
    local displayIndex = settingsMenu.displayOptions.display.get()
    if windowMode ~= "free" then
      optionSelector(settingsMenu.displayOptions.display, _tempX*2, suit.layout:right(_tempX,_tempY))
    else
      optionSelector(displayIndex .. ": " .. love.window.getDisplayName(displayIndex), _tempX*2, suit.layout:right(_tempX,_tempY))
    end
    suit.layout:translate(-_tempX, 0)
    -- Resolution
    suit:Label(lang.getText("settings.display.resolution"), suit.layout:down(_tempX,_tempY))
    if windowMode == "fullscreen" then
      optionSelector(settingsMenu.displayOptions.resolution, _tempX*2, suit.layout:right(_tempX,_tempY))
    elseif windowMode == "desktop" then
      local width, height = love.window.getDesktopDimensions(displayIndex)
      optionSelector(width.."x"..height, _tempX*2, suit.layout:right(_tempX,_tempY))
    else
      optionSelector(love.graphics.getWidth().."x"..love.graphics.getHeight(), _tempX*2, suit.layout:right(_tempX,_tempY))
    end
    suit.layout:translate(-_tempX, 0)
    -- MSAA
    suit:Label(lang.getText("settings.display.MSAA"), suit.layout:down(_tempX,_tempY))
    optionSelector(settingsMenu.displayOptions.msaa, _tempX*2, suit.layout:right(_tempX,_tempY))
    suit.layout:translate(-_tempX, 0)
    -- V-sync
    suit:Label(lang.getText("settings.display.vsync"), suit.layout:down(_tempX,_tempY))
    optionSelector(settingsMenu.displayOptions.vsync, _tempX*2, suit.layout:right(_tempX,_tempY))
    suit.layout:translate(-_tempX, 0)
    -- Frame Rate
    suit:Label(lang.getText("settings.display.framerate"), suit.layout:down(_tempX,_tempY))
    if settingsMenu.displayOptions.vsync.index == 1 then
      optionSelector(settingsMenu.displayOptions.maxFPS, _tempX*2, suit.layout:right(_tempX,_tempY))
    else
      optionSelector("settings.display.maxFPS.unlimited", _tempX*2, suit.layout:right(_tempX,_tempY))
    end
    suit.layout:translate(-_tempX, 0)
    -- Lock mouse
    suit:Label(lang.getText("settings.display.mouselock"), suit.layout:down(_tempX,_tempY))
    optionSelector(settingsMenu.displayOptions.mouselock, _tempX*2, suit.layout:right(_tempX,_tempY))
    suit.layout:translate(-_tempX, 0)
    
    -- MAYBE
    -- Background rendering ??
    -- Brightness ???
    -- Interface scale ???
  elseif settingsMenu.tab == "settings.audio" then
    --settings.client.volume pairs
    local height = _tempY/2
    for _, audio in ipairs(settingsMenu.audioOptions) do
      suit:Label(lang.getText(audio.langKey), suit.layout:down(_tempX,_tempY))
      backgroundShape(_tempX*2, audio)
      suit.layout:translate(0, height/4)
      local s = suit:Slider(audio, suit.layout:right(_tempX,height))
      cursor.switchIf(s.hovered, "hand")
      cursor.switchIf(s.left, nil)
      if s.changed then
        settings.client.volume[audio.audioType] = audio.value
        audioManager.setVolumeAll()
      end
      suit.layout:translate(-_tempX, height/4*3)
    end
    
    -- MAYBE
    -- Background audio
  elseif settingsMenu.tab == "settings.gameplay" then
    -- ??? ???? ???? ???
  elseif settingsMenu.tab == "settings.controls" then
    -- Subtab buttons
    -- local width = underlineWidth / 2
    -- suit.layout:translate(-width, 0)
    -- suit.layout:right(width, buttonHeight)
    -- for _, tab in ipairs(settingsMenu.controlsTabs) do
    --   tabButton(tab, font)
    -- end
    -- keyboard
    -- controller
    -- deadzone
    -- deadzone square
    -- controller type
    -- controller map
  elseif settingsMenu.tab == "settings.accessibility" then
    -- System Cursor
    suit:Label(lang.getText("settings.accessibility.systemMouse"), suit.layout:down(_tempX,_tempY))
    optionSelector(settingsMenu.accessibilityOptions.systemMouse, _tempX*2, suit.layout:right(_tempX,_tempY))
    suit.layout:translate(-_tempX, 0)

    -- gameplay?
    -- shaking?
    -- colourblind
      -- Game should be designed with this in mind anyway.
    -- Shaders? DoF, Bloom, Sharpen
  end
end

settingsMenu.draw = function()
  lg.push("all")
  lg.origin()
  lg.setColor(0,0,0, .8)
  lg.rectangle("fill", 0, 0, lg.getDimensions())
  lg.pop()
end

return settingsMenu