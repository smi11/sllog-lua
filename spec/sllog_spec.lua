-- don't add lines in front of mylog() function
local function mylog(log)
  log(1) -- should be on line 3 for asserts to pass without error!
end

-- make sure default envvar is set correctly to test it
local envvar = os.getenv("SLLOG_LEVEL")
local envvarok = {["1"]=1, ["2"]=2, ["3"]=3, ["4"]=4, err=1, warn=2, info=3, dbg=4}
if envvar and not envvarok[envvar] then
  print("please set environment variable SLLOG_LEVEL to either number 1 to 4 or")
  print("string 'err', 'warn', 'info' or 'dbg' before running 'busted'")
  os.exit()
end

-- make sure custom envvar is set correctly to test it
local envvarcustom = os.getenv("SLLOG_CUSTOM")
if envvarcustom and not envvarok[envvarcustom] then
  print("please set environment variable SLLOG_CUSTOM to either number 1 to 4 or")
  print("string 'err', 'warn', 'info' or 'dbg' before running 'busted'")
  os.exit()
end

local lf = package.config:sub(1,1) == "\\" and "\r\n" or "\n"

insulate("require 'sllog'", function()
  local req = _G["require"]
  local log = require "sllog"

  it("should return table", function()
    assert.equal("table",type(log))
  end)
  it("should return object set to defaults", function()
    assert.equal(4,#log._levels)
    local expected = envvar and tonumber(envvar) or (log._levels[envvar] or {}).index
    assert.equal(expected or 0,log._level)
    assert.equal("SLLOG_LEVEL",log._envvar)
    assert.equal(os.time,log._timefn)
    assert.equal(" ",log._pad)
    assert.equal(nil,log._report)
    assert.equal(nil,log._hookrequire)
    assert.equal(req,require)
  end)

  teardown(function()
    log = nil; collectgarbage()
  end)
end)

insulate("method init()", function()
  local log = require "sllog"
  local req = _G["require"]

  it("should report error", function()
    assert.has_error(function() log:init() end, "settings table expected")
  end)

  it("should patch 'require'", function()
      log:init{hookrequire=true}
      assert.is_not.equal(_G["require"], req)
  end)

  it("should restore 'require'", function()
      log:init{hookrequire=false}
      assert.equal(_G["require"], req)
  end)

  it("should set timefn", function()
    local f = function() return 123.456 end
    log:init{timefn=f}
    assert.equal(f, log._timefn)
  end)

  it("should clear timefn", function()
    log:init{timefn=false}
    assert.equal(os.time, log._timefn)
  end)

  it("should set pad character", function()
    log:init{pad="··"}
    assert.equal("··", log._pad)
  end)

  it("should set report level", function()
    log:init{report=0}
    assert.equal(0, log._report)
  end)

  it("should set level", function()
    log:init{level=3}
    assert.equal(3, log:getlevel())
  end)

  if envvar then
    it("should set level from default envvar", function()
      log:init{level=false}
      local expected = tonumber(envvar) or (log._levels[envvar] or {}).index
      assert.equal(expected, log:getlevel())
    end)
  end

  if envvarcustom then
    it("should set level from custom envvar", function()
      log:init{envvar="SLLOG_CUSTOM", level=false}
      local expected = tonumber(envvarcustom) or (log._levels[envvarcustom] or {}).index
      assert.equal(expected, log:getlevel())
    end)
  end

  it("should set custom levels", function()
    log:init{
      {"l1", "%F %T %-4L ", "%n", io.stderr},
      {"l2", "%F %T %-4L ", "%n", io.stderr},
      {"l3", "%F %T %-4L ", "%n", io.stderr},
    }
    assert.equal(3, #log._levels)
    for i = 1,3 do
      assert.equal(i, log._levels[i].index)
      assert.equal("l"..tostring(i), log._levels[i].name)
      assert.equal(io.stderr, log._levels[i].handle)
      assert.equal("function", type(log._levels[i].prefix))
      assert.equal("function", type(log._levels[i].suffix))
    end
  end)

end)

insulate("method init()", function()
  local log = require "sllog"

  it("should enable internal logging", function()
    local f = io.tmpfile()
    local now = {year=2023,month=3,day=21,hour=10,min=20,sec=30}
    log:init{
      {"test",  "%F %3T %L ", ";", f},
      timefn=function() return os.time(now) + 0.123 end,
      report="test",
      level="test",
    }
    log:setlevel(0)
    log:setlevel(1,"setlevel(%s)")
    f:seek("set",0)
    local s = f:read("*all")
    f:close()
    assert.equal("2023-03-21 10:20:30.123 test init() -- 1 levels initialized;"..
                 "2023-03-21 10:20:30.123 test .level=1;"..
                 '2023-03-21 10:20:30.123 test .report="test";'..
                 "2023-03-21 10:20:30.123 test .timefn=true -- timer reset;"..
                 "2023-03-21 10:20:30.123 test setlevel(1);",s)
  end)
end)

insulate("method setlevel()&getlevel()", function()
  local log = require "sllog"

  it("should set/get level", function()
    log:setlevel(-1000)
    assert.equal(0, log:getlevel())
    log:setlevel(0)
    assert.equal(0, log:getlevel())
    log:setlevel(1)
    assert.equal(1, log:getlevel())
    log:setlevel("err")
    assert.equal(1, log:getlevel())
    log:setlevel("dbg")
    assert.equal(4, log:getlevel())
    log:setlevel(1000)
    assert.equal(4, log:getlevel())
  end)

  it("should report error", function()
    assert.has_error(function() log:setlevel("nonexistent") end, "valid level index, level name or nil expected")
  end)

  if envvar then
    it("should set level from default envvar", function()
      log:setlevel()
      local expected = tonumber(envvar) or (log._levels[envvar] or {}).index
      assert.equal(expected, log:getlevel())
    end)
  end

  if envvarcustom then
    it("should set level from custom envvar", function()
      log:init{envvar="SLLOG_CUSTOM"}
      log:setlevel()
      local expected = tonumber(envvarcustom) or (log._levels[envvarcustom] or {}).index
      assert.equal(expected, log:getlevel())
    end)
  end
end)

local function testprefix(prefix, what, num, expected)
  it(prefix..' should show '..what,function()
    local f = io.tmpfile()
    local now = {year=2023,month=3,day=21,hour=10,min=20,sec=30}
    local log = require "sllog":init{
      {"lvl",  prefix, "", f},
      timefn=function() return os.time(now) + num end,
      level=1,
    }
    log._tstart = os.time(now)
    log._tprev = os.time(now)
    mylog(log)
    f:seek("set",0)
    local s = f:read("*all")
    f:close()
    if prefix == "%k" or prefix == "%b" then -- return of collectgarbage("count")
      assert.equal("number", type(tonumber(s))) -- unknown, but it should be number
    else
      assert.matches(expected, s)
    end
  end)
end

describe("prefix", function()
  testprefix("%F",    "full date", 0, '2023%-03%-21')
  testprefix("%x",    "locale date", 0, '03/21/23')
  testprefix("%c",    "date and time", 0, 'Tue Mar 21 10:20:30 2023')
  testprefix("%1c",   "date and time", 0.999, 'Tue Mar 21 10:20:31.0 2023')
  testprefix("%3c",   "date and time", 0.001234, 'Tue Mar 21 10:20:30.001 2023')
  testprefix("%r",    "12h time", 0.98765, '10:20:31 AM')
  testprefix("%3r",   "12h time", 0.98765, '10:20:30.988 AM')
  testprefix("%T",    "time", 0.98765, '10:20:31')
  testprefix("%X",    "time", 0.123, '10:20:30')
  testprefix("%e",    "elapsed time", 0.000001, '0.000001')
  testprefix("%7.3e", "elapsed time", 20.123, ' 20.123')
  testprefix("%.3e",  "elapsed time", 0.98765, '0.988')
  testprefix("%E",    "elapsed time", 0.000001, '00:00:00')
  testprefix("%1E",   "elapsed time", 20.12345, '00:00:20.1')
  testprefix("%3E",   "elapsed time", 123456.98765, '10:17:36.988')
  testprefix("%.3p",  "delta time", 123.4567, '123.457')
  testprefix("%.1P",  "delta time", 123.90765, '00:02:03.9')
  testprefix("%l",    "level number", 0, '1')
  testprefix("%L",    "level name", 0, 'lvl')
  testprefix("%S",    "module:line", 0, 'sllog_spec:3')
  testprefix("%f",    "function name", 0, ' mylog()')
  testprefix("%n",    "lf or crlf", 0, lf)
  testprefix("%k",    "memory in Kb", 0, 'number')
  testprefix("%b",    "memory in bytes", 0, 'number')
  testprefix("%F %3E %.2k Kb %S%f",    "all combined", 0.123,
             '^2023%-03%-21 00:00:00.123 %d+.%d%d Kb sllog_spec:3 mylog()')
end)

describe("method log()", function()
  local log = require "sllog"

  it("should produce output", function()
    local f = io.tmpfile()
    local now = {year=2023,month=3,day=21,hour=10,min=20,sec=30}
    log:init{
      {"err",  "%F %2T %-4L ", ";", f},
      {"warn", "%F %2T %-4L ", ";", f},
      {"info", "%F %2T %-4L ", ";", f},
      {"dbg",  "%F %2T %-4L ", ";", f},
      timefn=function() return os.time(now) + 0.987 end,
      report=4,
      level=4,
    }
    log:err("err message")
    log:warn("warn message")
    log:info("info message")
    log:dbg("dbg message")
    log:setlevel(2)
    log:err("err message")
    log:warn("warn message")
    log:info("info message")
    log:dbg("dbg message")
    log:setlevel(0)
    log:err("err message")
    log:warn("warn message")
    log:info("info message")
    log:dbg("dbg message")
    f:seek("set",0)
    local s = f:read("*all")
    f:close()
    assert.equal('2023-03-21 10:20:30.99 dbg  init() -- 4 levels initialized;' ..
                 '2023-03-21 10:20:30.99 dbg  .level=4;' ..
                 '2023-03-21 10:20:30.99 dbg  .report=4;' ..
                 '2023-03-21 10:20:30.99 dbg  .timefn=true -- timer reset;' ..
                 '2023-03-21 10:20:30.99 err  err message;' ..
                 '2023-03-21 10:20:30.99 warn warn message;' ..
                 '2023-03-21 10:20:30.99 info info message;' ..
                 '2023-03-21 10:20:30.99 dbg  dbg message;' ..
                 '2023-03-21 10:20:30.99 err  err message;' ..
                 '2023-03-21 10:20:30.99 warn warn message;', s)
  end)
end)

describe("method vardump()", function()
  local log = require "sllog"

  it("should serialize variable", function()
    local f = io.tmpfile()
    log:init{
      {"err",  "%-4L ", ";", f},
      {"warn", "%-4L ", ";", f},
      {"info", "%-4L ", ";", f},
      {"dbg",  "%-4L ", ";", f},
      timefn=function() return 1679390430.987 end,
      report="dbg",
      level=4,
    }
    log:vardump("log", log)
    log:vardump("log", log, 1)
    f:seek("set",0)
    local s = f:read("*all")
    f:close()
    assert.equal('dbg  init() -- 4 levels initialized;'..
                 'dbg  .level=4;'..
                 'dbg  .report="dbg";'..
                 'dbg  .timefn=true -- timer reset;'..
                 'dbg  log = <1>{;'..
                 'dbg   <function 1>,;'..
                 'dbg   <function 2>,;'..
                 'dbg   <function 3>,;'..
                 'dbg   <function 4>,;'..
                 'dbg   _envvar = "SLLOG_LEVEL",;'..
                 'dbg   _level = 4,;'..
                 'dbg   _levels = <2>{;'..
                 'dbg    <3>{;'..
                 'dbg     handle = <userdata 1>,;'..
                 'dbg     index = 1,;'..
                 'dbg     name = "err",;'..
                 'dbg     prefix = <function 5>,;'..
                 'dbg     suffix = <function 6>,;'..
                 'dbg    },;'..
                 'dbg    <4>{;'..
                 'dbg     handle = <userdata 1>,;'..
                 'dbg     index = 2,;'..
                 'dbg     name = "warn",;'..
                 'dbg     prefix = <function 5>,;'..
                 'dbg     suffix = <function 6>,;'..
                 'dbg    },;'..
                 'dbg    <5>{;'..
                 'dbg     handle = <userdata 1>,;'..
                 'dbg     index = 3,;'..
                 'dbg     name = "info",;'..
                 'dbg     prefix = <function 5>,;'..
                 'dbg     suffix = <function 6>,;'..
                 'dbg    },;'..
                 'dbg    <6>{;'..
                 'dbg     handle = <userdata 1>,;'..
                 'dbg     index = 4,;'..
                 'dbg     name = "dbg",;'..
                 'dbg     prefix = <function 5>,;'..
                 'dbg     suffix = <function 6>,;'..
                 'dbg    },;'..
                 'dbg    dbg = <table 6>,;'..
                 'dbg    err = <table 3>,;'..
                 'dbg    info = <table 5>,;'..
                 'dbg    warn = <table 4>,;'..
                 'dbg   },;'..
                 'dbg   _pad = " ",;'..
                 'dbg   _report = "dbg",;'..
                 'dbg   _timefn = <function 7>,;'..
                 'dbg   _tprev = 1679390430.987,;'..
                 'dbg   _tstart = 1679390430.987,;'..
                 'dbg   dbg = <function 8>,;'..
                 'dbg   err = <function 9>,;'..
                 'dbg   info = <function 10>,;'..
                 'dbg   warn = <function 11>,;'..
                 'dbg   <metatable> = <7>{;'..
                 'dbg    _VERSION = "sllog 0.2",;'..
                 'dbg    __call = <function 12>,;'..
                 'dbg    __gc = <function 13>,;'..
                 'dbg    __index = <table 7>,;'..
                 'dbg    _log = <function 14>,;'..
                 'dbg    getelapsed = <function 15>,;'..
                 'dbg    getlevel = <function 16>,;'..
                 'dbg    gettime = <function 17>,;'..
                 'dbg    gettprev = <function 18>,;'..
                 'dbg    init = <function 19>,;'..
                 'dbg    log = <function 20>,;'..
                 'dbg    setlevel = <function 21>,;'..
                 'dbg    vardump = <function 22>,;'..
                 'dbg   };'..
                 'dbg  };'..
                 'err  log = <1>{;'..
                 'err   <function 1>,;'..
                 'err   <function 2>,;'..
                 'err   <function 3>,;'..
                 'err   <function 4>,;'..
                 'err   _envvar = "SLLOG_LEVEL",;'..
                 'err   _level = 4,;'..
                 'err   _levels = <2>{;'..
                 'err    <3>{;'..
                 'err     handle = <userdata 1>,;'..
                 'err     index = 1,;'..
                 'err     name = "err",;'..
                 'err     prefix = <function 5>,;'..
                 'err     suffix = <function 6>,;'..
                 'err    },;'..
                 'err    <4>{;'..
                 'err     handle = <userdata 1>,;'..
                 'err     index = 2,;'..
                 'err     name = "warn",;'..
                 'err     prefix = <function 5>,;'..
                 'err     suffix = <function 6>,;'..
                 'err    },;'..
                 'err    <5>{;'..
                 'err     handle = <userdata 1>,;'..
                 'err     index = 3,;'..
                 'err     name = "info",;'..
                 'err     prefix = <function 5>,;'..
                 'err     suffix = <function 6>,;'..
                 'err    },;'..
                 'err    <6>{;'..
                 'err     handle = <userdata 1>,;'..
                 'err     index = 4,;'..
                 'err     name = "dbg",;'..
                 'err     prefix = <function 5>,;'..
                 'err     suffix = <function 6>,;'..
                 'err    },;'..
                 'err    dbg = <table 6>,;'..
                 'err    err = <table 3>,;'..
                 'err    info = <table 5>,;'..
                 'err    warn = <table 4>,;'..
                 'err   },;'..
                 'err   _pad = " ",;'..
                 'err   _report = "dbg",;'..
                 'err   _timefn = <function 7>,;'..
                 'err   _tprev = 1679390430.987,;'..
                 'err   _tstart = 1679390430.987,;'..
                 'err   dbg = <function 8>,;'..
                 'err   err = <function 9>,;'..
                 'err   info = <function 10>,;'..
                 'err   warn = <function 11>,;'..
                 'err   <metatable> = <7>{;'..
                 'err    _VERSION = "sllog 0.2",;'..
                 'err    __call = <function 12>,;'..
                 'err    __gc = <function 13>,;'..
                 'err    __index = <table 7>,;'..
                 'err    _log = <function 14>,;'..
                 'err    getelapsed = <function 15>,;'..
                 'err    getlevel = <function 16>,;'..
                 'err    gettime = <function 17>,;'..
                 'err    gettprev = <function 18>,;'..
                 'err    init = <function 19>,;'..
                 'err    log = <function 20>,;'..
                 'err    setlevel = <function 21>,;'..
                 'err    vardump = <function 22>,;'..
                 'err   };'..
                 'err  };', s)
  end)
end)
