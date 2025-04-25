local lfs, lg = love.filesystem, love.graphics

local logger = require("util.logger")
local flux = require("libs.flux")
local g3d = require("libs.g3d")

local missingTexture = lg.newImage("assets/missingTexture.png")
missingTexture:setWrap("repeat")

local plane = g3d.newModel("assets/models/plane.obj")

local pixelToUnitScale = 500 -- 500x500 = 1:1

local objVFormat = "v %.6f %.6f %.6f\n"
local objVTFormat = "vt %.6f %.6f\n"
local objVNFormat = "vn %.6f %.6f %.6f\n"
local createModelForQuad = function(quadX, quadY, quadW, quadH, texture)
  local objString = ""

  local halfW, halfH = (quadW / pixelToUnitScale) / 2, (quadH / pixelToUnitScale) / 2

  objString = objString .. objVFormat:format( halfW, -halfH, 0.0)
  objString = objString .. objVFormat:format(-halfW, -halfH, 0.0)
  objString = objString .. objVFormat:format( halfW,  halfH, 0.0)
  objString = objString .. objVFormat:format(-halfW,  halfH, 0.0)

  local textureWidth, textureHeight = texture:getDimensions()
  local u1 = quadX / textureWidth -- left U
  local v1 = quadY / textureHeight -- Bottom V
  local u2 = (quadX + quadW) / textureWidth -- Right U
  local v2 = (quadY + quadH) / textureHeight -- Top V

  objString = objString .. objVTFormat:format(u2, v2)
  objString = objString .. objVTFormat:format(u1, v1)
  objString = objString .. objVTFormat:format(u1, v2)
  objString = objString .. objVTFormat:format(u2, v1)

  objString = objString .. objVNFormat:format(0.0, 0.0, -1.0)

  objString = objString .. "f 2/1/1 3/2/1 1/3/1\nf 2/1/1 4/4/1 3/2/1"

  local tempFileName = ".temp_quad_model.obj"
  local success, errorMessage = love.filesystem.write(tempFileName, objString)

  if success then
    local model = g3d.newModel(tempFileName, texture)
    local success, errorMessage = love.filesystem.remove(tempFileName)
    if not success then
      logger.warn("Could not remove .temp file created for model generation")
    end
    return model
  else
    logger.fatal("OBJ TEMP FILE", "Unable to write to file[", love.filesystem.getSaveDirectory().."/"..tempFileName, "], reason:", errorMessage)
    error("Unable to create temp file used for OBJ generation")
    return nil
  end
end

local character = { }
character.__index = character

