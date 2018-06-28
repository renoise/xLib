--[[===============================================================================================
xInstrument
===============================================================================================]]--

--[[--

Static methods for dealing with renoise.Instrument
.
#

--]]

class 'xInstrument'

---------------------------------------------------------------------------------------------------
-- Set the instrument to use the previous scale 
-- @param instr, renoise.Instrument

function xInstrument.set_previous_scale(instr)
  TRACE("xInstrument.set_previous_scale(instr)",instr)

  assert(type(instr)=="Instrument","Expected instr to be a renoise.Instrument")

  local scale_name = instr.trigger_options.scale_mode
  local scale_idx = xScale.get_scale_index_by_name(scale_name)
  if (scale_idx > 1) then
    xInstrument.set_scale_by_index(instr,scale_idx-1)
  end

end

---------------------------------------------------------------------------------------------------
-- Set the instrument to use the next scale 
-- @param instr, renoise.Instrument

function xInstrument.set_next_scale(instr)
  TRACE("xInstrument.set_next_scale(instr)",instr)

  assert(type(instr)=="Instrument","Expected instr to be a renoise.Instrument")

  local scale_name = instr.trigger_options.scale_mode
  local scale_idx = xScale.get_scale_index_by_name(scale_name)
  if (scale_idx < #xScale.SCALES) then
    xInstrument.set_scale_by_index(instr,scale_idx+1)
  end

end

---------------------------------------------------------------------------------------------------
-- Set the instrument to use the a specific scale 
-- @param instr, renoise.Instrument
-- @param scale_idx, number

function xInstrument.set_scale_by_index(instr,scale_idx)
  TRACE("xInstrument.set_scale_by_index(instr,scale_idx)",instr,scale_idx)

  assert(type(instr)=="Instrument","Expected instr to be a renoise.Instrument")
  assert(type(scale_idx)=="number","Expected scale_idx to be a number")

  local scale = xScale.SCALES[scale_idx]
  if scale then
    instr.trigger_options.scale_mode = scale.name
  end

end

---------------------------------------------------------------------------------------------------
-- [Static] Test whether the instrument contain sample slices
-- @param instr (renoise.Instrument)
-- @return bool

function xInstrument.is_sliced(instr)
  TRACE("xInstrument.is_sliced(instr)",instr)

  if (#instr.samples > 0) then
    return (instr.sample_mappings[1][1].read_only)
  end

end

---------------------------------------------------------------------------------------------------
-- [Static] Test whether the keyzone can be reached with the instrument
-- (running in program mode + sample columns)
-- @param instr (renoise.Instrument)
-- @return boolean

function xInstrument.is_keyzone_available(instr)
  TRACE("xInstrument.is_keyzone_available(instr)",instr)

  if (#instr.phrases == 0) then
    return true
  end

  local all_sample_cols = true
  for k,v in ipairs(instr.phrases) do
    if not v.instrument_column_visible then
      all_sample_cols = false
    end
  end
  if all_sample_cols then
    return false
  end
  return true

end

---------------------------------------------------------------------------------------------------
-- [Static] Test whether instrument seems to be triggering a phrase
-- @param instr (renoise.Instrument)
-- @return boolean

function xInstrument.is_triggering_phrase(instr)
  TRACE("xInstrument.is_triggering_phrase(instr)",instr)

  if (#instr.phrases == 0) then
    return false
  end

  if (instr.phrase_playback_mode == renoise.Instrument.PHRASES_OFF) then
    return false
  end

  if (instr.phrase_playback_mode == renoise.Instrument.PHRASES_PLAY_SELECTIVE) then
    return true
  end

  -- TODO check for keymapped phrases 
  -- for now, assume that we are triggering a phrase 
  return true

end

---------------------------------------------------------------------------------------------------
-- [Static] Figure out the phrase playback mode
-- @return boolean

function xInstrument.get_phrase_playback_enabled(instr)
  TRACE("xInstrument.get_phrase_playback_enabled(instr)",instr)

  --- implementation depends on API version
  if (renoise.API_VERSION > 4) then
    return not (instr.phrase_playback_mode == renoise.Instrument.PHRASES_OFF)
  else
    return instr.phrase_playback_enabled 
  end
end

---------------------------------------------------------------------------------------------------
-- [Static] Set the phrase playback mode
-- @return boolean

function xInstrument.set_phrase_playback_enabled(instr,bool)
  TRACE("xInstrument.set_phrase_playback_enabled(instr,bool)",instr,bool)

  if (renoise.API_VERSION > 4) then
    -- this is a v4 method, so we assume Keymap trigger mode 
    local enum = bool and renoise.Instrument.PHRASES_PLAY_KEYMAP
      or renoise.Instrument.PHRASES_OFF
    instr.phrase_playback_mode = enum
  else
    instr.phrase_playback_enabled = bool
  end
end

---------------------------------------------------------------------------------------------------
-- [Static] Detect if there is a slice marker *approximately* at the sample pos
-- @return boolean, [error message (string)]

function xInstrument.get_slice_marker_at_pos(instr,pos,threshold)
  TRACE("xInstrument.get_slice_marker_at_pos(instr,pos,threshold)",instr,pos,threshold)

  if not xInstrument.is_sliced(instr) then
    return false, "Instrument contains no slices"
  end

  local sample = instr.samples[1]
  local max = pos + threshold
  local min = pos - threshold

  for marker_idx = 1,#sample.slice_markers do
    local marker = sample.slice_markers[marker_idx]
    if (marker < max) and (marker > min) then
      return marker_idx
    end
  end

end


---------------------------------------------------------------------------------------------------
-- [Static] Return the slice markers associated with a given sample 
-- @param instr (renoise.Instrument)
-- @param sample_idx (number)
-- @return table<number>

function xInstrument.get_slice_marker_by_sample_idx(instr,sample_idx)
  TRACE("xInstrument.get_slice_marker_by_sample_idx(instr,sample_idx)",instr,sample_idx)

  assert(type(instr)=="Instrument","Expected renoise.Instrument as argument")
  assert(type(sample_idx)=="number","Expected number as argument")

  if instr.samples[1] then
    return instr.samples[1].slice_markers[sample_idx-1]
  end 

end

---------------------------------------------------------------------------------------------------
-- [Static] Perform a simple autocapture and return the instrument 
-- @return int (instrument index) or nil 

function xInstrument.autocapture()
  TRACE("xInstrument.autocapture()")

  rns:capture_nearest_instrument_from_pattern()
  return rns.selected_instrument_index

end

---------------------------------------------------------------------------------------------------
-- [Static] Locate the first empty instrument in instrument list
-- @return int or nil 

function xInstrument.get_first_available()
  TRACE("xInstrument.get_first_available()")

  for k,v in ipairs(rns.instruments) do
    if xInstrument.is_empty(v) and (v.name == "") then
      return k
    end
  end

end

---------------------------------------------------------------------------------------------------
-- [Static] this is a workaround for the missing 'selected_phrase_index' in instruments. 
-- Will temporarily select the indicated instrument and revert the selected once done. 
-- See also: 
-- http://forum.renoise.com/index.php/topic/26329-the-api-wishlist-thread/?p=221484
-- @return int or nil 

function xInstrument.get_selected_phrase_index(instr_idx)
  TRACE("xInstrument.get_selected_phrase_index(instr_idx)",instr_idx)

  local phrase_idx = nil
  if (#rns.instruments >= instr_idx) then 
    local cached_instr_idx = rns.selected_instrument_index
    rns.selected_instrument_index = instr_idx 
    phrase_idx = rns.selected_phrase_index 
    rns.selected_instrument_index = cached_instr_idx 
  end
  return phrase_idx
end  

---------------------------------------------------------------------------------------------------
-- [Static] Resolve the assigned track (midi input properties)
-- @param instr (renoise.Instrument)
-- @return number, track index

function xInstrument.resolve_midi_track(instr)
  TRACE("xInstrument.resolve_midi_track(instr)",instr)

  if (instr.midi_input_properties.assigned_track == 0) then
    return rns.selected_track_index
  else
    return instr.midi_input_properties.assigned_track
  end
end

---------------------------------------------------------------------------------------------------
-- [Static] Check if instrument contains any samples, modulation etc. 
-- @param instr (renoise.Instrument)
-- @return bool

function xInstrument.is_empty(instr)
  TRACE("xInstrument.is_empty(instr)",instr)

  local is_empty = true
  if (#instr.samples > 0)
    and (#instr.phrases > 0)
    and (#instr.sample_device_chains > 0)
    and (#instr.sample_modulation_sets > 0)
    and not instr.plugin_properties.plugin_loaded
  then
    is_empty = false
  end

  return is_empty

end

---------------------------------------------------------------------------------------------------
-- [Static] reset sample-based part of instrument 

function xInstrument.reset_sampler()

  -- TODO 
  error("Not implemented")
  
end

---------------------------------------------------------------------------------------------------
-- Insert/create sample - insert at sample_idx, or after selected one 
--  use the provided values to initialize the sample 
-- @param instr (renoise.Instrument)
-- @param sample_idx (number), source sample index 
-- @param sample_rate (xSampleBuffer.SAMPLE_RATE) [optional]
-- @param bit_depth (xSampleBuffer.BIT_DEPTH) [optional]
-- @param num_channels (number) [optional]
-- @param num_frames (number) [optional]
-- @return number (sample index) or nil

function xInstrument.insert_sample(
  instr,sample_idx,sample_rate,bit_depth,num_channels,num_frames)
  TRACE("xInstrument.insert_sample()",instr,sample_idx,sample_rate,bit_depth,num_channels,um_frames)

  assert(type(instr)=="Instrument")
  assert(type(sample_idx)=="number")

  local defaults = xSampleBuffer.get_default_properties()
  sample_rate = sample_rate or defaults.sample_rate
  bit_depth = bit_depth or defaults.bit_depth
  num_channels = num_channels or defaults.number_of_channels
  num_frames = num_frames or defaults.number_of_frames

  -- create sample 
  sample_idx = sample_idx or rns.selected_sample_index
  sample_idx = 1 + cLib.clamp_value(sample_idx,1,#instr.samples)
  instr:insert_sample_at(sample_idx)

  local sample = instr.samples[sample_idx]
  if not sample then 
    error("Expected a new sample")
  end 

  -- create buffer 
  local buffer = sample.sample_buffer
  buffer:create_sample_data(sample_rate,bit_depth,num_channels,num_frames)
  return sample_idx

end

---------------------------------------------------------------------------------------------------
-- Clone sample the provided sample, frame by frame
--  * inserts sample after the provided one if dest_sample_idx is not specified. 
--  * can convert: provide custom sample_rate/bit_depth/channels/frames
-- @param instr (renoise.Instrument)
-- @param sample_idx (number), source sample index 
-- @param dest_sample_idx (number), insert sample at this index [optional]
-- @param sample_rate (xSampleBuffer.SAMPLE_RATE)
-- @param bit_depth (xSampleBuffer.BIT_DEPTH)
-- @param num_channels (number)
-- @param num_frames (number)
-- @return (...) or nil
--  number (sample index) 
--  boolean (drumkit mode)

function xInstrument.clone_sample(
  instr,sample_idx,dest_sample_idx,
  sample_rate,bit_depth,num_channels,num_frames)
  TRACE("xInstrument.clone_sample()")
  -- num_frames,num_channel,

  assert(type(instr)=="Instrument")
  assert(type(sample_idx)=="number")

  local sample = instr.samples[sample_idx]
  if not sample then 
    error("Expected a sample")
  end 

  local buffer = xSample.get_sample_buffer(sample) 
  if not buffer then 
    error("Expected a sample-buffer containing data")
  end 
  sample_rate = sample_rate or buffer.sample_rate
  bit_depth = bit_depth or buffer.bit_depth
  num_channels = num_channels or buffer.number_of_channels
  num_frames = num_frames or buffer.number_of_frames

  -- create sample
  dest_sample_idx = dest_sample_idx and dest_sample_idx or sample_idx + 1
  instr:insert_sample_at(dest_sample_idx)
  local new_sample = instr.samples[dest_sample_idx]
  if not new_sample then 
    error("Expected a new sample")
  end 
  --print("new_sample",new_sample)

  -- detect if instrument is in drumkit mode
  -- (usually, a newly inserted sample occupies the entire keyzone...)
  local drumkit_mode = not xSampleMapping.has_full_note_range(new_sample.sample_mapping)
  --print("drumkit_mode",drumkit_mode)

  -- initialize some properties before copying...
  --new_sample.loop_start = 1
  --new_sample.loop_end = num_frames
  
  -- copy general properties 
  cReflection.copy_object_properties(sample,new_sample)

  -- maintain beat sync 
  -- local new_sync_val = sample.beat_sync_lines * (num_frames/buffer.number_of_frames) 
  -- if (sample.beat_sync_enabled == false or new_sync_val > 256) then
  --   new_sample.beat_sync_lines = sample.beat_sync_lines
  -- else
  --   new_sample.beat_sync_lines = new_sync_val
  -- end 

  local new_buffer = new_sample.sample_buffer
  new_buffer:create_sample_data(sample_rate,bit_depth,num_channels,num_frames)

  return dest_sample_idx,drumkit_mode

end
