local computer = require("computer")
local event = require("event")
local gpu = require("component").gpu
local math = require("math")
local os = require("os")
local table = require("table")
local term = require("term")
local thread = require("thread")


local graphics = require("graphics")
local logger = require("logger")

-- There is no good way to get the screen's refresh rate
-- so this is just a good enough guesstimate
local SCREEN_REFRESH_RATE = 30

local TAB_HEIGHT = 3

local LOG_LVL = logger.verbosity.disabled

local tabIdCounter = 1
local tabs = {}
local currentTab

local newTabButton
local touchListenerId, blitTimerId, closeTabListenerId
local closeTab

local backgroundColor = gpu.getBackground()
local screenWidth, screenHeight = gpu.getResolution()
local SHELL = os.getenv("SHELL")

-- NOTE: This is a small possible attack vector from anyone who can overwrite the $HOME environment variable
-- However I'm not going to worry too much about it because the same kind of attack can be done with the $SHELL
-- environment variable above which there's no way around.
local logDir = os.getenv("HOME") .. "/.local/tabs/log/"
os.execute("mkdir -p " .. logDir)

local log = logger.new(logDir .. "/tabs.log", LOG_LVL)

graphics.startLog(logDir .. "/graphics.log", LOG_LVL)

--- @class (exact) Tab
--- @field buffer number
--- @field title string
--- This id is only used for inter-thread communication and should not be changed once set
--- @field id number
--- @field cursorCol number | nil
--- @field cursorRow number | nil
--- @field selectButton Button
--- @field closeButton Button
-- This is a thread object, but the thread library doesn't have a type for it
--- @field thread table

--- @param tabId number
local function shellThread(tabId)
  dofile(SHELL)
  -- Throw an event to the main thread to close the tab
  event.push("close_tab", tabId)
end

