--[[============================================================================
xNoteCapture
============================================================================]]
--
--[[--

Methods for capturing notes in pattern editor
.
#

]]



cLib.require(_xlibroot.."xPatternSequencer")

class 'xNoteCapture'


-------------------------------------------------------------------------------
-- [Static] Capture the note at the current position, or previous
-- if no previous is found, find the next one
-- @param compare_fn (function)
-- @param notepos (xCursorPos)
-- @param args (table) optional arguments
--  .ignore_previous (boolean) don't look back 
--  .ignore_next (boolean) don't look forward
-- @return xCursorPos or nil if not matched
-- @return number (lines travelled) or nil

function xNoteCapture.nearest(compare_fn,notepos,args)
  TRACE("xNoteCapture.nearest(notepos,compare_fn,args)",notepos,compare_fn,args)
  
  assert(type(compare_fn)=="function")
  
  if not notepos then
    notepos = xCursorPos()
  end
  
  if not args then 
    args = {}
  end
  
  local column, err = notepos:get_column()
  if column and (column.instrument_value < 255) then
    -- FIXME should compare! 
    return notepos,0
  else
    local prev_pos,lines_travelled = nil,nil
    if not args.ignore_previous then 
      prev_pos,lines_travelled = xNoteCapture.previous(compare_fn,notepos)
    end
    if prev_pos then
      return prev_pos,lines_travelled
    elseif not args.ignore_next then 
      return xNoteCapture.next(compare_fn,notepos)
    end
  end
end

---------------------------------------------------------------------------------------------------
-- [Static] Capture the previous note, starting from (but not including) pos
-- @param compare_fn (function)
-- @param notepos (xCursorPos)
-- @param end_seq_idx (int)[optional], stop searching at this sequence index
-- @return xCursorPos or nil 
-- @return number (lines travelled) or nil 

function xNoteCapture.previous(compare_fn, notepos, end_seq_idx)
  TRACE("xNoteCapture.previous(compare_fn,notepos,end_seq_idx)", compare_fn, notepos, end_seq_idx)
  
  assert(type(compare_fn)=="function")

  if not notepos then 
    notepos = xCursorPos()
  end
    
  local tmp_pos = xCursorPos(notepos)
  
  local matched = false
  local lines_travelled = 0
  local min_seq_idx = end_seq_idx or 1
  tmp_pos.line = tmp_pos.line - 1
  
  while not matched do
    local match = nil
    if (tmp_pos.line > 0) then
      match = xNoteCapture.search_track(tmp_pos, compare_fn,true)
    end
    if match then
      return match, lines_travelled + notepos.line - 1
    else
      tmp_pos.sequence = tmp_pos.sequence - 1
      if (tmp_pos.sequence < min_seq_idx) then
        return 
      end      
      local num_lines = xPatternSequencer.get_number_of_lines(tmp_pos.sequence)      
      if num_lines then
        tmp_pos.line = num_lines
        lines_travelled = lines_travelled + num_lines        
      else
        return 
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- [Static] Capture the next note, starting from (but not including) pos
-- @param compare_fn (function)
-- @param notepos (xCursorPos)
-- @param end_seq_idx (int)[optional], stop searching at this sequence index
-- @return xCursorPos or nil 
-- @return number (lines travelled) or nil

function xNoteCapture.next(compare_fn, notepos, end_seq_idx)
  TRACE("xNoteCapture.next(compare_fn,notepos,end_seq_idx)", compare_fn, notepos, end_seq_idx)
  
  assert(type(compare_fn)=="function")

  if not notepos then 
    notepos = xCursorPos()
  end
      
  local tmp_pos = xCursorPos(notepos)
  
  local matched = false
  local lines_travelled = 0
  local max_seq_idx = end_seq_idx or #rns.sequencer.pattern_sequence
  tmp_pos.line = tmp_pos.line + 1
  
  while not matched do
    local match = xNoteCapture.search_track(tmp_pos, compare_fn)
    if match then
      return match, lines_travelled + (match.line - notepos.line)
    else
      tmp_pos.sequence = tmp_pos.sequence + 1
      if (tmp_pos.sequence > max_seq_idx) then
        return 
      end      
      local num_lines,patt_idx,patt = xPatternSequencer.get_number_of_lines(tmp_pos.sequence)
      if patt then
        tmp_pos.line = 1
        lines_travelled = lines_travelled + num_lines       
      else
        return 
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- [Static] Iterate from notepos to end of pattern, or when reversed, notepos to patt.start 
-- @param notepos (xCursorPos)
-- @param compare_fn (function)
-- @param reverse (boolean) reverse iteration
-- @return xCursorPos or nil if not matched

function xNoteCapture.search_track(notepos, compare_fn, reverse)
  TRACE("xNoteCapture.search_track(notepos,compare_fn)", notepos, compare_fn)
  
  assert(type(compare_fn)=="function")
  
  local patt = xPatternSequencer.get_pattern_at_index(notepos.sequence)
  local patt_trk = patt.tracks[notepos.track]
  
  if (patt_trk.is_empty) then
    return 
  end
  
  local num_lines = patt.number_of_lines
  local from,to,step = nil
  if (reverse) then
    if (1 > num_lines) then
      return 
    end  
    local count = notepos.line
    local lines = patt_trk:lines_in_range(1, notepos.line)
    for line_idx = notepos.line, 1,-1 do
      local pos = xNoteCapture.compare_line(lines,count,line_idx,notepos,compare_fn)
      if (pos) then
        return pos
      end
      count = count - 1
    end

  else
    if (notepos.line > num_lines) then
      return
    end
    local count = 1
    local lines = patt_trk:lines_in_range(notepos.line, num_lines)
    for line_idx = notepos.line, num_lines do
      local pos = xNoteCapture.compare_line(lines,count,line_idx,notepos,compare_fn)
      if (pos) then
        return pos
      end
      count = count + 1
    end
  end

end

---------------------------------------------------------------------------------------------------
-- [Static] Invoke the callback method to compare a given line 
-- @param lines (table<renoise.PatternLine>)
-- @param count (number)
-- @param line_idx (number)
-- @param notepos (xCursorPos)
-- @param compare_fn (function)
-- @return xCursorPos or nil if not matched

function xNoteCapture.compare_line(lines,count,line_idx,notepos,compare_fn)
  TRACE("xNoteCapture.compare_line(lines,count,line_idx,notepos,compare_fn)",count,line_idx,notepos,compare_fn)

  local line = lines[count]
  if line then
    local notecol = line.note_columns[notepos.column]
    if (notecol and compare_fn(notecol)) then
      notepos = xCursorPos(notepos)
      notepos.line = line_idx
      return notepos
    end
  end  

end
