package = "sllog"
version = "0.1-0"
source = {
  url = "https://github.com/smi11/sllog-lua/archive/refs/tags/v0.1-0.zip",
  dir = "sllog-lua-0.1-0"
}
description = {
  summary = "Simple line logger",
  detailed = [[
    You can define prefix and suffix for each log message. Both allow various
    tags for date, time, elapsed time, level, debug info and memory usage so you
    can format your log as you wish. Each log level can have its own formatting
    and can be output to different file handles. You can also hook require
    function to automatically log its use. More precise timing and coloring is
    possible as well.
  ]],
  homepage = "https://github.com/smi11/sllog-lua",
  license = "MIT <http://opensource.org/licenses/MIT>"
}
dependencies = {
  "lua >= 5.1"
}
build = {
  type = "builtin",
  modules = {
    ["sllog"] = "sllog.lua"
  },
  copy_directories = {}
}
