--[[============================================================================
xSequencerSelection.lua
============================================================================]]--

--[[--

Static methods for working with pattern-sequence selections
.
#

### Sequence-selection 

  {
    start_line,     -- Start pattern line index (default = 1)
    start_sequence, -- Start sequence index 
    end_line,       -- End pattern line index (default = number_of_lines)
    end_pattern     -- End sequence index 
  }

]]

class 'xSequencerSelection'

-- args for shifting position (xSongPos)
local BOUNDS_MODE = xSongPos.OUT_OF_BOUNDS.CAP 
local LOOP_MODE = xSongPos.LOOP_BOUNDARY.NONE
local BLOCK_MODE = xSongPos.BLOCK_BOUNDARY.NONE


---------------------------------------------------------------------------------------------------
-- [Static] Retrieve the sequence selection 
-- @return table or nil if no selection is defined

function xSequencerSelection.get_selected_range()
  TRACE("xSequencerSelection.get_selected_range()")

  local seq_range = rns.sequencer.selection_range
  if (seq_range[1] == 0 and seq_range[2] == 0) then 
    return 
  else
    return {
      start_sequence = seq_range[1],
      start_line = 1,
      end_sequence = seq_range[2],
      end_line = xPatternSequencer.get_number_of_lines(seq_range[2])
    }
  end


end

