--[[===============================================================================================
xLinePattern
===============================================================================================]]--

--[[--

This class represents a 'virtual' renoise.PatternLine
.
#

See also:
@{xLine}
@{xLinePattern}

]]

--=================================================================================================

cLib.require(_xlibroot.."xNoteColumn")
cLib.require(_xlibroot.."xEffectColumn")

---------------------------------------------------------------------------------------------------

class 'xLinePattern'

--- number, maximum number of note columns 
xLinePattern.MAX_NOTE_COLUMNS = 12

--- number, maximum number of effect columns 
xLinePattern.MAX_EFFECT_COLUMNS = 8

--- number, constant value used for representing empty values 
xLinePattern.EMPTY_VALUE = 255     

--- string, constant value used for representing empty values 
xLinePattern.EMPTY_STRING = "00"

--- table, supported effect characters
xLinePattern.EFFECT_CHARS = {
  "0","1","2","3","4","5","6","7", 
  "8","9","A","B","C","D","E","F", 
  "G","H","I","J","K","L","M","N", 
  "O","P","Q","R","S","T","U","V", 
  "W","X","Y","Z"                  
}

---------------------------------------------------------------------------------------------------
-- [Constructor], accepts two arguments for initializing the class
-- @param note_columns (table, xNoteColumn descriptor)
-- @param effect_columns (table, xEffectColumn descriptor)

function xLinePattern:__init(note_columns,effect_columns)

  --- table<xNoteColumn>
  self.note_columns = table.create()

  --- table<xEffectColumn>
  self.effect_columns = table.create()

  -- initialize -----------------------

  self:apply_descriptor(note_columns,effect_columns)

end

---------------------------------------------------------------------------------------------------
-- [Class] Convert descriptors into class instances (empty tables are left as-is)
-- @param note_columns (xNoteColumn or table)
-- @param effect_columns (xEffectColumn or table)

function xLinePattern:apply_descriptor(note_columns,effect_columns)

  if not table.is_empty(note_columns) then
    local _,column_count = cTable.bounds(note_columns)
    for k = 1,math.min(xLinePattern.MAX_NOTE_COLUMNS,column_count) do
      self.note_columns[k] = xNoteColumn(note_columns[k])      
    end
  end
  if not table.is_empty(effect_columns) then
    local _,column_count = cTable.bounds(effect_columns)
    for k = 1,math.min(xLinePattern.MAX_EFFECT_COLUMNS,column_count) do
      self.effect_columns[k] = xEffectColumn(effect_columns[k])
    end

  end

end

---------------------------------------------------------------------------------------------------
-- Update subcolumn visibility (related: xNoteColumn.subcolumn_is_empty)
-- @param rns_track_or_phrase (renoise.Track or renoise.InstrumentPhrase) 
-- @param token (string), one of xNoteColumn.subcolumn_tokens
-- @param val (boolean)

function xLinePattern.set_subcolumn_visibility(rns_track_or_phrase,token,val)
  TRACE("xLinePattern.set_subcolumn_visibility(rns_track_or_phrase,token,val)",rns_track_or_phrase,token,val)
  
  local choices = {
    ["volume_value"] = function()
      rns_track_or_phrase.volume_column_visible = val
    end, 
    ["panning_value"] = function()
      rns_track_or_phrase.panning_column_visible = val
    end,
    ["delay_value"] = function()
      rns_track_or_phrase.delay_column_visible = val
    end,
    ["effect_number_value"] = function()
      rns_track_or_phrase.sample_effects_column_visible = val
    end,
    ["effect_amount_value"] = function()
      rns_track_or_phrase.sample_effects_column_visible = val
    end,
  }
  if choices[token] then 
    choices[token]()    
    return
  end

  error("Unexpected token - use `xNoteColumn.subcolumn_tokens`")
  
end


