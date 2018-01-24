--[[============================================================================
xLib
============================================================================]]--

--[[--

Static methods for dealing with Audio Devices.

]]


class 'xAudioDevice'

--------------------------------------------------------------------------------
-- @param device (AudioDevice)
-- @param param (DeviceParameter)
-- @return number or nil

function xAudioDevice.get_param_index(device,param)
  TRACE("xAudioDevice.get_param_index(device,param)",device,param)
  for k,v in ipairs(device.parameters) do
    if rawequal(v,param) then
      return k
    end
  end
end

--------------------------------------------------------------------------------
-- [Static] Resolve the device/parameter indices based on a parameter
-- (TODO: API5 makes a much more efficient implementation possible)
-- @param param, renoise.DeviceParameter 
-- @param track_idx, restrict search to this track (optional)
-- @param device_idx, restrict search to this device (optional)
-- @return int, parameter index
-- @return int, device index
-- @return int, track index

function xAudioDevice.resolve_parameter(param,track_idx,device_idx)
  TRACE("xAudioDevice.resolve_parameter(param,track_idx,device_idx)",param,track_idx,device_idx)

  assert(type(param)=="DeviceParameter")

  local search_device = function(device,device_idx,track_idx)
    TRACE("xAudioDevice.resolve_parameter:search_device(device,device_idx,track_idx)",device,device_idx,track_idx)
    local match_param_idx = xAudioDevice.get_param_index(device,param)
    if match_param_idx then 
      return match_param_idx,device_idx,track_idx
    end
  end

  local search_track = function(track,device_idx,track_idx)
    TRACE("xAudioDevice.resolve_parameter:search_track(track,device_idx,track_idx)",track,device_idx,track_idx)
		if device_idx then
      local device = track.devices[device_idx]
			if not device then
				return 
			end
      return search_device(device,device_idx,track_idx)
    else
      for _,device in ipairs(track.devices) do
        local param_idx = search_device(device,device_idx,track_idx)
        if param_idx then
          return param_idx,device_idx,track_idx
        end
      end
		end
	end


  if track_idx and device_idx then
		local track = rns.tracks[track_idx]
		if not track then
			return
		end
    local device = track.devices[device_idx]
    if not device then
      return 
    end
    return search_device()

  elseif track_idx then
		local track = rns.tracks[track_idx]
		if not track then
			return
		end
		return search_track(track,device_idx,track_idx)
  else
		for track_idx,track in ipairs(rns.tracks) do
      local param_idx = search_track(track,device_idx,track_idx)
      if param_idx then
        return param_idx,device_idx,track_idx
      end 
		end
	end

end

--------------------------------------------------------------------------------
-- [Static] Determine if a device is linked to different fx-chains/tracks
-- (detection not solid if the destination is automated - rare case!)
-- @param device (renoise.AudioDevice)
-- @return table (linked fx-chains/tracks)

function xAudioDevice.get_device_routings(device)
  TRACE("xAudioDevice.get_device_routings(device)",device)

  assert(type(device) =="AudioDevice",
    "Unexpected argument: device should be an instance of renoise.AudioDevice")

  local routings = {}
  for k,param in ipairs(device.parameters) do
    if (param.name:match("Out%d Track")) or
      (param.name:match("Receiver %d")) or
      (param.name == "Dest. Track") or
      (param.name == "Receiver")          
    then
      if (param.value ~= 0) then
        routings[param.value+1] = true
      end
    end
  end

  return routings

end

--------------------------------------------------------------------------------
-- [Static] Check if provided device is a send device
-- @param device (renoise.AudioDevice)
-- @return bool 

function xAudioDevice.is_send_device(device)
  TRACE("xAudioDevice.is_send_device(device)",device)

  assert(type(device) =="AudioDevice",
    "Unexpected argument: device should be an instance of renoise.AudioDevice")

  local send_devices = {"#Send","#Multiband Send"}
  return table.find(send_devices,device.name)

end

--------------------------------------------------------------------------------
-- [Static] Get parameters that are visible in the mixer
-- @param device (renoise.AudioDevice)
-- @return table<renoise.DeviceParameter>

function xAudioDevice.get_mixer_parameters(device)
  TRACE("xAudioDevice.get_mixer_parameters(device)",device)

  assert(type(device) =="AudioDevice",
    "Unexpected argument: device should be an instance of renoise.AudioDevice")

  local rslt = {}
  for k,v in ipairs(device.parameters) do
    if (v.show_in_mixer) then
      table.insert(rslt,v)
    end
  end

  return rslt

end

--------------------------------------------------------------------------------
-- @param device (renoise.AudioDevice)
-- @param param_name (string)
-- @return renoise.DeviceParameter or nil
-- @return number (parameter index) or nil 

