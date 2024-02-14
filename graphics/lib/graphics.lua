local event = require("event")
local gpu = require("component").gpu
local io = require("io")
local math = require("math")
local string = require("string")
local table = require("table")
local tty = require("tty")

local logging = require("logging")

local graphics = {}
graphics.draw = {}
graphics.button = {}
graphics.meter = {}
local buttons = {}
local meters = {}

--- @type Log
local log = nil

--- @class (exact) Meter
--- @field label string
--- @field x number
--- @field y number
--- @field xx number
--- @field yy number
--- @field frameColor number
--- @field fillColor number
--- @field fill number

--- @class (exact) Button
--- @field label string
--- @field x number
--- @field y number
--- @field xx number
--- @field yy number
--- @field inactiveColor number
--- @field activeColor number
--- @field textColor number
--- @field active boolean

--- Writes to log file at a given path
--- If not called, does not log
--- @param path string
--- @param level verbosity
function graphics.startLog(path, level)
  log = logging.new(path, level)
end

function graphics.closeLog()
  log:close()
end

--- Draws a dot on the screen
--- @param x number
--- @param y number
--- @param color number
function graphics.draw.dot(x, y, color)
  local oldColor = gpu.setBackground(color)
  tty.setCursor(x, y)
  io.write(" ")
  gpu.setBackground(oldColor)
end

--- Draws a rectangle on the screen
--- @param x number xmin
--- @param y number ymin
--- @param xx number xmax
--- @param yy number ymax
--- @param color number
function graphics.draw.rect(x, y, xx, yy, color)
  -- Default to current color if color is nil
  if color == nil then
    color = gpu.getBackground()
  end
  log:printFormatted(
    logging.verbosity.debug,
    "Drawing rectangle from (%i, %i) to (%i, %i) in color 0x%x",
    x,
    y,
    xx,
    yy,
    color
  )
  -- Get the width and height
  -- Have to add 1 because gpu.fill only goes to n-1
  local width = xx - x + 1
  local height = yy - y + 1
  local oldColor = gpu.setBackground(color)
  gpu.fill(x, y, width, height, " ")
  gpu.setBackground(oldColor)
end

--- Creates a new meter and adds it to the table of meters
--- @param label string
--- @param x number
--- @param y number
--- @param xx number
--- @param yy number
--- @param frameColor number
--- @param fillColor number
--- @return Meter
function graphics.meter.new(label, x, y, xx, yy, frameColor, fillColor)
  local meter = {}
  meter.label = label
  meter.x = x
  meter.y = y
  meter.xx = xx
  meter.yy = yy

  if fillColor == nil then
    fillColor = 0x555555
  end
  if frameColor == nil then
    frameColor = 0x888888
  end

  meter.frameColor = frameColor
  meter.fillColor = fillColor
  meter.fill = 0
  table.insert(meters, meter)
  return meter
end

--- Sets how full a meter is (from 0 to 1)
--- @param meter Meter
--- @param fill number
function graphics.meter.fill(meter, fill)
  meter.fill = fill
end

--- Draws a meter on the screen
--- @param meter Meter
function graphics.meter.draw(meter)
  -- Draw the meter frame
  graphics.draw.rect(
    meter.x,
    meter.y,
    meter.xx,
    meter.yy,
    meter.frameColor
  )
  -- Clear the inside of the meter
  local bgColor = gpu.getBackground()
  graphics.draw.rect(
    meter.x + 1,
    meter.y + 1,
    meter.xx - 1,
    meter.yy - 1,
    bgColor
  )
  -- Draw the filled part of the meter
  local fillPixels = (meter.xx - meter.x) * meter.fill
  graphics.draw.rect(
    meter.x + 1,
    meter.y + 1,
    meter.x + fillPixels,
    meter.yy - 1,
    meter.fillColor
  )
  -- Draw the label on the top of the meter
  local textX = (meter.xx - meter.x) - string.len(meter.label) / 2
  tty.setCursor(textX, meter.y)
  io.write(meter.label)
  gpu.setBackground(bgColor)
