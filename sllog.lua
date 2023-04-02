--[[

 sllog 0.2 Simple line logger
 no warranty implied; use at your own risk

 Simple line logger. You can define prefix and suffix for each log message. Both
 allow various tags for date, time, elapsed time, level, debug info and memory
 usage so you can format your log as you wish.

 Each log level can have its own formatting and can be output to different file
 handles. You can also hook require function to automatically log its use.

 If you need more precise timings, you can set sllog to use gettime() function
 from 'luasocket' or some other unix timestamp compatible library.

 Optionally you can colorize output by providing external function that converts
 color codes into ansi escape codes for prefix and suffix or insert them yourself
 before calling sslog:init().

 Compatible with Lua 5.1+ and LuaJIT 2.0+

 author: Milan Slunečko
 url: https://github.com/smi11/sllog-lua

 DEPENDENCY

 Lua 5.1+ or LuaJIT 2.0+

 Optionally:
  - luasocket (for more precise gettime() function)
  - eansi or some other color library (for colorizing output)

 BASIC USAGE

 -- level name, prefix, suffix, file handle
 local log = require "sllog":init{
  {"err",  "%F %T %-4L ",        "%n", io.stderr},
  {"warn", "%F %T %-4L ",        "%n", io.stderr},
  {"info", "%F %T %-4L ",        "%n", io.stderr},
  {"dbg",  "%F %T (%S) %-4L%f ", "%n", io.stderr},
  timefn=(socket or {}).gettime  -- use socket.gettime if available
  report="dbg",       -- to which level should internal log events be passed?
  hookrequire=true,   -- also report calls to require()
  level="dbg"         -- output levels up to and including "dbg"
}

 -- you can specify level either by index or name
 log(3, "some message")
 log[3]("some message")
 log:info("same as previous line, but using name")
 log("info", "also same as previous lines")

 local x = 123
 log:dbg("my var is ", x)

 See README.md for documentation

 HISTORY

 0.2 < active
      - finalized settings, methods and module structure
      - refactor all code

 0.1
      - first draft

 LICENSE

 MIT License. See end of file for full text.

--]]

-- constants
local INITMSG = "init() -- %s levels initialized" -- message when init() is called
local HOOKMSG = 'require "%s"'                    -- message when hooked require is called

-- safe navigation E and logger object
local E = {}
local logger = {_VERSION = "sllog 0.2"}
logger.__index = logger

-- table containing default settings and list of levels to be used with logger:init()
-- name, prefix, suffix, file handle
local default = {
  {"err",  "%F %T %-4L ",      "%n", io.stderr},
  {"warn", "%F %T %-4L ",      "%n", io.stderr},
  {"info", "%F %T %-4L ",      "%n", io.stderr},
  {"dbg",  "%F %T (%S) %-4L ", "%n", io.stderr},
  envvar = "SLLOG_LEVEL",  -- default environment variable
}

-- translate formating options for prefix and suffix to corresponding functions
local lookup = {
  -- time and date from os.date extended with subsecond precision from socket.gettime
  c = [[_fmttime("%c","<fmt>",x:gettime())]],  --  locale's date and time (e.g., Thu Mar  3 23:05:25 2005)
  F = [[date("%F", floor(x:gettime()))]],      --  full date; same as %Y-%m-%d
  r = [[_fmttime("%r","<fmt>",x:gettime())]],  --  locale's 12-hour clock time (e.g., 11:11:04 PM)
  T = [[_fmttime("%T","<fmt>",x:gettime())]],  --  time; same as %H:%M:%S
  x = [[date("%x", floor(x:gettime()))]],      --  locale's date representation (e.g., 12/31/99)
  X = [[_fmttime("%X","<fmt>",x:gettime())]],  --  locale's time representation (e.g., 23:13:48)

  -- elapsed time since start; since previous log
  e = [[sfmt("%<fmt>f", x:getelapsed())]],        -- in seconds (e.g., 0.424024)
  E = [[_fmttime("!%T","<fmt>",x:getelapsed())]], -- in seconds %H:%M:%S.000
  p = [[sfmt("%<fmt>f", x:gettprev())]],          -- in seconds (e.g., 0.424024)
  P = [[_fmttime("!%T","<fmt>",x:gettprev())]],   -- in seconds %H:%M:%S.000

  -- level
  l = [[lvl or 0]],                                     -- level number
  L = [[sfmt("%<fmt>s", x._levels[lvl].name or "")]],   -- level name

  -- debug, lf
  S = [[_getdebug(x)]],                                 -- module:line
  f = [[_getcaller(x)]],                                -- calling function name with leading space
  n = [[pconfig:sub(1,1) == "\\" and "\r\n" or "\n"]],  -- os based crlf or lf

  -- memory
  k = [[sfmt('%<fmt>f', collectgarbage("count"))]],              -- memory in Kb
  b = [[sfmt('%<fmt>i', floor(collectgarbage("count")*1024))]],  -- memory in bytes
}

