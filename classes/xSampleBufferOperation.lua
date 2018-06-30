--[[===============================================================================================
xSampleBufferOperation
===============================================================================================]]--

--[[--

Static methods for processing sample buffers
.

## About 

Use this class to 
* Automatically prepare/finalize buffer before/after processing 
* Keep keyzones and phrases intact while creating new/temp sample [1] 
* Keep/copy basic sample properties like transpose, fine-tune etc. 
* Retain/restore selection size, loop range and zoom settings 
* TODO Run multiple concurrent operations (process slicing)

[1]: Modifying a sample via the Renoise API can result in changes to the keyzone and/or phrases, due to the creation of a temporary sample. This class can automatically detect such changes and retain the original values. 

## How to use 

This class exposes just one public function, `run()`
  
## Arguments 

The arguments you provide contain callbacks that are used for handling both errors,
and to provide return values. 

@param args 
  
  instrument_index -- number, a valid source instrument index
  sample_index      -- number, a valid source sample index   
  on_complete       -- function, callback once processing is done  
  on_error          -- function, callback for error messages  
  operations        -- table, buffer operations {function,function,...}  
  create_sample     -- boolean, whether to create sample (default is to replace)
  restore_selection -- boolean, restore/preserve selection 
  restore_loop      -- boolean, restore/preserve loop settings
  restore_zoom      -- boolean, restore/preserve editor zoom settings
  force_sample_index -- number, define a custom sample index (otherwise after provided)
  force_sample_rate -- number, defined a fixed bit sample_rate
  force_bit_depth   -- number, defined a fixed bit depth 
  force_channels    -- number, define a custom channel count
  force_frames      -- number, define a custom buffer length 
  
-- callbacks 

  on_complete(table{
    sample        (renoise.Sample)
    sample_index  (int)
    drumkit_mode  (boolean)
  })
  
  on_error(string)

]]

--=================================================================================================

cLib.require(_xlibroot.."xKeyZone")
cLib.require(_xlibroot.."xInstrument")

class 'xSampleBufferOperation'

---------------------------------------------------------------------------------------------------
-- execute operations (start processing)

function xSampleBufferOperation.run(args)
  TRACE("xSampleBufferOperation.run(args)",args)

  local temp = xSampleBufferOperation._prepare(args)

  for k,v in ipairs(args.operations) do 
    if (type(v)=="function") then 
      -- anonymous function (no arguments)
      local success,err = pcall(function()
        v(temp.new_sample.sample_buffer)
      end)
      if not success and err then 
        if (type(args.on_error)=="function") then 
          LOG("*** An error occurred",err)
          args.on_error(err)
        end 
      end 
      
    else 
      error("Unexpected argument")
    end 
  end

  xSampleBufferOperation._finalize(args,temp)

end

---------------------------------------------------------------------------------------------------
-- prepare for changes, create new/temp buffer 

function xSampleBufferOperation._prepare(args)
  TRACE("xSampleBufferOperation._prepare(args)",args)

  -- provide defaults 
  args.create_sample = cReflection.as_boolean(args.create_sample,false)
  args.restore_selection = cReflection.as_boolean(args.restore_selection,false)
  args.restore_loop = cReflection.as_boolean(args.restore_loop,false)
  args.restore_zoom = cReflection.as_boolean(args.restore_zoom,false)
  
  local temp = {}
  
  temp.instrument = rns.instruments[args.instrument_index]
  assert(type(temp.instrument) == "Instrument")
  
  temp.sample = temp.instrument.samples[args.sample_index]
  assert(type(temp.sample) == "Sample")
  
  temp.buffer = xSample.get_sample_buffer(temp.sample)
  assert(type(temp.buffer) == "SampleBuffer")
  
  -- cache some information 
  if args.restore_selection then 
    temp._cached_selection_start = temp.buffer.selection_start
    temp._cached_selection_end = temp.buffer.selection_end
    temp._cached_selected_channel = temp.buffer.selected_channel
  end 

  if args.restore_loop then 
    temp._cached_loop_mode = temp.sample.loop_mode
    temp._cached_loop_start = temp.sample.loop_start
    temp._cached_loop_end = temp.sample.loop_end
  end 

  if args.restore_zoom then 
    temp._cached_display_start = temp.buffer.display_start
    temp._cached_display_length = temp.buffer.display_length
    temp._cached_zoom_factor = temp.buffer.vertical_zoom_factor
  end 

  --temp.new_sample = temp.instrument.samples[temp.new_sample_index]
  --if not temp.new_sample then 
    temp.new_sample_index,temp.drumkit_mode = xInstrument.clone_sample(
      temp.instrument,
      args.sample_index,
      {
        dest_sample_idx = args.force_sample_index,
        sample_rate = args.force_sample_rate,
        bit_depth = args.force_bit_depth,
        num_channels = args.force_channels,
        num_frames = args.force_frames
      }
    )
    temp.new_sample = temp.instrument.samples[temp.new_sample_index]    
  --end 

  assert(type(temp.new_sample) == "Sample")
  assert(type(temp.new_sample.sample_buffer)=="SampleBuffer")

  temp.new_sample.sample_buffer:prepare_sample_data_changes()
  
  return temp

end

---------------------------------------------------------------------------------------------------
-- copy from new buffer, (optionally) remove and finalize changes

function xSampleBufferOperation._finalize(args,temp)
  TRACE("xSampleBufferOperation._finalize()")

  temp.new_sample.sample_buffer:finalize_sample_data_changes()

  -- when in drumkit mode, shift back keyzone mappings
  if temp.drumkit_mode then
    xKeyZone.shift_by_semitones(args.instrument,temp.new_sample_index+1,-1)
  end  

  -- -- rewrite phrases so we don't loose direct sample 
  -- -- references when deleting the original sample
  -- for k,v in ipairs(instr.phrases) do
  --   xPhrase.replace_sample_index(v,sample_idx,sample_idx+1)
  -- end

  -- not creating a new sample: 
  -- remove original sample, and point to it's index
  if not args.create_sample then 
    temp.instrument:delete_sample_at(args.sample_index)
    temp.new_sample_index = args.sample_index
  end

  -- restore settings? 
  local buffer = temp.new_sample.sample_buffer     
  if buffer then 
    if args.restore_selection then 
      buffer.selection_end = temp._cached_selection_end 
      buffer.selection_start = temp._cached_selection_start 
      buffer.selected_channel = temp._cached_selected_channel
    end 
    if args.restore_zoom then 
      buffer.display_range = {
        temp._cached_display_start,
        temp._cached_display_start+temp._cached_display_length 
      }
      buffer.vertical_zoom_factor = temp._cached_zoom_factor 
    end 
  end 
  if args.restore_loop then 
    if temp.new_sample then 
      xSample.set_loop_pos(temp.new_sample,temp._cached_loop_start,temp._cached_loop_end)
      temp.new_sample.loop_mode = temp._cached_loop_mode
    end 
  end 

  if (type(args.on_complete)=="function") then 
    args.on_complete({
      sample = temp.new_sample,
      sample_index = temp.new_sample_index,
      drumkit_mode = temp.drumkit_mode,
    })
  end 

end