--- @return number
local function getTabWidth()
  return math.floor((screenWidth - 5) / #tabs)
end

local function updateButtonWidths()
  local tabWidth = getTabWidth()
  log:printFormatted(
    logger.verbosity.debug,
    "Got tabWidth: %i",
    tabWidth
  )
  local selectButtonWidth = tabWidth - 5
  for idx, tab in ipairs(tabs) do
    tab.selectButton.x = (tabWidth) * (idx - 1) + 1
    tab.selectButton.xx = tab.selectButton.x + selectButtonWidth - 1
    tab.closeButton.x = tab.selectButton.xx + 1
    tab.closeButton.xx = tab.closeButton.x + 4
  end
end

-- Redraw tab bar
local function redrawTabs()
  local cursorBlink = term.getCursorBlink()
  term.setCursorBlink(false)

  local oldBuffer = gpu.setActiveBuffer(0)
  -- Clear the tab area
  local screenWidth, _ = gpu.getResolution()
  gpu.fill(1, 1, screenWidth, TAB_HEIGHT, " ")
  -- Draw tab buttons
  for _, tab in pairs(tabs) do
    graphics.button.draw(tab.selectButton)
    graphics.button.draw(tab.closeButton)
  end
  graphics.button.draw(newTabButton)
  gpu.setActiveBuffer(oldBuffer)

  term.setCursorBlink(cursorBlink)
end

-- Blits a tab buffer to the screen
--- @param buffer number
local function blitTabBuffer(buffer)
  local bufferWidth, bufferHeight = gpu.getBufferSize(buffer)
  gpu.bitblt(0, 1, TAB_HEIGHT + 1, bufferWidth, bufferHeight, buffer)
end

local function switchTab(tab)
  log:printFormatted(
    logger.verbosity.debug,
    "Switching to tab %s",
    tab
  )

  -- Suspend current tab
  local col, row = term.getCursor()
  if currentTab ~= nil then
    currentTab.thread:suspend()
    graphics.button.setActive(currentTab.selectButton, false)
    currentTab.cursorCol = col
    currentTab.cursorRow = row
  end

  -- Switch to new tab
  graphics.button.setActive(tab.selectButton, true)
  currentTab = tab

  -- Redraw buttons with new states
  redrawTabs()

  -- Resume new tab
  gpu.setActiveBuffer(tab.buffer)
  blitTabBuffer(tab.buffer)

  if tab.cursorCol ~= nil then
    log:printFormatted(
      logger.verbosity.info,
      "Setting cursor to (%i, %i)",
      tab.cursorCol,
      tab.cursorRow
    )
    term.setCursor(tab.cursorCol, tab.cursorRow)
  end

  tab.thread:resume()
end

--- @return Tab
local function newTab()
  log:print(logger.verbosity.info, "Creating new tab")

  -- Coordinates for buttons are set by `updateButtonWidths`
  local selectButton = graphics.button.new(SHELL, 1, 1, 1, TAB_HEIGHT, 0x878787, backgroundColor)
  local closeButton = graphics.button.new("X", 1, 1, 1, TAB_HEIGHT, 0xff0000, 0xcc0000)

  local tab = {
    buffer=gpu.allocateBuffer(screenWidth, screenHeight - TAB_HEIGHT),
    title=SHELL,
    id=tabIdCounter,
    cursorCol=nil,
    cursorRow=nil,
    selectButton=selectButton,
    closeButton=closeButton,
    thread=nil,
  }

  tabIdCounter = tabIdCounter + 1

  -- Have to start the thread after the call to `setActiveBuffer`
  -- Otherwise the first lines of the shell get cut off before
  -- the shell thread yields back to the main thread
  gpu.setActiveBuffer(tab.buffer)
  tab.thread = thread.create(shellThread, tab.id)

  selectButton.tab = tab
  closeButton.tab = tab

  table.insert(tabs, tab)
  updateButtonWidths()
  switchTab(tab)
  redrawTabs()

  return tab
end

term.window.fullscreen = false
term.window.height = screenHeight - TAB_HEIGHT

newTabButton = graphics.button.new(
  "+",
  screenWidth - 4,
  1,
  screenWidth,
  3,
  0xb4b4b4,
  0x787878
)

-- Cleanup and exit
local function quit()
  -- Kill any remaining tabs
  for _, tab in pairs(tabs) do
    closeTab(tab, true)
  end

  --Cleanup events
  local blitResult = event.cancel(blitTimerId)
  local touchResult = event.cancel(touchListenerId)
  local closeResult = event.cancel(closeTabListenerId)
  if blitResult then
    log:printFormatted(
      logger.verbosity.info,
      "Cancelled blit timer %i",
      blitTimerId
    )
  else
    log:printFormatted(
      logger.verbosity.error,
      "Failed to cancel blit timer %i",
      blitTimerId
    )
  end
  if touchResult then
    log:printFormatted(
      logger.verbosity.info,
      "Cancelled touch listener %i",
      touchListenerId
    )
  else
    log:printFormatted(
      logger.verbosity.error,
      "Failed to cancel touch listener %i",
      touchListenerId
    )
  end
  if closeResult then
    log:printFormatted(
      logger.verbosity.info,
      "Cancelled close tab listener %i",
      closeTabListenerId
    )
  else
    log:printFormatted(
      logger.verbosity.error,
      "Failed to cancel close tab listener %i",
      closeTabListenerId
    )
  end

  -- Cleanup screen
  graphics.button.remove(newTabButton)
  term.window.fullscreen = true
  term.window.height = screenHeight
  term.clear()
  log:close()
  graphics.closeLog()

  -- Push interrupt event to kill main thread
  event.push("interrupted_tabs")
end

--- @param tab Tab
--- @param _quitting? boolean used by the quit function to avoid re-calling `quit()`
function closeTab(tab, _quitting)
  log:printFormatted(
    logger.verbosity.info,
    "Closing tab %s",
    tab
  )
  if _quitting == nil then
    _quitting = false
  end

  graphics.button.remove(tab.selectButton)
  graphics.button.remove(tab.closeButton)

  tab.thread:kill()
  tab.thread:join()

  gpu.freeBuffer(tab.buffer)
  for k, v in pairs(tabs) do
    if v == tab then
      table.remove(tabs, k)
    end
  end
  -- If all tabs are closed, stop the timers and handlers
  -- and quit the program
  if not _quitting and #tabs == 0 then
    quit()
  end
  updateButtonWidths()

  -- If closing current tab, switch back to first tab
  if tab == currentTab then
    switchTab(tabs[1])
  -- `redrawTabs` is already called by `switchTab`
  else
    redrawTabs()
  end
end

--- @param col number
--- @param row number
local function processTouch(_, _, col, row, ...)
  local pressed = graphics.button.getPressed(col, row)
  if pressed == nil then
    return
  end

  if pressed == newTabButton then
    newTab()
    return
  end

  local tab = pressed.tab
  if pressed == tab.closeButton then
    closeTab(tab)
  elseif pressed == tab.selectButton then
    switchTab(tab)
  end
end

--- @param id number
--- @return Tab?
--- Only used for inter-thread communication
local function getTabById(id)
  for _, tab in pairs(tabs) do
    if tab.id == id then
      return tab
    end
  end
  return nil
end

--- Listener which closes tabs when they throw a `close_tab` event
--- @param tabId number
local function closeTabListener(_, tabId)
  local tab = getTabById(tabId)
  if tab == nil then
    log:printFormatted(
      logger.verbosity.error,
      "Received close_tab event for non-existent tab %i",
      tabId
    )
    return
  end
  log:printFormatted(logger.verbosity.debug, "Received close_tab event with tab %s", tab)
  computer.beep()
  closeTab(tab)
end

currentTab = newTab()

-- Setup updateScreen timer
blitTimerId = event.timer(
  1 / SCREEN_REFRESH_RATE,
  function()
    blitTabBuffer(currentTab.buffer)
  end,
  math.huge
)

touchListenerId = event.listen(
  "touch",
  processTouch
)

closeTabListenerId = event.listen(
  "close_tab",
  closeTabListener
)

-- Stop the main shell from executing until it gets a special interrupt event
local ev = ""
repeat
  ev = event.pull("interrupted")
until ev == "interrupted_tabs"
