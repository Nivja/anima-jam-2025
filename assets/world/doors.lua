local worldManager = require("src.worldManager")

-- draw: {x, z, [r=0]}, entry: {x, z, [flipped]}

worldManager.newDoor("town", { 0, 6 }, { 0, 0 },
                     "workshop", { -10, 5 }, { 0, 0 })

