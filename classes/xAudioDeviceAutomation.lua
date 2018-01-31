--[[===============================================================================================
xLib
===============================================================================================]]--

--[[--

Create an instance to store audio-parameter automation data for an entire device
(creates multiple instances of xParameterAutomation)

]]

class 'xAudioDeviceAutomation'

-- configure process slicing (avoid timeouts while processing)
-- NB: first two values are shared with xParameterAutomation
xAudioDeviceAutomation.YIELD_AT = {
  NONE = 1,
  PATTERN = 2,    -- yield once per parameter + pattern-track (often)
  PARAMETER = 3,  -- yield once per parameter (sometimes)
}

---------------------------------------------------------------------------------------------------

function xAudioDeviceAutomation:__init()
  TRACE("xAudioDeviceAutomation:__init()")

  -- string, type of device (e.g. "Audio/Effects/Native/*XY Pad")
  self.device_path = nil

  -- (xParameterAutomation.SCOPE) 
  -- (shared interface with xParameterAutomation)
  self.scope = property(self._get_scope)

  -- parameter assignments, as a list of tables 
  -- {
  --    name = (string),
  --    index = (number),
  --    automation = (xParameterAutomation),
  -- }
  self.parameters = {}

end  

---------------------------------------------------------------------------------------------------
-- source scope can be deduced from our parameters 
-- @return xParameterAutomation.SCOPE

function xAudioDeviceAutomation:_get_scope()
  for k,v in ipairs(self.parameters) do
    if v.automation then
      return v.automation.scope
    end
  end
  error("Error: Could not determine scope (no automation was found)")
end

---------------------------------------------------------------------------------------------------
-- check if the parameters specify any points 
-- (shared interface with xParameterAutomation)
-- @return boolean

function xAudioDeviceAutomation:has_points()
  TRACE("xAudioDeviceAutomation:has_points()")

  local has_points = false
  for k,v in ipairs(self.parameters) do
    if v.automation then
      if v.automation:has_points() then
        has_points = true
        break
      end
    end
  end
  return has_points

end 

---------------------------------------------------------------------------------------------------
-- check if the device is of the same type 
-- @return boolean

function xAudioDeviceAutomation:compatible_with_device_path(device)
  assert(type(device)=="AudioDevice")
  return (device.device_path == self.device_path)
end 

---------------------------------------------------------------------------------------------------

function xAudioDeviceAutomation:__tostring()
  return type(self)
    .. ":device_path=" .. tostring(self.device_path)
    .. ",scope=" .. tostring(self.scope)
    .. ",parameters=" .. tostring(self.parameters)

end 

