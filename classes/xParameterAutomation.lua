--[[===============================================================================================
xLib
===============================================================================================]]--

--[[--

Create an instance to store automation data from a parameter 
(think of it like a clipboard for automation data)

Unlike in the Renoise API, automation "points" specifies a continous sequence of values 
which can go beyond the usual 512 line limit in a pattern. This one instead adds them 
together in a single stream, making it possible to apply the values to a different offset
in the timeline. 


]]

--=================================================================================================

class 'xParameterAutomation'

-- the various modes for pasting automation data 
xParameterAutomation.APPLY_MODE = {
  REPLACE = 1,    -- clear range before pasting (the default)
  MIX_PASTE = 2,  -- paste without clearing
}

---------------------------------------------------------------------------------------------------

function xParameterAutomation:__init()
  TRACE("xParameterAutomation:__init()")

  -- describes the source range - see "sequencer selection" in xSelection
  self.seq_range = {}

  -- the point values - array of {time, value, playmode} tables
  self.points = {}


end  

---------------------------------------------------------------------------------------------------

function xParameterAutomation:__tostring()
  return type(self)
    .. ":seq_range=" .. tostring(self.seq_range)
    .. ",points=" .. tostring(self.points)
end

---------------------------------------------------------------------------------------------------
-- copy automation, while clearing the existing data
-- @param param (renoise.DeviceParameter)
-- @param seq_range (xSelection "sequence range") restrict to this range (optional)
-- @param track_idx, where parameter is located (optional)
-- @param device_idx, where parameter is located (optional)
-- @return xParameterAutomation

function xParameterAutomation.cut(param,seq_range,track_idx,device_idx)

  local automation = xParameterAutomation._fetch(param,seq_range,track_idx,device_idx)



end  

---------------------------------------------------------------------------------------------------
-- internal function to retrieve automation 
-- @param param (renoise.DeviceParameter)
-- @param seq_range (xSelection "sequence range") restrict to this range (optional)
-- @param track_idx, where parameter is located (optional)
-- @param device_idx, where parameter is located (optional)
-- @return xParameterAutomation or nil if not automated 

function xParameterAutomation.copy(param,seq_range,track_idx,device_idx)
  TRACE("xParameterAutomation.copy(param,seq_range,track_idx,device_idx)",param,seq_range,track_idx,device_idx)

  assert(type(param) == "DeviceParameter")

  -- if no automation is present, return nil 
  if not param.is_automated then 
    return nil 
  end 

  local rslt = xParameterAutomation()

  -- if no range is defined, use full range (entire song)
  if not seq_range then 
    seq_range = xSelection.get_entire_sequence()
  end 
  
  -- if no track/device_idx are defined, resolve from the parameter 
  local param_idx = nil
  if (not device_idx or not track_idx) then 
    param_idx,device_idx,track_idx = xAudioDevice.resolve_parameter(param)
  end 

  assert(type(device_idx) == "number")
  assert(type(track_idx) == "number")  

  local src_track = rns.tracks[track_idx]
  local src_device = src_track.devices[device_idx]
  
  -- increase each time we cross a pattern boundary
  local line_offset = 0

  -- loop through sequence 
  for seq_idx = seq_range.start_sequence,seq_range.end_sequence do

    local patt,patt_idx = xPatternSequencer.get_pattern_at_index(seq_idx)
    local ptrack = patt.tracks[track_idx]
    
    local trk_automation = ptrack:find_automation(param)
    if trk_automation then 
      for k,v in ipairs(trk_automation.points) do
        table.insert(rslt.points,{
          playmode = trk_automation.playmode,
          time = v.time + line_offset,
          value = v.value,
        })
      end
    end
    
    line_offset = line_offset + patt.number_of_lines

  end


  return rslt 

end 

---------------------------------------------------------------------------------------------------
-- swap the specified parameters 

function xParameterAutomation.swap(
  source_param,
  source_track_index,
  source_device_index,
  dest_param,
  dest_track_index,
  dest_device_index,
  seq_range)

  --  TODO

end 

