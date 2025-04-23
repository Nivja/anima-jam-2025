local lfs = love.filesystem

local file = require("util.file")

local inventory = require("src.inventory")

local dialogueManager = {
  dialogue = { }
}

dialogueManager.parse = function(definition)
  local parsedDialogue = {
    definition = definition,
    tagLookup = { },
  }

  local actualIndex = 0
  for index, command in ipairs(definition) do
    if type(command) == "table" then
      if command[1] == "tag" then
        parsedDialogue.tagLookup[command[2]] = index
      elseif command[1] == "if" then
        local func
        if command[2] == "item" then
          func = function()
            local item = inventory.get(command[3])
            return item ~= nil and item[command[4]]:(unpack(command, 5, #command-1))
          end
        end
        if type(func) == "function" then
          definition[index] = {
            "if_true",
            func,
            command[#command], -- goto tag
          }
        end
      end
    end
  end

  for index, command in ipairs(definition) do

  end

  return parsedDialogue
end

dialogueManager.load = function(dir)
  for _, item in ipairs(lfs.getDirectoryItems(dir)) do
    local path = dir .. "/" .. item
    local name = file.getFileName(item)
    local chunk, errorMessage = lfs.load(path)
    if not chunk then
      error("Error loading dialogue: ", path, "\nError Message: ", errorMessage)
      return
    end
    local definition = chunk()
    dialogueManager.dialogue[name] = dialogueManager.parse(definition)
  end
end

return dialogueManager