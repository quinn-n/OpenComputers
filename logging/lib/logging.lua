local math = require("math")
local string = require("string")

--- @class (exact) Log
--- @field file file*?
--- @field level number
--- @field write fun(self: Log, level: verbosity, msg: string)
--- @field print fun(self: Log, level: verbosity, msg: string)
--- @field writeFormatted fun(self: Log, level: verbosity, format: string, ...: any)
--- @field printFormatted fun(self: Log, level: verbosity, format: string, ...: any)
--- @field printTable fun(self: Log, level: verbosity, t: table, recursive: boolean, _tabLevel?: number)
--- @field flush fun(self: Log)
--- @field close fun(self: Log)

local logging = {}

--- @param file file* | string file handle or path to write to
--- @param verbosity? verbosity verbosity level. Defaults to math.huge
--- @return Log
function logging.new(file, verbosity)
  if verbosity == nil then
    verbosity = math.huge
  end

  if type(file) == "string" and verbosity ~= logging.verbosity.disabled then
    local errmsg
    file, errmsg = io.open(file, "w")
    if file == nil then
      error(string.format("Could not open file %s for writing due to %s", file, errmsg))
    end
  end

  --- @cast file file*

  --- @type Log
  local log = {
    file = file,
    level = verbosity,
    write=function (self, level, msg)
      if self.level >= level then
        self.file:write(msg)
      end
    end,
    print=function (self, level, msg)
      self:write(level, msg .. "\n")
    end,
    writeFormatted=function (self, level, format, ...)
      self:write(level, string.format(format, ...))
    end,
    printFormatted=function (self, level, format, ...)
      self:writeFormatted(level, format .. "\n", ...)
    end,
    printTable=function (self, level, t, recursive, _tabLevel)
      if _tabLevel == nil then
        _tabLevel = 0
      end
      local tabString = string.rep("  ", _tabLevel)
      self:writeFormatted(level, "%s{\n", tabString)

      for k, v in pairs(t) do
        if type(v) == "table" and recursive then
          self:writeFormatted(level, "%s%s = ", tabString .. "  ", k)
          self:printTable(level, v, recursive, _tabLevel + 1)
        else
          self:writeFormatted(level, "%s%s = %s,\n", tabString .. "  ", k, v)
        end
      end

      self:writeFormatted(level, "%s},\n", tabString)
    end,
    flush=function (self)
      if self.level ~= logging.verbosity.disabled then
        self.file:flush()
      end
    end,
    close=function (self)
      if self.level ~= logging.verbosity.disabled then
        self.file:close()
      end
    end
  }
  return log
end

--- @enum verbosity
logging.verbosity = {
  disabled = -1,
  error = 1,
  warn = 2,
  info = 3,
  debug = 4
}

return logging
