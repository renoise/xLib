--[[===============================================================================================
xLib
===============================================================================================]]--

--[[--

Create an instance to store audio-parameter automation data for an entire device
(creates multiple instances of xParameterAutomation)

]]

class 'xAudioDeviceAutomation'

---------------------------------------------------------------------------------------------------

function xAudioDeviceAutomation:__init()
  TRACE("xAudioDeviceAutomation:__init()")

  -- string, type of device (e.g. "Audio/Effects/Native/*XY Pad")
  self.device_path = nil

  -- xSelection "sequence", the source range that got copied 
  self.range = nil

  -- parameter automation, as a list of tables 
  -- {
  --    name = (string),
  --    index = (number),
  --    automation = (xParameterAutomation),
  -- }
  self.parameters = {}

end  

---------------------------------------------------------------------------------------------------
-- check if the device is of the same type 
-- @return boolean

function xAudioDeviceAutomation:device_is_compatible(device)
  assert(type(device)=="AudioDevice")
  return (device.device_path == self.device_path)
end 

---------------------------------------------------------------------------------------------------

function xAudioDeviceAutomation:__tostring()
  return type(self)
    .. ":device_path=" .. tostring(self.device_path)
    .. ",parameters=" .. tostring(self.parameters)
    .. ",range=" .. tostring(self.range)

end 

