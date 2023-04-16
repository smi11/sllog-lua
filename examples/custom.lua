--[[

Try running this demo with an argument for level threshold.
It can be either a number between 0 and 4 or a name of the desired level.

Example:

> lua custom.lua dbg

Level threshold will be set to either value of 1st argument or to value of
environment variable SLLOG_LEVEL or to 0 if neither is provided in that
order of precedence.

--]]

local log = require "sllog":init{
  -- setup few levels; elapsed time, memory in KB, level name, module, function
  {"err",  "%.3e %5.k KB %-4L ",        "%n", io.stderr},
  {"warn", "%.3e %5.k KB %-4L ",        "%n", io.stderr},
  {"info", "%.3e %5.k KB %-4L ",        "%n", io.stderr},
  {"dbg",  "%.3e %5.k KB %-4L (%S)%f ", "%n", io.stderr},

  -- setup options
  report = "dbg",          -- report internal events as level "dbg"
  level = arg[1]           -- set level threshold to 1st cli argument
}

io.write("\nLevel is set to ", log:getlevel(), "\n\n")

log:err("level 1, error")
log:warn("level 2, warning")
log:info("level 3, information")
log:dbg("level 4, debug")

-- set threshold for displaying log severity up to level named "info"
log:setlevel("info")

for i = 1, 10 do
  log:info("counting... ", i)
  local time = os.clock()
  while os.clock() < time + 0.1 do end
end
