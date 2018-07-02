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
xSampleMapping.DEFAULT_BASENOTE = 48

xSampleMapping.DEFAULT_VEL_TO_VOL = true
xSampleMapping.DEFAULT_KEY_TO_PITCH = true

---------------------------------------------------------------------------------------------------

function xSampleMapping:__init(...)

	local args = cLib.unpack_args(...)
  
  self.layer = args.layer or xSampleMapping.DEFAULT_LAYER
  self.base_note = args.base_note or xSampleMapping.DEFAULT_BASENOTE
  self.note_range = args.note_range or xSampleMapping.get_full_note_range()
  self.velocity_range = args.velocity_range or xSampleMapping.get_full_velocity_range()
  self.map_key_to_pitch = cReflection.as_boolean(args.map_key_to_pitch, true)  
  self.map_velocity_to_volume = cReflection.as_boolean(args.map_velocity_to_volume, true) 
  self.sample = args.sample
  -- number, refers to the numerical index of the source mapping
  self.index = (type(args)~="SampleMapping") and args.index
  
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
-- Static Methods 
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
-- [Static] test if mapping has the maximum possible range 

function xSampleMapping.has_full_range(mapping)
  return xSampleMapping.has_full_note_range(mapping)
    and xSampleMapping.has_full_velocity_range(mapping)
end

---------------------------------------------------------------------------------------------------

function xSampleMapping.get_full_note_range()
  return {xSampleMapping.MIN_NOTE,xSampleMapping.MAX_NOTE}
end

---------------------------------------------------------------------------------------------------

-- [Static] test if mapping occupies the full note-range

function xSampleMapping.has_full_note_range(mapping)
  return (mapping.note_range[1] == xSampleMapping.MIN_NOTE) 
    and  (mapping.note_range[2] == xSampleMapping.MAX_NOTE)
end

---------------------------------------------------------------------------------------------------

function xSampleMapping.get_full_velocity_range()
  return {xSampleMapping.MIN_VELOCITY,xSampleMapping.MAX_VELOCITY}
end

---------------------------------------------------------------------------------------------------
-- [Static] test if mapping occupies the full note-range

function xSampleMapping.has_full_velocity_range(mapping)
  return (mapping.velocity_range[1] == xSampleMapping.MIN_VELOCITY) 
    and  (mapping.velocity_range[2] == xSampleMapping.MAX_VELOCITY)
end

---------------------------------------------------------------------------------------------------
-- get memoized key for a sample mapping  
-- @param mapping (SampleMapping or xSampleMapping)
-- @param idx (number) the source mapping index 
-- @return string 

function xSampleMapping.get_memoized_key(mapping)

  return ("%d.%d.%d.%d.%d"):format(
    mapping.layer,
    mapping.note_range[1],
    mapping.note_range[2],
    mapping.velocity_range[1],
    mapping.velocity_range[2]
  )

end

---------------------------------------------------------------------------------------------------
-- get memoized key for a sample mapping  
-- @param mapping (SampleMapping or xSampleMapping)
-- @param idx (number) the source mapping index 
-- @return string 

function xSampleMapping.get_memoized_key(mapping)

  return ("%d.%d.%d.%d.%d"):format(
    mapping.layer,
    mapping.note_range[1],
    mapping.note_range[2],
    mapping.velocity_range[1],
    mapping.velocity_range[2]
  )

end