end

--- Redraw all the meters
function graphics.meter.redrawAll()
  for _, meter in pairs(meters) do
    graphics.meter.draw(meter)
  end
end

--- Create a new button and add it to the table of buttons
--- @param label string
--- @param x number
--- @param y number
--- @param xx number
--- @param yy number
--- @param inactiveColor number
--- @param activeColor number
--- @param textColor? number
--- @return Button
function graphics.button.new(label, x, y, xx, yy, inactiveColor, activeColor, textColor)
  local button = {}
  button.label = label
  button.x = x
  button.y = y
  button.xx = xx
  button.yy = yy
  button.inactiveColor = inactiveColor
  button.activeColor = activeColor
  if textColor == nil then
    textColor = 0xffffff
  end
  button.textColor = textColor
  button.active = false
  table.insert(buttons, button)
  return button
end

--- Removes a button from the table
--- @param button Button
function graphics.button.remove(button)
  for k, v in pairs(buttons) do
    if v == button then
      table.remove(buttons, k)
      return
    end
  end
end

--- Clears the button list
function graphics.button.reset()
  buttons = {}
end

--- Draws a button
--- @param button Button
function graphics.button.draw(button)
  local color
  if button.active then
    color = button.activeColor
  else
    color = button.inactiveColor
  end

  log:printFormatted(
    logging.verbosity.debug,
    "Drawing button %s from (%i, %i) to (%i, %i) with background 0x%x",
    button.label,
    button.x,
    button.y,
    button.xx,
    button.yy,
    color
  )
  graphics.draw.rect(
    button.x,
    button.y,
    button.xx,
    button.yy,
    color
  )

  -- Draw text
  local labelWidth = string.len(button.label)
  local buttonWidth = button.xx - button.x
  local buttonHeight = button.yy - button.y
  local labelX = math.ceil(buttonWidth / 2 - labelWidth / 2) + button.x
  local labelY = (buttonHeight / 2) + button.y
  local oldBackground = gpu.setBackground(color)
  local oldForeground = gpu.setForeground(button.textColor)
  tty.setCursor(labelX, labelY)
  log:printFormatted(
    logging.verbosity.debug,
    "Drawing label on button %s at (%i, %i) with foreground 0x%x and background 0x%x",
    button.label,
    labelX,
    labelY,
    button.textColor,
    color
  )
  io.write(button.label)
  gpu.setBackground(oldBackground)
  gpu.setForeground(oldForeground)
end

--- Draw all buttons
function graphics.button.drawAll()
  for _, button in pairs(buttons) do
    graphics.button.draw(button)
  end
end

--- Sets a button as active or not
--- @param button Button
--- @param state boolean
function graphics.button.setActive(button, state)
  button.active = state
end

--- Toggles a button's active state
--- @param button Button
function graphics.button.toggle(button)
  button.active = not button.active
end

--- Flashes a button as active
--- If no time value is given, defaults to 0.15 seconds.
--- If blocking is nil, defaults to true
--- NOTE: If not blocking, button area will be drawn over after `interval` has passed.
--- If you draw something else in that area in that time it'll get drawn over.
--- @param button Button
--- @param time number
--- @param blocking boolean
function graphics.button.flash(button, time, blocking)
  if blocking == nil then
    blocking = true
  end

  -- Draw button as active
  button.active = true
  graphics.button.draw(button)
  if blocking then
    os.sleep(time)
    -- Draw button as inactive
    button.active = false
    graphics.button.draw(button)
  else
    event.timer(
      time,
      function()
        button.active = false
        graphics.button.draw(button)
      end,
      1
    )
  end
end

--- Returns the button that was pressed at the given coordinates.
--- If no button was pressed, returns nil.
--- @param x number
--- @param y number
--- @return Button | nil
function graphics.button.getPressed(x, y)
  for _, button in pairs(buttons) do
    if button.x <= x and button.xx >= x and button.y <= y and button.yy >= y then
      return button
    end
  end
  return nil
end

return graphics