StartTime = require("love.timer").getTime()

local console, identity, windowTitle = false, "AJ2025-EngineerSmith-beta", "Day Zero, Anima Jam 2025"

if jit then
  jit.on()
end

if console and love._os == "Windows" then
  love._openConsole()
end

local lfs = love.filesystem
lfs.setIdentity(identity, true)
love.setDeprecationOutput(true)

local args = require("util.args")
local logger = require("util.logger")

local assertFatal = function(condition, title, errorMessage)
  if condition then
    local success
    success, love.window = pcall(require, "love.window")
    if not success then love.window = nil end
    logger.fatal(title, errorMessage)
    os.exit(1) -- forces love to exit than continuing to main with an error message
    return 1
  end
  return nil
end

assertFatal(not jit, "Luajit missing", "This game requires luajit - that's packaged with the game.")
assertFatal(love._version_major ~= 12, "Love version error", "Project requires love 12.")
--assertFatal(jit.os ~= "Windows" and jit.os ~= "Linux", "Incompatible error", "This game does not support this platform: "..jit.os)

local settings = require("util.settings")
local json = require("util.json")
local lang = require("util.lang")
local file = require("util.file")

local saveDir = lfs.getSaveDirectory()
local saveDirLang = { }
for _, f in ipairs(lfs.getDirectoryItems("assets/languages")) do
  f = "assets/languages/" .. f
  if lfs.getRealDirectory(f) == saveDir then
    table.insert(saveDirLang, f)
  else
    local success, json = json.decode(f)
    if not success then
      return error("Could not decode language json "..tostring(f)..", error: "..tostring(json))
    end
    local fileName = file.getFileName(f)
    lang.importLocale(fileName, json)
  end
end

-- Second loop allows for savedir languages to override asset based ones
logger.info("Found", #saveDirLang, "additional language files")
for _, f in ipairs(saveDirLang) do
  if file.getFileExtension(f) == "json" then
    local success, json = json.decode(f)
    if not success then
      return error("Could not decode language json "..tostring(f)..", error: "..tostring(json))
    end
    local fileName = file.getFileName(f)
    lang.importLocale(fileName, json) 
  end
end

local lw = require("love.window")

local displayIndex = 1
if (settings.client.windowFullscreen or settings.client.windowMaximise) and
    settings.client.display and displayIndex <= lw.getDisplayCount() then
  displayIndex = settings.client.display
end

local width, height = settings.client.windowSize.width, settings.client.windowSize.height
local dw, dh = lw.getDesktopDimensions(displayIndex)
if width > dw or height > dh then
  width = settings._default.client.windowSize.width
  height = settings._default.client.windowSize.height
end

love.conf = function(t)
  logger.info("Configuring client")
  t.console = console
  t.version = "12.0"
  t.identity = identity
  t.appendidentity = true
  t.accelerometerjoystick = false
  t.highdpi = true

  t.window.title = windowTitle
  t.window.icon  = nil
  t.window.width = width
  t.window.height = height
  t.window.fullscreen = settings.client.windowFullscreen
  t.window.resizable = true
  t.window.minwidth = settings._default.client.windowSize.width
  t.window.minheight = settings._default.client.windowSize.height
  t.window.displayindex = displayIndex
  t.window.msaa = settings.client.msaa
  t.window.vsync = settings.client.vsync
  t.window.depth = true
  t.usedpiscale = true

  t.graphics.gammacorrect = true

  t.audio.mic = false
  t.audio.mixwithsystem = true

  t.modules.audio    = true
  t.modules.data     = true
  t.modules.event    = true
  t.modules.font     = true
  t.modules.graphics = true
  t.modules.image    = true
  t.modules.joystick = true
  t.modules.keyboard = true
  t.modules.math     = true
  t.modules.mouse    = true
  t.modules.system   = true
  t.modules.thread   = true
  t.modules.timer    = true
  t.modules.window   = true

  t.modules.physics  = false
  t.modules.touch    = false
  t.modules.video    = false
end