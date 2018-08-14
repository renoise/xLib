--[[===============================================================================================
xSongPos
===============================================================================================]]--

--[[--

Static methods for working with renoise.SongPos (or alike).

##

Three options are designed to deal with song boundaries, pattern-loop and block-loop boundaries. 
By default, they are set to settings which mimic the behavior in Renoise when playing/manipulating 
the playback position. You can specify alternative settings either by supplying them as a 
secondary argument (the 'args' table), or by defining alternative values for xSongPos.DEFAULT_XX 

Note also that anything relating to beats and bars depend on the currently set transport options. 
If you want to override these values with your own ones, they can be supplied via the secondary
argument (`beats_per_bar` and `lines_per_beat`, respectively). 

Note: throughout, the class accepts not only an instance of `renoise.SongPos` as argument, 
but also "SongPos-alike" objects - tables that contain a line and sequence property. 

]]

--=================================================================================================

cLib.require(_xlibroot.."xPatternSequencer")
cLib.require(_xlibroot.."xBlockLoop")

---------------------------------------------------------------------------------------------------

class 'xSongPos'

--- How to deal with sequence (song) boundaries
-- CAP: do not exceed, cap at beginning/end
-- LOOP: going past the end will take us to the start, and vice versa
-- NULL: going past the end or start will return nil
-- ALLOW: allow out-of-bounds values (when outside bounds, will keep the sequence index 
--  but line index will be higher than pattern length, or set to a negative value)
xSongPos.OUT_OF_BOUNDS = {
  CAP = 1,
  LOOP = 2,
  NULL = 3,
  ALLOW = 4,
}

--- How to deal with loop boundaries
-- HARD: always stay within loop, no matter the position
-- SOFT: only stay within loop when playback takes us there
-- NONE: continue past loop boundary (ignore)
xSongPos.LOOP_BOUNDARY = {
  HARD = 1,
  SOFT = 2,
  NONE = 3,
}

--- How to deal with block-loop boundaries
-- HARD: always stay within loop, no matter the position
-- SOFT: only stay within loop when playback takes us there
-- NONE: continue past loop boundary (ignore)
xSongPos.BLOCK_BOUNDARY = {
  HARD = 1,
  SOFT = 2,
  NONE = 3,
}

--- Provide fallback values 
xSongPos.DEFAULT_BOUNDS_MODE = xSongPos.OUT_OF_BOUNDS.LOOP
xSongPos.DEFAULT_LOOP_MODE = xSongPos.LOOP_BOUNDARY.SOFT
xSongPos.DEFAULT_BLOCK_MODE = xSongPos.BLOCK_BOUNDARY.SOFT

--- If defined, these values are used when calculating beats and bars. 
-- When not, LINES_PER_BEAT will use `transport.lpb` while
-- BEATS_PER_BAR will use `transport.metronome_beats_per_bar`
xSongPos.BEATS_PER_BAR = nil
xSongPos.LINES_PER_BEAT = nil

---------------------------------------------------------------------------------------------------
-- [Static] Create a native SongPos object 
-- @param pos, renoise.SongPos or alike
-- @return renoise.SongPos 

function xSongPos.create(pos)
  TRACE("xSongPos.create(pos)",pos)
  local rslt = rns.transport.playback_pos
  rslt.sequence = pos.sequence
  rslt.line = pos.line
  return rslt
end

---------------------------------------------------------------------------------------------------
-- Convert a number (number of beats) into a SongPos 
-- @param beats (number)
-- @eturn renoise.SongPos or nil

function xSongPos.create_from_beats(beats,args)
  TRACE("xSongPos.create_from_beats(beats,args)",beats,args)

  assert(type(beats) == "number")
  
  args = xSongPos._init_args(args)
  
  local tmp_beats = 0
  for seq_idx = 1, #rns.sequencer.pattern_sequence do 
    local patt_num_lines = xPatternSequencer.get_number_of_lines(seq_idx)
    local patt_num_beats = patt_num_lines/args.lines_per_beat
    if (patt_num_beats+tmp_beats > beats) then 
      local line = (beats-tmp_beats)*args.lines_per_beat
      return {
        line = line+1,
        sequence = seq_idx,
      }
    end
    tmp_beats = tmp_beats + patt_num_beats
  end
  
