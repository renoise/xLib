# Changelog

## 0.54 - June 28th, 2018

- New class: `xKeyZone`, contains refactored methods:
  `xInstrument.get_samples_mapped_to_note` -> `xKeyZone.get_samples_mapped_to_note`
  `xSampleMapping.shift_keyzone_by_semitones` -> `xKeyZone.shift_by_semitones`
- xInstrument: new methods `insert_sample`, `clone_sample`
- Change `xSongSettings` -> `xPersistentSettings` - support instr. comments
- New class: `xSampleBuffer` - contains refactored methods:
  `xSample.get_bit_depth` -> `xSampleBuffer.get_bit_depth`
  `xSample.bits_to_xbits` -> `xSampleBuffer.bits_to_xbits`
  `xSample.get_channel_info` -> `xSampleBuffer.get_channel_info`
  `xSample.sample_buffer_is_silent` -> `xSampleBuffer.is_silent`
  `xSample.detect_leading_trailing_silence` -> `xSampleBuffer.detect_leading_trailing_silence`
  `xSample.set_buffer_selection` -> `xSampleBuffer.set_buffer_selection`
  `xSample.get_buffer_frame_by_line` -> `xSampleBuffer.get_frame_by_line`
  `xSample.get_buffer_frame_by_beat` -> `xSampleBuffer.get_frame_by_beat`
- Fixed: `xPhraseManager.delete_selected_phrase_mapping` - resolve mapping, not phrase

## 0.53 - Apr 2, 2018

- `xLinePattern` - ensure that `visible_only` applies everywhere
- `xLinePattern.set_effect_column_command` - return the column
- `xPhrase.get_line_from_cursor` - fix value when last line in phrase
- `xSample.get_buffer_frame_by_notepos` : obtain fraction from line 
- `xLinePattern` - use new syntax (`amount_value`)
- `xCursorPos` : make it clear that line can be fractional
- `xPhrase.get_line_from_cursor` :  apply delay column to result
- `xLinePattern` - make table key names returned by `get_effect_XX ` more descriptive
- `xLinePattern.get_effect_column_command` - allow it to search all columns
- `xLinePattern.get_available_effect_column` - allow optional start column for search
- `xLinePattern.set_effect_column_command` - don't search note cols if no column index
- `xLinePattern` - method for retrieving first effect column + writing effect commands
- `xPhrase` - method for determining line from pattern position
- `xLinePattern.get_effect_command`: include `xEffectColumn.TYPE` in result
- `xInstrument.get_selected_phrase_index` - get selected phrase index in any instr.
- `xParameterAutomation` - include "inverted" line boundary
- `xAudioDeviceAutomation` - add `number_of_lines` method
- `xEnvelope` - add `number_of_lines` method

## 0.52 - Feb 22, 2018

- Specify dependencies within classes, using `cLib.require()`
- Make offline automation classes extend from cPersistence
- xEnvelope, refactored from xParameterAutomation (now a static class)
- xSongPos: (fix) return when going past song boundary
- xLib: specify constants for sliced processing

## 0.51

- Added classes to deal with offline automation:  
  `xAudioDeviceAutomation`, `xParameterAutomation`
- Refactored `xSelection` into separate classes:  
    `xPatternSelection`, `xMatrixSelection`, `xPatternSelection`, `xSequencerSelection`  
    Method are now available as:   
    `xSelection.get_pattern_track` -> `xPatternSelection.get_pattern_track`  
    `xSelection.get_pattern_column` -> `xPatternSelection.get_pattern_column`  
    `xSelection.get_pattern_if_single_track` -> `xPatternSelection.get_pattern_if_single_track`  
    `xSelection.get_column_in_track` -> `xPatternSelection.get_column_in_track`  
    `xSelection.get_group_in_pattern` -> `xPatternSelection.get_group_in_pattern`  
    `xSelection.get_phrase` -> `xPhraseSelection.get_phrase`  
    `xSelection.get_matrix_selection` -> `xMatrixSelection.get_selection`  
    `xSelection.get_entire_sequence` -> `xSequencerSelection.get_entire_range`    
    `xSelection.is_single_column` -> `xPatternSelection.is_single_column`   
    `xSelection.is_single_track` -> `xPatternSelection.is_single_track`   
    `xSelection.includes_note_columns` -> `xPatternSelection.includes_note_columns`  
    `xSelection.within_sequence_range` --> `xSequencerSelection.within_range`  
    `xSelection.get_lines_in_range` --> `xSequencerSelection.pluck_from_range`  
- Fixed `xTrack.get_next_track`/`get_previous_track`: wrap_pattern option was always applied

## 0.5

- xPhrase: new DOC_PROPS implementation
- Standalone version