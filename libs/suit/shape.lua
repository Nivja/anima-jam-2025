return function(core, id, color, ...)
  local opt, x,y,w,h = core.getOptionsAndSize(...)
  
  if not opt.noScaleX then
    x, w = x * core.scale, w * core.scale
  end
  if not opt.noScaleY then
    y, h  = y * core.scale, h * core.scale
  end

  opt.id = opt.id or id

  if opt.gamepadOption then
    core:registerGamepadOption(id or opt.id)
  end

  local hit, hovered, entered, left
  if opt.hitbox == nil or opt.hitbox then
    opt.state = core:registerHitbox(opt.id, x,y,w,h)

    hit = core:mouseReleasedOn(opt.id)
    hovered = core:isHovered(opt.id)
    entered = hovered and not core:wasHovered(opt.id)
    left = not hovered and core:wasHovered(opt.id)

    opt.hit, opt.hovered, opt.entered, opt.left = hit, hovered, entered, left
  end

  core:registerDraw(opt.draw or core.theme.Shape, color, opt, x,y,w,h)

  return {
    id = opt.id,
    hit = hit,
    hovered = hovered,
    entered = entered,
    left = left,
    x = x, y = y,
    w = w, h = h,
  }
end