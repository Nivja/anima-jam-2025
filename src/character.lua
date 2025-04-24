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
    local model = g3d.newModel(tempFileName)
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
    x = 0, y = 0, z = 4,
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

    if self.spritesheet and type(partDefinition.texture) == "table" then
      local t = partDefinition.texture
      local x, y, w, h = t.x, t.y, t.width, t.height
      part.model = createModelForQuad(x, y, w, h, self.spritesheet)
    else
      if partDefinition.texture then
        local path = directory .. "/" .. partDefinition.texture
        if lfs.getInfo(path, "file") then
          part.texture = lg.newImage(path)
        else
          logger.warn("Character", dirName, "part[", partDefinition.name,"] couldn't find texture file:", path)
        end
      else
        logger.warn("Character", dirName, "has a part[", partDefinition.name,"] with a missing texture")
      end
      if not part.texture then
        logger.warn("Character", dirName, "part[", partDefinition.name,"] idn't load a texture, setting missing texture")
        part.texture = missingTexture
      end
    end

    if partDefinition.pivot then
      part.pivot = partDefinition.pivot
    elseif partDefinition.pixelPivot and type(partDefinition.texture) == "table" then
      local x, y = unpack(partDefinition.pixelPivot)
      x, y = x or 0, y or 0
      local t = partDefinition.texture
      x = ((x - t.x) / t.width) * 100
      y = ((y - t.y) / t.height) * 100
      part.pivot = { x, y }
    end
    if type(part.pivot) ~= "table" then part.pivot = { 50, 50 } end
    if type(part.pivot[1]) ~= "number" then part.pivot[1] = 50 end
    if type(part.pivot[2]) ~= "number" then part.pivot[2] = 50 end

    part.offset = partDefinition.offset
    if type(part.offset) ~= "table" then part.offset = { .5, .5 } end
    if type(part.offset[1]) ~= "number" then part.offset[1] = .5 end
    if type(part.offset[2]) ~= "number" then part.offset[2] = .5 end

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
    if part.name ~= "Scarf" then
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
    if part.name ~= "BagStrap.Left" and part.name ~= "BagStrap.Right" then
      a()
    end
    deg = deg / 1.5
    for _, part in ipairs(part.children) do
      f(part, deg)
    end
  end
  f(root, 90)

  return setmetatable(self, character)
end

character.update = function(self, dt)
  -- self.y = self.y + dt
end

local collectDrawItems
collectDrawItems = function(part, transform, drawingQueue, spritesheet)
  transform:scale(part.scale * part.ascale) -- this doesn't set the Z axis to scale; but we don't care about it
  local model = part.model or plane
  local v01, v02, _, _, v05, v06 = transform:getMatrix()
  local scaleX, scaleY = math.sqrt(v01^2 + v05^2), math.sqrt(v02^2 + v06^2)
  local offsetX, offsetY = ((part.offset[1]/100)) * scaleX, ((part.offset[2]/100)) * scaleY
  local pivotX, pivotY = ((part.pivot[1]/100)-0.5) * scaleX, ((part.pivot[2]/100)-0.5) * scaleY
  -- logger.info(part.name, pivotX, pivotY)

  transform:translate(part.x + part.ax + offsetX, part.y + part.ay + offsetY)
  transform:translate(-pivotX, -pivotY)
  transform:rotate(part.r + part.ar)
  transform:translate(pivotX, pivotY)

  local v01, v02, v03, v04,
        v05, v06, v07, v08,
        v09, v10, v11, v12,
        v13, v14, v15, v16 = transform:getMatrix()

  v12 = v12 + -(part.zOffset/100)

  local finalMatrix = {
    v01, v02, v03, v04,
    v05, v06, v07, v08,
    v09, v10, v11, v12,
    v13, v14, v15, v16,
  }

  transform:setMatrix(v01, v02, v03, v04,
                      v05, v06, v07, v08,
                      v09, v10, v11, v12,
                      v13, v14, v15, v16)

  table.insert(drawingQueue, {
    model = model,
    texture = spritesheet or part.texture,
    matrix = finalMatrix,
    zPosition = v12,
  })

  transform:translate(-pivotX, -pivotY)
  for _, child in ipairs(part.children) do
    collectDrawItems(child, transform:clone(), drawingQueue, spritesheet)
  end
end

character.draw = function(self)
  local drawingQueue = { }

  lg.push()
  local pivotX, pivotY = (self.root.pivot[1]/100) * self.scale, (self.root.pivot[2]/100) * self.scale
  local transform = love.math.newTransform(0, 0,self.rotation, self.scale, self.scale, pivotX, pivotY)
  transform:translate(self.x, self.y)

  local v01, v02, v03, v04,
        v05, v06, v07, v08,
        v09, v10, v11, v12,
        v13, v14, v15, v16 = transform:getMatrix()

  v12 = v12 + self.z
  -- print("'ere", v04, v08)

  transform:setMatrix(v01, v02, v03, v04,
                      v05, v06, v07, v08,
                      v09, v10, v11, v12,
                      v13, v14, v15, v16)


  collectDrawItems(self.root, transform, drawingQueue, self.spritesheet)

  table.sort(drawingQueue, function(a, b) return a.zPosition > b.zPosition end)

  for _, item in ipairs(drawingQueue) do
    item.model.matrix = item.matrix
    item.model.mesh:setTexture(item.texture)
    item.model:draw()
  end

  lg.pop()
end

return character