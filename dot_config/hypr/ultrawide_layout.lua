-- A fixed, FancyZones-style layout inspired by the three-column desktop photo.
--
-- Five tiled windows are placed like this, in layout order:
--
--   +-----------+------------------+----------+
--   |     1     |                  |    3     |
--   +-----------+        2         +----------+
--   |     4     |                  |    5     |
--   +-----------+------------------+----------+
--
-- With fewer windows the same shape grows naturally; more than five windows
-- fall back to a balanced grid so every tiled window remains usable.

local M = {}

local layout_name = "ultrawide-five"
local layout_id = "lua:" .. layout_name

local left_width = 0.28
local center_width = 0.47
local right_width = 1 - left_width - center_width

local function relative_box(area, x, y, width, height)
  return {
    x = area.x + area.w * x,
    y = area.y + area.h * y,
    w = area.w * width,
    h = area.h * height,
  }
end

local function place(target, area, x, y, width, height)
  target:place(relative_box(area, x, y, width, height))
end

hl.layout.register(layout_name, {
  recalculate = function(ctx)
    local targets = ctx.targets
    local count = #targets

    if count == 0 then
      return
    end

    if count == 1 then
      targets[1]:place(ctx.area)
      return
    end

    if count > 5 then
      local columns = math.ceil(math.sqrt(count))
      for index, target in ipairs(targets) do
        target:place(ctx:grid_cell(index, columns))
      end
      return
    end

    -- One narrow side pane plus a wide main pane.
    if count == 2 then
      place(targets[1], ctx.area, 0, 0, left_width, 1)
      place(targets[2], ctx.area, left_width, 0, 1 - left_width, 1)
      return
    end

    -- Three columns. The outer columns become stacks as windows four and five
    -- arrive, matching the reference desktop.
    local left_height = count >= 4 and 0.5 or 1
    local right_height = count >= 5 and 0.5 or 1

    place(targets[1], ctx.area, 0, 0, left_width, left_height)
    place(targets[2], ctx.area, left_width, 0, center_width, 1)
    place(targets[3], ctx.area, left_width + center_width, 0, right_width, right_height)

    if count >= 4 then
      place(targets[4], ctx.area, 0, 0.5, left_width, 0.5)
    end

    if count == 5 then
      place(targets[5], ctx.area, left_width + center_width, 0.5, right_width, 0.5)
    end
  end,
})

function M.toggle()
  local workspace = hl.get_active_special_workspace() or hl.get_active_workspace()
  if not workspace then
    return
  end

  local use_ultrawide = workspace.tiled_layout ~= layout_id
  local next_layout = use_ultrawide and layout_id or "dwindle"
  local workspace_selector = workspace.special and tostring(workspace.name) or tostring(workspace.id)

  hl.workspace_rule({ workspace = workspace_selector, layout = next_layout })
  hl.exec_cmd(o.notify("Workspace layout set to " .. (use_ultrawide and "ultrawide five" or "dwindle")))
end

return M