-- environment for (factory)
local fenv = {
  floor=math.floor,
  date=os.date, time=os.time, pconfig=package.config,
  sfmt=string.format, tconcat=table.concat,
  collectgarbage=collectgarbage
}

-- convert time to string using os.date and add fractions of seconds
function fenv._fmttime(fmt, prec, time)
  local sec, frac = math.modf(time)
  prec = ((tostring(prec) or "0"):gsub("%.", ""))
  local fpart = string.format("%0."..prec.."f",frac)
  local carry = tonumber(fpart:sub(1,1))
  return (os.date(fmt,sec+carry):gsub(":%d%d%f[%s%z]", "%1"..fpart:gsub("^%d","")))
end

-- get module name and line number as a string
function fenv._getdebug(self)
  local req = self._require or require
  local t = req "debug".getinfo(5,"Sl")
  return (t.short_src:match("([^/]*).lua$") or "")..":"..(t.currentline or "")
end

-- get name of the calling function with leading space or empty string
function fenv._getcaller(self)
  local req = self._require or require
  local fname = req "debug".getinfo(5).name
  return fname and " "..fname.."()" or ""
end

-- factory that builds function for formating prefix and suffix
local function format_factory(str, lvl)
  local code = {
    "return function(x)",
    "local lvl="..lvl,
    "local t = {}",
  }
  local i = 1
  local s, e, val, ss
  while true do
    s, e, val = str:find("(%%[%d.+#%-]*[cFrTxXeEpPlLSfnkb])", i) -- tags from lookup
    if s then
      ss = str:sub(i,s-1) -- substring before tag
      if #ss > 0 then
        code[#code+1] = string.format("t[#t+1] = %q", ss)
      end
      local chr = val:sub(-1)
      local fmt = val:sub(2,-2) or ""
      if lookup[chr] then -- replace tag with appropriate lua code
        code[#code+1] = "t[#t+1] = " .. lookup[chr]:gsub("<fmt>", fmt)
      end
      i = e + 1
    else -- part of str after last tag
      ss = str:sub(i)
      if #ss > 0 then
        code[#code+1] = string.format("t[#t+1] = %q", ss)
      end
      break
    end
  end -- while

  code[#code+1] = "return tconcat(t)"
  code[#code+1] = "end"

  local index = 0
  local function reader()
      index = index + 1
      return code[index]
  end

  if setfenv then -- Lua 5.1
    local f = assert(load(reader,"=(factory)"))
    setfenv(f,fenv)
    return f()
  else
    return assert(load(reader,"=(factory)", "t", fenv))()
  end
end

-- get level index or nil
local function getlevelidx(self, lvl)
  lvl = tonumber(lvl) or (self._levels[lvl] or E).index or lvl
  lvl = lvl ~= false and lvl or nil
  assert(type(lvl)=="number" or lvl==nil, "valid level number, name or nil expected")
  return lvl
end

-- fetch level index from provided string or number or environment variable
local function fetchlevel(self, lvl, msg)
  lvl = getlevelidx(self, lvl)
  msg = msg or "level=%s"
  if not lvl then
    local env = os.getenv(self._envvar)
    if env then
      lvl = getlevelidx(self, env)
      msg = (msg or "") .. " -- os.getenv('%s')"
    else
      lvl = 0
    end
  end
  lvl = lvl < 0 and 0 or lvl
  lvl = math.min(lvl, #self._levels)
  return lvl, msg or ""  -- lvl is always number normalized to levels range
end

-- initialization; can be called multiple times to change settings
function logger:init(settings) -- table just like 'default' at the top
  assert(type(settings)=="table","table containing list of levels and settings expected")
  self._report = settings.report or self._report
  self._envvar = settings.envvar or self._envvar
  local tf = self._timefn
  self._timefn = type(settings.timefn) == "function" and settings.timefn or
                      settings.timefn  == false      and os.time or self._timefn or os.time
  if tf ~= self._timefn then -- timefn changed? reset elapsed time counter
    self._tstart = self:gettime()
    self._tprev = self._tstart % 1 == 0 and os.clock() or self._tstart
  end
  local colorizefn = type(settings.colorizefn) == "function" and settings.colorizefn or function(s) return s end

  -- monkeypatch 'require' if requested, or remove patch
  if settings.hookrequire == true then
    self._require = _G["require"]
    _G["require"] = function (module)
      if not package.loaded[module] then
        self:_log(string.format(HOOKMSG, module))
      end
      return self._require(module)
    end
  elseif settings.hookrequire == false then
    _G["require"] = self._require or _G["require"]
    self._require = nil
  end

  -- initialize new levels from settings
  if #settings > 0 then
    -- remove existing levels
    for key in pairs(self) do
      if type(key) == "number" or key:sub(1,1) ~= "_" then
        self[key] = nil
      end
    end

    -- build lookup table containing levels as specified in settings
    local t = {}
    for i, v in ipairs(settings) do
      local name = v[1]
      t[i] = {name=name, index=i, handle=v[4],
              prefix=format_factory(colorizefn(v[2]), i),
              suffix=format_factory(colorizefn(v[3]), i)}
      assert(t[name] == nil, "duplicate level name")
      t[name] = t[i]
      self[name] = function(x, ...) x:log(i,...) end -- log:name(...) named levels
      self[i] = function(...) self:log(i,...) end    -- log[index](...) levels by index
    end
    self._levels = t
  end

  -- report changed settings
  local lvl, msg = fetchlevel(self, settings.level, ".level=%s")
  self._level = lvl
  self:_log(string.format(INITMSG, #settings))
  if settings.level ~= nil or #settings > 0 then
    self:_log(string.format(msg, lvl, self._envvar))
  end
  if settings.report ~=nil then self:_log(".report=", self._report) end
  if settings.envvar ~=nil then self:_log(".envvar=", self._envvar) end
  if settings.timefn ~=nil then
    self:_log(".timefn=", tostring(settings.timefn ~= false and true),
              tf ~= self._timefn and " -- timer reset" or "")
  end
  if type(settings.hookrequire)=="boolean" then
    self:_log(".hookrequire=",tostring(settings.hookrequire))
  end
  return self
end

-- private: do tail call to self:log() to stay on same stack depth
function logger:_log(...)
  return self:log(self._report,...)
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

-- set level; acts as a threshold for output
function logger:setlevel(lvl, msg) -- number or string with valid level name
  lvl, msg = fetchlevel(self, lvl, msg)
  self._level = lvl
  self:_log(string.format(msg, self._level, self._envvar))
end

-- return current level number
function logger:getlevel()
  return self._level
end

-- do output
function logger:log(lvl, ...) -- level number; ... desired output
  lvl = getlevelidx(self, lvl)
  if type(lvl)=="number" and lvl > 0 and lvl <= self._level then
    local p = self._levels[lvl]
    local handle = p.handle
    handle:write(p.prefix(self))
    handle:write(...)
    handle:write(p.suffix(self))
    local x = self:gettime()
    self._tprev = x % 1 == 0 and os.clock() or x
  end
end

-- make log method callable by object name
function logger:__call(...)
  self:log(...)
end

-- make sure open file handles are closed and 'require' is restored
function logger:__gc()
  for _, v in ipairs(self._levels or E) do
    if io.type(v.handle) == "file" and
       v.handle ~= io.stdout and
       v.handle ~= io.stderr then
      assert(v.handle:close())
    end
  end
  _G["require"] = self._require or _G["require"]
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
