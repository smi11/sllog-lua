--local inspect = require "inspect"
local log = require"sllog"

local M = {}

function M.say(something)
  log(2, "module method")
  print(something)
end

log(2, "load module")

return M
