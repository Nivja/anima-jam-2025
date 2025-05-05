local worldManager = require("src.worldManager")

-- draw: {x, z, [r=0]}, entry: {x, z, [flipped]}

worldManager.newDoor("town-workshop", -- id unique; not checked
                     "town", { 0, 6 }, { 0, 5 },
                     "workshop", { 10, 4.5, math.rad(90) }, { 10, 4.5, false })

