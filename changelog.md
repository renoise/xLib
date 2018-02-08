# Changelog

## 0.52
+ Make offline automation classes extend from cPersistence
+ xEnvelope, refactored from xParameterAutomation (now a static class)
+ xSongPos: (fix) return when going past song boundary
+ xLib: specify constants for sliced processing

## 0.51

+ Added classes to deal with offline automation:  
  `xAudioDeviceAutomation`, `xParameterAutomation`
+ Refactored `xSelection` into separate classes:  
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
+ Fixed `xTrack.get_next_track`/`get_previous_track`: wrap_pattern option was always applied

## 0.5

* xPhrase: new DOC_PROPS implementation
* Standalone version