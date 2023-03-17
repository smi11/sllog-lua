--[[

 sllog 0.1 Simple line logger
 no warranty implied; use at your own risk

 Simple line logger. You can define prefix and suffix for each log message. Both
 allow various tags for date, time, elapsed time, level, debug info and memory
 usage so you can format your log as you wish.

 Each log level can have its own formatting and can be output to different file
 handles. You can also hook require function to automatically log its use. If
 you need more precise timings, you can set sllog to use gettime() function from
 luasocket or some other unix timestamp compatible library.

 You can colorize output by inserting ansi codes into prefix and suffix. If you
 require optional "eansi" module, it will be used to convert color codes to ansi
 for you or you can use some other ansi color library. And best of all, it's
 minimalistic, really easy to use and super fast.

 Compatible with Lua 5.1+ and LuaJIT 2.0+

 author: Milan Slunečko
 url:

 DEPENDENCY

 Lua 5.1+ or LuaJIT 2.0+

 Optionally:
  - luasocket (for more precise gettime() function)
  - eansi (to convert color tags to ansi escape sequences)

 BASIC USAGE

 -- level name, prefix, suffix, file handle
 local log = require "sllog":init{
  {"info",   "%c %L ", "\n", io.stdout},
  {"more",   "%c %L ", "\n", io.stdout},
  {"debug",  "%c %L %S ", "\n", io.stderr},
 }

 -- you can specify level either by index or name
 log(1, "some message")
 log:info("same as previous line, but using name")
 log("info", "also same as previous two lines")

 local x = 123
 log:debug("my var is ", x)

 See README.md for documentation

 HISTORY

 0.1 < active
      - first draft

 LICENSE

 MIT License. See end of file for full text.

--]]

-- constants
local ENVVAR = "LUA_SLLOG_LEVEL"  -- which environment variable to use
local LVLDEFAULT = 0              -- default threshold for logging; 0 = no logging

-- safe navigation E and logger object
local E = {}
local logger = {_VERSION = 'sllog 0.1', _levelenv=os.getenv(ENVVAR)}
logger.__index = logger

-- table containing default list of levels to be used with logger:init(levels)
-- name, prefix, suffix, file handle
local default = {
  {"info",   "%c %L ", "\n", io.stdout},
  {"more",   "%c %L ", "\n", io.stdout},
  {"debug",  "%c %L %S ", "\n", io.stderr},
}

-- translate formating options for prefix and suffix to corresponding functions
local lookup = {
  -- time and date from os.date extended with subsecond precision from socket.gettime
  c = [[x:fmttime("%c","<fmt>",math.modf(x:gettime()))]],  --  locale's date and time (e.g., Thu Mar  3 23:05:25 2005)
  F = [[os.date("%F")]],                                   --  full date; same as %Y-%m-%d
  r = [[x:fmttime("%r","<fmt>",math.modf(x:gettime()))]],  --  locale's 12-hour clock time (e.g., 11:11:04 PM)
  T = [[x:fmttime("%T","<fmt>",math.modf(x:gettime()))]],  --  time; same as %H:%M:%S
  x = [[os.date("%x")]],                                   --  locale's date representation (e.g., 12/31/99)
  X = [[x:fmttime("%X","<fmt>",math.modf(x:gettime()))]],  --  locale's time representation (e.g., 23:13:48)

  -- elapsed time since start; since previous log
  e = [[sfmt('%<fmt>f', x:getelapsed())]],                    -- in seconds (e.g., 0.424024)
  E = [[x:fmttime("!%T","<fmt>",math.modf(x:getelapsed()))]], -- in seconds %H:%M:%S.000
  p = [[sfmt('%<fmt>f', x:gettprev())]],                      -- in seconds (e.g., 0.424024)
  P = [[x:fmttime("!%T","<fmt>",math.modf(x:gettprev()))]],   -- in seconds %H:%M:%S.000

  -- level
  l = [[lvl or 0]],                                       -- level number
  L = [[sfmt('%<fmt>s', x._levels[lvl].name or '')]],     -- level name

  -- debug, lf
  S = [[x:getdebug()]],                                        -- module:line
  n = [[package.config:sub(1,1) == "\\" and "\r\n" or "\n"]],  -- os based crlf or lf

  -- memory
  k = [[sfmt('%<fmt>f', collectgarbage("count"))]],                   -- memory in Kb
  b = [[sfmt('%<fmt>i', math.floor(collectgarbage("count")*1024))]],  -- memory in bytes
}