character.new = function(directory, dirName, definition)
  local self = {
    x = 0, y = 0, z = 3,
    rotation = 0,
    scale = 1,
    state = "idle",
  }

  if definition.transform then
    for index, value in pairs(definition.transform) do
      if self[index] and type(value) == "number" then
        self[index] = value
      end
    end
  end

  if definition.spritesheet then
    local path = directory .. "/" .. definition.spritesheet
    if lfs.getInfo(path, "file") then
      self.spritesheet = lg.newImage(path)
    else
      error("Couldn't find spritesheet path:", path)
    end
  else
    error("Character is missing spritesheet, of:", dirName)
  end

  local partLookup = { }
  -- Create and validate parts 
  for _, partDefinition in ipairs(definition.parts) do
    if not partDefinition.name then
      logger.warn("Character", dirName, "has a part that doesn't have a name")
      goto continue
    end

    local part = {
      name = partDefinition.name,
      x = 0, y = 0, r = 0, scale = 1, -- Defaults are actually set later for these values
      ax = 0, ay = 0, ar = 0, ascale = 1, -- Used for animation
      children = { } -- populated later
    }
    partLookup[partDefinition.name] = part

    part.shouldDraw = not (partDefinition.draw == false)
    if self.spritesheet and type(partDefinition.texture) == "table" then
      local t = partDefinition.texture
      local x, y, w, h = t.x, t.y, t.width, t.height
      part.quad = lg.newQuad(x, y, w, h, self.spritesheet)
    else
      error("Missing texture property of part:", partDefinition.name, "of", dirName)
    end

    part.pivot = partDefinition.pivot
    local t = partDefinition.texture
    if type(part.pivot) ~= "table" then part.pivot = { t.x + t.width/2, t.y + t.height/2 } end
    if type(part.pivot[1]) ~= "number" then part.pivot[1] = t.x + t.width/2 end
    if type(part.pivot[2]) ~= "number" then part.pivot[2] = t.y + t.height/2 end

    part.pivot[1] = part.pivot[1] - t.x
    part.pivot[2] = part.pivot[2] - t.y

    part.offset = partDefinition.offset
    if type(part.offset) ~= "table" then part.offset = { 0, 0 } end
    if type(part.offset[1]) ~= "number" then part.offset[1] = 0 end
    if type(part.offset[2]) ~= "number" then part.offset[2] = 0 end

    part.zOffset = partDefinition.zOffset
    if type(part.zOffset) ~= "number" then part.zOffset = 0 end

    part.x = partDefinition.x
    if type(part.x) ~= "number" then part.x = 0 end

    part.y = partDefinition.y
    if type(part.y) ~= "number" then part.y = 0 end

    part.r = partDefinition.r
    if type(part.r) ~= "number" then part.r = 0 end

    part.scale = partDefinition.scale
    if type(part.scale) ~= "number" then part.scale = 1 end

    ::continue::
  end

  -- Relationship: children
  local root = nil
  for _, partDefinition in ipairs(definition.parts) do
    if partDefinition.parent == nil then
      if not root then
        root = partLookup[partDefinition.name]
      else
        logger.warn("Character", dirName, "has more than one part with parent property is null! Ignoring:", partDefinition.type)
      end
    else
      local parent = partLookup[partDefinition.parent]
      if not parent then
        logger.warn("Character", dirName, "part[", partDefinition.name,"] has parent that hasn't been defined! Ignoring:", partDefinition.parent)
      else
        table.insert(parent.children, partLookup[partDefinition.name])
      end
    end
  end

  self.partLookup = partLookup
  self.dirName = dirName
  self.root = root

  -- debug
  local f
  f = function(part, deg)
    if part.name == "Scarf" then
      deg = deg / 1.5
    end
    local a, b
    a = function()
      flux.to(part, 1, {
        ar = math.rad(-deg),
      }):oncomplete(b)
    end
    b = function()
      flux.to(part, 1, {
        ar = math.rad( deg),
      }):oncomplete(a)
    end
    if part.name ~= "BagStrap.Left" and part.name ~= "BagStrap.Right" and part.name ~= "Shoulder.Right" and part.name ~= "Shoulder.Left" then
      a()
    end
    deg = deg / 1.5
    for _, part in ipairs(part.children) do
      f(part, deg)
    end
  end
  -- f(root, 50)
  -- f(root, 15)

  return setmetatable(self, character)
end

character.update = function(self, dt)
  -- self.root.y = self.root.y + dt
  -- self.root.scale = self.root.scale + dt * 0.5
end

local collectDrawItems
collectDrawItems = function(part, transform, z, drawingQueue, spritesheet)
  if not part.shouldDraw then
    return
  end

  local offsetX, offsetY = unpack(part.offset)
  local pivotX, pivotY = unpack(part.pivot)

  transform:translate(part.x + part.ax + offsetX, part.y + part.ay + offsetY)
  transform:scale(part.scale * part.ascale)
  transform:rotate(part.r + math.rad(part.ar))

  z = z + part.zOffset

  transform:translate(-pivotX, -pivotY)
  table.insert(drawingQueue, {
    name = part.name,
    texture = part.texture or spritesheet,
    quad = part.quad,
    transform = transform:clone(),
    zPosition = z,
  })
  transform:translate(pivotX, pivotY)

  for _, child in ipairs(part.children) do
    collectDrawItems(child, transform:clone(), z, drawingQueue, spritesheet)
  end
end

local characterCanvasSize = 1700
local characterCanvas = lg.newCanvas(characterCanvasSize, characterCanvasSize)
local characterCanvasPlane = createModelForQuad(0, 0, characterCanvasSize, characterCanvasSize, characterCanvas)

character.draw = function(self)
  local drawingQueue = { }

  collectDrawItems(self.root, love.math.newTransform(), 0, drawingQueue, self.spritesheet)
  table.sort(drawingQueue, function(a, b) return a.zPosition < b.zPosition end)

  lg.push("all")
  lg.origin()
  lg.setCanvas(characterCanvas)
  lg.clear(0, 0, 0, 0)
  local w, h = characterCanvas:getDimensions()
  lg.translate(w/2, h/2)
  -- lg.scale(-1, 1) -- flip
  for _, item in ipairs(drawingQueue) do
    lg.push()
    lg.applyTransform(item.transform)

    if item.quad then
      lg.draw(item.texture, item.quad)
    else
      lg.draw(item.texture)
    end
    lg.pop()
  end
  lg.pop()

  
  lg.push()
  characterCanvasPlane:setTranslation(self.x, self.y, self.z)
  characterCanvasPlane:draw()
  lg.pop()
end

return character