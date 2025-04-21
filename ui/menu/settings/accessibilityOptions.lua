local settings = require("util.settings")
local cursor = require("util.cursor")

return function(optionSelectorFactory)
  local accessibilityOptions = { }
  accessibilityOptions.execute = function()
    cursor.setType(settings.client.systemCursor and "system" or "custom")

    settings.encode()
  end

  accessibilityOptions.systemMouse = optionSelectorFactory(
    "settings.accessibility.systemMouse.",
    { "game", "system" },
    function(option) -- set
      settings.client.systemCursor = option == "system"
      cursor.setType(settings.client.systemCursor and "system" or "custom")
    end,
    function() -- get
      if cursor.type == "custom" then
        return 1
      elseif cursor.type == "system" then
        return 2
      end
    end
  )

  return accessibilityOptions
end