end

---------------------------------------------------------------------------------------------------
-- Figure out the position in beats (identical to e.g. "edit_pos_beats")
-- @param beats (number)
-- @eturn renoise.SongPos or nil

function xSongPos.get_number_of_beats(pos,args)
  TRACE("xSongPos.get_number_of_beats(pos,args)",pos,args)

  args = xSongPos._init_args(args)
  
  local num_beats = (pos.line-1)/args.lines_per_beat
  for seq_idx = 2, pos.sequence do 
    local patt_num_lines = xPatternSequencer.get_number_of_lines(seq_idx-1)
    if not patt_num_lines then 
      break
    end
    num_beats = num_beats + patt_num_lines/args.lines_per_beat
  end
  
  return num_beats
  
end

---------------------------------------------------------------------------------------------------
-- For convenience, return default settings 

function xSongPos.get_defaults()
  TRACE("xSongPos.get_defaults()",xSongPos.BLOCK_BOUNDARY)
  return {
    bounds_mode = xSongPos.DEFAULT_BOUNDS_MODE,
    loop_boundary = xSongPos.DEFAULT_LOOP_MODE,
    block_boundary = xSongPos.DEFAULT_BLOCK_MODE,
    beats_per_bar = rns.transport.metronome_beats_per_bar,
    lines_per_beat = rns.transport.lpb,
    loop_sequence_range = rns.transport.loop_sequence_range
  }
end 

---------------------------------------------------------------------------------------------------
-- For convenience, apply default settings 

function xSongPos.set_defaults(val)
  TRACE("xSongPos.set_defaults(val)",val)
  xSongPos.DEFAULT_BOUNDS_MODE = val.bounds_mode
  xSongPos.DEFAULT_LOOP_MODE = val.loop_boundary
  xSongPos.DEFAULT_BLOCK_MODE = val.block_boundary
end 

---------------------------------------------------------------------------------------------------
-- Apply a position to the "transport.edit_pos"
-- NB: take care - the property might not be updated immediately 
-- @param pos: SongPos, or SongPos-alike object (e.g. xCursorPos)

function xSongPos.apply_to_edit_pos(pos)
  TRACE("xSongPos.apply_to_edit_pos(pos)",pos)
  
  local tmp_pos = rns.transport.edit_pos
  tmp_pos.sequence = pos.sequence
  tmp_pos.line = pos.line
  rns.transport.edit_pos = tmp_pos
  
end

---------------------------------------------------------------------------------------------------
-- [Class] Normalize the position, takes us from an 'imaginary' position to one 
-- that respect the actual pattern length/sequence plus loops
-- @return SongPos