---------------------------------------------------------------------------------------------------
-- Retrieve the length (#indices) spanned by the selection 
-- @return number (0 if no selection)

function xSequencerSelection.get_selected_range_length()
  TRACE("xSequencerSelection.get_selected_range_length()")
  local range = rns.sequencer.selection_range
  return range[2] - range[1]
end


---------------------------------------------------------------------------------------------------
-- [Static] Retrieve a sequence selection representing the entire song
-- @return table

function xSequencerSelection.get_entire_range()
  TRACE("xSequencerSelection.get_entire_range()")

  local last_seq_index = #rns.sequencer.pattern_sequence
  return {
    start_sequence = 1,
    start_line = 1,
    end_sequence = last_seq_index,
    end_line = xPatternSequencer.get_number_of_lines(last_seq_index)
  }

end

---------------------------------------------------------------------------------------------------
-- [Static] Get a sequence selection representing the selected pattern
-- @return table

function xSequencerSelection.get_selected_index()
  TRACE("xSequencerSelection.get_selected_index()")

  local seq_index = rns.selected_sequence_index
  return {
    start_sequence = seq_index,
    start_line = 1,
    end_sequence = seq_index,
    end_line = xPatternSequencer.get_number_of_lines(seq_index)
  }

end

---------------------------------------------------------------------------------------------------
-- [Static] Get a represention of the selected part of the current pattern
-- @return table or nil if no selection exists

function xSequencerSelection.get_pattern_selection()
  TRACE("xSequencerSelection.get_pattern_selection()")

  if not rns.selection_in_pattern then 
    return
  else
    local seq_index = rns.selected_sequence_index
    return {
      start_sequence = seq_index,
      start_line = rns.selection_in_pattern.start_line,
      end_sequence = seq_index,
      end_line = rns.selection_in_pattern.end_line,
    }
  end

end

---------------------------------------------------------------------------------------------------
-- check if song-position is within a sequence range
-- @param seq_range (xSequenceSelection)
-- @param songpos (renoise.SongPos, or songpos-alike table)
-- @return bool

function xSequencerSelection.is_within_range(seq_range,songpos)
  TRACE("xSequencerSelection.is_within_range(seq_range,songpos)",seq_range,songpos)

  assert(type(seq_range)=="table")
  
  if (seq_range.start_sequence < songpos.sequence) 
    and (seq_range.end_sequence > songpos.sequence) 
  then 
    return false 
  else
    if (seq_range.start_sequence == songpos.sequence) 
      and (seq_range.start_line > songpos.line)  
    then
      return false 
    end
    if (seq_range.end_sequence == songpos.sequence)  
    and (seq_range.end_line < songpos.line) 
    then 
      return false
    end 
  end
  return true

end

---------------------------------------------------------------------------------------------------
-- retrieve the pattern-lines contained in a specific sequence-index 
-- @param seq_range (xSequenceSelection)
-- @param seq_idx (number)
-- @param patt_num_lines (number), optional (if undefined, derived from seq_idx)
-- @return from_line (number), to_line (number) or nil if outside range 

function xSequencerSelection.pluck_from_range(seq_range,seq_idx,patt_num_lines)
  TRACE("xSequencerSelection.pluck_from_range(seq_range,seq_idx,patt_num_lines)",seq_range,seq_idx,patt_num_lines)

  assert(type(seq_range)=="table")
  assert(type(seq_idx)=="number")

  if not patt_num_lines then 
    local patt,patt_idx = xPatternSequencer.get_pattern_at_index(seq_idx)
    patt_num_lines = patt.number_of_lines
  end 

  if (seq_idx >= seq_range.start_sequence) and (seq_idx <= seq_range.end_sequence) then 
    -- pattern is within range 
    local at_start_seq = (seq_range.start_sequence == seq_idx)
    local at_end_seq = (seq_range.end_sequence == seq_idx)
    if not at_start_seq and not at_end_seq then 
      return 1,patt_num_lines
    else
      local from_line = at_start_seq and seq_range.start_line or 1
      local to_line = at_end_seq and seq_range.end_line or patt_num_lines
      return from_line,to_line
    end
  end

end

---------------------------------------------------------------------------------------------------
-- look up song to determine the total number of lines in the range
-- @return number  

function xSequencerSelection.get_number_of_lines(seq_range)
  TRACE("xSequencerSelection.get_number_of_lines(seq_range)",seq_range)

  assert(type(seq_range)=="table")

  local num_lines = 0
  for seq_idx = seq_range.start_sequence,seq_range.end_sequence do 
    local patt,patt_idx = xPatternSequencer.get_pattern_at_index(seq_idx)
    assert(patt,"Expected a pattern here")
    num_lines = num_lines + patt.number_of_lines
    if (seq_idx == seq_range.start_sequence) then 
      num_lines = num_lines - (seq_range.start_line-1)
    end
    if (seq_idx == seq_range.end_sequence) then
      num_lines = num_lines - (patt.number_of_lines-seq_range.end_line)
    end
  end
  return num_lines

end

---------------------------------------------------------------------------------------------------
-- shift sequence indices by specified amount, confined to boundaries
-- (modifies the seq_range in-place)

function xSequencerSelection.shift_by_indices(seq_range,offset)
  TRACE("xSequencerSelection.shift_by_indices(seq_range,offset)",seq_range,offset)

  if (offset > 0) then 
    -- forward, check if at boundary 
    local last_seq_index = #rns.sequencer.pattern_sequence
    if ((seq_range.end_sequence + offset) > last_seq_index) then 
      return seq_range
    end
  else
    if ((seq_range.start_sequence + offset) < 1) then 
      return seq_range
    end
  end
  seq_range.end_sequence = seq_range.end_sequence + offset
  seq_range.start_sequence = seq_range.start_sequence + offset

end

---------------------------------------------------------------------------------------------------
-- shift range forward by it's own size 

function xSequencerSelection.shift_forward(seq_range)
  TRACE("xSequencerSelection.shift_forward(seq_range)",seq_range)

  assert(type(seq_range)=="table")

  local range_num_lines = xSequencerSelection.get_number_of_lines(seq_range)

  local start_pos = {sequence = seq_range.start_sequence, line = seq_range.start_line}
  local end_pos =   {sequence = seq_range.end_sequence,   line = seq_range.end_line}

  xSongPos.increase_by_lines(range_num_lines,start_pos,BOUNDS_MODE,LOOP_MODE,BLOCK_MODE)
  xSongPos.increase_by_lines(range_num_lines,end_pos,BOUNDS_MODE,LOOP_MODE,BLOCK_MODE)

  return {
    start_sequence = start_pos.sequence,
    start_line = start_pos.line,
    end_sequence = end_pos.sequence,
    end_line = end_pos.line,
  }

end

---------------------------------------------------------------------------------------------------
-- shift range backward by it's own size 

function xSequencerSelection.shift_backward(seq_range)
  TRACE("xSequencerSelection.shift_backward(seq_range)",seq_range)

  assert(type(seq_range)=="table")

  local range_num_lines = xSequencerSelection.get_number_of_lines(seq_range)

  local start_pos = {sequence = seq_range.start_sequence,line = seq_range.start_line}
  local end_pos =   {sequence = seq_range.end_sequence,line = seq_range.end_line}

  xSongPos.decrease_by_lines(range_num_lines,start_pos,BOUNDS_MODE,LOOP_MODE,BLOCK_MODE)
  xSongPos.decrease_by_lines(range_num_lines,end_pos,BOUNDS_MODE,LOOP_MODE,BLOCK_MODE)

  return {
    start_sequence = start_pos.sequence,
    start_line = start_pos.line,
    end_sequence = end_pos.sequence,
    end_line = end_pos.line,
  }

end

---------------------------------------------------------------------------------------------------
-- apply the range to the currently selected pattern

function xSequencerSelection.apply_to_pattern(seq_range)

  local seq_idx = rns.selected_sequence_index
  local from_line,to_line = xSequencerSelection.pluck_from_range(seq_range,seq_idx)
  rns.selection_in_pattern = { 
    start_track = rns.selection_in_pattern.start_track,
    start_column = rns.selection_in_pattern.start_column,
    start_line = from_line, 
    end_track = rns.selection_in_pattern.end_track,
    end_column = rns.selection_in_pattern.end_column,
    end_line = to_line,
  } 

end