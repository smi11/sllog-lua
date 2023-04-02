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
    assert.has_error(function() log:init() end, "table containing list of levels and settings expected")
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

  it("should set report level", function()
    log:init{report=0}
    assert.equal(0, log._report)
  end)

  it("should set level", function()
    log:init{level=1}
    assert.equal(1, log:getlevel())
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
                 "2023-03-21 10:20:30.123 test .report=test;"..
                 "2023-03-21 10:20:30.123 test .timefn=true -- timer reset;"..
                 "2023-03-21 10:20:30.123 test setlevel(1);",s)
  end)
end)

insulate("method setlevel()", function()
  local log = require "sllog"

  it("should set level", function()
    log:setlevel(1)
    assert.equal(1, log:getlevel())
    log:setlevel("err")
    assert.equal(1, log:getlevel())
    log:setlevel("dbg")
    assert.equal(4, log:getlevel())
  end)

  if envvar then
    it("should set level from default envvar", function()
      log:setlevel()
      local expected = tonumber(envvar) or (log._levels[envvar] or {}).index
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
  testprefix("%e",    "elasped time", 0.000001, '0.000001')
  testprefix("%7.3e", "elasped time", 20.123, ' 20.123')
  testprefix("%.3e",  "elasped time", 0.98765, '0.988')
  testprefix("%E",    "elasped time", 0.000001, '00:00:00')
  testprefix("%1E",   "elasped time", 20.12345, '00:00:20.1')
  testprefix("%3E",   "elasped time", 123456.98765, '10:17:36.988')
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
