# sllog 0.2 Simple line logger

[![License](https://img.shields.io/:license-mit-blue.svg)](https://mit-license.org) 
[![test](https://github.com/smi11/sllog-lua/actions/workflows/test.yml/badge.svg)](https://github.com/smi11/sllog-lua/actions/workflows/test.yml) [![Luacheck](https://github.com/smi11/sllog-lua/actions/workflows/luacheck.yml/badge.svg)](https://github.com/smi11/sllog-lua/actions/workflows/luacheck.yml)

`sllog.lua` is a simple logging module for Lua that provides basic logging functionality. It allows you to log messages with different levels of severity and
to different outputs such as the console or a file. You can also customize the
format of the log messages and colorize them.

## Installation

### Using LuaRocks

Installing `sllog.lua` using [LuaRocks](https://www.luarocks.org/):

`$ luarocks install sllog`

### Without LuaRocks

Download file `sllog.lua` and put it into the directory for Lua libraries or
your working directory.

## Quick start

```lua
-- level name, prefix, suffix, file handle
local log = require "sllog":init{
  {"err",  "%F %T %-4L ",        "%n", io.stderr},
  {"warn", "%F %T %-4L ",        "%n", io.stderr},
  {"info", "%F %T %-4L ",        "%n", io.stderr},
  {"dbg",  "%F %T (%S) %-4L%f ", "%n", io.stderr},
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
```

## API

### constructor `init(settings table)`

Constructor `init(settings table)` initializes logger with specified `settings table` describing levels and/or options. By default it is called once when you `require "sllog"` with default settings table. So if you're happy with defaults, there is no need to call constructor again. However it can be called multiple times if changes to settings are needed.

#### Settings table

```lua
-- default settings table
{
  -- index represents levels {name, prefix, suffix, handle}
  {"err",  "%F %T %-4L ",      "%n", io.stderr},
  {"warn", "%F %T %-4L ",      "%n", io.stderr},
  {"info", "%F %T %-4L ",      "%n", io.stderr},
  {"dbg",  "%F %T (%S) %-4L ", "%n", io.stderr},
  -- hash part represents options
  envvar = "SLLOG_LEVEL",  -- default environment variable
}
```

#### Setting levels

Array part of settings table defines levels where each index/level should be another table containing four elements in following order: `level name`, `prefix`, `suffix`, `file handle`. 

- `level name` must be a unique string among all levels. It is also recommended to comply with identifier rules. It should start with a letter 'A to Z' or 'a to z' or an underscore '_' followed by zero or more letters, underscores, and digits (0 to 9).

- `prefix` is string representing what should be printed before your log message, and `suffix` is string representing what should be printed after your log message. Both can contain anything including tags that produce time, date, elapsed time, level number and name, module name and line, calling function, cr and lf characters and memory usage in kilobytes or bytes.

- `file handle` should be either `io.stdout` or `io.stderr` or file.

#### Format strings for `prefix` and `suffix`

| format |                       description                       |
|--------|---------------------------------------------------------|
| `%c`   | locale's date and time (e.g., Thu Mar  3 23:05:25 2005) |
| `%F`   | full date (e.g., 2005-12-31)                            |
| `%r`   | locale's 12-hour clock time (e.g., 11:11:04 PM)         |
| `%T`   | time (e.g., 23:13:48)                                   |
| `%x`   | locale's date representation (e.g., 12/31/99)           |
| `%X`   | locale's time representation (e.g., 23:13:48)           |
| `%e`   | elapsed time since start (e.g., 0.424024)               |
| `%E`   | elapsed time since start (e.g., 00:04:34.334)           |
| `%p`   | elapsed time since last log (e.g., 0.424024)            |
| `%P`   | elapsed time since last log (e.g., 00:04:34.334)        |
| `%l`   | level number                                            |
| `%L`   | level name                                              |
| `%S`   | module:line                                             |
| `%f`   | calling function name with leading space                |
| `%n`   | crlf or lf based on os                                  |
| `%k`   | used memory in kb                                       |
| `%b`   | used memory in bytes                                    |

Format string for displaying time `%c`, `%r`, `%T`, `%X`, `%E` and `%P` allow additional numeric parameter between % sign and character for setting number of decimal places to show. For example `%3c` will show time with precision of 3 decimal places. This make only sense if higher precision time function is assigned (See `timefn` option bellow).

Format string for `%e`, `%p` and `%k` use same options as `%f` in C printf function for formating floating-point numbers. For example `%.3e` would show three decimal places for elapsed time.

Format string for `%L` uses same options as `%s` in C printf function for formatting strings.

Format string for `%b` uses same options as `%i` in C printf function for formating integers.

You can combine format strings to form a prefix and suffix. For example setting `prefix` to `"%F %T %-4L "` would produce full date followed by space then by time and space and level name left aligned to four characters followed by final space (eg. "2005-12-31 23:13:48 err  ")

You should end each suffix with newline character or `%n` format string.

#### Setting options

In hash part of the settings table we may define following options:

|     option    |                        meaning                         |
|---------------|--------------------------------------------------------|
| `level`       | Up to which level should output be produced?           |
| `envvar`      | Which environment variable to use to set level         |
| `hookrequire` | Monkey patch `require` function with logger            |
| `report`      | On which level should internal log events be generated |
| `pad`         | Pad character(s) for `dumpvar()` method                |
| `timefn`      | Custom time function                                   |
| `colorizefn`  | Custom colorize function                               |

#### `level`

With `level` we specify up to which level number should we generate output. For example if we set `level = 2`, only levels 1 and 2 would be output. Setting `level = 0` would disable all output. We can use either level index or name. So `level = "info"` is the same as `level = 3` with default settings table. Setting level to nonexistent level name will generate error. Setting `level` lower than 0 or higher than last level's index is okay since value will be normalized.

Setting `level = false` will set level to value of environment variable if it exists or 0 otherwise. That is also the default setting.

#### `envvar`

With `envvar` we define which environment variable to use for setting `level`. Default if `"SLLOG_LEVEL"`.

#### `hookrequire`

With `hookrequire` we can patch `require` function to automatically generate log events. `hookrequire = true` will enable patch, and `hookrequire = false` will restore the built-in `require` function. For `hookrequire` to work, you must also set `report`. By default `hookrequire` is disabled.

#### `report`

With `report`, we set on which level should internal log events be produced. We can use either level index or name. By default, `report` is nil which means no internal log events. Example: `report = "dbg"` will generate internal log events on level named "dbg".

#### `pad`

One or more characters to be used for padding output of `dumpvar()` method. By default `pad` is set to one space character `" "`.

#### `timefn`

With `timefn` we can set custom time function. This may be useful if you require more precise timing than internal `os.time()` function. The time function should produce a Unix timestamp.

For example if you use LuaSocket in your application, you could use `socket.gettime()`. Example: `timefn = (socket or {}).gettime`.

Setting `timefn = false` will restore built-in `os.time()` function, which is also a default setting.

#### `colorizefn`

With the `colorizefn` option, we can set function that converts color tags to ANSI. This function is called only during initialization of prefixes and suffixes for all levels.

```lua
local eansi = require "eansi"

-- example of conversion of color tags to ANSI using eansi.rawpaint function
local log = require "sllog":init{
  {"mylevel",  "${green}%F %T${normal} ${red}%-4L$${reset}", "%n", io.stderr},
  colorizefn = eansi.rawpaint,
}
```

### Methods

All methods should be called using colon syntax.

#### Method `setlevel(lvl[, msg])`

Sets level. `lvl` can be either level index, level name or boolean false or nil. If `lvl` is false or nil then the level will be set to value of environment variable if it exists and is valid or to 0 otherwise which means logger will not generate any output. If invalid level name is provided then an error will be raised. An optional `msg` can be provided which is a string to use for logging internal logger events. The default `msg` is string `"setlevel(%s)"`

#### Method `getlevel()`

The `getlevel` method returns the current level index.

#### Method `gettime()`

The `gettime` method returns the current time.

#### Method `getelapsed()`

The `getelapsed` method returns elapsed time since first initialization of logger or last setting of time function. Whichever function have higher precision will be used, either method `gettime` or `os.clock`.

#### Method `gettprev()`

The `gettprev` method returns elapsed time since previous call to `log()`. Whichever function have higher precision will be used, either method `gettime` or `os.clock`.

#### Method `log(lvl, ...)`

Method `log` outputs to specified level only when specified level index is lower or equal to level specified by the `setlevel()` method.

The `log` method is also bound to the `__call` metamethod which allows following syntaxes:

```lua
local log = require "sllog"

log(3, "some message")           -- using level index
log[3]("some message")           -- another form using index
log:info("some message")         -- using level name; this is preferred way
log("info", "some message")      -- using level name
```

Output is done by `io.write` which means all arguments should be explicitly converted to string using Lua's `tostring()` function. If an invalid level name is provided then an error will be raised. If non-existent level number is provided than no output will be generated.

#### Method `vardump(name, var[, lvl])`

Method `vardump` will output value of any variable including cyclic tables with metatables. `name` is a string containing variable name, and `var` is variable we wish to serialize.

If optional `lvl` is not specified, the variable will be output to level specified by an option `report` if set or nothing will be output.

If we do specify `lvl` then output will be made to that level.

In all cases output will be made only if the `report` level or specified `lvl` is smaller or equal to threshold set by `setlevel`.

## Examples

There are few examples in folder `examples` demonstrating common functionality.

## HISTORY

### 0.2 < active

- finalized settings, methods and module structure
- refactor all code
- fixed compatibility issues with Lua 5.1 and Lua 5.4
- added memoize for generating prefix and suffix functions
- added vardump() method
- added pad option
- added documentation to README.md
- added examples

### 0.1 < active

- first draft
