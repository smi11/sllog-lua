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
  {"err",  "%F %T %-4L ",      "%n", io.stderr},
  {"warn", "%F %T %-4L ",      "%n", io.stderr},
  {"info", "%F %T %-4L ",      "%n", io.stderr},
  {"dbg",  "%F %T %-4L (%S)%f ", "%n", io.stderr},
  timefn=(socket or {}).gettime,  -- use socket.gettime if available
  report="dbg",       -- to which level should internal log events be passed?
  hookrequire=true,   -- also report calls to require()
  level="dbg"         -- output levels up to and including "dbg"
}

-- you can specify level either by index or name
log(3, "some message")
log[3]("some message")
log:info("same as previous line, but using name")
log("info", "also same as previous lines")

-- log uses io.write so same rules apply
local n = 123
local b = true
log:dbg("my var n = ", n, " and b = ", tostring(b))

-- output any Lua value including tables with cycles and metatables
local t = setmetatable({1, 2, 3, sub_t={"Hello, ", "world"}}, {__mode="kv"})
t[123] = t
log:vardump("t", t)

See README.md for documentation

HISTORY

0.2 < active

- finalized settings, methods and module structure
- refactor all code
- fixed compatibility issues with Lua 5.1 and Lua 5.4
- added memoize for generating prefix and suffix functions
- added dumpvar() method
- added pad option

0.1

- first draft

LICENSE

MIT License. See end of file for full text.
--]]

local sformat = string.format
local smatch = string.match
local sgmatch = string.gmatch
local tconcat = table.concat
local tostring = tostring
local tonumber = tonumber
local debug = require "debug"

-- constants
local INITMSG = "init() -- %s levels initialized" -- message when init() is called
local HOOKMSG = 'require "%s"'                    -- message when hooked require is called

-- safe navigation E and logger object
local E = {}
local logger = {}
if _VERSION == "Lua 5.1" then
  logger = getmetatable(newproxy(true)) -- hack for __gc metamethod in Lua 5.1
end
logger._VERSION = "sllog 0.2"
logger.__index = logger

