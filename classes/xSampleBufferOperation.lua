--[[===============================================================================================
xSampleBufferOperation
===============================================================================================]]--

--[[--

Manage processing of sample buffers
.

## About 

Use this class to 
* Automatically prepare/finalize buffer before/after processing 
* Keep keyzones and phrases intact while creating new/temp sample [1] 
* Keep/copy basic sample properties like transpose, fine-tune etc. 
* Retain/restore selection size, loop range and zoom settings 
* TODO Run multiple concurrent operations (process slicing)

[1]: Modifying a sample via the Renoise API can result in changes to the keyzone and/or phrases, due to the creation of a temporary sample. This class can automatically detect such changes and retain the original values. 

]]

--=================================================================================================

class 'xSampleBufferOperation'

---------------------------------------------------------------------------------------------------
-- @param ... (vararg)

function xSampleBufferOperation:__init(...)
  TRACE("xSampleBufferOperation:__init()")

  local args = cLib.unpack_args(...)
  --rprint(args)

  --== assign arguments ==-- 
  
  -- number, a valid source instrument index
  self.instrument_index = args.instrument_index
  -- number, a valid source sample index 
  self.sample_index = args.sample_index
  -- function, callback once processing is done
  self.on_complete = args.on_complete 
  -- function, callback for error messages
  self.on_error = args.on_complete 
  -- table, buffer operations {function,function,...}
  self.operations = args.operations or {}
  -- boolean, whether to create sample (default is to replace)
  self.create_sample = cReflection.as_boolean(args.create_sample,false)
  -- boolean, restore/preserve selection 
  self.restore_selection = cReflection.as_boolean(args.restore_selection,false)
  -- boolean, restore/preserve loop settings
  self.restore_loop = cReflection.as_boolean(args.restore_loop,false)
  -- boolean, restore/preserve editor zoom settings
  self.restore_zoom = cReflection.as_boolean(args.restore_zoom,false)
  -- number, define a custom sample index (otherwise after provided)
  self.force_sample_index = args.force_sample_index 
  -- number, defined a fixed bit sample_rate
  self.force_sample_rate = args.force_sample_rate
  -- number, defined a fixed bit depth 
  self.force_bit_depth = args.force_bit_depth
  -- number, define a custom channel count
  self.force_channels = args.force_channels 
  -- number, define a custom buffer length 
  self.force_frames = args.force_frames 

  --== define getters ==-- 

  self.instrument = property(self.get_instrument)
  self.sample = property(self.get_sample)
  self.buffer = property(self.get_buffer)
  self.new_sample = property(self.get_new_sample)
  self.new_buffer = property(self.get_new_buffer)

  --== validate ==--  

  assert(type(self.instrument) == "Instrument")
  assert(type(self.sample) == "Sample")
  assert(type(self.buffer) == "SampleBuffer")

  --== internal ==-- 

  -- number  
  self.new_sample_index = nil 
  -- boolean
  self.drumkit_mode = nil
  -- values to restore 
  self._cached_selection_start = nil
  self._cached_selection_end = nil
  self._cached_selected_channel = nil

end

---------------------------------------------------------------------------------------------------
-- @return renoise.Instrument or nil 

function xSampleBufferOperation:get_instrument()
  return rns.instruments[self.instrument_index]
end

---------------------------------------------------------------------------------------------------
-- @return renoise.Sample or nil 

function xSampleBufferOperation:get_sample()
  return self.instrument.samples[self.sample_index]
end

---------------------------------------------------------------------------------------------------
-- @return renoise.Sample or nil 

function xSampleBufferOperation:get_new_sample()
  return self.instrument.samples[self.new_sample_index]
end

---------------------------------------------------------------------------------------------------
-- @return renoise.SampleBuffer or nil 

function xSampleBufferOperation:get_buffer()
  local sample = self.sample 
  if sample then 
    return xSample.get_sample_buffer(sample)
  end 
end

---------------------------------------------------------------------------------------------------
-- @return renoise.SampleBuffer or nil 

