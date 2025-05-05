local lg = love.graphics

local workstation = {
  world = "workshop",
  show = false,
}

table.insert(require("src.worldManager").interactable, workstation)

local canMovePlayer = function(boolean)
  local playerChar = require("src.characterManager").get("player")
  playerChar.canMove = boolean
  playerChar:moveX(0)
end

local xRange, zRange = 1, 0.5
workstation.interact = function(_, x, z)
  if not workstation.show and
    workstation.interactX - xRange < x and
    workstation.interactX + xRange > x and
    workstation.interactZ - zRange <= z and
    workstation.interactZ + zRange >= z then
    canMovePlayer(false)
    workstation.show = true
    return true -- consumed
  end
  return false
end

local interactSign = require("src.interactSign")()
workstation.set = function(x, z, interactX, interactZ)
  interactSign:setTranslation(x or 0, 2.1 + (0.25*500/1000), z or 0)

  workstation.interactX = interactX or 0
  workstation.interactZ = interactZ or 0
end

workstation.update = function(dt, scale, isGamepadActive)
  
end

workstation.draw = function(playerX, playerZ)
  if not workstation.show and workstation.interactZ - (zRange+.5) <= playerZ and workstation.interactZ + (zRange+.5) >= playerZ and
    workstation.interactX - (xRange+.5) <= playerX and workstation.interactX + (xRange+.5) >= playerX then
    if workstation.interactX - xRange <= playerX and
      workstation.interactX + xRange >= playerX and
      workstation.interactZ - zRange <= playerZ and
      workstation.interactZ + zRange >= playerZ then
      lg.setColor(1,1,1,1)
    else
      lg.setColor(.5,.5,.5,.7)
    end
    interactSign:draw()
    lg.setColor(1,1,1,1)
  end
end

workstation.drawUI = function(scale)

end

return workstation