local lm = love.mouse

local isCursorSupported = lm.isCursorSupported()

local cursors = {
  system = { },
  custom = { },
}
if isCursorSupported then
  do -- System cursors
    local c = cursors.system
    c["sizewe"] = lm.getSystemCursor("sizewe")
    c["sizens"] = lm.getSystemCursor("sizens")
    c["sizenesw"] = lm.getSystemCursor("sizenesw")
    c["sizenwse"] = lm.getSystemCursor("sizenwse")
    c["sizeall"] = lm.getSystemCursor("sizeall")
    c["ibeam"] = lm.getSystemCursor("ibeam")
    c["hand"] = lm.getSystemCursor("hand")
    c["arrow"] = lm.getSystemCursor("arrow")
  end
  do -- Custom cursors
    local c = cursors.custom
    c["arrow"] = {
      lm.newCursor("assets/UI/cursor/x1/cursor_none.png", 8, 4),
      lm.newCursor("assets/UI/cursor/x2/cursor_none.png", 16, 8),
    }
    c["hand"] = {
      lm.newCursor("assets/UI/cursor/x1/hand_point_n.png", 14, 1),
      lm.newCursor("assets/UI/cursor/x2/hand_point_n.png", 28, 1),
    }
  end
end

local cursor = {
  type = "custom",
  scale = 1,
}

cursor.switch = function(cursorType)
  if isCursorSupported then
    if cursorType == nil then cursorType = "arrow" end
    local c = type(cursorType) == "string" and cursors[cursor.type][cursorType] or cursorType
    if type(c) == "string" then
      print("Unsupported cursor requested:", cursor.type, ":", cursorType)
      c = cursors.system.arrow
    end
    if type(c) == "table" then
      c = c[cursor.scale]
    end
    cursor.currentType = cursorType
    lm.setCursor(c)
    return true
  end
  return false
end

cursor.switchIf = function(bool, type)
  if bool then
    return cursor.switch(type)
  end
  return false
end

cursor.setScale = function(scale)
  scale = scale + 0.5
  cursor.scale = math.max(1, math.min(2, math.floor(scale)))
  cursor.switch(cursor.currentType)
end

cursor.setType = function(type)
  cursor.type = type
end

cursor.switch("arrow")
return cursor 