---------------------------------------------------------------------------------------------------
-- [Class] Combined method for writing to pattern or phrase
-- @param sequence (int)
-- @param line (int)
-- @param track_idx (int), when writing to pattern
-- @param phrase (renoise.InstrumentPhrase), when writing to phrase
-- @param include_hidden (bool) apply to hidden columns as well
-- @param expand_columns (bool) reveal columns as they are written to
-- @param clear_undefined (bool) clear existing data when ours is nil

function xLinePattern:do_write(
  sequence,
  line,
  track_idx,
  phrase,
  include_hidden,
  expand_columns,
  clear_undefined)

  local rns_line,_patt_idx,_rns_patt,rns_track,_rns_ptrack
  local rns_track_or_phrase

  if track_idx then -- pattern
    rns_line,_patt_idx,_rns_patt,rns_track,_rns_ptrack = 
      xLine.resolve_pattern_line(sequence,line,track_idx)
    rns_track_or_phrase = rns_track
  else -- phrase
    rns_line = xLine.resolve_phrase_line(line)
    rns_track_or_phrase = phrase
  end

  local is_seq_track = (rns_track.type == renoise.Track.TRACK_TYPE_SEQUENCER)
  
  if is_seq_track then
    self:process_columns(rns_line.note_columns,
      rns_track_or_phrase,
      self.note_columns,
      include_hidden,
      expand_columns,
      clear_undefined)
  else
    if self.note_columns then
      LOG("Can only write note-columns to a sequencer track")
    end
  end

  self:process_columns(rns_line.effect_columns,
    rns_track_or_phrase,
    self.effect_columns,
    include_hidden,
    expand_columns,
    clear_undefined)

end

---------------------------------------------------------------------------------------------------
-- [Class] Write to either note or effect column
-- @param rns_columns (table<renoise.NoteColumn or renoise.EffectColumn>) 
-- @param rns_track_or_phrase (renoise.Track or renoise.InstrumentPhrase) 
-- @param xline_columns (table<xNoteColumn or xEffectColumn>)
-- @param include_hidden (bool) apply to hidden columns as well
-- @param expand_columns (bool) reveal columns as they are written to
-- @param clear_undefined (bool) clear existing data when ours is nil