function xSongPos.normalize(pos,args)
  TRACE("xSongPos.normalize(pos,args)",pos,args)

  local seq_idx = pos.sequence
  local line_idx = pos.line

  -- cap sequence if out-of-bounds ------------------------
  local seq_length = cLib.clamp_value(seq_idx,1,#rns.sequencer.pattern_sequence)

  -- check for pattern out-of-bounds ----------------------
  local patt_num_lines = xPatternSequencer.get_number_of_lines(seq_idx)
  if (line_idx < 1) then
    return xSongPos.decrease_by_lines(line_idx-patt_num_lines,pos,args)
  elseif (line_idx > patt_num_lines) then 
    local new_pos = {
      sequence = pos.sequence,
      line = patt_num_lines
    }
    return xSongPos.increase_by_lines(line_idx-patt_num_lines,new_pos,args)
  else 
    return xSongPos.create(pos)
  end

end

---------------------------------------------------------------------------------------------------
-- [Class] Increase position by X number of lines
-- @param num_lines (number)
-- @param pos (SongPos)
-- @param args, table (xSongPos-options - see description of class)
-- @return SongPos or nil 
-- @return number, lines travelled or nil

function xSongPos.increase_by_lines(num_lines,pos,args)
  TRACE("xSongPos.increase_by_lines(num_lines,pos,args)",num_lines,pos,args)

  assert(type(num_lines) == "number")
  
  if (num_lines == 0) then
    -- nothing to do
    return xSongPos.create(pos)
  end
  
  args = xSongPos._init_args(args)

  -- true when no further action is needed
  local done = false
  
  local seq_idx = pos.sequence
  local line_idx = pos.line

  -- even when we are supposedly spanning multiple 
  -- patterns, block looping might prevent this
  local exiting_blockloop = false
  if rns.transport.loop_block_enabled 
    and (args.block_boundary ~= xSongPos.BLOCK_BOUNDARY.NONE)
  then
    exiting_blockloop = xBlockLoop.exiting(seq_idx,line_idx,num_lines) or false
  end

  local patt_num_lines = xPatternSequencer.get_number_of_lines(seq_idx)
  if (line_idx+num_lines <= patt_num_lines) or exiting_blockloop then
    return {
      sequence = seq_idx,
      line = xSongPos.enforce_block_boundary({sequence=seq_idx,line=line_idx},num_lines,args.block_boundary)
    }
  else
    
    local lines_remaining = num_lines - (patt_num_lines - line_idx)
    while(lines_remaining > 0) do
      seq_idx = seq_idx + 1
      seq_idx,line_idx,done = xSongPos.enforce_boundary("increase",{sequence=seq_idx,line=lines_remaining},args)
      if done then
        if not seq_idx then 
          if (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.NULL) then 
            return
          else 
            error("*** not supposed to get here")
          end
        elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.CAP) then
          return {
            sequence = seq_idx,
            line = line_idx,
          }
        elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.ALLOW) then 
          --num_lines = num_lines - lines_remaining
          return {
            sequence = seq_idx,
            line = pos.line + lines_remaining
          }
        end
        break
      end

      patt_num_lines = xPatternSequencer.get_number_of_lines(seq_idx)
      lines_remaining = lines_remaining - patt_num_lines

      -- check if we have reached our goal
      if (lines_remaining < 0) then
        line_idx = lines_remaining + patt_num_lines
        break
      end

    end
    
    return {
      sequence = seq_idx,
      line = line_idx
    }

  end
  
  error("*** not supposed to get here")

end

---------------------------------------------------------------------------------------------------
-- [Class] Subtract a number of lines from position
-- @param num_lines, int
-- @param pos (SongPos)
-- @param args, table (xSongPos-options - see description of class)
-- @return SongPos or nil 
-- @return number, lines travelled or nil

function xSongPos.decrease_by_lines(num_lines,pos,args)
  TRACE("xSongPos.decrease_by_lines(num_lines,pos,args)",num_lines,pos,args)

  assert(type(num_lines) == "number")

  if (num_lines == 0) then
    -- nothing to do
    return xSongPos.create(pos)
  end
  
  args = xSongPos._init_args(args)

  -- true when no further action is needed
  local done = false

  local seq_idx = pos.sequence
  local line_idx = pos.line

  -- even when we are supposedly spanning multiple 
  -- patterns, block looping might prevent this
  local exiting_blockloop = 
    (args.block_boundary ~= xSongPos.BLOCK_BOUNDARY.NONE) and
      xBlockLoop.exiting(seq_idx,line_idx,-num_lines) or false

  if (pos.line-num_lines > 0) or exiting_blockloop then
    return {
      sequence = seq_idx,
      line = xSongPos.enforce_block_boundary({sequence=seq_idx,line=pos.line},-num_lines,args.block_boundary)
    }

  else
    local patt_num_lines = xPatternSequencer.get_number_of_lines(seq_idx)
    local lines_remaining = num_lines - line_idx

    -- make sure loop is evaluated at least once
    local first_run = true
    while first_run or (lines_remaining > 0) do

      first_run = false
      seq_idx = seq_idx - 1

      seq_idx,line_idx,done = 
        xSongPos.enforce_boundary("decrease",{sequence=seq_idx,line=lines_remaining},args)
      if done then
        if not seq_idx and (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.NULL) then 
          return
        elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.CAP) then
          return {
            sequence = seq_idx,
            line = line_idx,
          }
        elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.ALLOW) then
          --num_lines = num_lines - lines_remaining
          return {
            sequence = seq_idx,
            line = -lines_remaining,
          }
        end
        break
      end

      patt_num_lines = xPatternSequencer.get_number_of_lines(seq_idx)
      lines_remaining = lines_remaining - patt_num_lines

      -- check if we have reached our goal
      if (lines_remaining <= 0) then
        line_idx = -lines_remaining
        if (line_idx < 1) then
          -- zero is not a valid line index, normalize!!
          local new_pos = {sequence=seq_idx,line=line_idx}
          xSongPos.decrease_by_lines(1,new_pos,args)
          seq_idx = new_pos.sequence
          line_idx = new_pos.line
        end
        break
      end

    end
    
    return {
      sequence = seq_idx,
      line = line_idx
    }
  end
  
