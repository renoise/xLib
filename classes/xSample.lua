--[[===============================================================================================
xSample
===============================================================================================]]--

--[[--

Static methods for working with renoise.Sample objects
.
#

]]

--=================================================================================================

cLib.require(_xlibroot.."xNoteColumn")
cLib.require(_xlibroot.."xSampleBuffer")
cLib.require(_xlibroot.."xSampleBufferOperation")

class 'xSample'

--- SAMPLE_CONVERT: misc. channel operations
-- MONO_MIX: stereo -> mono mix (mix left and right)
-- MONO_LEFT: stereo -> mono (keep left)
-- MONO_RIGHT: stereo -> mono (keep right)
-- STEREO: mono -> stereo
-- SWAP: stereo (swap channels)
xSample.SAMPLE_CONVERT = {
  MONO_MIX = 1, -- TODO
  MONO_LEFT = 2,
  MONO_RIGHT = 3,
  STEREO = 4,
  SWAP = 5,
}

---------------------------------------------------------------------------------------------------
-- get sample name, as it appears in the sample-list (untitled samples included)
-- @param sample (renoise.Sample)
-- @return string

function xSample.get_display_name(sample,sample_idx)
  TRACE("xSample.get_display_name(sample,sample_idx)",sample,sample_idx)
  assert(type(sample)=="Sample")
  assert(type(sample_idx)=="number")
  return (sample.name == "") 
    and ("Sample %02X"):format(sample_idx-1) 
    or sample.name

end

---------------------------------------------------------------------------------------------------
-- set sample loop to entire range, optionally set loop mode (else OFF)
-- @param sample (renoise.Sample)
-- @param [loop_mode] (renoise.Sample.LOOP_MODE_X)

function xSample.set_loop_all(sample,loop_mode)
  TRACE("xSample.set_loop_all()",sample,loop_mode)
  assert(type(sample)=="Sample")
  local buffer = xSample.get_sample_buffer(sample)
  if buffer then 
    xSample.set_loop_pos(sample,1,buffer.number_of_frames)
    sample.loop_mode = loop_mode or renoise.Sample.LOOP_MODE_OFF
  end
end

---------------------------------------------------------------------------------------------------
-- true when loop spans the entire range 
-- @return boolean or nil when no buffer 

function xSample.is_fully_looped(sample)
  TRACE("xSample.is_fully_looped()",sample)
  assert(type(sample)=="Sample")
  local buffer = xSample.get_sample_buffer(sample)
  if buffer then 
    return (sample.loop_start == 1) and (sample.loop_end == buffer.number_of_frames)
  end
end

---------------------------------------------------------------------------------------------------
-- set sample loop - fit to range, allow end before start (flip)
-- @param sample (renoise.Sample)
-- @param start_pos (int)
-- @param end_pos (int)

function xSample.set_loop_pos(sample,start_pos,end_pos)
  TRACE("xSample.set_loop_pos(sample,start_pos,end_pos)",sample,start_pos,end_pos)

  local buffer = xSample.get_sample_buffer(sample)
  if not buffer then 
    return
  end 

  -- flip start/end if needed 
  local start_pos,end_pos = math.min(start_pos,end_pos),math.max(start_pos,end_pos)

  -- fit within buffer boundaries 
  start_pos = math.max(1,start_pos)
  end_pos = math.min(buffer.number_of_frames,end_pos)

  -- take care that we set the smallest position first
  -- (as we set start/end individually)
  if (start_pos > sample.loop_end) then
    sample.loop_end = end_pos
    sample.loop_start = start_pos
  else
    sample.loop_start = start_pos
    sample.loop_end = end_pos
  end

  --print("set_loop_pos - loop_start",sample.loop_start)
  --print("set_loop_pos - loop_end",sample.loop_end)

end

---------------------------------------------------------------------------------------------------
-- match sample loop with buffer selection 
-- @param sample (renoise.Sample)
-- @param [loop_mode] (renoise.Sample.LOOP_MODE_X)

function xSample.set_loop_to_selection(sample,loop_mode)
  TRACE("xSample:set_loop_to_selection(sample)",sample)
  local buffer = xSample.get_sample_buffer(sample) 
  if buffer then 
    xSample.set_loop_pos(sample,buffer.selection_start,buffer.selection_end)  
    if loop_mode then 
      sample.loop_mode = loop_mode
    end
  end 
end

---------------------------------------------------------------------------------------------------
-- clear loop (set to off, with full range)

function xSample.clear_loop(sample)
  TRACE("xSample.clear_loop(sample)",sample)
  local buffer = xSample.get_sample_buffer(sample) 
  if buffer then 
    xSample.set_loop_pos(sample,1,buffer.number_of_frames)  
    sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
  end 
end

---------------------------------------------------------------------------------------------------
-- obtain the sample buffer if defined and not empty 
-- @param sample (renoise.Sample)
-- @return renoise.SampleBuffer or nil 

