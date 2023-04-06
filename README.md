# sllog 0.2 Simple line logger

[![License](https://img.shields.io/:license-mit-blue.svg)](https://mit-license.org) 
[![test](https://github.com/smi11/sllog-lua/actions/workflows/test.yml/badge.svg)](https://github.com/smi11/sllog-lua/actions/workflows/test.yml)

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

## Installation

### Using LuaRocks

Installing `sllog.lua` using [LuaRocks](https://www.luarocks.org/):

`$ luarocks install sllog`

### Without LuaRocks

Download file `sllog.lua` and put it into the directory for Lua libraries or
your working directory.

## Quick start

```
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
```

## HISTORY

0.2 < active
    - finalized settings, methods and module structure
    - refactor all code
    - fixed compatibility issues with Lua 5.1 and Lua 5.4

0.1 < active
    - first draft