---------------------------------------------------------------------------------------------------
-- apply an instance of xParameterAutomation to a parameter
-- @param auto (instance of xParameterAutomation), create via copy() or cut()
-- @param mode (xParameterAutomation.APPLY_MODE), optional
-- @param param (renoise.DeviceParameter)
-- @param seq_range (xSelection "sequence range") restrict to this range (optional)
-- @param track_idx (number), optional

function xParameterAutomation.paste(auto,mode,param,seq_range,track_idx)
  TRACE("xParameterAutomation.paste(auto,mode,param,seq_range,track_idx)",auto,mode,param,seq_range,track_idx)

  assert(type(auto)=="xParameterAutomation")
  assert(type(param)=="DeviceParameter")

  -- use internal range? 
  if not seq_range then 
    seq_range = auto.seq_range
  end 
  assert(type(seq_range)=="table")

  -- use replace mode if not defined 
  if not mode then 
    mode = xParameterAutomation.APPLY_MODE.REPLACE
  end

  -- how many lines have we progressed? 
  local line_offset = 0

  -- keep track of the point index 
  local point_idx = 1

  -- loop through sequence 
  for seq_idx = seq_range.start_sequence,seq_range.end_sequence do

    local patt,patt_idx = xPatternSequencer.get_pattern_at_index(seq_idx)
    local ptrack = patt.tracks[track_idx]
    
    local trk_automation = ptrack:find_automation(param)
    -- create automation if not present 
    if not trk_automation then 
      trk_automation = ptrack:create_automation(param)
    else 
      -- clear automation in range if "mode" tells us to
      if (mode == xParameterAutomation.APPLY_MODE.REPLACE) then
        local from_line,to_line = 
          xSelection.get_lines_in_range(seq_range,seq_idx,patt.number_of_lines)
        print("clearing automation in range: seq_idx,from_line,to_line",seq_idx,from_line,to_line)
        trk_automation:clear_range(from_line,to_line)
      end
    end
    assert(type(trk_automation)=="PatternTrackAutomation")

    if (point_idx == #auto.points) then 
      -- no more automation data - 
      -- if mode is MIX_PASTE we have nothing more to do, 
      -- but REPLACE should be allowed to continue (clear existing automation)
      if (mode == xParameterAutomation.APPLY_MODE.MIX_PASTE) then 
        break
      end 
    else

      print(">>> iterate from",point_idx,"to",#auto.points)
      for k = point_idx, #auto.points do
        local point = auto.points[k]
        local point_time_in_patt = point.time-line_offset
        assert(point) -- remove once done
        --print(">>> point.time",point.time)
        --print(">>> line_offset",line_offset)
        if (patt.number_of_lines < point_time_in_patt) then 
          print("reached end of pattern, new point_idx: ",point_idx)
          point_idx = k
          break
        else
          -- write automation
          print("add_point_at: ",point_time_in_patt,point.value)
          trk_automation:add_point_at(point_time_in_patt,point.value)
        end 
        if (k == #auto.points) then 
          print("reached end of automation data",k)
          -- TODO "continous output", repeat from beginning          
          point_idx = k
          break
        end
      end
    end
    
    line_offset = line_offset + patt.number_of_lines

  end

end 

---------------------------------------------------------------------------------------------------
-- @param param (renoise.DeviceParameter)
-- @param seq_range (xSelection "sequence range") range that should be cleared
-- @param track_idx (number)

function xParameterAutomation.clear(param,seq_range,track_idx)
  TRACE("xParameterAutomation.clear(param,seq_range,track_idx)",param,seq_range,track_idx)
  
  assert(type(param)=="DeviceParameter")
  assert(type(seq_range)=="table")
  assert(type(track_idx)=="number")
  
  -- loop through sequence 
  for seq_idx = seq_range.start_sequence,seq_range.end_sequence do
    local patt,patt_idx = xPatternSequencer.get_pattern_at_index(seq_idx)
    local ptrack = patt.tracks[track_idx]
    local trk_automation = ptrack:find_automation(param)
    if trk_automation then 
      local from_line,to_line = xSelection.get_lines_in_range(
        seq_range,seq_idx,patt.number_of_lines)
      print(">>> about to clear automation in range: from_line,to_line",from_line,to_line)
      trk_automation:clear_range(from_line,to_line)
    end
  end
  
end

