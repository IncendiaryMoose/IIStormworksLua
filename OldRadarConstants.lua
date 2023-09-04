-- Author: Incendiary Moose
-- GitHub: <GithubLink>
-- Workshop: https://steamcommunity.com/profiles/76561198050556858/myworkshopfiles/?appid=573090
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

---@section MIN_DISTANCE
MIN_DISTANCE = property.getNumber('Min Distance')
---@endsection

---@section POSITION_RANGE
POSITION_RANGE = 6000
---@endsection

---@section MAX_POSITION_INTEGER
POSITION_BITS = 24
MAX_POSITION_INTEGER = 2^POSITION_BITS - 2^(POSITION_BITS - 8) - 1
MIN_POSITION = -3000
---@endsection

---@section MASS_RESOLUTION
MASS_RESOLUTION = 10
---@endsection

---@section MAX_MASS_INTEGER
MASS_BITS_PER_CHANNEL = 32 - POSITION_BITS
MASS_BITS = MASS_BITS_PER_CHANNEL*3 + 4
MAX_MASS_INTEGER = 2^MASS_BITS - 1
---@endsection

---@section MASS_RANGE
MASS_RANGE = MAX_MASS_INTEGER / (MASS_RESOLUTION * 10)
---@endsection

---@section MASS_MASK
MASS_MASK = 2^(MASS_BITS_PER_CHANNEL - 1) - 1
---@endsection

---@section ZOOM_RANGE
MIN_ZOOM = 1
ZOOM_RANGE = 49
MAX_ZOOM_INTEGER = 2^8 - 1

MIN_RANGE = 100
RANGE_RANGE = 2900
MAX_RANGE_INTEGER = 2^8 - 1
---@endsection

---@section POSITION_INT_TO_FLOAT_RATIO
POSITION_INT_TO_FLOAT_RATIO = 1 / 16711679 * 6000
---@endsection

---@section MASS_INT_TO_FLOAT_RATIO
MASS_INT_TO_FLOAT_RATIO = 0.1 / MASS_RESOLUTION
---@endsection

---@section RANGE_INT_TO_FLOAT_RATIO
RANGE_INT_TO_FLOAT_RATIO = 1 / 255 * 2900
---@endsection

---@section ZOOM_INT_TO_FLOAT_RATIO
ZOOM_INT_TO_FLOAT_RATIO = 1 / 255 * 49
---@endsection

---@section POSITION_FLOAT_TO_INT_RATIO
POSITION_FLOAT_TO_INT_RATIO = 1 / 6000 * 16711679
---@endsection

---@section MASS_FLOAT_TO_INT_RATIO
MASS_FLOAT_TO_INT_RATIO = 10 * MASS_RESOLUTION
---@endsection

---@section RANGE_FLOAT_TO_INT_RATIO
RANGE_FLOAT_TO_INT_RATIO = 1 / 2900 * 255
---@endsection

---@section ZOOM_FLOAT_TO_INT_RATIO
ZOOM_FLOAT_TO_INT_RATIO = 1 / 49 * 255
---@endsection

---@section WORST_MATCH_DISTANCE
WORST_MATCH_DISTANCE = 100 -- The largest allowed distance between an existing and a new target for them to be considered the same target
---@endsection

---@section MAX_TIME_UNSEEN
MAX_TIME_UNSEEN = 100 -- How many ticks a target can remain unseen before it is removed
---@endsection

---@section POSITION_MEMORY_LENGTH
POSITION_MEMORY_LENGTH = 10 -- How many past positions of a target to keep in memory
---@endsection

---@section SCREEN_HEIGHT
SCREEN_HEIGHT = 160
SCREEN_WIDTH = 288
---@endsection

---@section MAX_CLICK_DISTANCE
MAX_CLICK_DISTANCE = 40
---@endsection

---@section TARGET_COLORS
TARGET_COLORS = {
    IIVector(0, 100, 0),
    IIVector(110, 110, 0),
    IIVector(100, 0, 0)
}
---@endsection

---@section SEARCH_PATTERN
SEARCH_PATTERN = { -- What order the radar scans in
    0,
    0.5,
    0.25,
    -0.25,
    0.375,
    -0.125,
    0.125,
    -0.375
}

SEARCH_PATTERN_SIZE = #SEARCH_PATTERN
---@endsection

---@section RADAR_FACING_DELAY
RADAR_FACING_DELAY = 5
---@endsection

---@section RADAR_OFFSET
RADAR_OFFSET = {-5, 0, 0}
---@endsection