function xSample.get_sample_buffer(sample) 
  --TRACE("xSample.get_sample_buffer(sample)",sample,sample.name,sample.sample_buffer)
  if sample.sample_buffer 
    and sample.sample_buffer.has_sample_data
  then
    return sample.sample_buffer
  end
end 

----------------------------------------------------------------------------------------------------
-- convert sample: change bit-depth, perform channel operations, crop etc.
-- @param instr_idx (int)
-- @param sample_idx (int)
-- @param bit_depth (xSampleBuffer.BIT_DEPTH)
-- @param channel_action (xSample.SAMPLE_CONVERT)
-- @param range (table) source start/end frames
-- @param callback (function) return resulting sample 

function xSample.convert_sample(instr_idx,sample_idx,bit_depth,channel_action,range)
  TRACE("xSample.convert_sample(instr_idx,sample_idx,bit_depth,channel_action)",instr_idx,sample_idx,bit_depth,channel_action)

  local instr = rns.instruments[instr_idx]
  assert(type(instr)=="Instrument")

  local sample = instr.samples[sample_idx]
  assert(type(sample)=="Sample")

  local buffer = sample.sample_buffer
  if not buffer.has_sample_data then
    return false
  end

  local num_channels = (channel_action == xSample.SAMPLE_CONVERT.STEREO) and 2 or 1
  local num_frames = (range) and (range.end_frame-range.start_frame+1) or buffer.number_of_frames
  --print(">>> num_frames,number_of_frames",num_frames,buffer.number_of_frames)

  -- only when copying single channel 
  local channel_idx = 1 
  if(channel_action == xSample.SAMPLE_CONVERT.MONO_RIGHT) then
    channel_idx = 2
  end
  
  -- change sample 

  local do_process = function(new_buffer)
    local f = nil
    local new_f_idx = 1
    local from_idx = range.start_frame
    local to_idx = range.start_frame+num_frames-1
    --new_buffer:prepare_sample_data_changes()
  
    for f_idx = from_idx,to_idx do
      if(channel_action == xSample.SAMPLE_CONVERT.MONO_MIX) then
        -- mix stereo to mono signal
        -- TODO 
      else
        -- copy from one channel to target channel(s)
        f = buffer:sample_data(channel_idx,f_idx)
        new_buffer:set_sample_data(1,new_f_idx,f)
        if (num_channels == 2) then
          f = buffer:sample_data(channel_idx,f_idx)
          new_buffer:set_sample_data(2,new_f_idx,f)
        end
      end
      new_f_idx = new_f_idx+1
    end
  end

  local bop = xSampleBufferOperation{
    instrument_index = instr_idx,
    sample_index = sample_idx,
    operations = {
      do_process
    },
    on_complete = function(_bop_)
      print(">>> on_complete",_bop_)
      --local buffer = _bop_.buffer 
      --local sample = _bop_.sample
      callback(_bop_.sample)
    end,
    on_error = function(err)
      TRACE("*** error message",err)
    end    
  }
  bop:run()

  --return new_sample

end

----------------------------------------------------------------------------------------------------
-- extract tokens from a sample name 
-- @param str, e.g. "VST: Synth1 VST (Honky Piano)_0x7F_C-5" 
-- @return table, {
--    sample_name = string ("Recorded sample 01"),
--    plugin_type = string ("VST" or "AU"),
--    plugin_name = string ("Synth1 VST"),
--    preset_name = string ("Honky Piano"),
--    velocity = string ("0x7F"),
--    note = string ("C-5")
--  }

function xSample.get_name_tokens(str)

  -- start by assuming it's a plugin
  local matches = str:gmatch("(.*): (.*) %((.*)%)[_%s]?([^_%s]*)[_%s]?([A-Z]*[-#]?[%d]*)")  
  local arg1,arg2,arg3,arg4,arg5 = matches()

  -- from end 
  local arg5_is_note = arg5 and xNoteColumn.note_string_to_value(arg5)
  local arg4_is_note = arg4 and xNoteColumn.note_string_to_value(arg4)
  local arg4_is_velocity = arg4 and tonumber(arg4)
  if arg5_is_note then
    return {
      plugin_type = arg1,
      plugin_name = arg2,
      preset_name = arg3,
      velocity = arg4,
      note = (arg5 ~= "") and arg5 or nil,
    }
  elseif arg4_is_velocity then
    return {
      plugin_type = arg1,
      plugin_name = arg2,
      preset_name = arg3,
      velocity = arg4
    }
  elseif arg4_is_note then
    return {
      plugin_type = arg1,
      plugin_name = arg2,
      preset_name = arg3,
      note = (arg4 ~= "") and arg4 or nil,
    }
  elseif arg3 then
    return {
      plugin_type = arg1,
      plugin_name = arg2,
      preset_name = arg3,
    }
  else
    -- does not seem to be a plugin
    local matches = str:gmatch("(.-)[_%s]?([^_%s]*)[_%s]?([A-Z]*[-#]?[%d]*)$") 
    local arg1,arg2,arg3 = matches()
    local arg3_is_note = arg3 and xNoteColumn.note_string_to_value(arg3)
    local arg2_is_note = arg2 and xNoteColumn.note_string_to_value(arg2)
    local arg2_is_velocity = arg2 and tonumber(arg2)
    if (arg1 == "") then
      return {
        sample_name = arg2,
      }
    elseif arg3_is_note then
      return {
        sample_name = arg1,
        velocity = arg2,
        note = (arg3 ~= "") and arg3 or nil,
      }
    elseif arg2_is_velocity then
      return {
        sample_name = arg1,
        velocity = arg2,
      }
    elseif arg2_is_note then
      return {
        sample_name = arg1,
        note = (arg2 ~= "") and arg2 or nil,
      }
    else 
      return {
        sample_name = arg1,
      }
    end
  end

  return {}