function xLinePattern:process_columns(
  rns_columns,
  rns_track_or_phrase,
  xline_columns,
  include_hidden,
  expand_columns,
  clear_undefined)

  local visible_cols = 1
  local is_note_column = (type(rns_columns[1]) == "NoteColumn")
  
  -- callback function - reveals non-empty subcolumns 
  -- as values are written to them 
  local subcolumn_callback = function(note_col,token)
    if not xNoteColumn.subcolumn_is_empty(note_col,token) then 
      xLinePattern.set_subcolumn_visibility(rns_track_or_phrase,token,true)
    end
  end
  
	for k,rns_col in ipairs(rns_columns) do
    
    if not expand_columns and not include_hidden and (k > visible_cols) then
      break
    elseif (k > #rns_columns) then 
      break
    end

    local col = xline_columns[k]
    
    if col then

      if expand_columns then
        visible_cols = k
      end

      local tokens = {}
      local callback = nil
      if (type(col) == "table") then
        -- convert table descriptor into class instance 
        if is_note_column then
          col = xNoteColumn(col)
        else
          col = xEffectColumn(col)        
        end
      end
      if (type(col) == "xNoteColumn") then 
        tokens = xNoteColumn.output_tokens
        callback = expand_columns and subcolumn_callback
      elseif (type(col) == "xEffectColumn") then 
        tokens = xEffectColumn.output_tokens
      else 
        error("Unexpected column type: "..type(col))
      end
      col:do_write(rns_col,tokens,clear_undefined,callback)
    else
      if clear_undefined then
        rns_col:clear()
      end
    end
	end

  if is_note_column then
    rns_track_or_phrase.visible_note_columns = visible_cols
  else
    rns_track_or_phrase.visible_effect_columns = visible_cols
  end

end

---------------------------------------------------------------------------------------------------
-- [Static] Read from pattern, return note/effect-column descriptors 
-- This method is made more performant by taking the raw string representation of the line, 
-- instead of accessing the individual NoteColumn/EffectColumn properties (thanks joule!)
-- @param rns_line (renoise.PatternLine)
-- @param max_note_cols (int)
-- @param max_fx_cols (int)
-- @return table, note columns
-- @return table, effect columns

function xLinePattern.do_read(rns_line,max_note_cols,max_fx_cols)

  local line_str = tostring(rns_line)
  local note_cols, fx_cols = {}, {}
  local start_pos
  
  for ncol = 1, max_note_cols do
    start_pos = (ncol*18)-17
    local note_string          = string.sub(line_str, start_pos, start_pos+2)
    local instrument_string    = string.sub(line_str, start_pos+3, start_pos+4)
    local volume_string        = string.sub(line_str, start_pos+5, start_pos+6)
    local panning_string       = string.sub(line_str, start_pos+7, start_pos+8)
    local delay_string         = string.sub(line_str, start_pos+9, start_pos+10)
    local effect_number_string = string.sub(line_str, start_pos+11, start_pos+12)
    local effect_amount_string = string.sub(line_str, start_pos+13, start_pos+14)
    note_cols[ncol] = {
      note_string          = note_string,
      instrument_string    = instrument_string,
      volume_string        = volume_string,
      panning_string       = panning_string,
      delay_string         = delay_string,
      effect_number_string = effect_number_string,
      effect_amount_string = effect_amount_string,
      note_value           = xNoteColumn.note_string_to_value(note_string),
      instrument_value     = xNoteColumn.instr_string_to_value(instrument_string),
      delay_value          = xNoteColumn.delay_string_to_value(delay_string),
      volume_value         = xNoteColumn.column_string_to_value(volume_string),
      panning_value        = xNoteColumn.column_string_to_value(panning_string),
      effect_number_value  = xEffectColumn.number_string_to_value(effect_number_string),
      effect_amount_value  = xEffectColumn.amount_string_to_value(effect_amount_string)
    }
  end

  for fxcol = 1, max_fx_cols do
    start_pos = (fxcol*7)+209
    local number_string = string.sub(line_str, start_pos+1, start_pos+2)
    local amount_string = string.sub(line_str, start_pos+3, start_pos+4)
    fx_cols[fxcol] = {
      number_string = number_string,
      amount_string = amount_string,
      number_value  = xEffectColumn.number_string_to_value(number_string),
      amount_value  = xEffectColumn.amount_string_to_value(amount_string)
    }
  end

  return note_cols, fx_cols

end

---------------------------------------------------------------------------------------------------
-- [Static] Look for a specific type of effect command in line, return all matches
-- (the number of characters in 'fx_type' decides if we search columns or sub-columns)
-- @param track (renoise.Track)
-- @param line (renoise.PatternLine)
-- @param fx_type (number), e.g. "0S" or "B" 
-- @param notecol_idx (number), note-column index
-- @param [visible_only] (boolean), restrict search to visible columns in track 
-- @return table<{
--  column_index: note/effect column index (across visible columns)
--  column_type: xEffectColumn.TYPE
--  amount_value: number 
--  amount_string: string 
-- }> or nil

function xLinePattern.get_effect_command(track,line,fx_type,notecol_idx,visible_only)
  --TRACE("xLinePattern.get_effect_command(track,line,fx_type,notecol_idx,visible_only)")

  assert(type(track)=="Track","Expected renoise.Track as argument")
  assert(type(line)=="PatternLine","Expected renoise.PatternLine as argument")
  assert(type(fx_type)=="string","Expected string as argument")
  assert(type(notecol_idx)=="number","Expected number as argument")

  if (#fx_type == 1) then 
    return xLinePattern.get_effect_subcolumn_command(track,line,fx_type,notecol_idx,visible_only)
  elseif (#fx_type == 2) then 
    return xLinePattern.get_effect_column_command(track,line,fx_type,notecol_idx,visible_only)
  else 
    error("Unexpected effects type")
  end 

end

---------------------------------------------------------------------------------------------------
-- [Static] Get effect command using single-digit syntax (sub-column)
-- (look through vol/pan subcolumns in note-columns)

function xLinePattern.get_effect_subcolumn_command(track,line,fx_type,notecol_idx,visible_only)
  TRACE("xLinePattern.get_effect_subcolumn_command(track,line,fx_type,notecol_idx,visible_only)",track,line,fx_type,notecol_idx,visible_only)

    -- TODO 
    error("Not yet implemented")

end 

---------------------------------------------------------------------------------------------------
-- [Static] Get effect command using two-digit syntax (effect-column)
-- (look through note effect-columns and effect-columns)
-- @param track (renoise.Track)
-- @param line (renoise.PatternLine)
-- @param fx_type (string), two-digit string, e.g. "0S"
-- @param [notecol_idx] (number), restrict search to this note-column 
-- @param [visible_only] (boolean), restrict search to visible note/effect-columns
-- @return table - see get_effect_command()

function xLinePattern.get_effect_column_command(track,line,fx_type,notecol_idx,visible_only)
  TRACE("xLinePattern.get_effect_column_command(track,line,fx_type,notecol_idx,visible_only)",track,line,fx_type,notecol_idx,visible_only)

  local matches = table.create()
  local col_idx = 1

  local check_notecols = not visible_only and true or track.sample_effects_column_visible 
  if check_notecols then 
    for k,notecol in ipairs(line.note_columns) do
      if visible_only and (k > track.visible_note_columns) then
        break
      else
        local do_search = not notecol_idx and true or (k == notecol_idx) 
        if do_search then 
          if (notecol.effect_number_string == fx_type) then
            matches:insert({
              column_index = col_idx,
              column_type = xEffectColumn.TYPE.EFFECT_NOTECOLUMN,
              amount_value = notecol.effect_amount_value,
              amount_string = notecol.effect_amount_string,
            })
          end
        end
        col_idx = col_idx + 1
      end
    end
  else
    col_idx = track.visible_note_columns + 1
  end 

  for k,fxcol in ipairs(line.effect_columns) do
    if visible_only and (k > track.visible_effect_columns) then 
      break 
    else
      if (fxcol.number_string == fx_type) then
        matches:insert({
          column_index = col_idx,
          column_type = xEffectColumn.TYPE.EFFECT_COLUMN,
          amount_value = fxcol.amount_value,
          amount_string = fxcol.amount_string,
        })
      end
      col_idx = col_idx + 1
    end
  end

  return matches 

end 

---------------------------------------------------------------------------------------------------
-- Get the first available effect column 
-- @param track (renoise.Track)
-- @param line (renoise.PatternLine)
-- @param [visible_only] (boolean), restrict search to visible columns in track 
-- @param [from_column] (number), which column to start search from 
-- @return {
--    column_index: number, note/effect column index (across visible columns)
--    column_type: xEffectColumn.TYPE  
--  }

function xLinePattern.get_available_effect_column(track,line,visible_only,from_column)
  TRACE("xLinePattern.get_available_effect_column(track,line,visible_only,from_column)",track,line,visible_only,from_column)

  local col_idx = 1
  
  local check_notecols = not visible_only and true or track.sample_effects_column_visible   
  if check_notecols then
    for k,notecol in ipairs(line.note_columns) do
      if visible_only and (k > track.visible_note_columns) then
        break
      else
        if (from_column and col_idx < from_column) then 
          -- do nothing 
        elseif (notecol.effect_number_value == 0 and notecol.effect_amount_value == 0) then
          -- found empty sample-effect-column 
          return {
            column_index = col_idx,
            column_type = xEffectColumn.TYPE.EFFECT_NOTECOLUMN,
          }
        end
        col_idx = col_idx + 1        
      end
    end
  else
    -- note-fx columns hidden - increase column count 
    col_idx = track.visible_note_columns + 1
  end 

  for k,fxcol in ipairs(line.effect_columns) do
    if visible_only and (k > track.visible_effect_columns) then 
      break 
    else
      if (from_column and col_idx < from_column) then 
        -- do nothing 
      elseif fxcol.is_empty then
        -- found empty effect-column 
        return {
          column_index = col_idx,
          column_type = xEffectColumn.TYPE.EFFECT_COLUMN,
        }
      end
      col_idx = col_idx + 1      
    end
  end

end

---------------------------------------------------------------------------------------------------
-- Write command into effect-column or note-effects column - does the following 
--  * check if effect-command already is present in effect columns 
--  * check if it needs to allocate new effect-columns (when existing ones are occupied)
-- @param track (renoise.Track)
-- @param line (renoise.PatternLine)
-- @param fx_number (string) - two-digit string 
-- @param fx_amount (number) - fx value 
-- @param [column_index] (number) - column index (visible note-columns -> effect columns)
-- @param [overwrite] (boolean) - replace existing value (only when column_index is specified)
-- @return renoise.NoteColumn/renoise.EffectColumn when command was written, else nil 
-- @return string, error message when unable to write  

function xLinePattern.set_effect_column_command(track,line,fx_number,fx_amount,column_index,overwrite)
  TRACE("xLinePattern.set_effect_column_command(track,line,fx_number,fx_amount,column_index,overwrite)",track,line,fx_number,fx_amount,column_index,overwrite)
  
  local visible_only = true
  -- check if the command is already present
  local notecol_idx = -1 -- only match effect-columns
  local rslt = xLinePattern.get_effect_column_command(track,line,fx_number,notecol_idx,visible_only)
  if not table.is_empty(rslt) 
    and rslt[1].amount_value == fx_amount
  then 
    -- command already exists
    return nil, "Effect Command already exists"
  else 
    local from_column = column_index and column_index or track.visible_note_columns+1
    local rslt = xLinePattern.get_available_effect_column(track,line,visible_only,from_column)
    if rslt then 
      column_index = rslt.column_index 
    else 
      
      -- finally, attempt to allocate another effect column 
      if (track.visible_effect_columns < track.max_effect_columns) then 
        local visible_cols = track.visible_effect_columns + 1 
        track.visible_effect_columns = visible_cols
        column_index = track.sample_effects_column_visible 
          and track.visible_note_columns + visible_cols
          or visible_cols
      end
    end
  end   
  
  if not column_index then 
    return nil, "No effect-column was matched"
  end
    
  local note_fx_cols = track.sample_effects_column_visible and track.visible_note_columns or 0
  if (column_index > note_fx_cols) then 
    local column = line.effect_columns[column_index-track.visible_note_columns]
    column.number_string = fx_number
    column.amount_value = math.floor(fx_amount)
    return column
  else
    local column = line.note_columns[column_index]
    column.effect_number_string = fx_number
    column.effect_amount_value = math.floor(fx_amount)
    return column
  end
    
end

---------------------------------------------------------------------------------------------------
-- [Static] Get midi command from line
-- (look in last note-column, panning + first effect column)
-- @return xMidiCommand or nil if not found

function xLinePattern.get_midi_command(track,line)
  TRACE("xLinePattern.get_midi_command(track,line)",track,line)

  assert(type(track)=="Track","Expected renoise.Track as argument")
  assert(type(line)=="PatternLine","Expected renoise.PatternLine as argument")

  local note_col = line.note_columns[track.visible_note_columns]
  local fx_col = line.effect_columns[1]

  if note_col.is_empty or fx_col.is_empty then 
    return 
  end 

  -- command number/value needs to be plain numeric 
  local fx_num_val = xEffectColumn.amount_string_to_value(fx_col.number_string)
  if not fx_num_val then 
    return 
  end 

  if (note_col.instrument_value < 255) 
    and (note_col.panning_string:sub(1,1) == "M")
  then
    local msg_type = tonumber(note_col.panning_string:sub(2,2))
    return xMidiCommand{
      instrument_index = note_col.instrument_value+1,
      message_type = msg_type,
      number_value = fx_col.number_value,
      amount_value = fx_col.amount_value,
    }
  end

end

---------------------------------------------------------------------------------------------------
-- [Static] Set midi command (write to pattern)
-- @param track renoise.Track
-- @param line renoise.PatternLine
-- @param cmd xMidiCommand
-- @param [expand] boolean, show target panning/effect-column (default is true)
-- @param [replace] boolean, replace existing commands (default is false - push to side)

function xLinePattern.set_midi_command(track,line,cmd,expand,replace)

  assert(type(track)=="Track","Expected renoise.Track as argument")
  assert(type(line)=="PatternLine","Expected renoise.PatternLine as argument")
  assert(type(cmd)=="xMidiCommand","Expected xMidiCommand as argument")

  expand = expand or true
  replace = replace or false

  local note_col = line.note_columns[track.visible_note_columns]
  local fx_col = line.effect_columns[1]

  -- if there is an existing non-MIDI command, push it to the side 
  -- (insert in next available effect column)
  if not replace and not fx_col.is_empty then 
    local xcmd = xLinePattern.get_midi_command(track,line) 
    if not xcmd then 
      -- only non-numeric effects are pushed to side
      local fx_num_val = xEffectColumn.amount_string_to_value(fx_col.number_string)
      if not fx_num_val then 
        for k = 2, xLinePattern.MAX_EFFECT_COLUMNS do
          local tmp_fx_col = line.effect_columns[k]
          if tmp_fx_col.is_empty then 
            tmp_fx_col.number_value = fx_col.number_value
            tmp_fx_col.amount_value = fx_col.amount_value
            fx_col:clear()
            -- make column visible if needed 
            if expand and (k > track.visible_effect_columns) then
              track.visible_effect_columns = k
            end
            break
          end 
        end 
      end 
    end 
  end

  note_col.instrument_value = cmd.instrument_index-1
  note_col.panning_string = ("M%d"):format(cmd.message_type)
  fx_col.number_value = cmd.number_value
  fx_col.amount_value = cmd.amount_value

  if expand then
    if not track.panning_column_visible then 
      track.panning_column_visible = true
    end
    if (track.visible_effect_columns == 0) then
      track.visible_effect_columns = 1
    end
  end 

end

---------------------------------------------------------------------------------------------------
-- [Static] Clear previously set midi command. 
-- @param track renoise.Track
-- @param line renoise.PatternLine

function xLinePattern.clear_midi_command(track,line)
  TRACE("xLinePattern.clear_midi_command(track,line)",track,line)

  assert(type(track)=="Track","Expected renoise.Track as argument")
  assert(type(line)=="PatternLine","Expected renoise.PatternLine as argument")

  local note_col = line.note_columns[track.visible_note_columns]
  local fx_col = line.effect_columns[1]

  note_col.panning_value = xLinePattern.EMPTY_VALUE
  fx_col.number_value = 0
  fx_col.amount_value = 0

  -- remove instrument if last thing left
  if (note_col.volume_value == xLinePattern.EMPTY_VALUE)
    and (note_col.delay_value == 0)
    and (note_col.note_value == 121)
  then 
    note_col.instrument_value = xLinePattern.EMPTY_VALUE
  end

end


---------------------------------------------------------------------------------------------------

function xLinePattern:__tostring()

  return type(self)
    .."#note_columns="..tostring(#self.note_columns)
    .."#effect_columns="..tostring(#self.effect_columns)

end

