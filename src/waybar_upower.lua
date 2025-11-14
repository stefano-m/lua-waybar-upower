#!/usr/bin/env lua
--[[
  Copyright 2025 Stefano Mazzucco

  Licensed under the GNU GENERAL PUBLIC LICENSE Version 3 or later.  You may
  not use this file except in compliance with the License.

  You may obtain a copy of the License at

  https://www.gnu.org/licenses/gpl-3.0.html

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
]]
local GLib = require("lgi").GLib
local json = require("cjson.safe")
local string = string
local math = math
local arg = arg
local io = io

local SIGINT = 2
local SIGTERM = 15


local function to_hour_min_str(seconds)
  local hours = math.floor(seconds/3600)
  local minutes = math.ceil( (seconds % 3600) / 60)
  return string.format("%02dh:%02dm", hours, minutes)
end


--[[
  Change 'class' depending on warning level
  get percentage
  get time to empty and to full, use to_hour_min_str put in tooltip
  may run swaymsg with a warning when the battery is critical? make it configurable?
  use on_properties_change signal
  put device type in 'alt'? It's going to be a battery 99% fof the times anyway.
  acutally, the percentage can be used to displa a full/half full/empty icon
--]]

local function format(device)

  local tooltip

  local percentage = device.Percentage and math.floor(device.Percentage) or ""

  local percentage_msg = (percentage ~= "") and string.format("%d%%", percentage) or ""
  percentage_msg = (percentage_msg ~= "") and percentage_msg .. " - " or percentage_msg
  percentage_msg = percentage_msg .. device.state

  local what
  local when

  if device.TimeToEmpty > 0 then
    what = "Empty"
    when = device.TimeToEmpty
  elseif device.TimeToFull > 0 then
    what = "Full"
    when = device.TimeToFull
  end

  local charge_status_msg = ""
  if when then
    charge_status_msg = string.format("\r%s in %s", what, to_hour_min_str(when))
  end

  local capacity_msg = (device.Capacity and device.Capacity > 0) and string.format("%d%%", device.Capacity) or ""
  capacity_msg = capacity_msg .. (device.CapacityLevel and string.format("(%s)", device.CapacityLevel) or "")
  capacity_msg = (capacity_msg ~= "") and "\rCapacity: " .. capacity_msg or capacity_msg

  tooltip =  string.format(
    "%s%s%s",
    percentage_msg,
    charge_status_msg,
    capacity_msg
  )

  return {
    text = device.state,
    alt = device.state,
    tooltip =  tooltip,
    class =  device.warninglevel and device.warninglevel:lower() or "unknown",
    percentage =  percentage,
  }
end

local relevant_property_names = {
  TimeToEmpty = true,
  TimeToFull = true,
  Percentage = true,
  State = true,
  WarningLevel = true, -- Low = 3, Critical = 4, Action = 5
  CapacityLevel = true,
  Capacity = true;
}

local function run()

  local upower = require("upower_dbus")

  local device

  for _, d in ipairs(upower.Manager.devices) do
    if d.type == upower.enums.DeviceType.Battery.name then
      device = d
      break
    end
  end

  if not device then
    device = upower.display_device
  end
  print(json.encode(format(device)))

  device:on_properties_changed(
    function(dvc, changed)
      for prop_name in pairs(changed) do
        if relevant_property_names[prop_name] then
          print(json.encode(format(dvc)))
        end
      end
    end
  )

  local main_loop = GLib.MainLoop()

  local function exit_on_signal()
    print(json.encode({
              text = "exited",
              alt = "quit",
              tooltip = "exited",
              class = "quit",
              percentage = "",
    }))
    main_loop:quit()
  end

  GLib.unix_signal_add(GLib.PRIORITY_HIGH, SIGINT, exit_on_signal)
  GLib.unix_signal_add(GLib.PRIORITY_HIGH, SIGTERM, exit_on_signal)

  main_loop:run()
end

if arg and arg[1] == "run" then
  io.stdout:setvbuf("no")       -- unbuffered output
  run()
end
