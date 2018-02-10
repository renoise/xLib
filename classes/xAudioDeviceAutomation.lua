--[[===============================================================================================
xLib
===============================================================================================]]--

--[[--

Create an instance to store audio-parameter automation data for an entire device

]]

--==============================================================================

cLib.require(_clibroot.."cPersistence")
cLib.require(_xlibroot.."xAudioDevice")
cLib.require(_xlibroot.."xTrack")

---------------------------------------------------------------------------------------------------

class 'xAudioDeviceAutomation' (cPersistence)

xAudioDeviceAutomation.__PERSISTENCE = {
  "device_path",
  "parameters",
}

---------------------------------------------------------------------------------------------------

function xAudioDeviceAutomation:__init()
  TRACE("xAudioDeviceAutomation:__init()")

  -- string, type of device (e.g. "Audio/Effects/Native/*XY Pad")
  self.device_path = nil

  -- parameter assignments, as a list of tables 
  -- {
  --    name = (string),
  --    index = (number),
  --    envelope = (xEnvelope),
  -- }
  self.parameters = {}

  -- number, derived from parameters
  self.number_of_lines = property(self._get_number_of_lines)

end  

---------------------------------------------------------------------------------------------------
-- check if the parameters specify any points 
-- @return boolean

function xAudioDeviceAutomation:has_points()
  TRACE("xAudioDeviceAutomation:has_points()")

  local has_points = false
  for k,v in ipairs(self.parameters) do
    if v.envelope and v.envelope:has_points() then
      has_points = true
      break
    end
  end
  return has_points

end 

---------------------------------------------------------------------------------------------------
-- @return number 

function xAudioDeviceAutomation:_get_number_of_lines()
  TRACE("xAudioDeviceAutomation:_get_number_of_lines()")

  for k,v in ipairs(self.parameters) do
    if v.envelope and v.envelope:has_points() then
      return v.envelope.number_of_lines
    end
  end

  error("Error: should not get here (automation without points)")

end 

---------------------------------------------------------------------------------------------------
-- check if the device is of the same type 
-- @return boolean

function xAudioDeviceAutomation:compatible_with_device_path(device)
  assert(type(device)=="AudioDevice")
  return (device.device_path == self.device_path)
end 

---------------------------------------------------------------------------------------------------
-- assign values in table (e.g. when applying deserialized values)
-- @param t (table)

function xAudioDeviceAutomation:assign_definition(t)
  TRACE("xAudioDeviceAutomation:assign_definition(t)",t)

  self.device_path = t.device_path
  self.parameters = {}

  for k,v in ipairs(t.parameters) do 
    local param = {
      name = v.name,
      index = v.index,
      envelope = xEnvelope()
    }
    param.envelope:assign_definition(v.envelope)
    table.insert(self.parameters,param)
  end

end

---------------------------------------------------------------------------------------------------

function xAudioDeviceAutomation:__tostring()
  return type(self)
    .. ":device_path=" .. tostring(self.device_path)
    .. ",parameters=" .. tostring(self.parameters)

end 