end

---------------------------------------------------------------------------------------------------
-- [Class] Set to the next beat position
-- @param pos (SongPos)
-- @param args, table (xSongPos-options - see description of class)
-- @return SongPos or nil
-- @return number, lines travelled or nil

function xSongPos.next_beat(pos,args)
  TRACE("xSongPos.next_beat(pos,args)",pos,args)

  args = xSongPos._init_args(args)

  local pos_beat = math.floor(xSongPos.get_number_of_beats(pos)) + 1
  local new_pos = xSongPos.create_from_beats(pos_beat)
  if new_pos then 
    local line_diff = xSongPos.get_line_diff(pos,new_pos)
    return xSongPos.increase_by_lines(line_diff,pos,args),line_diff
  else 
    -- handle out of bounds 
    if (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.LOOP) then 
      -- set to first bar 
      local line_diff = xSongPos.get_line_diff(pos,{line = 1,sequence = 1})
      return xSongPos.decrease_by_lines(line_diff,pos,args),line_diff
    elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.CAP) then 
      -- TODO 
    elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.ALLOW) then 
      -- TODO 
    elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.NULL) then 
      return   
    end
    
  end
  
end

---------------------------------------------------------------------------------------------------
-- [Class] Set to the previous beat position
-- @param pos (SongPos)
-- @param args, table (xSongPos-options - see description of class)
-- @return number, lines travelled

function xSongPos.previous_beat(pos,args)
  TRACE("xSongPos.previous_beat(pos,args)",pos,args)

  args = xSongPos._init_args(args)

  -- bars are based on position in beats
  local pos_beat = xSongPos.get_number_of_beats(pos)
  local new_pos_beat = nil
  if (cLib.fraction(pos_beat) == 0) then
    new_pos_beat = pos_beat - 1 
  else
    new_pos_beat = math.floor(pos_beat)
  end
  local new_pos = xSongPos.create_from_beats(new_pos_beat)
  if (new_pos_beat >= 0) then 
    local line_diff = xSongPos.get_line_diff(pos,new_pos)
    return xSongPos.decrease_by_lines(line_diff,pos,args),line_diff
  else 
    -- handle out of bounds 
    if (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.LOOP) then 
      -- set to last beat in last pattern 
      local last_seq_idx = #rns.sequencer.pattern_sequence
      local patt_num_lines = xPatternSequencer.get_number_of_lines(last_seq_idx)
      local new_pos = {
        sequence = last_seq_idx,
        line = patt_num_lines,
      }
      return xSongPos.previous_beat(new_pos,args)
    elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.CAP) then 
      local new_pos = {sequence = 1,line = 1}
      local line_diff = xSongPos.get_line_diff(pos,new_pos)
      return new_pos,line_diff
    elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.ALLOW) then 
      local line_diff = xSongPos.get_line_diff(pos,new_pos)
      return new_pos,line_diff
    elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.NULL) then 
      return   
    end    
  end

end

---------------------------------------------------------------------------------------------------
-- [Class] Set to the next bar position
-- NB: bars are based on position in beats and use metronome_beats_per_bar as basis
-- @param pos (SongPos)
-- @param args, table (xSongPos-options - see description of class)
-- @return xSongPos or nil
-- @return number, lines travelled or nil

function xSongPos.next_bar(pos,args)
  TRACE("xSongPos.next_bar(pos,args)",pos,args)

  args = xSongPos._init_args(args)

  local pos_bar = math.floor(xSongPos.get_number_of_beats(pos)/args.beats_per_bar) + 1
  local new_pos = xSongPos.create_from_beats(pos_bar*args.beats_per_bar)
  if new_pos then 
    local line_diff = xSongPos.get_line_diff(pos,new_pos)
    return xSongPos.increase_by_lines(line_diff,pos,args),line_diff
  else
    -- handle out of bounds 
    if (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.LOOP) then 
      local last_pos = xSongPos.get_last_line_in_song()
      local line_diff = 1 + xSongPos.get_line_diff(pos,last_pos)
      return {line = 1,sequence = 1}, line_diff
    elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.CAP) then 
      local last_pos = xSongPos.get_last_line_in_song()
      local line_diff = xSongPos.get_line_diff(pos,last_pos)
      return last_pos,line_diff
    elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.ALLOW) then 
      -- TODO 
    elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.NULL) then 
      return   
    end
  end
  

