--[[===============================================================================================
xSampleMapping
===============================================================================================]]--

--[[--

Static methods for working with renoise sample mappings
.
#

### See also
@{xInstrument}

--]]

--=================================================================================================

class 'xSampleMapping'

---------------------------------------------------------------------------------------------------
-- [Static] Test if a given note is within the provided note-range 
-- @param note (number)
-- @param mapping (table{number,number})

function xSampleMapping.within_note_range(note,mapping)
  TRACE("xSampleMapping.within_note_range(note,mapping)",note,mapping)
  local rng = mapping.note_range
  return (note >= rng[1]) and (note <= rng[2]) 
end

