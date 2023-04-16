--[[

Demonstration of option hookrequire.

--]]

local log = require "sllog":init{
  -- setup few levels; elapsed time, memory in KB, level name, module, function
  {"err",  "%.3e %5.k KB %-4L ",        "%n", io.stderr},
  {"warn", "%.3e %5.k KB %-4L ",        "%n", io.stderr},
  {"info", "%.3e %5.k KB %-4L ",        "%n", io.stderr},
  {"dbg",  "%.3e %5.k KB %-4L (%S)%f ", "%n", io.stderr},

  -- setup options
  report = "dbg",          -- this must be set, for hookrequire to produce output
  hookrequire = true,      -- enable logging of calls to require
  level = "dbg"            -- set high enough level threshold to see our events
}

io.write("\nLevel is set to ", log:getlevel(), "\n\n")

log:err("level 1, error")
log:warn("level 2, warning")
log:info("level 3, information")
log:dbg("level 4, debug")

local mymod = require "mymod"

mymod.say"hello, world"