-- factory that builds function for formating prefix and suffix
local function format_factory(str)
  local code = {
      "return function(x,lvl) ",
      "local sfmt = string.format ",
      "local t = {} ",
  }
  local i = 1
  local s, e, val, ss
  while true do
    s, e, val = str:find("(%%[%d.+#%-]*[cFrTxXeEpPlLSnkb])", i)
    if s then
      ss = str:sub(i,s-1)
      if #ss > 0 then
        code[#code+1] = string.format("t[#t+1] = %q ", ss)
      end
        local chr = val:sub(-1)
        local fmt = val:sub(2,-2) or ""
        if lookup[chr] then
          code[#code+1] = "t[#t+1] = " .. lookup[chr]:gsub("<fmt>", fmt) .. " "
        end
      i = e + 1
    else
      ss = str:sub(i)
      if #ss > 0 then
        code[#code+1] = string.format("t[#t+1] = %q ", ss)
      end
      break
    end
  end

  code[#code+1] = "return table.concat(t) "
  code[#code+1] = "end"

  local index = 0
  local function reader()
      index = index + 1
      return code[index]
  end

  return assert(load(reader))()
end

-- initialization of log levels
function logger:init(tlevels) -- table just like 'default' above
  assert(type(tlevels)=="table","table containing list of levels expected")
  if not self._timefn then self:settimefn() end
  self._tstart = self:gettime()
  self._tprev = self._tstart % 1 == 0 and os.clock() or self._tstart
  local eansi = (package.loaded["eansi"] or E).rawpaint or function(s) return s end
  -- erase existing keys except private ones starting with underscore (_)
  for key in pairs(self) do
    if key:sub(1,1) ~= "_" then
      self[key] = nil
    end
  end
  -- build new lookup table containing all levels
  local t = {}
  for i, v in ipairs(tlevels) do
    local name = v[1]
    t[i] = {name=name, index=i, handle=v[4],
            prefix=format_factory(eansi(v[2])),
            suffix=format_factory(eansi(v[3]))}
    assert(t[name] == nil, "duplicate level name")
    t[name] = t[i]
    self[name] = function(x, ...) x:log(i,...) end
  end
  -- do tail call to x:log() to maintain same stack depth
  self.report = function(x, ...) return x:log(x._report,...) end
  self._levels = t
  self:report("log init()")
  return self
end

-- set level name for internal log reports
function logger:setreport(name)
  assert(type(name)=="string" or name==nil, "string with level name for reports expected")
  self._report = name
  return self
end

-- set time function; also set start time
function logger:settimefn(fn)
  assert(type(fn)=="function" or fn == nil,"function or nil expected")
  self._timefn = fn or os.time
  self._tstart = self:gettime()
  return self
end

-- get current time
function logger:gettime()
  return self._timefn()
end

-- get elapsed time from start in seconds using time with higher precision
function logger:getelapsed()
  local x = self:gettime()
  return x % 1 == 0 and os.clock() or x - self._tstart
end

-- get elapsed time from previous log in seconds using time with higher precision
function logger:gettprev()
  local x = self:gettime()
  return x % 1 == 0 and os.clock() - self._tprev or x - self._tprev
end

-- convert time to string and add fractions of seconds
-- luacheck: ignore 212
function logger:fmttime(fmt, prec, sec, frac)
  prec = ((tostring(prec) or "0"):gsub("%.", ""))
  local fpart = string.format("%0."..prec.."f",frac)
  local carry = tonumber(fpart:sub(1,1))
  return (os.date(fmt,sec+carry):gsub(":%d%d%f[%s%z]", "%1"..fpart:gsub("^%d","")))
end

-- get module name and line number as a string
function logger:getdebug()
  local req = self._require or require
  local getinfo = req "debug".getinfo
  local t = getinfo(self._stack or 5,"Sl")
  return (t.short_src:match("([^/]*).lua$") or "")..":"..(t.currentline or "")
end

-- set level; acts as a threshold for output
-- nil will restore level to either environment variable or LVLDEFAULT
function logger:setlevel(lvl, msg) -- number or string with valid level name
  lvl = tonumber(lvl) or (self._levels[lvl] or E).index or lvl
  assert(type(lvl)=="number" or lvl==nil, "valid level number, name or nil expected")
  self._level = lvl
  self:report(string.format(msg or [[log setlevel(%s)]], self._level, ENVVAR))
  return self
end

-- return current level number or fetch environment setting or default setting
function logger:getlevel()
  if type(self._level) ~= "number" then
    self._stack = 8
    if self._levelenv then
      self:setlevel(self._levelenv, [[log setlevel(%s) -- os.getenv("%s")]])
    else
      self:setlevel(LVLDEFAULT, [[log setlevel(%s) -- LVLDEFAULT]])
    end
  end
  return self._level
end

-- do output
function logger:log(lvl, ...) -- level number; ... desired output
  lvl = tonumber(lvl) or (self._levels[lvl] or E).index or lvl
  if type(lvl)=="number" and lvl > 0 and lvl <= self:getlevel() then
    local p = self._levels[lvl]
    local handle = p.handle
    handle:write(p.prefix(self,lvl))
    handle:write(...)
    handle:write(p.suffix(self,lvl))
  end
  local x = self:gettime()
  self._tprev = x % 1 == 0 and os.clock() or x
  self._stack = nil
end

-- monkey-patch function 'require' to enable logging it's use
function logger:hookrequire(msg)
  self._require = require
  _G["require"] = function (module)
    if not package.loaded[module] then
      self:report(string.format(msg or 'require "%s"', module))
    end
    return self._require(module)
  end
  self:report("log hookrequire()")
  return self
end

-- restore require
function logger:unhookrequire()
  _G["require"] = self._require or _G["require"]
  if self._require then
    self.require = nil
    self:report("log unhookrequire()")
  end
  return self
end

-- make log method callable by object name
logger.__call = function(self,...)
  self:log(...)
end

-- make sure file handles are closed and 'require' is restored
logger.__gc = function (self)
  for _, v in ipairs(self._levels or E) do
    if io.type(v.handle) == "file" then
      v.handle:close() -- safe with io.stdout and io.stderr
    end
  end
  _G["require"] = self._require or _G["require"]
  print("fin done")
end

-- Lua 5.1 does not support __gc on tables, so we need to use newproxy
local function setmeta(mt)
  if _G._VERSION == "Lua 5.1" then
    local u = newproxy(false)
    require "debug".setmetatable(u, mt)
    return u
  else
    return setmetatable({}, mt)
  end
end

-- create instance of logger object and return it as a module table
return setmeta(logger):init(default)

--[[

MIT License
Copyright (c) 2023 Milan Slunečko

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without imitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Except as contained in this notice, the name(s) of the above copyright holders
shall not be used in advertising or otherwise to promote the sale, use or other
dealings in this Software without prior written authorization.

--]]