end

---------------------------------------------------------------------------------------------------
-- [Class] Set to the previous bar position
-- NB: bars are based on position in beats and use metronome_beats_per_bar as basis
-- @param pos (SongPos)
-- @param args, table (xSongPos-options - see description of class)
-- @return SongPos or nil
-- @return number, lines travelled or nil

function xSongPos.previous_bar(pos,args)
  TRACE("xSongPos.previous_bar(pos,args)",pos,args)

  args = xSongPos._init_args(args)

  -- bars are based on position in beats
  local pos_bar = xSongPos.get_number_of_beats(pos)/args.beats_per_bar
  local new_pos_bar = nil
  if (cLib.fraction(pos_bar) == 0) then
    new_pos_bar = pos_bar - 1 
  else
    new_pos_bar = math.floor(pos_bar)
  end
  local new_pos = xSongPos.create_from_beats(new_pos_bar*args.beats_per_bar)
  if (new_pos_bar >= 0) then 
    local line_diff = xSongPos.get_line_diff(pos,new_pos)
    return xSongPos.decrease_by_lines(line_diff,pos,args),line_diff
  else 
    -- handle out of bounds 
    if (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.LOOP) then 
      -- set to last bar in last pattern 
      local last_seq_idx = #rns.sequencer.pattern_sequence
      local patt_num_lines = xPatternSequencer.get_number_of_lines(last_seq_idx)
      local new_pos = {
        sequence = last_seq_idx,
        line = patt_num_lines
      }
      return xSongPos.previous_bar(new_pos,args)
    elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.CAP) then 
      local new_pos = {sequence = 1,line = 1}
      local line_diff = xSongPos.get_line_diff(pos,new_pos)
      return new_pos,line_diff
    elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.ALLOW) then 
      local line_diff = xSongPos.get_line_diff(pos,new_pos)
      return new_pos,line_diff
    elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.NULL) then 
      return   
    end
          
  end

end

---------------------------------------------------------------------------------------------------
-- [Class] Set to the next block position
-- @param pos (SongPos)
-- @param args, table (xSongPos-options - see description of class)
-- @return SongPos or nil
-- @return number, lines travelled or nil

function xSongPos.next_block(pos,args)
  TRACE("xSongPos.next_block(pos,args)",pos,args)

  args = xSongPos._init_args(args)

  local lines_block = xBlockLoop.get_block_lines(pos.sequence)
  local next_beat = math.ceil(pos.line/lines_block)
  local next_line = 1 + next_beat*lines_block
  local line_diff = next_line - pos.line
  local new_pos = xSongPos.increase_by_lines(line_diff,pos,args)
  if new_pos and xSongPos.less_than(new_pos,pos) then 
    -- wrapped around (LOOP), lines travelled is equal to 
    -- the number of lines from pos to end of song 
    line_diff = 1 + xSongPos.get_line_diff(pos,xSongPos.get_last_line_in_song())
  elseif new_pos and xSongPos.equal(pos,new_pos) then 
    -- at boundary (CAP) 
    line_diff = 0
  end
  if new_pos then 
    return new_pos,line_diff
  end

end

---------------------------------------------------------------------------------------------------
-- [Class] Set to the next block position
-- @param pos (SongPos)
-- @param args, table (xSongPos-options - see description of class)
-- @return SongPos or nil
-- @return number, lines travelled or nil

