local characterManager = require("src.characterManager")

local getCharacter = function(id)
  return characterManager.characters[id]
end

-- Where characters appear in the world
local child = getCharacter("child")
child.x, child.z = -5, 5

local electrician = getCharacter("electrician")
electrician.x, electrician.z = -3, 5

local sami = getCharacter("sami")
sami.x, sami.z = -1, 5

local zyla = getCharacter("zyla")
zyla.x, zyla.z = 1, 5