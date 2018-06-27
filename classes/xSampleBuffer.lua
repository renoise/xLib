--[[===============================================================================================
xSample
===============================================================================================]]--

--[[--

Static methods for working with renoise.SampleBuffer objects
.

## About

This class contains a selection of processing functions that can be used for 
* getting statistics (number of actual bits, channels used, etc.)
* inserting/resizing sample data (primitive stretching)
* shifting/rotating sample data 
* adjusting amplitude 

The class is designed to work as standalone, or in combination with xSampleBufferOperation
If used standalone, you need to create a temporary sample and apply changes to the buffer 
before replacing the original sample.


## How to use 

  TODO... 

]]

--=================================================================================================
require (_clibroot.."cDocument")

class 'xSampleBuffer' (cDocument)

xSampleBuffer.SAMPLE_INFO = {
  EMPTY = 1,
  SILENT = 2,
  PAN_LEFT = 4,
  PAN_RIGHT = 8,
  DUPLICATE = 16,
  MONO = 32,
  STEREO = 64,
}

xSampleBuffer.SAMPLE_CHANNELS = {
  LEFT = 1,
  RIGHT = 2,
  BOTH = 3,
}

xSampleBuffer.BIT_DEPTH = {
  0,
  8,
  16,
  24,
  32
}

xSampleBuffer.SAMPLE_RATE = {
  11025,
  22050, 
  32000,
  44100, 
  48000, 
  88200, 
  96000, 
  192000,
}

xSampleBuffer.DEFAULT_BIT_DEPTH = 16
xSampleBuffer.DEFAULT_SAMPLE_RATE = 48000
xSampleBuffer.DEFAULT_NUM_CHANNELS = 1
xSampleBuffer.DEFAULT_NUM_FRAMES = 168

-- utility table for channel selecting
xSampleBuffer.CH_UTIL = {
  --{0,0,{1,1}}, -- mono,selected_channel is 3
  --{{1,1},{2,2},{1,2}} -- stereo
  {0,0,{{1,1},1}}, -- mono,selected_channel is 3
  {{{1,2},1},{{2,1},1},{{1,2},2}}, -- stereo
  
}

-- exportable properties (cDocument)
xSampleBuffer.DOC_PROPS = {
  bit_depth = "number",
  sample_rate = "number",
  number_of_frames = "number",
  number_of_channels = "number",
}

---------------------------------------------------------------------------------------------------
-- Constructor
---------------------------------------------------------------------------------------------------
-- create a 'virtual' sample-buffer object, unbound from Renoise 
-- @param (vararg or renoise.SampleBuffer)

function xSampleBuffer:__init(...)

  local args = cLib.unpack_args(...)
  --print("args",rprint(args),type(args))

  self.bit_depth = args.bit_depth or xSampleBuffer.DEFAULT_BIT_DEPTH
  self.sample_rate = args.sample_rate or xSampleBuffer.DEFAULT_SAMPLE_RATE
  self.number_of_channels = args.number_of_channels or xSampleBuffer.DEFAULT_NUM_CHANNELS
  self.number_of_frames = args.number_of_frames or xSampleBuffer.DEFAULT_NUM_FRAMES

end

---------------------------------------------------------------------------------------------------
-- Selections
---------------------------------------------------------------------------------------------------
-- select everything 

function xSampleBuffer.select_all(buffer)
  buffer.selection_end = buffer.number_of_frames
  buffer.selection_start = 1
end

