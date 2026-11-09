GooseChase icon layers. Every file is 1024x1024 on the same coordinates, so they stack aligned.
svg/ = vector (preferred by Icon Composer), png/ = transparent 1024 PNGs.

Icon Composer setup:
  Background  -> don't import; use Fill > Gradient #3FA2E0 (top) -> #6CC3F0 (bottom)
                 Dark appearance: #173F63 -> #2C7DB4  (0_background_sky*.svg are only for previews)
  Group 1     -> 1_grass                               (glass subtle)
  Group 2     -> 2a_goose_body, 2b_belly_shade, 2c_wing (Liquid Glass ON, shadow Neutral)
  Group 3     -> 3a_beak, 3b_legs_feet, 3c_eye          (glass ON)
  Group 4     -> 4a_speed_lines (+ 4b_brackets optional; skip if busy at small sizes)
