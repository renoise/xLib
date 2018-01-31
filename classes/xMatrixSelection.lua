--[[============================================================================
xMatrixSelection
============================================================================]]--

--[[--

Static methods for working with matrix-selections
.
#

### Matrix-selection

  {
    [sequence_index] = {
      [track_index] = true,
      [track_index] = true,
    },
    [sequence_index] = {
      [track_index] = true,
      [track_index] = true,
    },
  }

]]

class 'xMatrixSelection'

-------------------------------------------------------------------------------
-- [Static] Retrieve the matrix selection 
-- @return table<[sequence_index][track_index]>

function xMatrixSelection.get_selection()
  TRACE("xMatrixSelection.get_selection()")

  local sel = {}
  for k,v in ipairs(rns.sequencer.pattern_sequence) do
    sel[k] = {}
    for k2,v2 in ipairs(rns.tracks) do
      if rns.sequencer:track_sequence_slot_is_selected(k2,k) then
        sel[k][k2] = true
      end
    end
    if table.is_empty(sel[k]) then
      sel[k] = nil
    end
  end
  return sel

end