function xSampleBufferOperation:get_new_buffer()
  local sample = self.new_sample 
  if sample then 
    return xSample.get_sample_buffer(sample)
  end 
end


---------------------------------------------------------------------------------------------------
-- execute operations (start processing)

function xSampleBufferOperation:run()
  TRACE("xSampleBufferOperation:run()")

  self:prepare()

  local new_sample = self.new_sample
  local new_buffer = self.new_buffer
  --print("xSampleBufferOperation:run() - new_sample,new_buffer",new_sample,new_buffer)

  for k,v in ipairs(self.operations) do 
    --print("run operation",k,v,type(v))
    if (type(v)=="function") then 
      -- anonymous function (no arguments)
      local success,err = pcall(function()
        v(new_buffer)
      end)
      if not success and err then 
        if (type(self.on_error)=="function") then 
          LOG("*** An error occurred",err)
          self.on_error(err)
        end 
      end 
      
    else 
      error("Unexpected argument")
    end 
  end

  self:finalize()

end

---------------------------------------------------------------------------------------------------
-- prepare for changes, create new/temp buffer 

function xSampleBufferOperation:prepare()
  TRACE("xSampleBufferOperation:prepare()")

  if not self.new_sample then 
    self.new_sample_index,self.drumkit_mode = xInstrument.clone_sample(
      self.instrument,
      self.sample_index,
      self.force_sample_index,
      self.force_sample_rate,
      self.force_bit_depth,
      self.force_channels,
      self.force_frames)
  end 

  if self.restore_selection then 
    self._cached_selection_start = self.buffer.selection_start
    self._cached_selection_end = self.buffer.selection_end
    self._cached_selected_channel = self.buffer.selected_channel
  end 

  if self.restore_loop then 
    self._cached_loop_mode = self.sample.loop_mode
    self._cached_loop_start = self.sample.loop_start
    self._cached_loop_end = self.sample.loop_end
  end 

  if self.restore_zoom then 
    self._cached_display_start = self.buffer.display_start
    self._cached_display_length = self.buffer.display_length
    self._cached_zoom_factor = self.buffer.vertical_zoom_factor
  end 

  -- confirm that buffer got created 
  assert(type(self.new_buffer)=="SampleBuffer")

  self.new_buffer:prepare_sample_data_changes()

end

---------------------------------------------------------------------------------------------------
-- copy from new buffer, (optionally) remove and finalize changes

function xSampleBufferOperation:finalize()
  TRACE("xSampleBufferOperation:finalize()")

  self.new_buffer:finalize_sample_data_changes()

  -- when in drumkit mode, shift back keyzone mappings
  if self.drumkit_mode then
    xKeyZone.shift_by_semitones(self.instrument,self.new_sample_index+1,-1)
  end  

  -- -- rewrite phrases so we don't loose direct sample 
  -- -- references when deleting the original sample
  -- for k,v in ipairs(instr.phrases) do
  --   xPhrase.replace_sample_index(v,sample_idx,sample_idx+1)
  -- end

  if not self.create_sample then 
    self.sample:copy_from(self.new_sample)
    self.instrument:delete_sample_at(self.new_sample_index)
  end

  self.sample_index = self.create_sample and self.new_sample_index or self.sample_index

  -- restore settings? 
  local buffer = self.sample.sample_buffer     
  if buffer then 
    if self.restore_selection then 
      buffer.selection_end = self._cached_selection_end 
      buffer.selection_start = self._cached_selection_start 
      buffer.selected_channel = self._cached_selected_channel
    end 
    if self.restore_zoom then 
      --print("restore_zoom",self._cached_zoom_factor)
      buffer.display_range = {
        self._cached_display_start,
        self._cached_display_start+self._cached_display_length 
      }
      buffer.vertical_zoom_factor = self._cached_zoom_factor 
    end 
  end 
  if self.restore_loop then 
    if self.sample then 
      xSample.set_loop_pos(self.sample,self._cached_loop_start,self._cached_loop_end)
      self.sample.loop_mode = self._cached_loop_mode
    end 
  end 

  if (type(self.on_complete)=="function") then 
    self:on_complete(self)
  end 

end



