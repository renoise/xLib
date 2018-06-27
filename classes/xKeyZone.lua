--[[===============================================================================================
xKeyZone
===============================================================================================]]--

--[[--

Static methods for working with instrument keyzones (a.k.a. sample mappings)
.

]]

--=================================================================================================
require (_clibroot.."cDocument")
require (_xlibroot.."xSampleMapping")

--=================================================================================================
-- describe a multi-sample keyzone layout 

class 'xKeyZoneLayout' (cDocument)

-- exportable properties (cDocument)
xKeyZoneLayout.DOC_PROPS = {
  note_steps = "number",
  note_min = "number",
  note_max = "number",
  vel_steps = "number",
  vel_min = "number",
  vel_max = "number",
  extend_notes = "boolean",
  layer = "number",
  map_velocity_to_volume = "boolean",
  map_key_to_pitch = "boolean",
}

---------------------------------------------------------------------------------------------------

function xKeyZoneLayout:__init(...)

  local args = cLib.unpack_args(...)

  self.extend_notes = args.extend_notes or xKeyZone.DEFAULT_EXTEND_NOTES
  self.note_steps = args.note_steps or xKeyZone.DEFAULT_NOTE_STEPS
  self.note_min = args.note_min or xKeyZone.DEFAULT_NOTE_MIN
  self.note_max = args.note_max or xKeyZone.DEFAULT_NOTE_MAX
  self.vel_steps = args.vel_steps or xKeyZone.DEFAULT_VEL_STEPS
  self.vel_min = args.vel_min or xSampleMapping.MIN_VEL
  self.vel_max = args.vel_max or xSampleMapping.MAX_VEL
  self.layer = args.layer or xSampleMapping.DEFAULT_LAYER
  self.map_velocity_to_volume = args.map_velocity_to_volume or xSampleMapping.DEFAULT_VEL_TO_VOL
  self.map_key_to_pitch = args.map_key_to_pitch or xSampleMapping.DEFAULT_KEY_TO_PITCH

end

--=================================================================================================

class 'xKeyZone'

xKeyZone.KEYS_MODE = {
  ALL_KEYS = 1,
  WHITE_KEYS = 2,
}

-- default layout options 
xKeyZone.DEFAULT_NOTE_MIN = 24
xKeyZone.DEFAULT_NOTE_MAX = 95
xKeyZone.DEFAULT_NOTE_STEPS = 6
xKeyZone.DEFAULT_VEL_STEPS = 1
xKeyZone.MIN_VEL_STEPS = 1
xKeyZone.MAX_VEL_STEPS = 16
xKeyZone.MAX_VEL_STEPS = 1
xKeyZone.MAX_NOTE_STEPS = 16
xKeyZone.DEFAULT_EXTEND_NOTES = true

---------------------------------------------------------------------------------------------------
-- [Static] Shift samples by amount of semitones, starting from the sample index 
-- TODO use "mappings" array (support <xSampleMapping>)
-- @param instr (renoise.Instrument)
-- @param sample_idx_from (int)
-- @param amt (int)

function xKeyZone.shift_by_semitones(instr,sample_idx_from,amt)
  TRACE("xKeyZone.shift_by_semitones(instr,sample_idx_from,amt)",instr,sample_idx_from,amt)

  for sample_idx = sample_idx_from,#instr.samples do
    local sample = instr.samples[sample_idx]
    local smap = sample.sample_mapping
    smap.base_note = smap.base_note+amt
    smap.note_range = {smap.note_range[1]+amt, smap.note_range[2]+amt}
  end

end

---------------------------------------------------------------------------------------------------
-- memoize a keyzone layer 
-- @param mappings (table<SampleMapping or xSampleMapping>)
-- @return table<xSampleMapping>, ordered by 