---------------------------------------------------------------------------------------------------
-- get the size of the selected range (1 - #number_of_frames)
-- @param renoise.SampleBuffer

function xSampleBuffer.get_selection_range(buffer)
  --assert(type(buffer)=="SampleBuffer")
  return buffer.selection_end - buffer.selection_start + 1
end

---------------------------------------------------------------------------------------------------
-- check if right channel is selected 
-- @return boolean

function xSampleBuffer.right_is_selected(buffer)
  return (buffer.selected_channel == renoise.SampleBuffer.CHANNEL_LEFT_AND_RIGHT)
    or (buffer.selected_channel == renoise.SampleBuffer.CHANNEL_RIGHT)
end

---------------------------------------------------------------------------------------------------
-- check if left channel is selected 
-- @return boolean

function xSampleBuffer.left_is_selected(buffer)
  return (buffer.selected_channel == renoise.SampleBuffer.CHANNEL_LEFT_AND_RIGHT)
    or (buffer.selected_channel == renoise.SampleBuffer.CHANNEL_LEFT)
end

---------------------------------------------------------------------------------------------------
-- toggle right channel, but never remove selection

function xSampleBuffer.selection_toggle_right(buffer)
  if (buffer.selected_channel == renoise.SampleBuffer.CHANNEL_LEFT) then 
    buffer.selected_channel = renoise.SampleBuffer.CHANNEL_LEFT_AND_RIGHT
  elseif (buffer.selected_channel == renoise.SampleBuffer.CHANNEL_LEFT_AND_RIGHT) then
    buffer.selected_channel = renoise.SampleBuffer.CHANNEL_LEFT
  end 
end

---------------------------------------------------------------------------------------------------
-- toggle left channel, but never remove selection

function xSampleBuffer.selection_toggle_left(buffer)
  if (buffer.selected_channel == renoise.SampleBuffer.CHANNEL_RIGHT) then 
    buffer.selected_channel = renoise.SampleBuffer.CHANNEL_LEFT_AND_RIGHT
  elseif (buffer.selected_channel == renoise.SampleBuffer.CHANNEL_LEFT_AND_RIGHT) then
    buffer.selected_channel = renoise.SampleBuffer.CHANNEL_RIGHT
  end 
end

---------------------------------------------------------------------------------------------------
-- Processing
---------------------------------------------------------------------------------------------------
-- making up the function for modulating
-- @param fn (function)
-- @return function

function xSampleBuffer.mod_fn_shaped(fn)
  local type_x = type(fn)
  if (type_x == "number") then 
    return function (x) 
      return fn*x 
    end
  elseif (type_x == "function") then 
    return fn
  else 
    return function(x) 
      return x 
    end
  end
end

---------------------------------------------------------------------------------------------------
-- return the function that return the selected sample data
-- (source: modulation.lua)
-- @param renoise.SampleBuffer
-- @param rough (boolean)
-- @param sel_start (number)
-- @param sel_end (number)

function xSampleBuffer.copy_fn_fn(buffer,rough,sel_start,sel_end)
  TRACE("xSampleBuffer.copy_fn_fn()",buffer,rough,sel_start,sel_end)
  
  assert(type(buffer)=="SampleBuffer")

  sel_start = sel_start or buffer.selection_start
  sel_end = sel_start or buffer.selection_end
  
  local range = sel_end - sel_start + 1
  local rgh = (not rough) and 1 or 0 

  return function (_x,ch)
    local x =  cWaveform.cycle_fmod(_x)
    local xx = cWaveform.cycle_fmod(x*range,range+1)
    local x1 = math.floor(xx)  -- <= (range -1)
    local x2 = x1 +1
    if (x2 >= range) then
      -- near the last point
      x2 = x1 
    end 
    local d = (xx - x1) * rgh
    return 
      buffer:sample_data(ch,x1 + sel_start) * (1-d) + 
      buffer:sample_data(ch,x2 + sel_start) * d
  end

end


---------------------------------------------------------------------------------------------------
-- == Copy to table == --
-- Use with 'cWaveform.table2fn'

function xSampleBuffer.wave2tbl(...)
  TRACE("xSampleBuffer.wave2tbl(...)")

  local args = xSampleBuffer.parse_processing_args(...)

  local ch_util = {
    {0,0,{1,1}}, -- mono,selected_channel is 3
    {{1,1},{2,2},{1,2}} -- stereo
  }
  local _ch = ch_util[args.number_of_channels][args.selected_channel]        
  
  local ch1,ch2 = _ch[1],_ch[2]    
  --print("ch1,ch2",ch1,ch2)
  local tbl = {{},{}}  
  for i_ch = ch1,ch2 do
    for i = 1,args.range do
      tbl[i_ch][i] = args.buffer:sample_data(i_ch,i + args.selection_start -1)
    end
    -- add last point data for reference (??)
    if (math.abs(tbl[i_ch][args.range]) <= 2/32767) then
      tbl[i_ch][args.range +1] = 0
    else  
      tbl[i_ch][args.range +1] = tbl[i_ch][args.range]
    end
  end
 return tbl
end   

----------------------------------------------------------------------------------------------------
-- Analysis
----------------------------------------------------------------------------------------------------
-- credit goes to dblue
-- @param buffer (renoise.SampleBuffer)
-- @return int (0 when no sample data)

function xSampleBuffer.get_bit_depth(buffer)
  TRACE("xSampleBuffer.get_bit_depth(buffer)",buffer)

  assert(buffer.has_sample_data,"Sample buffer is empty")

  local function reverse(t)
    local nt = {}
    local size = #t + 1
    for k,v in ipairs(t) do
      nt[size - k] = v
    end
    return nt
  end
  
  local function tobits(num)
    local t = {}
    while num > 0 do
      local rest = num % 2
      t[#t + 1] = rest
      num = (num - rest) / 2
    end
    t = reverse(t)
    return t
  end
  
  -- Vars and crap
  local bit_depth = 0
  local sample_max = math.pow(2, 32) / 2
  local channels = buffer.number_of_channels
  local frames = buffer.number_of_frames
  
  for f = 1, frames do
    for c = 1, channels do
    
      -- Convert float to 32-bit unsigned int
      local s = (1 + buffer:sample_data(c, f)) * sample_max
      
      -- Measure bits used
      local bits = tobits(s)
      for b = 1, #bits do
        if bits[b] == 1 then
          if b > bit_depth then
            bit_depth = b
          end
        end
      end

    end
  end
    
  return xSampleBuffer.bits_to_xbits(bit_depth),bit_depth

end

---------------------------------------------------------------------------------------------------
-- convert any bit-depth to a valid xSample representation
-- @param num_bits (int)
-- @return int (xSampleBuffer.BIT_DEPTH)

function xSampleBuffer.bits_to_xbits(num_bits)
  if (num_bits == 0) then
    return 0
  end
  for k,xbits in ipairs(xSampleBuffer.BIT_DEPTH) do
    if (num_bits <= xbits) then
      return xbits
    end
  end
  error("Number is outside allowed range")

end


----------------------------------------------------------------------------------------------------
-- check if sample buffer has duplicate channel data, is hard-panned or silent, etc.
-- @param buffer  (renoise.SampleBuffer)
-- @return enum (xSampleBuffer.SAMPLE_[...])

function xSampleBuffer.get_channel_info(buffer)
  TRACE("xSampleBuffer.get_channel_info(buffer)",buffer)

  if not buffer.has_sample_data then
    return xSampleBuffer.SAMPLE_INFO.EMPTY
  end

  -- not much to do with a monophonic sound...
  if (buffer.number_of_channels == 1) then
    if xSampleBuffer.is_silent(buffer,xSampleBuffer.SAMPLE_CHANNELS.LEFT) then
      return xSampleBuffer.SAMPLE_INFO.SILENT
    else
      return xSampleBuffer.SAMPLE_INFO.MONO
    end
  end

  local l_pan = true
  local r_pan = true
  local silent = true
  local duplicate = true

  local l = nil
  local r = nil
  local frames = buffer.number_of_frames
  for f = 1, frames do
    l = buffer:sample_data(1,f)
    r = buffer:sample_data(2,f)
    if (l ~= 0) then
      silent = false
      r_pan = false
    end
    if (r ~= 0) then
      silent = false
      l_pan = false
    end
    if (l ~= r) then
      duplicate = false
      if not silent and not r_pan and not l_pan then
        return xSampleBuffer.SAMPLE_INFO.STEREO
      end
    end
  end

  if silent then
    return xSampleBuffer.SAMPLE_INFO.SILENT
  elseif duplicate then
    return xSampleBuffer.SAMPLE_INFO.DUPLICATE
  elseif r_pan then
    return xSampleBuffer.SAMPLE_INFO.PAN_RIGHT
  elseif l_pan then
    return xSampleBuffer.SAMPLE_INFO.PAN_LEFT
  end

  return xSampleBuffer.SAMPLE_INFO.STEREO

end

----------------------------------------------------------------------------------------------------
-- check if the sample buffer contains leading or trailing silence
-- @param buffer (renoise.SampleBuffer)
-- @param channels (xSampleBuffer.SAMPLE_CHANNELS)
-- @param [threshold] (number), values below this level is considered silence (default is 0)
-- @return table
--  start_frame 
--  end_frame 

function xSampleBuffer.detect_leading_trailing_silence(buffer,channels,threshold)
  TRACE("xSampleBuffer.detect_leading_trailing_silence(buffer,channels,threshold)",buffer,channels,threshold)

  assert(buffer.has_sample_data,"Sample buffer is empty")

  if not threshold then 
    threshold = 0
  end

  local frames = buffer.number_of_frames
  local last_frame_value = nil
  local first_frame_with_signal = nil
  local first_silent_frame_after_signal = nil

  local compare_fn = function(frame,val) 
    local abs_val = math.abs(val)
    if (abs_val > threshold) then 
      if not first_frame_with_signal then 
        first_frame_with_signal = frame 
        --print("first_frame_with_signal",frame,abs_val)
      end 
      first_silent_frame_after_signal = nil
    else
      if (last_frame_value and last_frame_value > threshold) then 
        first_silent_frame_after_signal = frame
        --print("first_silent_frame_after_signal",frame,abs_val)
      end 
    end 
    last_frame_value = abs_val
  end

  if (channels == xSampleBuffer.SAMPLE_CHANNELS.BOTH) then
    for f = 1, frames do
      -- use averaged value 
      local val = (buffer:sample_data(1,f) + buffer:sample_data(2,f)) / 2
      compare_fn(f,val)
    end
  elseif (channels == xSampleBuffer.SAMPLE_CHANNELS.LEFT) then
    for f = 1, frames do
      compare_fn(f,buffer:sample_data(1,f))
    end
  elseif (channels == xSampleBuffer.SAMPLE_CHANNELS.RIGHT) then
    for f = 1, frames do
      compare_fn(f,buffer:sample_data(2,f))
    end
  end

  return first_frame_with_signal,first_silent_frame_after_signal

end


----------------------------------------------------------------------------------------------------
-- check if the indicated sample buffer is silent
-- @param buffer (renoise.SampleBuffer)
-- @param channels (xSampleBuffer.SAMPLE_CHANNELS)
-- @return bool (or nil if no data)

function xSampleBuffer.is_silent(buffer,channels)
  TRACE("xSampleBuffer.is_silent(buffer,channels)",buffer,channels)

  assert(buffer.has_sample_data,"Sample buffer is empty")

  local frames = buffer.number_of_frames

  if (channels == xSampleBuffer.SAMPLE_CHANNELS.BOTH) then
    for f = 1, frames do
      if (buffer:sample_data(1,f) ~= 0) or 
        (buffer:sample_data(2,f) ~= 0) 
      then
        return false
      end
    end
  elseif (channels == xSampleBuffer.SAMPLE_CHANNELS.LEFT) then
    for f = 1, frames do
      if (buffer:sample_data(1,f) ~= 0) then
        return false
      end
    end
  elseif (channels == xSampleBuffer.SAMPLE_CHANNELS.RIGHT) then
    for f = 1, frames do
      if (buffer:sample_data(2,f) ~= 0) then
        return false
      end
    end
  end

  return true

end

---------------------------------------------------------------------------------------------------
-- select region in waveform editor (clamp to valid range)
-- @param buffer (renoise.SampleBuffer)
-- @param sel_start (int)
-- @param sel_end (int)
-- @return boolean, string (when failed to select)

function xSampleBuffer.set_buffer_selection(buffer,sel_start,sel_end)
  TRACE("xSampleBuffer.set_buffer_selection()",buffer,sel_start,sel_end)
  
  assert(buffer.has_sample_data,"Sample buffer is empty")

  local min = 1
  local max = buffer.number_of_frames  
  
  buffer.selection_range = {
    cLib.clamp_value(sel_start,min,max),
    cLib.clamp_value(sel_end,min,max),
  }

end

---------------------------------------------------------------------------------------------------
-- Sample Offsets (0x0S Effect) & Position
---------------------------------------------------------------------------------------------------
-- with small buffer sizes, not all offsets are valid 
-- this method returns the "missing" and "filled" ones as separate tables
-- @return table<number>, values between 0x00 - 0xFF 

function xSampleBuffer.get_offset_indices(num_frames)
  TRACE("xSampleBuffer.get_offset_indices(num_frames)",num_frames)

  local unit = num_frames/256
  local last_n = 0
  local gaps,indices = {},{0}
  for k = 1,256 do
    local val = unit*k
    local n = cLib.round_value(val)
    if (last_n == n) then 
      table.insert(gaps,k)
    else 
      table.insert(indices,k)
    end
    last_n = n
  end
  return indices,gaps
end

---------------------------------------------------------------------------------------------------
-- check for gaps, return first viable offset
-- @param offset (number), between 0x00 and 0xFF
-- @param reverse (boolean), match in reverse
-- @return number 

function xSampleBuffer.get_nearest_offset(num_frames,offset,reverse)
  TRACE("xSampleBuffer.get_nearest_offset(num_frames,offset,reverse)",num_frames,offset,reverse)

  local indices,_ = xSampleBuffer.get_offset_indices(num_frames)
  return cTable.nearest(indices,offset)  

end

---------------------------------------------------------------------------------------------------
-- return next viable offset
-- @param offset (number), between 0x00 and 0xFF
-- @return number 

function xSampleBuffer.get_next_offset(num_frames,offset)
  TRACE("xSampleBuffer.get_next_offset(num_frames,offset)",num_frames,offset)

  local indices,_ = xSampleBuffer.get_offset_indices(num_frames)
  --print("indices",rprint(indices))
  return cTable.next(indices,offset)  

end

---------------------------------------------------------------------------------------------------
-- return previous viable offset
-- @param offset (number), between 0x00 and 0xFF
-- @return number 

function xSampleBuffer.get_previous_offset(num_frames,offset)
  TRACE("xSampleBuffer.get_previous_offset(num_frames,offset)",num_frames,offset)

  local indices,_ = xSampleBuffer.get_offset_indices(num_frames)
  return cTable.previous(indices,offset)  

end

---------------------------------------------------------------------------------------------------
-- get a "OS" offset by position in buffer 
-- (NB: this method does not support/detect the Amiga/FT2 compatibility mode)
-- @param buffer (renoise.SampleBuffer)
-- @param frame (number)
-- @return number or nil if out of bounds

function xSampleBuffer.get_offset_by_frame(buffer,frame)
  TRACE("xSampleBuffer.get_offset_by_frame(buffer,frame)",buffer,frame)

  assert(buffer.has_sample_data,"Sample buffer is empty")

  if (frame <= 1) then 
    return 0 -- special case  
  end

  local num_frames = buffer.number_of_frames
  local offset = (frame-1)*(0x100/buffer.number_of_frames)

  -- handle small buffers differently 
  if (num_frames < 0x100) then 
    offset = xSampleBuffer.get_nearest_offset(num_frames,cLib.round_value(offset),true)
  else 
    offset = cLib.round_value(offset)
  end 

  --print("*** get_offset_by_frame - in,out",frame,offset)  
  return offset
  
end

---------------------------------------------------------------------------------------------------
-- get a "OS" offset by position in buffer 
-- (NB: this method does not support/detect the Amiga/FT2 compatibility mode)
-- @param buffer (renoise.SampleBuffer)
-- @param offset (number), between 0x00 and 0xFF
-- @return number or nil if out of bounds

function xSampleBuffer.get_frame_by_offset(buffer,offset)
  TRACE("xSampleBuffer.get_frame_by_offset(buffer,offset)",buffer,offset)

  assert(buffer.has_sample_data,"Sample buffer is empty")

  if (offset == 0) then
    return 1 
  end

  local num_frames = buffer.number_of_frames
  if (offset >= 0x100) then 
    return num_frames
  end

  if (num_frames < 0x100) then 
    -- compensate for gaps in small samples 
    offset = xSampleBuffer.get_nearest_offset(num_frames,offset)
  end

  local frame = 1+(offset*num_frames)/0x100
  frame = math.min(frame,num_frames)

  --print("*** get_frame_by_offset - in,out",offset,cLib.round_value(frame),frame)
  return cLib.round_value(frame)

end

---------------------------------------------------------------------------------------------------
-- get a buffer position by "line"
-- @param buffer (renoise.SampleBuffer)
-- @param line (number) supports fractional values 
-- @param lpb (number) will use song LPB if not defined
-- @param bpm (number) will use song BPM if not defined
-- @return number or nil if out of bounds/no buffer

function xSampleBuffer.get_frame_by_line(buffer,line,lpb,bpm)
  TRACE("xSampleBuffer.get_frame_by_line(buffer,line,lpb,bpm)",buffer,line,lpb,bpm)

  assert(buffer.has_sample_data,"Sample buffer is empty")

  lpb = not lpb and rns.transport.lpb or lpb
  bpm = not bpm and rns.transport.bpm or bpm

  local lines_per_minute = (rns.transport.lpb*rns.transport.bpm)
  local lines_per_sec = 60/lines_per_minute
  local line_frames = lines_per_sec*buffer.sample_rate
  return line*line_frames

end

---------------------------------------------------------------------------------------------------
-- get a buffer position by "beat"
-- @param buffer (renoise.SampleBuffer)
-- @param beat (number) supports fractional values
-- @param lpb (number) will use song LPB if not defined
-- @param bpm (number) will use song BPM if not defined
-- @return number or nil if out of bounds

function xSampleBuffer.get_frame_by_beat(buffer,beat,lpb,bpm)
  TRACE("xSampleBuffer.get_frame_by_beat(buffer,beat,lpb,bpm)",buffer,beat,lpb,bpm)
  
  lpb = not lpb and rns.transport.lpb or lpb
  bpm = not bpm and rns.transport.bpm or bpm
  
  return (xSampleBuffer.get_frame_by_line(buffer,beat*lpb))

end

---------------------------------------------------------------------------------------------------
-- get a line by position in buffer 
-- @param buffer (renoise.SampleBuffer)
-- @param frame (number)
-- @param lpb (number) will use song LPB if not defined
-- @param bpm (number) will use song BPM if not defined
-- @return number or nil if out of bounds

function xSampleBuffer.get_beat_by_frame(buffer,frame,bpm)
  TRACE("xSampleBuffer.get_beat_by_frame(buffer,frame,bpm)",buffer,frame,bpm)

  assert(type(buffer)=="SampleBuffer")
  assert(type(frame)=="number")
  assert(buffer.has_sample_data,"Sample buffer is empty")

  bpm = not bpm and rns.transport.bpm or bpm
  return ((frame) / ((1 / rns.transport.bpm * 60) * buffer.sample_rate)) 

end

---------------------------------------------------------------------------------------------------
-- get a beat by position in buffer 
-- @param buffer (renoise.SampleBuffer)
-- @param frame (number)
-- @param lpb (number) will use song LPB if not defined
-- @param bpm (number) will use song BPM if not defined
-- @return number or nil if out of bounds

function xSampleBuffer.get_line_by_frame(buffer,frame,lpb,bpm)
  TRACE("xSampleBuffer.get_line_by_frame(buffer,frame,lpb,bpm)",buffer,frame,lpb,bpm)

  lpb = not lpb and rns.transport.lpb or lpb
  local beat = xSampleBuffer.get_beat_by_frame(buffer,frame,bpm)
  --print("get_beat_by_frame - beat",beat)
  return (lpb * beat)

end


---------------------------------------------------------------------------------------------------
-- parse processing arguments, provide buffer defaults if undefined 
-- @return table

function xSampleBuffer.parse_processing_args(...)

  local args = cLib.unpack_args(...)
  --print(">>> args...")
  --rprint(args)

  assert(type(args.buffer)=="SampleBuffer")

  args.number_of_frames = args.number_of_frames or args.buffer.number_of_frames
  args.number_of_channels = args.number_of_channels or args.buffer.number_of_channels
  args.selected_channel = args.selected_channel or args.buffer.selected_channel
  args.selection_start = args.selection_start or args.buffer.selection_start
  args.selection_end = args.selection_end or args.buffer.selection_end
  args.range = xSampleBuffer.get_selection_range(args)

  return args

end

---------------------------------------------------------------------------------------------------
-- Processing methods 
---------------------------------------------------------------------------------------------------
-- create waveform from waveform/modulator function 

function xSampleBuffer.create_wave_fn(...)
  TRACE("xSampleBuffer.create_wave_fn(...)")

  local args = xSampleBuffer.parse_processing_args(...)
  assert(type(args.fn)=="function")
  -- if args.mod_fn then
  --   assert(type(args.mod_fn)=="function","Expected function, got"..type(args.mod_fn))
  -- end

  local do_process = function(new_buffer)
    TRACE("[make_wave] do_process - new_buffer",new_buffer)
    for ch = 1, args.number_of_channels do
      local fn_shpd = xSampleBuffer.get_frame_generator_fn(args.fn,ch,args.mod_fn,
        args.buffer,args.selection_start,args.range,args.selected_channel)
      for fr = 1,args.selection_start-1 do
        new_buffer:set_sample_data(ch,fr,args.buffer:sample_data(ch,fr))
      end
      for fr = args.selection_start,args.selection_end do
        new_buffer:set_sample_data(ch,fr,fn_shpd(fr))
      end        
      for fr = args.selection_end+1,args.number_of_frames do
        new_buffer:set_sample_data(ch,fr,args.buffer:sample_data(ch,fr))  
      end
    end      
  end 

  return do_process

end

---------------------------------------------------------------------------------------------------
-- extend sample length (pad with silent frames)
-- @param extend_by (number), how many frames - positive @ end or negative @ start

function xSampleBuffer.extend(...)
  TRACE("xSampleBuffer.extend(...)")
  
  local args = xSampleBuffer.parse_processing_args(...)
  assert(type(args.extend_by)=="number")

  local do_process = function(new_buffer)

    local insert_before = (args.extend_by <= 0)
    local content_offset = insert_before and math.abs(args.extend_by) or 0
    --print("content_offset",content_offset)

    for ch = 1,args.number_of_channels do
      if insert_before then 
        for fr = 1,math.abs(args.extend_by) do
          new_buffer:set_sample_data(ch,fr,0)
        end
      end 
      for fr = 1,args.number_of_frames do
        new_buffer:set_sample_data(ch,fr+content_offset,args.buffer:sample_data(ch,fr))
      end
      if not insert_before then 
        for fr = args.number_of_frames+1,args.extend_by do
          new_buffer:set_sample_data(ch,fr,0)
        end
      end
    end
  end 

  return do_process

end

---------------------------------------------------------------------------------------------------
-- insert data in selected channel(s)

function xSampleBuffer.sweep_ins(...)
  TRACE("xSampleBuffer.sweep_ins(...)")

  local args = xSampleBuffer.parse_processing_args(...)

  if (args.selected_channel == renoise.SampleBuffer.CHANNEL_LEFT_AND_RIGHT) then
    return xSampleBuffer.ins_in_all_ch(...)
  else
    return xSampleBuffer.ins_in_one_ch(...)
  end
end

---------------------------------------------------------------------------------------------------
-- insert data in all channels

function xSampleBuffer.ins_in_all_ch(...)
  TRACE("xSampleBuffer.ins_in_all_ch(...)")

  local args = xSampleBuffer.parse_processing_args(...)
  local end_point = args.number_of_frames + args.range

  local do_process = function(new_buffer)
    for ch = 1,args.number_of_channels do
      for fr = 1,args.selection_start -1 do
        new_buffer:set_sample_data(ch,fr,args.buffer:sample_data(ch,fr))
      end
      for fr = args.selection_start ,args.selection_end do
        new_buffer:set_sample_data(ch,fr,0)
      end
      for fr = args.selection_end +1,end_point do
        new_buffer:set_sample_data(ch,fr,args.buffer:sample_data(ch,fr - args.range))
      end        
    end      
  end

  return do_process

end

---------------------------------------------------------------------------------------------------
-- insert data in a single channel

function xSampleBuffer.ins_in_one_ch(...)
  TRACE("xSampleBuffer.ins_in_one_ch(...)")
  
  local args = xSampleBuffer.parse_processing_args(...)
  
  local end_point = args.number_of_frames + args.range
  local ch1,ch2
  ch1 = xSampleBuffer.CH_UTIL[args.number_of_channels][args.selected_channel][1][1]  
  ch2 = xSampleBuffer.CH_UTIL[args.number_of_channels][args.selected_channel][1][2]   

  local do_process = function(new_buffer) 
    -- in selected channel
    for fr = 1,args.selection_start -1 do
      new_buffer:set_sample_data(ch1,fr,args.buffer:sample_data(ch1,fr))
    end
    for fr = args.selection_start ,args.selection_end do
      new_buffer:set_sample_data(ch1,fr,0)
    end
    for fr = args.selection_end +1,end_point do
      new_buffer:set_sample_data(ch1,fr,args.buffer:sample_data(ch1,fr - args.range))
    end        

    -- in another channel
    for fr = 1,args.number_of_frames do
      new_buffer:set_sample_data(ch2,fr,args.buffer:sample_data(ch2,fr))
    end
    for fr = args.number_of_frames +1,end_point do
      new_buffer:set_sample_data(ch2,fr,0)
    end  
  end 

  return do_process

end

---------------------------------------------------------------------------------------------------
-- return function that can generate frames 
-- note: only generate data for the selected channel(s)
-- @param fn (function)
-- @param ch (number)
-- @param mod_fn (function), modulating frequency  
-- @param buffer (renoise.SampleBuffer)
-- @param sel_start (number)
-- @param range (number)
-- @param sel_channel (number)
-- @return function 

function xSampleBuffer.get_frame_generator_fn(
  fn,ch,mod_fn,buffer,sel_start,range,sel_channel)

  if (ch == sel_channel or 
    sel_channel == renoise.SampleBuffer.CHANNEL_LEFT_AND_RIGHT) 
  then -- generate
    return function (fr)
      local x = (fr-sel_start)/range
      return fn(xSampleBuffer.mod_fn_shaped(mod_fn)(x),ch)
    end
  else -- pass existing
    return function (fr)
      return buffer:sample_data(ch,fr)
    end
  end
end

---------------------------------------------------------------------------------------------------
-- silence entire sample 

function xSampleBuffer.empty_smple(...)
  TRACE("xSampleBuffer.empty_smple(...)")

  local args = xSampleBuffer.parse_processing_args(...)

  local do_process = function(new_buffer)
    for ch = 1,args.number_of_channels do
      for fr = 1,args.number_of_frames do
        new_buffer:set_sample_data(ch,fr,0)
      end
    end
  end

  return do_process

end

---------------------------------------------------------------------------------------------------
-- trim: delete samples outside selection 

function xSampleBuffer.trim(...)
  TRACE("xSampleBuffer.trim(...)")

  local args = xSampleBuffer.parse_processing_args(...)

  local do_process = function(new_buffer)
    if (args.range ~= new_buffer.number_of_frames) then 
      error("Buffer length mismatch",args.range,new_buffer.number_of_frames)
    end
    local offset = args.selection_start-1
    for ch = 1,args.number_of_channels do
      for fr = 1,args.range do
        --print("fr",fr)
        new_buffer:set_sample_data(ch,fr,args.buffer:sample_data(ch,fr+offset))
      end
    end
  end

  return do_process

end

---------------------------------------------------------------------------------------------------
-- delete from selected channel(s) while preserving length 

function xSampleBuffer.sync_del(...)
  TRACE("xSampleBuffer.sync_del(...)")

  local args = xSampleBuffer.parse_processing_args(...)

  if (args.selected_channel == renoise.SampleBuffer.CHANNEL_LEFT_AND_RIGHT) then
    return xSampleBuffer.del_in_all_ch(...)
  else
    return xSampleBuffer.del_in_one_ch(...)
  end

end

---------------------------------------------------------------------------------------------------
-- delete from all channels (see sync_del)
-- @buffer, source buffer

function xSampleBuffer.del_in_all_ch(...)
  TRACE("xSampleBuffer.del_in_all_ch(...)",...)

  local args = xSampleBuffer.parse_processing_args(...)

  local end_point = args.number_of_frames - args.range
  if end_point <= 0 then 
    -- entire sample
    return xSampleBuffer.empty_smple(...) 
  end
  
  local do_process = function(new_buffer)
    for ch = 1,args.number_of_channels do
      for fr = 1,args.selection_start -1 do
        new_buffer:set_sample_data(ch,fr,args.buffer:sample_data(ch,fr))
      end
      for fr = args.selection_start,end_point do
        new_buffer:set_sample_data(ch,fr,args.buffer:sample_data(ch,fr+args.range))
      end
    end      
  end

  return do_process

end

---------------------------------------------------------------------------------------------------
-- delete from single channel (see sync_del)
-- @buffer, source buffer

function xSampleBuffer.del_in_one_ch(...)
  TRACE("xSampleBuffer.del_in_one_ch(...)")

  local args = xSampleBuffer.parse_processing_args(...)

  local ch1,ch2
    local ch_util = {
    --{0,0,{1,1}}, -- mono,selected_channel is 3
    --{{1,1},{2,2},{1,2}} -- stereo
    {0,0,{{1,1},1}}, -- mono,selected_channel is 3
    {{{1,2},1},{{2,1},1},{{1,2},2}}, -- stereo
  }
  ch1 = ch_util[args.number_of_channels][args.selected_channel][1][1]  
  ch2 = ch_util[args.number_of_channels][args.selected_channel][1][2] 
  
  local do_process = function()
    --in selected channel
    if (args.selection_start > 1) then
      for fr = 1, args.selection_start -1 do
        new_buffer:set_sample_data(ch1,fr,args.buffer:sample_data(ch1,fr))
      end
    end
    for fr = args.selection_start, args.number_of_frames -args.range do
      new_buffer:set_sample_data(ch1,fr,args.buffer:sample_data(ch1,(fr+args.range)))
    end
    if args.number_of_frames -args.range +1 <  args.number_of_frames then
      for fr = args.number_of_frames -args.range +1,args.number_of_frames do
        new_buffer:set_sample_data(ch1,fr,0)
      end
    end
    -- in another channel
    for fr = 1,args.number_of_frames do
      new_buffer:set_sample_data(ch2,fr,args.buffer:sample_data(ch2,fr))
    end     
  end     
  
  return do_process

end

---------------------------------------------------------------------------------------------------
-- shift/rotate the specified region
-- @param frame (number, number of frames to shift by)
-- @param range (number)
-- @param buffer (renoise.SampleBuffer)
-- @return function

function xSampleBuffer.phase_shift(...)
  TRACE("xSampleBuffer.phase_shift(...)",...)
  
  local args = xSampleBuffer.parse_processing_args(...)
  
  args.frame = math.floor(args.frame)  
  local point = cLib.round_with_precision(math.fmod(math.fmod(args.frame,args.range)+args.range,args.range)) 
  if (point == 0) then
    -- nothing to do 
    --print("*** phase_shift - nothing to do...")
    return nil
  end
  
  local pt_with_ch_in_phase_shift = function (point,ch)
    if (ch == args.buffer.selected_channel or 
      args.buffer.selected_channel == renoise.SampleBuffer.CHANNEL_LEFT_AND_RIGHT) 
    then
      return point
    else 
      return 0
    end
  end
  
  local do_process = function(new_buffer)
    TRACE("[phase_shift] do_process - new_buffer",new_buffer)

    if (args.selection_start > 1) then
      for ch = 1,args.number_of_channels do
        for fr = 1,(args.selection_start -1) do
          new_buffer:set_sample_data(ch,fr,args.buffer:sample_data(ch,fr))
        end
      end
    end
      
    if (args.selection_end < args.number_of_frames) then
      for ch = 1,args.buffer.number_of_channels do
        for fr = (args.selection_end +1),args.number_of_frames do
          new_buffer:set_sample_data(ch,fr,args.buffer:sample_data(ch,fr))
        end
      end
    end

    for ch = 1,args.number_of_channels do
      for fr =(args.selection_start
        + pt_with_ch_in_phase_shift (point,ch)),args.selection_end do
        new_buffer:set_sample_data(
          ch,(fr - pt_with_ch_in_phase_shift (point,ch)),args.buffer:sample_data(ch,fr))
      end
    end      
        
    for ch = 1,args.number_of_channels do
      if (pt_with_ch_in_phase_shift (point,ch) >= 1) then
        for fr = args.selection_start,(args.selection_start
          + pt_with_ch_in_phase_shift (point,ch) -1) do
            new_buffer:set_sample_data(
              ch,(fr + args.range - pt_with_ch_in_phase_shift (point,ch)),args.buffer:sample_data(ch,fr))
          end
      end      
    end
  end -- /do_process
      
  return do_process

end


---------------------------------------------------------------------------------------------------
-- @param buffer (renoise.SampleBuffer)
-- @param fn (number, waveform function )
-- @param mod_fn (number, modulating function)

function xSampleBuffer.set_fade(...)
  TRACE("xSampleBuffer.set_fade(...)")
  
  local args = xSampleBuffer.parse_processing_args(...)
  
  assert(type(args.fn)=="function")
  if args.mod_fn then
    assert(type(args.mod_fn)=="function")
  end
  
  -- function to calculate amplification per frame 
  local get_frame_fade_fn = function(fn,ch,mod_fn)
    if (ch == args.buffer.selected_channel or 
      args.selected_channel == renoise.SampleBuffer.CHANNEL_LEFT_AND_RIGHT) 
    then 
      return function (fr)
        local x = (fr-args.selection_start)/args.range
        return fn(xSampleBuffer.mod_fn_shaped(mod_fn)(x),ch)
      end
    else 
      return function ()
        return 1
      end
    end
  end
  
  local do_process = function(new_buffer)
    for ch = 1,args.number_of_channels do
      local fn_shpd = get_frame_fade_fn(args.fn,ch,args.mod_fn)
      for fr = 1,args.selection_start-1 do
        new_buffer:set_sample_data(ch,fr,args.buffer:sample_data(ch,fr))
      end
      for fr = args.selection_start,args.selection_end do
        new_buffer:set_sample_data(ch,fr,(fn_shpd(fr)*(args.buffer:sample_data(ch,fr))))
      end        
      for fr = args.selection_end+1,args.number_of_frames do
        new_buffer:set_sample_data(ch,fr,args.buffer:sample_data(ch,fr))  
      end
    end      
  end

  return do_process

end




