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

xSampleMapping.MIN_NOTE = 0
xSampleMapping.MAX_NOTE = 119

xSampleMapping.MIN_VELOCITY = 0x00
xSampleMapping.MAX_VELOCITY = 0x80

xSampleMapping.DEFAULT_LAYER = 1

xSampleMapping.DEFAULT_VEL_TO_VOL = true
xSampleMapping.DEFAULT_KEY_TO_PITCH = true

---------------------------------------------------------------------------------------------------

function xSampleMapping:__init(...)

	local args = cLib.unpack_args(...)
  
  self.layer = args.layer
  self.base_note = args.base_note
  self.map_velocity_to_volume = args.map_velocity_to_volume
  self.map_key_to_pitch = args.map_key_to_pitch
  self.note_range = args.note_range
  self.velocity_range = args.velocity_range
  self.sample = args.sample
  self.index = args.index
  
end

---------------------------------------------------------------------------------------------------
-- [Static] Test if a given note is within the provided note-range 
-- @param note (number)
-- @param mapping (table{number,number})

function xSampleMapping.within_note_range(note,mapping)
  TRACE("xSampleMapping.within_note_range(note,mapping)",note,mapping)
  local rng = mapping.note_range
  return (note >= rng[1]) and (note <= rng[2]) 
end

---------------------------------------------------------------------------------------------------

function xSampleMapping.has_full_note_range(mapping)
  local rng = mapping.note_range
  return (rng[1] == 0 and rng[2] == 119)
end