function xKeyZone.memoize_mappings(mappings)
  TRACE("xKeyZone.memoize_mappings(mappings)",mappings)

  if (#mappings == 0) then 
    return {}
  end

  local rslt = {}
  for k,v in ipairs(mappings) do
    local key = xSampleMapping.get_memoized_key(v)
    rslt[key] = xSampleMapping(v)
    rslt[key].index = k
  end

  return rslt

end


---------------------------------------------------------------------------------------------------
-- Locate a sample-mapping that match the provided information
-- @param mappings (table<SampleMapping/xSampleMapping>), can be ordered by memoized keys
-- @param note_range (table)
-- @param vel_rng (table)
-- @param layer (number, renoise.Instrument.LAYER_NOTE_XX), defaults to LAYER_NOTE_ON
-- @return xSampleMapping or nil 

function xKeyZone.find_mapping(mappings,note_rng,vel_rng,layer)
  TRACE("xKeyZone.find_mapping(mappings,note_rng,vel_rng,layer)",#mappings,note_rng,vel_rng,layer)

  -- table contain non-numeric keys (memoized)
  local t_keys = table.keys(mappings)
  if (#t_keys == 0) then 
    return 
  end

  if not layer then 
    layer = renoise.Instrument.LAYER_NOTE_ON
  end

  local is_memoized = (type(t_keys[1])=="string")
  --print("*** is_memoized",is_memoized)

  if is_memoized then 
    -- retrieve mapping via memoized table (fast)
    local key = xSampleMapping.get_memoized_key(xSampleMapping{
      layer = layer,
      note_range = note_rng,
      velocity_range = vel_rng,
    })
    if (mappings[key]) then 
      return mappings[key]
    end
  else
    -- iterate through mappings, compare one by one (slow)
    for k,v in ipairs(mappings) do
      --print("k,v",k,rprint(v))
      local matched = nil
      local continue = true
      if note_rng then 
        continue = cLib.table_compare(note_rng,v.note_range) 
        matched = continue and v or nil
        --print("matched note_rng",matched)
      end 
      if continue and vel_rng then 
        continue = cLib.table_compare(vel_rng,v.velocity_range) 
        matched = continue and v or nil
        --print("matched vel_rng",matched)
      end 
      if matched then 
        -- add mapping index on the fly... 
        local mapping = xSampleMapping(v)
        if (not mapping.index) then
          mapping.index = k 
        end
        return mapping
      end
    end
  end

end

--------------------------------------------------------------------------------
-- [Static] Figure out which samples are mapped to the provided note
-- @return table<number> (sample indices)

function xKeyZone.get_samples_mapped_to_note(instr,note)
  TRACE("xKeyZone.get_samples_mapped_to_note(instr,note)",instr,note)

  local rslt = table.create()
  for sample_idx = 1,#instr.samples do 
    local sample = instr.samples[sample_idx]
    if xSampleMapping.within_note_range(note,sample.sample_mapping) then
      rslt:insert(sample_idx)
    end
  end
  return rslt

end

---------------------------------------------------------------------------------------------------
-- same as 'distribute' in the keyzone editor 
--[[
function xKeyZone.distribute()

  -- TODO 
  
end

---------------------------------------------------------------------------------------------------
-- same as 'layer' in the keyzone editor 

function xKeyZone.layer()

  -- TODO 
  
end
]]

---------------------------------------------------------------------------------------------------
-- create layout from the provided settings 
-- table is ordered same way as Renoise: bottom up, velocity-wise, and left-to-right, note-wise
-- note: specify 'instr' to define the 'sample' property for the returned xSampleMappings
-- @param layout (xKeyZoneLayout)
-- @param instr (renoise.Instrument), if included, this will add 'sample' property 
-- @return table<xSampleMapping>

function xKeyZone.create_multisample_layout(layout,instr)
  TRACE("xKeyZone.create_multisample_layout(layout,instr)",layout,instr)

  local base_notes = xKeyZone.compute_multisample_notes(
    layout.note_steps,layout.note_min,layout.note_max,false)
  local notes = xKeyZone.compute_multisample_notes(
    layout.note_steps,layout.note_min,layout.note_max,layout.extend_notes)
  local velocities = xKeyZone.compute_multisample_velocities(
    layout.vel_steps,layout.vel_min,layout.vel_max)

  local layer = renoise.Instrument.LAYER_NOTE_ON
  local memoized
  if instr then
    memoized = xKeyZone.memoize_mappings(instr.sample_mappings[layer]) 
  end

  local rslt = {}
  for k,note_rng in ipairs(notes) do 
    for k2,vel_rng in ipairs(velocities) do 

      local sample
      if instr then 
        local mapping = xKeyZone.find_mapping(memoized,note_rng,vel_rng)
        sample = mapping and mapping.sample
      end

      table.insert(rslt,xSampleMapping{
        layer = layout.layer,
        base_note = base_notes[k][1],
        map_velocity_to_volume = layout.map_key_to_pitch,
        map_key_to_pitch = layout.map_key_to_pitch,
        note_range = note_rng,
        velocity_range = vel_rng,
        sample = sample,
        index = #rslt,
      })
    end
  end

  return rslt

end

---------------------------------------------------------------------------------------------------
-- @param vel_steps (number), the number of velocity layers to create
-- return table{number,number}

function xKeyZone.compute_multisample_velocities(vel_steps,vel_min,vel_max)
  TRACE("xKeyZone.compute_multisample_velocities()",vel_steps,vel_min,vel_max)

  if (vel_min > vel_max) then 
    vel_min,vel_max = vel_max,vel_min
  end 

  local rslt = {}
  local unit = (vel_max - vel_min + 1)/vel_steps
  local velocity = 0
  for k = 1,vel_steps do 
    local new = velocity+unit
    table.insert(rslt,{
      cLib.round_value(vel_min+velocity),
      cLib.round_value(vel_min+new-1)
    })
    velocity = new
  end

  --print("compute_multisample_velocities rslt...",rprint(rslt))
  return rslt

end

---------------------------------------------------------------------------------------------------
-- @param note_steps (number), create a new mapping for every Nth note 
-- @param extend (boolean), extend "outside" mapped region 
-- return table{number,number}

function xKeyZone.compute_multisample_notes(note_steps,note_min,note_max,extend)
  TRACE("xKeyZone.compute_multisample_notes(note_steps,note_min,note_max,extend)",note_steps,note_min,note_max,extend)

  if (extend == nil) then
    extend = xKeyZone.DEFAULT_EXTEND_NOTES
  end

  if (note_min > note_max) then 
    note_min,note_max = note_max,note_min
  end 

  local rslt = {}
  local note = note_min 
  while (note < note_max) do
    local from = note
    local new = note+note_steps  
    local to = new-1
    -- extend first/last sample
    if extend then 
      if (note == note_min) then 
        from = 0 
      end 
      if (new >= note_max) then 
        to = xSampleMapping.MAX_NOTE
      end 
    end 
    table.insert(rslt,{
      cLib.round_value(from), 
      cLib.round_value(to),
    })
    note = new
  end

  --print("compute_multisample_notes rslt...",note_steps,note_min,note_max,extend,rprint(rslt))
  return rslt

end