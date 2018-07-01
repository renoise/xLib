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

xSampleMapping.DEFAULT_LAYER = renoise.Instrument.LAYER_NOTE_ON

xSampleMapping.DEFAULT_VEL_TO_VOL = true
xSampleMapping.DEFAULT_KEY_TO_PITCH = true

---------------------------------------------------------------------------------------------------

function xSampleMapping:__init(...)

	local args = cLib.unpack_args(...)
  
  assert(type(args.base_note) == "number")
  assert(type(args.note_range) == "table")
  assert(type(args.velocity_range) == "table")
  
  self.layer = args.layer or xSampleMapping.DEFAULT_LAYER
  self.base_note = args.base_note
  self.note_range = args.note_range
  self.velocity_range = args.velocity_range
  self.map_key_to_pitch = cReflection.as_boolean(args.map_key_to_pitch, true)  
  self.map_velocity_to_volume = cReflection.as_boolean(args.map_velocity_to_volume, true) 
  self.sample = args.sample
  self.index = args.index
  
end

---------------------------------------------------------------------------------------------------

function xSampleMapping:__tostring()
  
  return self.type 
    .." layer:"..tostring(self.layer)
    ..", base_note:"..tostring(self.base_note)
    ..", map_velocity_to_volume:"..tostring(self.map_velocity_to_volume)
    ..", map_key_to_pitch:"..tostring(self.map_key_to_pitch)
    ..", note_range:"..tostring(self.note_range)
    ..", velocity_range:"..tostring(self.velocity_range)
    ..", sample:"..tostring(self.sample)
    ..", index:"..tostring(self.index)
  
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