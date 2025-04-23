local lfs, lg = love.filesystem, love.graphics

local logger = require("util.logger")
local flux = require("libs.flux")
local g3d = require("libs.g3d")

local missingTexture = lg.newImage("assets/missingTexture.png")

local plane = g3d.newModel("assets/models/plane.obj")

local character = { }
character.__index = character

character.new = function(directory, dirName, definition)
  local c = {
    x = 0, y = 0, z = 5,
    rotation = 0,
    scale = 1,
    state = "idle"
  }

  if definition.transform then
    for index, value in pairs(definition.transform) do
      if c[index] and type(value) == "number" then
        c[index] = value
      end
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

    part.pivot = partDefinition.pivot
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

  c.partLookup = partLookup
  c.dirName = dirName
  c.root = root

  return setmetatable(c, character)
end

character.update = function(self, dt)
  -- self.y = self.y + dt
end

local drawPart
drawPart = function(part, transform)
  transform:scale(part.scale * part.ascale) -- this doesn't set the Z axis to scale; but we don't care about it
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

  plane.matrix[01], plane.matrix[02], plane.matrix[03], plane.matrix[04] = v01, v02, v03, v04
  plane.matrix[05], plane.matrix[06], plane.matrix[07], plane.matrix[08] = v05, v06, v07, v08
  plane.matrix[09], plane.matrix[10], plane.matrix[11], plane.matrix[12] = v09, v10, v11, v12
  plane.matrix[13], plane.matrix[14], plane.matrix[15], plane.matrix[16] = v13, v14, v15, v16

  transform:setMatrix(v01, v02, v03, v04,
                      v05, v06, v07, v08,
                      v09, v10, v11, v12,
                      v13, v14, v15, v16)

  -- logger.info(part.name, v04, v08, v12)
  plane.texture = part.texture
  plane.mesh:setTexture(part.texture)
  plane:draw()

  transform:translate(-pivotX, -pivotY)
  for _, child in ipairs(part.children) do
    drawPart(child, transform:clone(), z)
  end
end

character.draw = function(self)
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

  drawPart(self.root, transform)
  lg.pop()
end

return character