function xSongPos.previous_block(pos,args)
  TRACE("xSongPos.previous_block(pos,args)",pos,args)

  args = xSongPos._init_args(args)

  local lines_block = xBlockLoop.get_block_lines(pos.sequence)
  local beat = math.ceil(pos.line/lines_block) - 1
  local line = 1 + beat*lines_block
  local new_pos, line_diff
  if (line == pos.line) then 
    line_diff = lines_block
  else
    line_diff = pos.line - line
  end
  local tmp_args = {}
  if not (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.ALLOW) then 
    -- don't wrap - the block size depends on the pattern itself
    tmp_args = {bounds_mode = xSongPos.OUT_OF_BOUNDS.NULL}
  else 
    tmp_args = args
  end
  new_pos = xSongPos.decrease_by_lines(line_diff,pos,tmp_args)  
  if not new_pos then 
    if (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.LOOP) then 
      local block_line_diff
      new_pos,block_line_diff = xSongPos.get_last_block_in_song()
      local line_diff = 1 + pos.line + block_line_diff
      return new_pos,line_diff
    elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.CAP) then 
      return {sequence=1,line=1},pos.line-1
    end
  else
    return new_pos,line_diff
  end 


end

---------------------------------------------------------------------------------------------------
-- [Class] Set to the beginning of next pattern 
-- @param pos (SongPos)
-- @param args, table (xSongPos-options - see description of class)
-- @return SongPos or nil
-- @return number, lines travelled or nil

function xSongPos.next_pattern(pos,args)
  TRACE("xSongPos.next_pattern(pos,args)",pos,args)

  args = xSongPos._init_args(args)

  local patt_num_lines = xPatternSequencer.get_number_of_lines(pos.sequence)
  local next_line = 1 + patt_num_lines
  local line_diff = next_line - pos.line
  local new_pos = xSongPos.increase_by_lines(line_diff,pos,args)
  if new_pos and xSongPos.less_than(new_pos,pos) then 
    -- wrapped around (LOOP), lines travelled is equal to 
    -- the number of lines from pos to end of song 
    line_diff = 1 + xSongPos.get_line_diff(pos,xSongPos.get_last_line_in_song())
  elseif new_pos and xSongPos.equal(pos,new_pos) then 
    -- at boundary (CAP) 
    line_diff = 0
  end
  if new_pos then 
    return new_pos,line_diff
  end

end

---------------------------------------------------------------------------------------------------
-- [Class] Set to the beginning of pattern, or previous pattern
-- @param pos (SongPos)
-- @param args, table (xSongPos-options - see description of class)
-- @return number, lines travelled

function xSongPos.previous_pattern(pos,args)
  TRACE("xSongPos.previous_pattern(pos,args)",pos,args)

  args = xSongPos._init_args(args)
  local line = pos.line 
  if (pos.line == 1) then 
    local patt_num_lines = xPatternSequencer.get_number_of_lines(pos.sequence-1)
    if patt_num_lines then
      line = line + patt_num_lines
    elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.LOOP) then
      local patt_num_lines = xPatternSequencer.get_number_of_lines(#rns.sequencer.pattern_sequence)
      line = line + patt_num_lines
    end
    return xSongPos.decrease_by_lines(line - pos.line,pos,args)
  else
    return xSongPos.decrease_by_lines(pos.line-1,pos,args)    
  end
  

end

---------------------------------------------------------------------------------------------------
-- [Static] Restrict the position to boundaries (sequence, loop)
-- @param direction, string ("increase" or "decrease")
-- @param pos, SongPos 
-- @param args, table (xSongPos-options - see description of class)
-- @return sequence,line,done
--  sequence, int or nil
--  line, int or nil 
--  done (bool), true when boundary was "enforced" (capped/nullified/allowed)

function xSongPos.enforce_boundary(direction,pos,args)
  TRACE("xSongPos.enforce_boundary(direction,pos,args)",direction,pos,args)

  assert(type(direction) == "string")

  args = xSongPos._init_args(args)

  local seq_idx = pos.sequence
  local line_idx = pos.line 

  -- enforce loop boundaries
  -- (only modifies the sequence, not the line)
  if (args.loop_boundary ~= xSongPos.LOOP_BOUNDARY.NONE) then
    
    local loop_sequence_start,loop_sequence_end
    if rns.transport.loop_pattern then
      -- pattern loop takes precedence over sequence
      -- (just like in Renoise...)
      local curr_pos = rns.transport.playing and 
        rns.transport.playback_pos or rns.transport.edit_pos      
      loop_sequence_start = curr_pos.sequence
      loop_sequence_end = curr_pos.sequence
    else 
      loop_sequence_start = args.loop_sequence_range[1]
      loop_sequence_end = args.loop_sequence_range[2]
    end
    
    if loop_sequence_start and (loop_sequence_start ~= 0) then
      local hard_boundary = (args.loop_boundary == xSongPos.LOOP_BOUNDARY.HARD)
      if (direction == "increase") then
        if hard_boundary then 
          if (seq_idx > loop_sequence_end) or (seq_idx < loop_sequence_start) then 
            return loop_sequence_start,line_idx,false 
          end
        end          
      elseif (direction == "decrease") then
        if hard_boundary then
          if (seq_idx > loop_sequence_end) or (seq_idx < loop_sequence_start) then 
            return loop_sequence_end,line_idx,false 
          end
        end
      end
    end
    
  end -- /looping

  -- true when no further action is needed
  local done = false
  
  -- sequence (entire song) -------------------------------
  if not xSongPos.within_bounds(pos) then 
    if (direction == "increase") then
      if (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.CAP) then
        seq_idx = #rns.sequencer.pattern_sequence
        local patt_num_lines = xPatternSequencer.get_number_of_lines(seq_idx)
        line_idx = patt_num_lines
        done = true
      elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.ALLOW) then
        seq_idx = #rns.sequencer.pattern_sequence
        line_idx = nil 
        done = true
      elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.LOOP) then
        seq_idx = 1
      elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.NULL) then
        seq_idx = nil
        line_idx = nil
        done = true
      end
    elseif (direction == "decrease") then
      if (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.CAP) then
        seq_idx = 1
        line_idx = 1
        done = true
      elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.ALLOW) then
        seq_idx = 1
        line_idx = nil
        done = true
      elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.LOOP) then
        seq_idx = #rns.sequencer.pattern_sequence
        local last_patt_lines = xPatternSequencer.get_number_of_lines(seq_idx)
        line_idx = last_patt_lines - line_idx 
      elseif (args.bounds_mode == xSongPos.OUT_OF_BOUNDS.NULL) then
        seq_idx = nil
        line_idx = nil
        done = true
      end
    end
  end

  return seq_idx, line_idx, done

