local lfs = love.filesystem

local g3d = require("libs.g3d")

local pixelToUnitScale = 500 -- 500x500 = 1:1

local objVFormat = "v %.6f %.6f %.6f\n"
local objVTFormat = "vt %.6f %.6f\n"
local objVNFormat = "vn %.6f %.6f %.6f\n"

-- createPlaneForQuad
return function(quadX, quadY, quadW, quadH, texture)
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
  local success, errorMessage = lfs.write(tempFileName, objString)

  if not success then
    logger.fatal("OBJ TEMP FILE", "Unable to write to file[", lfs.getSaveDirectory().."/"..tempFileName, "], reason:", errorMessage)
    return nil
  end

  local model = g3d.newModel(tempFileName, texture)
  local success, errorMessage = lfs.remove(tempFileName)
  if not success then
    logger.warn("Could not remove .temp file created for model generation")
  end
  return model
end