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

xParameterAutomation.SCOPE = {
  WHOLE_SONG = 1,
  WHOLE_PATTERN = 2,
  SELECTION_IN_SEQUENCE = 3,
  SELECTION_IN_PATTERN = 4,
}

-- configure process slicing (avoid timeouts while processing)
xParameterAutomation.YIELD_AT = {
  NONE = 1,
  PATTERN = 2,
}

-- the various modes for pasting automation data 
xParameterAutomation.APPLY_MODE = {
  REPLACE = 1,    -- clear range before pasting (the default)
  MIX_PASTE = 2,  -- paste without clearing
}

-- the exact point.time where point line up at the boundary
xParameterAutomation.LINE_BOUNDARY = 0.99609375


--=================================================================================================
-- Class methods 
--=================================================================================================

function xParameterAutomation:__init()
  TRACE("xParameterAutomation:__init()")

  -- (xParameterAutomation.SCOPE) the scope used when capturing the automation
  -- (shared interface with xParameterAutomation)
  self.scope = nil

  -- the point values - array of {
  --  time,     -- point time 
  --  value,    -- point value
  --  playmode, -- interpolation type (renoise.PatternTrackAutomation.PLAYMODE_XX)
  --  } 
  self.points = {}

end  

---------------------------------------------------------------------------------------------------
-- check if the automation specifies any points 
-- (shared interface with xParameterAutomation)
-- @return boolean

