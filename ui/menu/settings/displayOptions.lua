local settings = require("util.settings")
local logger = require("util.logger")
local input = require("util.input")

local setMode = function()
  local w, h, flags = love.window.getMode()
  flags.fullscreen = settings.client.windowFullscreen
  flags.fullscreentype = settings.client.windowFullscreenType
  if flags.fullscreen then
    flags.displayindex = settings.client.display
  end
  w, h = settings.client.windowSize.width, settings.client.windowSize.height
  flags.msaa = settings.client.msaa
  local texturemsaa = love.graphics.getSystemLimits().texturemsaa
  if flags.msaa > texturemsaa then
    logger.warn("Settings tried to apply MSAA of", flags.msaa, ", but this system supports max", texturemsaa)
    flags.msaa = texturemsaa
  end
  flags.vsync = settings.client.vsync
  love.window.setMode(w, h, flags)
  if not flags.fullscreen then
    local dw, dh = love.window.getDesktopDimensions(flags.displayIndex)
    if dw == w and dh == h then
      love.window.maximize()
    end
  end

  love.mouse.setGrabbed(settings.client.mouselock)

  settings.encode()
end

return function(optionSelectorFactory)
  local displayOptions = {
    execute = setMode
  }

  displayOptions.mode = optionSelectorFactory(
    "settings.display.displayMode.",
    {"free", "desktop", "fullscreen"},
    function(option) -- set
      if option == "free" then
        settings.client.windowFullscreen = false
      elseif option == "desktop" then
        settings.client.windowFullscreen = true
        settings.client.windowFullscreenType = "desktop"
      elseif option == "fullscreen" then
        settings.client.windowFullscreen = true
        settings.client.windowFullscreenType = "exclusive"
      end
    end,
    function() -- get
      if not settings.client.windowFullscreen then
        return 1
      elseif settings.client.windowFullscreenType == "desktop" then
        return 2
      elseif settings.client.windowFullscreenType == "exclusive" then
        return 3
      end
    end
  )

  local displays = { }
  for i = 1, love.window.getDisplayCount() do
    displays[i] = ("%d: %s"):format(i, love.window.getDisplayName(i))
  end

  displayOptions.display = optionSelectorFactory(
    "NULL",
    displays,
    function(option) -- set
      if option == "NULL" then return end
      local i = option:match("^(%d+): ")
      settings.client.display = i

      -- Get modes, sort, format
      local modes = love.window.getFullscreenModes(displayOptions.display.index)
      table.sort(modes, function(a, b) return a.width*a.height>b.width*b.height end)
      for i, mode in ipairs(modes) do
        modes[i] = ("%dx%d"):format(mode.width, mode.height)
      end

      -- Clear resolution
      for i, _ in ipairs(displayOptions.resolution) do
        displayOptions.resolution[i] = nil
      end

      -- Set resolution modes
      for i, mode in ipairs(modes) do
        displayOptions.resolution[i] = mode
      end

      if #modes == 0 then
        displayOptions.resolution.index = -1
      elseif displayOptions.resolution.index > #displayOptions.resolution then
        displayOptions.resolution.index = 1
      end

      displayOptions.resolution.set(displayOptions.resolution[displayOptions.resolution.index])
    end,
    function() -- get
      local _, _, flags = love.window.getMode()
      return flags.displayindex or 1
    end
  )
  displayOptions.display.buttonID = "settings.display.display."

  displayOptions.resolution = optionSelectorFactory(
    "NULL",
    { },
    function(option) -- set
      if option == "NULL" then return end
      local width, height = option:match("^(%d+)x(%d+)$")
      local size = settings.client.windowSize
      size.width, size.height = width, height
    end,
    function() -- get
      return 1 -- call displayOptions.display.update() to set index
    end
  )
  displayOptions.resolution.buttonID = "settings.display.resolution."

  displayOptions.msaa = optionSelectorFactory(
    "NULL",
    { "settings.display.MSAA.disabled", "x2", "x4", "x8" },
    function(option) --set
      local msaa
      if option == "settings.display.MSAA.disabled" then
        msaa = 0
      elseif option == "x2" then
        msaa = 2
      elseif option == "x4" then
        msaa = 4
      elseif option == "x8" then
        msaa = 8
      end
      settings.client.msaa = msaa
    end,
    function() --get
      local _, _, flags = love.window.getMode()
      local msaa = flags.msaa
      if msaa <= 0 then
        return 1
      elseif msaa <= 2 then
        return 2
      elseif msaa <= 4 then
        return 3
      else
        return 4
      end
    end
  )
  displayOptions.msaa.buttonID = "settings.display.msaa."

  displayOptions.vsync = optionSelectorFactory(
    "settings.display.vsync.",
    { "disabled", "enabled", "adaptive" },
    function(option) -- set
      local vsync
      if option == "disabled" then
        vsync = 0
      elseif option == "enabled" then
        vsync = 1
      elseif option == "adaptive" then
        vsync = -1
      end
      settings.client.vsync = vsync
    end,
    function() -- get
      local vsync = love.window.getVSync()
      if vsync == -1 then
        return 3
      elseif vsync == 0 then
        return 1
      elseif vsync == 1 then
        return 2
      end
    end
  )

  displayOptions.maxFPS = optionSelectorFactory(
    "NULL",
    { "settings.display.maxFPS.unlimited", "15", "30", "45", "60", "90", "120" },
    function(option) -- set
      -- TODO
      if option == "settings.display.maxFPS.unlimited" then
        return -1
      else
        return tonumber(option)
      end
    end,
    function() -- get
      local fps = settings.client.maxFPS
      if fps <= -1 then
        return 1
      elseif fps <= 15 then
        return 2
      elseif fps <= 30 then
        return 3
      elseif fps <= 45 then
        return 4
      elseif fps <= 60 then
        return 5
      elseif fps <= 90 then
        return 6
      else
        return 7
      end
    end
  )
  displayOptions.maxFPS.buttonID = "settings.display.maxFPS"

  displayOptions.mouselock = optionSelectorFactory(
    "settings.display.mouselock.",
    { "unlocked", "locked" },
    function(option) -- set
      settings.client.mouselock = option == "locked"
    end,
    function() -- get
      return love.mouse.isGrabbed() and 2 or 1
    end
  )

  return displayOptions
end