end

---------------------------------------------------------------------------------------------------
-- [Static] Restrict position to boundaries (block-loop)
-- @param pos, SongPos 
-- @param line_delta, int - #lines to add/subtract, negative when decreasing
-- @param [boundary], xSongPos.BLOCK_BOUNDARY
-- @return line, int

function xSongPos.enforce_block_boundary(pos,line_delta,boundary)
  TRACE("xSongPos.enforce_block_boundary(pos,line_delta,boundary)",pos,line_delta,boundary)

  assert(type(line_delta) == "number")
  
  if (line_delta == 0) then 
    return pos.line 
  end
    
  if not boundary then boundary = xSongPos.DEFAULT_BLOCK_MODE end

  if rns.transport.loop_block_enabled then

    if (boundary == xSongPos.BLOCK_BOUNDARY.NONE) then
      return pos.line + line_delta
    end

    local block_pos = rns.transport.loop_block_start_pos
    if (pos.sequence ~= block_pos.sequence) then
      return pos.line + line_delta
    end

    -- hard_boundary: if outside block, go to first/last line in block
    -- always: if inside block, wrap around
    local loop_block_end_pos = xBlockLoop.get_end()
    local hard_boundary = (boundary == xSongPos.BLOCK_BOUNDARY.HARD)
    local within_block = 
      xBlockLoop.within(block_pos.sequence,pos.line,loop_block_end_pos)
    local within_block_post = 
      xBlockLoop.within(block_pos.sequence,pos.line+line_delta,loop_block_end_pos)
    if (line_delta > 0) then
      if (hard_boundary and not within_block) then
        return rns.transport.loop_block_start_pos.line
      end
      if (within_block and not within_block_post) then
        return -1 + block_pos.line + (pos.line+line_delta) - loop_block_end_pos
      end
    else -- decrease 
      if (hard_boundary and not within_block) then
        return loop_block_end_pos
      end
      if (within_block and not within_block_post) then
        return 1 + loop_block_end_pos + (pos.line+line_delta) - rns.transport.loop_block_start_pos.line
      end
    end
  end
  return pos.line + line_delta

end

---------------------------------------------------------------------------------------------------
-- Check if position is within bounds of the song 
-- Note: this method only verifies the line-index for the last pattern 
-- @param pos, SongPos
-- @return boolean