function xParameterAutomation:has_points()
  TRACE("xParameterAutomation:has_points()")
  
  return (#self.points > 0) 

end 

---------------------------------------------------------------------------------------------------

function xParameterAutomation:__tostring()
  return type(self)
    --.. ":seq_range=" .. tostring(self.seq_range)
    .. ",points=" .. tostring(self.points)
end

--=================================================================================================
-- Static methods 
--=================================================================================================
-- copy automation, while clearing the existing data
-- @param param (renoise.DeviceParameter)
-- @param seq_range (xSequencerSelection) restrict to this range (optional)
-- @param track_idx, where parameter is located (optional)
-- @param device_idx, where parameter is located (optional)
-- @return xParameterAutomation

function xParameterAutomation.cut(param,seq_range,track_idx,device_idx)

  local automation = xParameterAutomation._fetch(param,seq_range,track_idx,device_idx)

  -- TODO


end  

---------------------------------------------------------------------------------------------------
-- internal function to retrieve automation 
-- @param param (renoise.DeviceParameter)
-- @param seq_range (xSequencerSelection) source range 
-- @param track_idx, where parameter is located
-- @param device_idx, where parameter is located
-- @param scope (xParameterAutomation.SCOPE)
-- @param yield_at (xParameterAutomation.YIELD_AT), for sliced processing
-- @return xParameterAutomation or nil if not automated 

function xParameterAutomation.copy(param,seq_range,track_idx,device_idx,scope,yield_at)
  TRACE("xParameterAutomation.copy(param,seq_range,track_idx,device_idx,scope,yield_at)",param,seq_range,track_idx,device_idx,scope,yield_at)

  assert(type(param) == "DeviceParameter")
  assert(type(seq_range) == "table")
  assert(type(track_idx) == "number")  
  assert(type(device_idx) == "number")
  assert(type(scope) == "number")

  -- ?? (AutoMate related) why does "is_automated" not work in headless mode 
  if not param.is_automatable then 
    return nil 
  end 
  
  local rslt = xParameterAutomation()
  rslt.scope = scope

  local src_track = rns.tracks[track_idx]
  local src_device = src_track.devices[device_idx]
  
  -- increase each time we cross a pattern boundary
  local line_offset = 0

  -- loop through sequence 
  for seq_idx = seq_range.start_sequence,seq_range.end_sequence do
    local is_first_seq = (seq_idx == seq_range.start_sequence)
    local is_last_seq = (seq_idx == seq_range.end_sequence)    
    local patt,patt_idx = xPatternSequencer.get_pattern_at_index(seq_idx)
    local ptrack = patt.tracks[track_idx]
    local trk_auto = ptrack:find_automation(param)
    if trk_auto then
      for _,point in ipairs(trk_auto.points) do
        local point_time_in_patt = point.time-line_offset
        --print("xParameterAutomation.copy - point_time_in_patt",point_time_in_patt,point.time)
        if is_last_seq and (seq_range.end_line < math.floor(point_time_in_patt)) then
          break
        elseif is_first_seq and (seq_range.start_line > math.floor(point_time_in_patt)) then
          -- not yet begun
        else
          --print("xParameterAutomation.copy - captured point at",point_time_in_patt,point.value)
          table.insert(rslt.points,{
            playmode = trk_auto.playmode,
            time = point.time+line_offset-(seq_range.start_line-1),
            value = point.value,
          })
        end
      end
    end
    line_offset = line_offset + patt.number_of_lines

    if (yield_at == xParameterAutomation.YIELD_AT.PATTERN) then 
      coroutine.yield()
    end

  end

  --print("xParameterAutomation.copy - points...",rprint(rslt.points))
  return rslt 

end 

---------------------------------------------------------------------------------------------------
-- @param track_idx (number)
-- @param param (renoise.DeviceParameter)
-- @param seq_range (xSequencerSelection) range that should be cleared
-- @return boolean

function xParameterAutomation.clear(track_idx,param,seq_range)
  TRACE("xParameterAutomation.clear(track_idx,param,seq_range)",track_idx,param,seq_range)
  
  assert(type(track_idx)=="number")
  assert(type(param)=="DeviceParameter")
  assert(type(seq_range)=="table")
  
  -- ?? (AutoMate related) why does "is_automated" not work in headless mode 
  if not param.is_automatable then 
    return nil 
  end 
  
  -- loop through sequence-range
  for seq_idx = seq_range.start_sequence,seq_range.end_sequence do
    local patt,patt_idx = xPatternSequencer.get_pattern_at_index(seq_idx)
    local ptrack = patt.tracks[track_idx]
    local trk_auto = ptrack:find_automation(param)
    if trk_auto then 
      xParameterAutomation._clear_impl(trk_auto,seq_range,seq_idx,patt.number_of_lines)
    end
  end

  return true
  
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
-- @param apply_mode (xParameterAutomation.APPLY_MODE)
-- @param param (renoise.DeviceParameter)
-- @param seq_range (xSequencerSelection) restrict to this range
-- @param track_idx (number)
-- @param yield_at (xParameterAutomation.YIELD_AT), for sliced processing
-- @return boolean

function xParameterAutomation.paste(auto,apply_mode,param,seq_range,track_idx,yield_at)
  TRACE("xParameterAutomation.paste(auto,apply_mode,param,seq_range,track_idx,yield_at)",auto,apply_mode,param,seq_range,track_idx,yield_at)

  assert(type(auto)=="xParameterAutomation")
  assert(type(apply_mode)=="number")
  assert(type(param)=="DeviceParameter")
  assert(type(seq_range)=="table")
  assert(type(track_idx)=="number")

  -- how many lines have we progressed? 
  local line_offset = 0

  -- keep track of the point index 
  local point_idx = 1

  -- loop through sequence 
  for seq_idx = seq_range.start_sequence,seq_range.end_sequence do

    local is_first_seq = (seq_idx == seq_range.start_sequence)
    local is_last_seq = (seq_idx == seq_range.end_sequence)
    local patt,patt_idx = xPatternSequencer.get_pattern_at_index(seq_idx)
    local ptrack = patt.tracks[track_idx]
    
    -- find or create automation 
    local trk_auto = ptrack:find_automation(param)
    if trk_auto then 
      if (apply_mode == xParameterAutomation.APPLY_MODE.REPLACE) then
        xParameterAutomation._clear_impl(trk_auto,seq_range,seq_idx,patt.number_of_lines)
      end
    end
      
    for k = point_idx, #auto.points do
      
      local point = auto.points[k]
      local point_time_in_patt = point.time-line_offset+seq_range.start_line

      -- function to write a single automation point 
      -- * create automation as needed 
      -- * update playmode (interpolation type)
      local add_point = function()
        --print(">>> add_point_at: ",point_time_in_patt,point.value)
        if not trk_auto then
          trk_auto = ptrack:create_automation(param)
        end
        trk_auto:add_point_at(point_time_in_patt-1,point.value)
        trk_auto.playmode = point.playmode
      end

      if is_last_seq and (seq_range.end_line < math.floor(point_time_in_patt)) then
        --print(">>> reached end of range, point_idx: ",point_idx,"point_time_in_patt",point_time_in_patt)
        add_point()
        break          
      elseif is_first_seq and (seq_range.start_line > math.floor(point_time_in_patt)) then
        -- output has not yet begun...
      elseif (patt.number_of_lines+1 < math.floor(point_time_in_patt)) then 
        --print(">>> reached end of pattern, new point_idx: ",point_idx,"point_time_in_patt",point_time_in_patt)          
        point_idx = k
        break
      else
        add_point()
      end 
      if (k == #auto.points) then 
        --print(">>> reached end of automation data",k)
        -- TODO "continous output", repeat from beginning          
        point_idx = k
        break
      end
    end
    
    line_offset = line_offset + patt.number_of_lines

    if (yield_at == xParameterAutomation.YIELD_AT.PATTERN) then 
      coroutine.yield()
    end    

  end

  return true

end 

---------------------------------------------------------------------------------------------------
-- internal clear implementation

function xParameterAutomation._clear_impl(trk_auto,seq_range,seq_idx,patt_num_lines)

  local from_line,to_line = xSequencerSelection.pluck_from_range(seq_range,seq_idx,patt_num_lines)
  --print(">>> clear automation in range: seq_idx,from_line,to_line",seq_idx,from_line,to_line)
  
  if (from_line == 1 and to_line == patt_num_lines) then 
    -- prefer to just clear() when possible 
    trk_auto:clear()    
  else
    -- include points arriving in the "boundary line"
    local boundary_time = to_line+xParameterAutomation.LINE_BOUNDARY
    trk_auto:clear_range(from_line,boundary_time)
    if (trk_auto:has_point_at(boundary_time)) then 
      trk_auto:remove_point_at(boundary_time)
    end
  end

end

