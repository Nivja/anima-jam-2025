local lfs = love.filesystem
local json = require("util.json")
local args = require("util.args")
local logger = require("util.logger")

local settingsFile = "settings.json"
if type(args["--settings"]) == "table" then
  settingsFile = args["-settings"][1]
end

local defaultSettings = { 
    client = {
      windowSize = { width = 800, height = 450, },
      windowMaximise = false,
      windowFullscreen = false,
      windowFullscreenType = "desktop",
      display = 1,
      msaa = 4,
      vsync = 1,
      maxFPS = -1,
      mouselock = false,
      systemCursor = false,
      input = { -- Controls defined by https://github.com/tesselode/baton
        moveLeft  = { "sc:a", "sc:left",  "axis:leftx-" },
        moveRight = { "sc:d", "sc:right", "axis:leftx+" },
        moveUp    = { "sc:w", "sc:up",    "axis:lefty-" },
        moveDown  = { "sc:s", "sc:down",  "axis:lefty+" },
        menuNavLeft  = { "sc:a", "sc:left",  "axis:leftx-", "button:dpleft"  },
        menuNavRight = { "sc:d", "sc:right", "axis:leftx+", "button:dpright" },
        menuNavUp    = { "sc:w", "sc:up",    "axis:lefty-", "button:dpup"    },
        menuNavDown  = { "sc:s", "sc:down",  "axis:lefty+", "button:dpdown"  },
        menuNavLeftN  = { "sc:a", "sc:left",  "button:dpleft"  },
        menuNavRightN = { "sc:d", "sc:right", "button:dpright" },
        menuNavUpN    = { "sc:w", "sc:up",    "button:dpup"    },
        menuNavDownN  = { "sc:s", "sc:down",  "button:dpdown"  },
        settingsMenuLeft  = { "axis:triggerleft+" },
        settingsMenuRight = { "axis:triggerright+" },
        cameraLeft  = { "axis:rightx-" }, -- Cannot map to mouse; it doesn't act like a thumbstick!
        cameraRight = { "axis:rightx+" },
        cameraUp    = { "axis:righty-" }, -- Should you be able to remap, or map the movements of the mouse
        cameraDown  = { "axis:righty+" }, --   to an axis that isn't normalized? TODO POLISH?
        interact = { "sc:space", "sc:return", "button:a" },
        accept = { "sc:space", "sc:return", "mouse:1", "button:a" },
        reject = { "sc:escape", "sc:backspace", "button:b" },
        pause =   { "sc:escape", "button:start" },
        unpause = { "sc:escape", "sc:backspace", "button:start", "button:back", "button:b" },
        leftBumper = { "button:leftshoulder" },
        rightBumper = { "button:rightshoulder" },
      },
      deadzone = .15,
      deadzoneSquared = false,
      disableShaking = false, --todo make it variable 0..1
      gamepadType = "general",
      gamepadGUID = "nil",
      locale = "en",
      volume = { -- update \ui\menu\settings\init.lua#load -> audio
        master = 0.8,
        music = 0.6,
        ui = 0.8, 
        sfx = 0.8,
      },
    },
  }

local inputControls = {
  "moveUp", "moveDown", "moveLeft", "moveRight", "menuNavUp", "menuNavDown", "menuNavLeft", "menuNavRight", "settingsMenuLeft", "settingsMenuRight", "interact", "accept", "reject"
}

-- lazy deep copy, the best kind of copy
-- 27/08/24 This is literally the only reason why this project needs luajit right now lol
local b = require("string.buffer")
local settings = b.decode(b.encode(defaultSettings))
b = nil

local formatTable
formatTable = function(dirtyTable, cleanTable)
  for k,v in pairs(cleanTable) do
    local vType = type(v)
    if type(dirtyTable[k]) ~= vType then
        dirtyTable[k] = v
    else
      if vType == "table" then
        dirtyTable[k] = formatTable(dirtyTable[k],v)
      end
    end
  end
  return dirtyTable
end

local newSettings = false

if not args["--reset"] and lfs.getInfo(settingsFile, "file") then
  local success, decodedSettings = json.decode(settingsFile)
  if success then
    settings = formatTable(decodedSettings, defaultSettings)
  end
else
  newSettings = true
end

local encode = function()
  local success, message = json.encode(settingsFile, settings)
  if not success then
    logger.error("Could not update", settingsFile, ":", message)
  end
end
encode() -- creates default file

local handlers = {}
local out = {
    client = {
      inputControls = inputControls,
      encode = encode,
      resize = function(w, h)
          if love.window then
            settings.client.windowMaximise = love.window.isMaximized()
            if not settings.client.windowMaximise then
              settings.client.windowSize = {
                width = w, height = h
              }
            else
              local _, _, flags = love.window.getMode()
              settings.client.display = flags.displayindex
            end
            encode()
          end
        end,
    },
    _default = defaultSettings,
    addHandler = function(key, func)
        local h = handlers[key] or { }
        handlers[key] = h
        table.insert(h, func)
      end,
    encode = encode,
    newSettings = newSettings,
  }
setmetatable(out.client, {
    __index = function(_, key)
        return settings.client[key]
      end,
    __newindex = function(_, key, value)
        settings.client[key] = value
        encode()
        if handlers[key] then
          for _, func in ipairs(handlers[key]) do
            func()
          end
        end
      end,
  })
return out