-- table containing default settings and list of levels to be used with logger:init()
-- name, prefix, suffix, file handle
local default = {
  {"err",  "%F %T %-4L ",      "%n", io.stderr},
  {"warn", "%F %T %-4L ",      "%n", io.stderr},
  {"info", "%F %T %-4L ",      "%n", io.stderr},
  {"dbg",  "%F %T %-4L (%S)%f ", "%n", io.stderr},
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
  S = [[_getdebug()]],                                  -- module:line
  f = [[_getcaller()]],                                 -- calling function name with leading space
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
  local fpart = sformat("%0."..prec.."f",frac)
  local carry = tonumber(fpart:sub(1,1))
  return (os.date(fmt,sec+carry):gsub(":%d%d%f[%s%z]", "%1"..fpart:gsub("^%d","")))
end

-- get module name and line number as a string
function fenv._getdebug()
  local t = debug.getinfo(5,"Sl")
  return (t.short_src:match("([^/]*).lua$") or "")..":"..(t.currentline or "")
end

-- get name of the calling function with leading space or empty string
function fenv._getcaller()
  local fname = debug.getinfo(5).name
  return fname and " "..fname.."()" or ""
end

-- factory that builds function for formating prefix and suffix
local function format_factory(str)
  local code = {
    "return function(x, lvl)",
    " local t = {}",
  }
  local i = 1
  local s, e, val, ss
  while true do
    s, e, val = str:find("(%%[%d.+#%-]*[cFrTxXeEpPlLSfnkb])", i) -- tags from lookup
    if s then
      ss = str:sub(i,s-1) -- substring before tag
      if #ss > 0 then
        code[#code+1] = sformat(" t[#t+1] = %q", ss)
      end
      local chr = val:sub(-1)
      local fmt = val:sub(2,-2) or ""
      if lookup[chr] then -- replace tag with appropriate lua code
        code[#code+1] = " t[#t+1] = " .. lookup[chr]:gsub("<fmt>", fmt)
      end
      i = e + 1
    else -- part of str after last tag
      ss = str:sub(i)
      if #ss > 0 then
        code[#code+1] = sformat("t[#t+1] = %q", ss)
      end
      break
    end
  end -- while

  code[#code+1] = " return tconcat(t)"
  code[#code+1] = " end"

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

-- memoize for format_factory
local function memoize(f)
  local memo = setmetatable({}, {__mode="kv"})
  return function (x)
    local r = memo[x]
    if r == nil then
      r = f(x)
      memo[x] = r
    end
    return r
  end
end

format_factory = memoize(format_factory)

-- get level index or nil
local function getlevelidx(self, lvl)
  lvl = tonumber(lvl) or (self._levels[lvl] or E).index or lvl
  lvl = lvl ~= false and lvl or nil
  assert(type(lvl)=="number" or lvl==nil, "valid level index, level name or nil expected")
  lvl = lvl and lvl < 0 and 0 or lvl
  return lvl
end

-- fetch level index from provided string or number or environment variable
local function fetchlevel(self, lvl, msg)
  lvl = getlevelidx(self, lvl)
  msg = msg or "setlevel(%s)"
  if not lvl then
    local env = os.getenv(self._envvar)
    if env and env ~= "" then
      lvl = getlevelidx(self, env)
      msg = msg .. " -- os.getenv('%s')"
    else
      lvl = 0
    end
  end
  lvl = math.min(lvl, #self._levels) -- lvl normalized to levels range
  return lvl, msg or ""
end

-- initialization; can be called multiple times to change settings
function logger:init(settings) -- table just like 'default' at the top
  assert(type(settings)=="table", "settings table expected")
  self._pad    = settings.pad or self._pad or " "
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
        self:_log(sformat(HOOKMSG, module))
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
              prefix=format_factory(colorizefn(v[2])),
              suffix=format_factory(colorizefn(v[3]))}
      assert(t[name] == nil, "duplicate level name")
      t[name] = t[i]
      self[name] = function(x, ...) x:log(i,...) end -- log:name(...)
      self[i] = function(...) self:log(i,...) end    -- log[index](...)
    end
    self._levels = t
  end

  -- report changed settings
  if settings.level ~= nil or #settings > 0 then
    local lvl, msg = fetchlevel(self, settings.level, ".level=%s")
    self._level = lvl
    self:_log(sformat(INITMSG, #settings))
    self:_log(sformat(msg, self._level, self._envvar))
  else
    self:_log(sformat(INITMSG, #settings))
  end
  if settings.pad    ~=nil then self:_log(sformat(".pad=%q", self._pad)) end
  if settings.report ~=nil then self:_log(sformat(".report=%q", self._report)) end
  if settings.envvar ~=nil then self:_log(sformat(".envvar=%q", self._envvar)) end
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
  self:_log(sformat(msg, self._level, self._envvar))
end

-- return current level number
function logger:getlevel()
  return self._level
end

-- do output
function logger:log(lvl, ...) -- level number; ... desired output
  lvl = getlevelidx(self, lvl)
  if type(lvl)=="number" and lvl > 0 and lvl <= self._level then
    local p, i = self._levels[lvl], self._levels[lvl].index
    local handle = p.handle
    handle:write(p.prefix(self, i))
    handle:write(...)
    handle:write(p.suffix(self, i))
    local x = self:gettime()
    self._tprev = x % 1 == 0 and os.clock() or x
  end
end

-- split string on linefeed
local function lfsplit(s, sep)
  sep = sep or "\n"
  local t={}
  for str in sgmatch(s, "([^"..sep.."]+)") do
    t[#t+1] = str
  end
  return t
end

-- return string if Lua identifier or nil otherwise
local isidentifier
do
  local function set(list)
    local t = {}
    for _, l in ipairs(list) do t[l] = true end
    return t
  end
  local reserved = set{
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return",
    "then", "true", "until", "while"
  }

  function isidentifier(k)
    return     type(k) == "string"
           and      k  == smatch(k,"^[%a_][%w_]*$")
           and not reserved[k]
  end
end

-- sort keys for serializer
local function sorted_pairs(t)
  local keys = {}
  for k in pairs(t) do
    table.insert(keys, k)
  end
  table.sort(keys, function (a, b)
    if type(a) == "number" and type(b) == "number" then
      return a < b
    else
      return tostring(a) < tostring(b)
    end
  end)
  local i = 0
  return function()
    i = i + 1
    if keys[i] == nil then
      return nil
    else
      return keys[i], t[keys[i]]
    end
  end
end

-- build output by concatenating all strings and then splitting them by lf
local function out_factory()
  local buf = {}
  return function (s, ...)
    if s == nil then
      s = tconcat(buf)
      buf = {}
      return lfsplit(s)
    end
    buf[#buf+1] = s
    for i = 1, select("#", ...) do
      buf[#buf+1] = select(i, ...)
    end
  end
end

local out = out_factory()

-- serialize any Lua value including tables with cycles and metatables
local function serialize(value, pad, depth, store)
  pad = pad or "  "
  depth = depth or 1
  store = store or {}
  local t = type(value)
  if t == "nil" then
    out "nil"
  elseif t == "boolean" then
    out(tostring(value))
  elseif t == "number" then
    out(tostring(value))
  elseif t == "string" then
    out(sformat("%q", value))
  elseif t == "table" then
    store.tables = store.tables or {}
    local indent = string.rep(pad, depth-1)
    if store.tables[value] then
      out(sformat("<table %i>", store.tables[value]))
    else
      store.tables[#store.tables+1] = value
      store.tables[value] = #store.tables
      out(sformat("<%i>{\n", store.tables[value]))
      local i = 1
      for k, v in sorted_pairs(value) do
        out(indent, pad)
        if k == i then
          serialize(v, pad, depth+1, store)
          out(",\n")
        else
          if isidentifier(k) then
            out(k, " = ")
          else
            out("[")
            serialize(k, pad, depth+1, store)
            out("] = ")
          end
          serialize(v, pad, depth+1, store)
          out(",\n")
        end
        i = i + 1
      end
      local mt = getmetatable(value)
      if mt then
        out(indent, pad, "<metatable> = ")
        serialize(mt, pad, depth+1, store)
        out("\n")
      end
      out(indent, "}")
    end
  elseif   t == 'function'
        or t == 'thread'
        or t == 'userdata' then
    store[t] = store[t] or {}
    if not store[t][value] then
      store[t][#store[t]+1] = value
      store[t][value] = #store[t]
    end
    out(sformat("<%s %i>", t, store[t][value]))
  else
    out("Cannot serialize a ", t, " value.\n")
  end
end

-- show value of any variable
function logger:vardump(name, value, lvl)
  lvl = getlevelidx(self, lvl or self._report) or 0
  if self._level >= lvl then
    out(name, " = ")
    serialize(value, self._pad or " ")
    local buf = out()
    for _, v in ipairs(buf) do
      self:log(lvl, v)
    end
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

-- create instance of logger object and return it as a module table
return setmetatable({}, logger):init(default)

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
