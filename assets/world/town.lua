local lg = love.graphics

local characterManager = require("src.characterManager")

local world = {
  min = -13,
  max =  13,
  clearColor = lg.newImage("assets/textures/Sky.png"),
  musicKey = "audio.music.town",
}

local child = characterManager.get("child")
child:setHome("town", -5, 4, true)
  :teleportHome()

local lyn = characterManager.get("lyn")
lyn:setHome("town", -3, 4)
  :teleportHome()

local electrician = characterManager.get("electrician")
electrician:setHome("town", 8.5, 4.5, true)
  :teleportHome()

local sami = characterManager.get("sami")
sami:setHome("town", 5, 3, true)
  :teleportHome()

local zyla = characterManager.get("zyla")
zyla:setHome("town", 7, 3)
  :teleportHome()

------------------------------------

local g3d = require("libs.g3d")

-- world.setupColliders = function() -- todo

-- end

local createPlaneForQuad = require("src.createPlaneForQuad")
local _assets = require("util.assets") -- moved assets to asset loader to speed loading
local outside_assets_1 = _assets["img.town.1"]
local outside_assets_2 = _assets["img.town.2"]

local small_tuft, _h = createPlaneForQuad(3776, 587, 226, 174, outside_assets_1, 400)
small_tuft:setTranslation(0, _h, 0)

local flower, _h = createPlaneForQuad(4072, 135, 277, 352, outside_assets_1, 400)
flower:setTranslation(0, _h, 0)

local large_tuft, _h = createPlaneForQuad(3683, 181, 292, 332, outside_assets_1, 350)
large_tuft:setTranslation(0, _h, 0)

world.objects = { } -- for objects that don't have alpha considerations

local newSmallTuft = function(x, z)
  local tuft = small_tuft:clone()
  tuft:setTranslation(x, small_tuft.translation[2], z - 0.1)
  table.insert(world.objects, tuft)
end

local newFlower = function(x, z)
  local f = flower:clone()
  f:setTranslation(x, flower.translation[2], z - 0.1)
  table.insert(world.objects, f)
end

local newLargeTuft = function(x, z)
  local tuft = large_tuft:clone()
  tuft:setTranslation(x, large_tuft.translation[2], z - 0.1)
  table.insert(world.objects, tuft)
end

local gen = love.math.newRandomGenerator(0xCBBF7A44, 0x0139408D)

local patches = { 13.75, 6, -1.25, -9 }
for _, patch in ipairs(patches) do
  for z = 4.5, 6, 0.5 do
    for x = -5, 0, 1 do
      local v = gen:random(0, 3)
      local xVer = (gen:random()-0.5)/2
      if v == 1 then
        newSmallTuft(x+patch+xVer, z)
      elseif v == 2 or v == 3 then
        newFlower(x+patch+xVer, z)
      end
    end
  end
end

for x = 14, -14, -2 do
  local v = gen:random(0, 4)
  if v == 0 then
    newSmallTuft(x+gen:random()-.5, 2.4)
  else
    newLargeTuft(x+gen:random()-.5, 2.4)
  end
end

local requestBoardSRC = require("src.requestBoard")

world.update = function(dt, scale, isGamepadActive)
  requestBoardSRC.update(dt, scale, isGamepadActive)
end

local postbox, _h = createPlaneForQuad(5932, 1765, 139, 226, outside_assets_2, 200)
postbox:setTranslation(1.25, _h, 4.25)
requestBoardSRC.set(1.25, 4.25, 2, 4)

local tree_left_1, _h = createPlaneForQuad(3098, 23, 557, 979, outside_assets_1, 190)
tree_left_1:setTranslation(-4, _h, 1.8)
local tree_left_2 = tree_left_1:clone()
tree_left_2:setTranslation(11, nil, 2.2)

world.get3DObjects = function() -- for alpha objects
  return {
    postbox,
    tree_left_1,
    tree_left_2,
  }
end

local workshopExterior, _h = createPlaneForQuad(98, 135, 956, 893, lg.newImage("assets/textures/House.png"), 180)
workshopExterior:setTranslation(-.2, _h-.05, 6.25)
local workshopExtension, _h = createPlaneForQuad(3410, 1401, 857, 573, outside_assets_2, 180)
workshopExtension:setTranslation(-3.8, _h, 6.5)

local yellowHouse, _h = createPlaneForQuad(4355, 1185, 1206, 806, outside_assets_2, 180)
yellowHouse:setTranslation(-9.5, _h, 6.25)
local yellowExtension, _h = createPlaneForQuad(161, 1124, 480, 852, outside_assets_2, 150)
yellowExtension:setTranslation(-13.25, _h, 6.75)

local blueHouse, _h = createPlaneForQuad(660, 1123, 1216, 863, outside_assets_2, 180)
blueHouse:setTranslation(9.05, _h, 6.25)
local blueExtension, _h = createPlaneForQuad(1932, 1687, 857, 304, outside_assets_2, 150)
blueExtension:setTranslation(5.5, _h, 6.5)
local blueExtension2 = yellowExtension:clone()
blueExtension2:setTranslation(12.5, nil, 6.75)

local hill_1, _h = createPlaneForQuad(89, 69, 1993, 970, outside_assets_2, 150)
hill_1:setTranslation(10, _h, 8.5)
local hill_2, _h = createPlaneForQuad(2148, 344, 1846, 704, outside_assets_2, 150)
hill_2:setTranslation(-1, _h, 6.9)
local hill_3, _h = createPlaneForQuad(4073, 69, 1993, 973, outside_assets_2, 150)
hill_3:setTranslation(-8, _h, 8.5)

local tree_right_1, _h = createPlaneForQuad(2855, 1082, 537, 944, outside_assets_2, 180)
tree_right_1:setTranslation(14, _h, 6.8)
local tree_right_2 = tree_right_1:clone()
tree_right_2:setTranslation(4, nil, nil)

local player = characterManager.get("player")
world.draw = function()
  hill_1:draw()
  hill_3:draw()
  hill_2:draw()
  tree_right_1:draw()
  tree_right_2:draw()

  workshopExtension:draw()
  workshopExterior:draw()
  yellowExtension:draw()
  yellowHouse:draw()
  blueExtension:draw()
  blueExtension2:draw()
  blueHouse:draw()
  requestBoardSRC.draw(player.x, player.z)
end

world.drawUI = function(scale)
  requestBoardSRC.drawUI(scale)
end

local floor = g3d.newModel("assets/models/town_floor.obj", "assets/textures/Floor_Outside.png", { 0, 0, 4 }, nil, nil, true, false)

world.drawFloor = function() 
  floor:draw()
end

return world