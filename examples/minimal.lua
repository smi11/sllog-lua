--[[

There will be no logs output if environment variable SLLOG_LEVEL is not set!

Try setting it to either string 'err', 'warn', 'info' or 'dbg' or
set it to any number between 1 and 4 and then run this script.

Example:

> export SLLOG_LEVEL=3
> lua minimal.lua

or

> SLLOG_LEVEL="dbg" lua minimal.lua

--]]

local log = require "sllog"
local x = 123

io.write("\nLevel is set to ", log:getlevel(), "\n\n")

log:err("level 1, error")
log:warn("level 2, warning")
log:info("level 3, information")
log:dbg("level 4, debugging x = ", x)
