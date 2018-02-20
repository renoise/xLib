--[[===============================================================================================
xPhraseSelection
===============================================================================================]]--

--[[--

Static methods for working with phrase-selections
.
#

### Phrase-selection 

  {
    start_line,     -- Start pattern line index
    start_column,   -- Start column index within start_track   
    end_line,       -- End pattern line index
    end_column      -- End column index within end_track
  }


]]

--=================================================================================================

class 'xPhraseSelection'

---------------------------------------------------------------------------------------------------
-- [Static] Get selection spanning the entire selected phrase
-- @return table (Phrase-selection)

function xPhraseSelection.get_phrase()

  local phrase = rns.selected_phrase

  if not phrase then
    return false,"Could not retrieve selection, no phrase selected"
  end

  return {
    start_line = 1,    
    start_column = 1,  
    end_line = phrase.number_of_lines,      
    end_column = phrase.visible_note_columns+phrase.visible_effect_columns      
  }

end