function xSongPos.within_bounds(pos)

  if not xPatternSequencer.within_bounds(pos.sequence) then 
    return false 
  elseif (pos.sequence < 1 ) or (pos.sequence == 1 and pos.line < 1) then 
    return false 
  else 
    local seq_count = #rns.sequencer.pattern_sequence
    if (pos.sequence == seq_count) then 
      local num_lines = xPatternSequencer.get_number_of_lines(seq_count) 
      if (pos.line > num_lines) then 
        return false 
      end 
    end
  end
  
  return true 
  
end

---------------------------------------------------------------------------------------------------
-- Get the last line in the last pattern 
-- @return SongPos

function xSongPos.get_last_line_in_song()
  TRACE("xSongPos.get_last_line_in_song()")

  local last_seq_idx = #rns.sequencer.pattern_sequence
  
  return {
    sequence = last_seq_idx,
    line = xPatternSequencer.get_number_of_lines(last_seq_idx)
  }
  
end

---------------------------------------------------------------------------------------------------
--

function xSongPos.get_last_block_in_song()
  
  local last_seq_idx = #rns.sequencer.pattern_sequence
  local new_pos = {
    sequence = last_seq_idx,
    line = xPatternSequencer.get_number_of_lines(last_seq_idx)
  }
  
  return xSongPos.previous_block(new_pos)
  
end

---------------------------------------------------------------------------------------------------
-- [Static] Get the difference in lines between two song-positions
-- @param pos1 (SongPos)
-- @param pos2 (SongPos)
-- @return int

function xSongPos.get_line_diff(pos1,pos2)
  TRACE("xSongPos.get_line_diff(pos1,pos2)",pos1,pos2)

  local num_lines = 0

  if xSongPos.equal(pos1,pos2) then
    return num_lines
  end

  local early,late
  if not xSongPos.less_than(pos1,pos2) then
    early,late = pos2,pos1
  else
    early,late = pos1,pos2 
  end

  if (pos1.sequence == pos2.sequence) then
    return late.line - early.line
  else
    for seq_idx = early.sequence, late.sequence do
      local patt_num_lines = xPatternSequencer.get_number_of_lines(seq_idx)
      if (seq_idx == early.sequence) then
        num_lines = num_lines + patt_num_lines - early.line
      elseif (seq_idx == late.sequence) then
        num_lines = num_lines + late.line
      else
        num_lines = num_lines + patt_num_lines
      end
    end
    return num_lines
  end

end

---------------------------------------------------------------------------------------------------

function xSongPos.less_than(pos1,pos2)
  if (pos1.sequence == pos2.sequence) then
    return (pos1.line < pos2.line)
  else
    return (pos1.sequence < pos2.sequence)
  end
end

---------------------------------------------------------------------------------------------------

function xSongPos.equal(pos1,pos2)
  if (pos1.sequence == pos2.sequence) and (pos1.line == pos2.line) then
    return true
  else
    return false
  end
end

---------------------------------------------------------------------------------------------------

function xSongPos.less_than_or_equal(pos1,pos2)
  if (pos1.sequence == pos2.sequence) then
    if (pos1.line == pos2.line) then
      return true
    else
      return (pos1.line < pos2.line)
    end
  else
    return (pos1.sequence < pos2.sequence)
  end
end

---------------------------------------------------------------------------------------------------
-- Apply default boundary-values 
-- @param args, table (xSongPos-options - see description of class)

function xSongPos._init_args(args)
  
  if not args then 
    return xSongPos.get_defaults()
  end
  
  if not args.bounds_mode then args.bounds_mode = xSongPos.DEFAULT_BOUNDS_MODE end
  if not args.loop_boundary then args.loop_boundary = xSongPos.DEFAULT_LOOP_MODE end
  if not args.block_boundary then args.block_boundary = xSongPos.DEFAULT_BLOCK_MODE end
  if not args.beats_per_bar then args.beats_per_bar = rns.transport.metronome_beats_per_bar end
  if not args.lines_per_beat then args.lines_per_beat = rns.transport.lpb end
  if not args.loop_sequence_range then args.loop_sequence_range = rns.transport.loop_sequence_range end

  return args
  
end

