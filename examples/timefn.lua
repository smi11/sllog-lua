--[[

Demonstration of more precise timer function.

You need to have LuaSocket installed for this to work.

--]]

local ok, socket = pcall(require, "socket")

if not ok then
  print("LuaSocket required for this demo. Please install with:")
  print("")
  print("luarocks install luasocket")
  os.exit()
end

local log = require "sllog":init{
  -- setup few levels; time, elapsed time, elapsed previous, memory in KB, level name, module, function
  {"err",  "%3T %.3e %.3p %5.k KB %-4L ",        "%n", io.stderr},
  {"warn", "%3T %.3e %.3p %5.k KB %-4L ",        "%n", io.stderr},
  {"info", "%3T %.3e %.3p %5.k KB %-4L ",        "%n", io.stderr},
  {"dbg",  "%3T %.3e %.3p %5.k KB %-4L (%S)%f ", "%n", io.stderr},

  -- setup options
  timefn = (socket or {}).gettime, -- use socket.gettime()
  report = "dbg",                  -- report internal events as level "dbg"
  level = 4                        -- show all four levels
}

io.write("\nLevel is set to ", log:getlevel(), "\n\n")

log:err("level 1, error")
log:warn("level 2, warning")
log:info("level 3, information")
log:dbg("level 4, debug")

for i = 1, 10 do
  log:dbg("counting... ", i)
  local time = os.clock()
  while os.clock() < time + 0.1 do end
end
