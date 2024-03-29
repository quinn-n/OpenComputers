# OpenComputers Programs

## Tabs

### Overview
Tabs lets users manage multiple programs at the same time in different tabs.  
  
Note that it doesn't quite run multiple programs at the same time. It only
runs the tab the user is currently in, due to limitations with OpenOS's gpus.

![Tabs screenshot](images/tabs%20screenshot.png "Tabs running")

# Libraries

## Graphics

### Overview
Manages buttons and meters.
NOTE: There's some breaking refactoring I'd like to do to this library so
I recommend not using it for the time being.

## Logging

### Overview

Library that contains a lot of boiler plate behind logging.

### Reference

  - `logging.new(file: string | file*, verbosity?: logging.verbosity): Log`  
    Instantiates a new `Log` class.
      - `file`: Either a filepath or an already opened file to write logs to. If given a file path for `file` and `verbosity` is not `logging.verbosity.disabled`, auto-opens the file in `write` mode.
      - `verbosity`: Verbosity level for the `Log`. Calls to `Log:write` and similar functions don't print if they are passed a higher `verbosity` than the `Log` class was instantized with. If `logging.verbosity.disabled` is passed in, the instantized `Log` class is a no-op. You can also use normal integers for this rather than the `logging.verbosity` enum, though I find the enum helps with code readability.

  - `logging.verbosity`  
    Enum which contains different log levels:
      - `disabled`
      - `error`
      - `warn`
      - `info`
      - `debug`

  - `Log:write(level: verbosity, msg: string)`  
    Writes a message at the given verbosity level to the log, unless `logging.verbosity.disabled` was passed to `logging.new`.

  - `Log:print(level: verbosity, msg: string)`  
    Writes a message at the given verbosity level to the log, followed by a newline. Basically a wrapper for `Log:write`.

  - `Log:writeFormatted(level: verbosity, format: string, ...: any)`  
    Writes a formatted message using [string.format](https://lua.org/manual/5.3/manual.html#pdf-string.format) at the given verbosity level to the log, unless `logging.verbosity.disabled` was passed to `logging.new`.

  - `Log:printFormatted(level: verbosity, format: string, ...: any)`  
    Writes a formatted message at the given verbosity level to the log, followed by a newline. Basically a wrapper for `Log:writeFormatted`.

  - `Log:printTable(level: verbosity, t: table, recursive: boolean)`  
    Recursively prints the contents of a table in a human-readable format. Can get stuck in a recursion-loop if tables point to each other circularly.

  - `Log:flush()`  
    Flushes log file handler

  - `Log:close()`  
    Closes log file handler