function xAudioDevice.get_parameter_by_name(device,param_name)
  TRACE("xAudioDevice.get_parameter_by_name(device,param_name)",device,param_name)

  assert(type(device)=="AudioDevice")
  assert(type(param_name)=="string")

  for k,v in ipairs(device.parameters) do 
    if (v.name == param_name) then 
      return v,k
    end
  end

end


---------------------------------------------------------------------------------------------------
-- copy automation from the specified device 
-- @param track_idx (number, track index 
-- @param device_idx (number), device index 
-- @param seq_range (xSelection "sequence"), restrict to range - use full range if undefined

function xAudioDevice.copy_automation(track_idx,device_idx,seq_range)
  TRACE("xAudioDevice.copy_automation(track_idx,device_idx,seq_range)",track_idx,device_idx,seq_range)

  local rns_track = rns.tracks[track_idx]
  assert(type(rns_track)=="Track")

  local rns_device = rns_track.devices[device_idx]
  assert(type(rns_device) == "AudioDevice")

  -- if no range is defined, use full range (entire song)
  if not seq_range then 
    seq_range = xSelection.get_entire_sequence()
  end 
    
  local rslt = xAudioDeviceAutomation()
  rslt.device_path = rns_device.device_path
  rslt.range = seq_range

  -- include all automatable parameters 
  for k,param in ipairs(rns_device.parameters) do 
    if param.is_automatable then 
      table.insert(rslt.parameters,{
        name = param.name,
        index = k,
        automation = xParameterAutomation.copy(param,seq_range,track_idx,device_idx),
      })
    end
  end 

  return rslt

end  

---------------------------------------------------------------------------------------------------
-- cut automation from the specified device 
-- @param track_idx (number, track index 
-- @param device_idx (number), device index 
-- @param seq_range (xSelection "sequence"), restrict to range - use full range if undefined

function xAudioDevice.cut_automation(track_idx,device_idx,seq_range)

  -- TODO 

end  

---------------------------------------------------------------------------------------------------
-- swap all automated parameters in the specified devices 

function xAudioDevice.swap_automation(
  source_track_index,
  source_device_index,
  dest_track_index,
  dest_device_index,
  seq_range)

  -- TODO 

end  

---------------------------------------------------------------------------------------------------
-- @param device_auto (instance of xAudioDeviceAutomation)
-- @param track_idx (number)
-- @param device_idx (number)
-- @param apply_mode (xParameterAutomation.APPLY_MODE)
-- @param seq_range (xSelection "sequence"), restrict to range (optional)
-- @return boolean, false when failed 
-- @return string, error message when failed

function xAudioDevice.paste_automation(device_auto,track_idx,device_idx,apply_mode,seq_range)
  TRACE("xAudioDevice.paste_automation(device_auto,track_idx,device_idx,apply_mode,seq_range)",device_auto,track_idx,device_idx,apply_mode,seq_range)

  assert(type(device_auto)=="xAudioDeviceAutomation")

  local rns_track = rns.tracks[track_idx]
  assert(type(rns_track)=="Track")

  local rns_device = rns_track.devices[device_idx]
  assert(type(rns_device) == "AudioDevice")

  -- check for device compatibility
  if not device_auto:device_is_compatible(rns_device) then 
    local err_msg = "*** Incompatible device. Please target a device of this type: "
    return false, err_msg..device_auto.device_path
  end 

  -- retrieve our range from the source (where it was copied from)
  if not seq_range then 
    seq_range = device_auto.range
  end
  assert(type(seq_range)=="table")

  -- if not specified, set default apply_mode 
  if not apply_mode then 
    apply_mode = xParameterAutomation.APPLY_MODE.REPLACE
  end

  -- apply the individual parameters
  for k,auto_param in ipairs(device_auto.parameters) do 
    local dest_param = rns_device.parameters[auto_param.index]
    if (auto_param.automation) then 
      -- we have automation
      xParameterAutomation.paste(auto_param.automation,apply_mode,dest_param,seq_range,track_idx)
    elseif (apply_mode == xParameterAutomation.APPLY_MODE.REPLACE) then
      -- no automation, clear while in REPLACE mode
      xParameterAutomation.clear(dest_param,seq_range,track_idx)      
    end
  end 

  return true

end  

---------------------------------------------------------------------------------------------------
-- @param device (renoise.AudioDevice)
-- @param track_idx (number)
-- @param seq_range (xSelection "sequence range") range that should be cleared

function xAudioDevice.clear_automation(device,track_idx,seq_range)
  TRACE("xAudioDevice.clear_automation(device,track_idx,seq_range)",device,track_idx,seq_range)
  
  assert(type(device)=="AudioDevice")
  assert(type(track_idx)=="number")
  assert(type(seq_range)=="table")
  
  for k,param in ipairs(device.parameters) do
    if (param.is_automatable) then
      xParameterAutomation.clear(param,seq_range,track_idx)
    end
  end
  
end

