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
POSITION_BITS = 24
MAX_POSITION_INTEGER = 2^POSITION_BITS - 2^(POSITION_BITS - 8) - 1
MIN_POSITION = -3000
POSITION_RANGE = 6000

MASS_RESOLUTION = 10
MASS_BITS_PER_CHANNEL = 32 - POSITION_BITS
MASS_BITS = MASS_BITS_PER_CHANNEL*3 + 4
MAX_MASS_INTEGER = 2^MASS_BITS - 1
MIN_MASS = 0
MASS_RANGE = MAX_MASS_INTEGER / (MASS_RESOLUTION * 10)

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

---@section TRACK_BITS
TRACK_BITS = {
    1 << 25,
    1 << 23,
    1 << 21
}
ATTACK_BITS = {
    1 << 24,
    1 << 22,
    1 << 20
}
-- Bit 26: Track Friendly
-- Bit 25: Attack Friendly
-- Bit 24: Track Unkown
-- Bit 23: Attack Unkown
-- Bit 22: Track Hostile
-- Bit 21: Attack Hostile
---@endsection