end

---------------------------------------------------------------------------------------------------
-- obtain the buffer frame from a particular position in the song
-- @param sample (renoise.Sample)
-- @param trigger_pos (xCursorPos), triggering position + note/pitch/delay/offset
-- @param end_pos (xCursorPos), the end position
-- @param [ignore_sxx] (boolean), handle special case with sliced instruments, where Sxx is 
--  used on the root sample for triggering individual slices 
-- @return table{
--  frame (number)
--  notecol (renoise.NoteColumn)
-- } or false,error (string) when failed

function xSample.get_buffer_frame_by_notepos(sample,trigger_pos,end_pos,ignore_sxx)
  TRACE("xSample.get_buffer_frame_by_notepos(sample,trigger_pos,end_pos,ignore_sxx)",sample,trigger_pos,end_pos,ignore_sxx)

  assert(type(sample)=="Sample")
  assert(type(trigger_pos)=="xCursorPos")
  assert(type(end_pos)=="xCursorPos")
  
  local patt_idx,patt,track,ptrack,line = trigger_pos:resolve()
  if not line then
    return false,"Could not resolve pattern-line"                    
  end

  local notecol = line.note_columns[trigger_pos.column]
  if not notecol then
    return false, "Could not resolve note-column"
  end

  -- get number of lines to the trigger note
  local line_diff = xSongPos.get_line_diff(trigger_pos,end_pos)

  -- precise position #1: subtract delay from triggering note
  if track.delay_column_visible then
    if (notecol.delay_value > 0) then
      line_diff = line_diff - (notecol.delay_value / 255)
    end
  end
  -- precise position #2: add fractional line 
  line_diff = line_diff + cLib.fraction(end_pos.line)

  local frame = xSampleBuffer.get_frame_by_line(sample.sample_buffer,line_diff)
  frame = xSample.get_transposed_frame(notecol.note_value,frame,sample)

  -- increase frame if the sample was triggered using Sxx command 
  if not ignore_sxx and sample.sample_buffer.has_sample_data then 
    local matched_sxx = xLinePattern.get_effect_command(track,line,"0S",trigger_pos.column,true)
    if not table.is_empty(matched_sxx) then 
      -- the last matched value is the one affecting playback 
      local total_frames = sample.sample_buffer.number_of_frames       
      local applied_sxx = matched_sxx[#matched_sxx].amount_value
      frame = frame + ((total_frames/256) * applied_sxx)
    end 
  end 


  return frame,notecol

end

---------------------------------------------------------------------------------------------------
-- transpose the number of frames 

function xSample.get_transposed_frame(note_value,frame,sample)
  TRACE("xSample.get_transposed_frame(note_value,frame,sample)",note_value,frame,sample)
  
  local transposed_note = xSample.get_transposed_note(note_value,sample)
  local transp_hz = cLib.note_to_hz(transposed_note)
  local base_hz = cLib.note_to_hz(48) -- middle C-4 note
  local ratio = base_hz / transp_hz
  frame = frame / ratio
  return frame

end

---------------------------------------------------------------------------------------------------
-- obtain the transposed note. Final pitch of the played sample is:
--   played_note - mapping.base_note + sample.transpose + sample.finetune 
-- @param played_note (number)
-- @param sample (Renoise.Sample)
-- @return number (natural number = pitch, fraction = finetune)

function xSample.get_transposed_note(played_note,sample)
  TRACE("xSample.get_transposed_note(played_note,sample)",played_note,sample)

  local mapping_note = sample.sample_mapping.base_note
  local sample_transpose = sample.transpose + (sample.fine_tune/128)
  return 48 + played_note - mapping_note + sample_transpose
end

---------------------------------------------------------------------------------------------------
-- obtain the note which is used when synced across a number of lines
-- (depends on sample length and playback speed)

function xSample.get_beatsynced_note(bpm,sample)
  TRACE("xSample.get_beatsynced_note(bpm,sample)",bpm,sample)
  
  local bpm = rns.transport.bpm
  local lpb = rns.transport.lpb
  return cLib.lines_to_note(sample.beat_sync_lines,bpm,lpb)

end

