--[[

Demonstration of method vardump(name, variable[, level]).

--]]

local log = require "sllog":init{
  -- setup few levels; elapsed time, memory in KB, level name, module, function
  {"err",  "%.3e %5.k KB %-4L ",        "%n", io.stderr},
  {"warn", "%.3e %5.k KB %-4L ",        "%n", io.stderr},
  {"info", "%.3e %5.k KB %-4L ",        "%n", io.stderr},
  {"dbg",  "%.3e %5.k KB %-4L (%S)%f ", "%n", io.stderr},

  -- setup options
  report = "dbg",          -- report internal events as level "dbg"
  level = "dbg"            -- set level threshold to level 4 - "dbg"
}

io.write("\nLevel is set to ", log:getlevel(), "\n\n")

log:err("level 1, error")
log:warn("level 2, warning")
log:info("level 3, information")
log:dbg("level 4, debug")

local myvar = {"a", "b", "c"}

-- this will output as level 4 event (set by option 'report')
log:vardump("myvar", myvar)

-- or we can ask vardump() to produce output to custom level by providing 3rd argument
log:vardump("log", log, 3)

