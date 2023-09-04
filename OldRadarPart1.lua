-- Author: Incendiary Moose
-- GitHub: <GithubLink>
-- Workshop: https://steamcommunity.com/profiles/76561198050556858/myworkshopfiles/?appid=573090
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey


--[====[ HOTKEYS ]====]
-- Press F6 to simulate this file
-- Press F7 to build the project, copy the output from /_build/out/ into the game to use
-- Remember to set your Author name etc. in the settings: CTRL+COMMA


--[====[ EDITABLE SIMULATOR CONFIG - *automatically removed from the F7 build output ]====]
---@section __LB_SIMULATOR_ONLY__
do
    ---@type Simulator -- Set properties and screen sizes here - will run once when the script is loaded
    simulator = simulator
    simulator:setScreen(1, "3x3")
    simulator:setProperty("Spin Time", 9)
    simulator:setProperty("Spin Correction", 4)
    simulator:setProperty("Minimum Distance", 9)
    simulator:setProperty("Maximum Distance", 5000)

    -- Runs every tick just before onTick; allows you to simulate the inputs changing
    ---@param simulator Simulator Use simulator:<function>() to set inputs etc.
    ---@param ticks     number Number of ticks since simulator started
    function onLBSimulatorTick(simulator, ticks)

        -- touchscreen defaults
        local screenConnection = simulator:getTouchScreen(1)
        simulator:setInputBool(1, screenConnection.isTouched)
        simulator:setInputNumber(1, screenConnection.width)
        simulator:setInputNumber(2, screenConnection.height)
        simulator:setInputNumber(3, screenConnection.touchX)
        simulator:setInputNumber(4, screenConnection.touchY)

        -- NEW! button/slider options from the UI
        simulator:setInputBool(31, simulator:getIsClicked(1))       -- if button 1 is clicked, provide an ON pulse for input.getBool(31)
        simulator:setInputNumber(31, simulator:getSlider(1))        -- set input 31 to the value of slider 1

        simulator:setInputBool(32, simulator:getIsToggled(2))       -- make button 2 a toggle, for input.getBool(32)
        simulator:setInputNumber(32, simulator:getSlider(2) * 50)   -- set input 32 to the value from slider 2 * 50
    end;
end
---@endsection

require('II_MathHelpers')
require('II_SmallVectorMath')
require('II_BinaryIO')
require('II_IO')
require('OldRadarConstants')

filterMassValues = -- TODO: Update to tenths resolution and re-introduce check
{
    12, 13, --Player (Technically 12.5)
    20,   --Lifesaver
    25,   --Player
    30,
    35,   --Fire Ext Prop
    50,   --Pallet
    80,   --Barrel
    100,  --Fluid Crate, Propane, Large Propane
    112, -- Small Fuel Gantry
    125,  --Tool Cart
    160, --Animal
    175,  --Large Cart
    180, --Animal
    203, --Animal
    300,  --Large Chest
    320,  --Animal
    347,  --Gas Gantry
    397, -- Coal Gantry
    400,  --Loot Crate
    405,  --Animal
    2499, --Container
    2500,  --Tree
    2623,  --Animal
    4170, --Animal
}

excludeMasses = {}

for index, value in ipairs(filterMassValues) do
    excludeMasses[value] = true
end

function onTick()
    clearOutputs()
    for i = 0, 7 do
        local distance = input.getNumber(i*4+1)
        if distance > MIN_DISTANCE and distance < -MIN_POSITION then
            local targetPosition = IIVector()
            local elevation, azimuth = input.getNumber(i*4+3)*PI2, -input.getNumber(i*4+4)*PI2
            azimuth = arcsin(math.sin(azimuth) / math.cos(elevation))
            targetPosition:setVector(distance, azimuth, elevation)
            targetPosition:toCartesian()
            targetPosition[3] = targetPosition[3] - 0.5

            local massInteger = fastFloatToInteger(distance * input.getNumber(i*4+2), 0, MASS_FLOAT_TO_INT_RATIO, MAX_MASS_INTEGER)

            for j = 1, 4 do
                local bitMask = 1 << (MASS_BITS - j)
                outputBools[j + i*4] = massInteger & bitMask == bitMask
            end
            outputNumbers[i*3 +  9] = binaryToOutput(
                ((massInteger >> (MASS_BITS - 5) & 1) << 31)
                | fastFloatToInteger(targetPosition[1], MIN_POSITION, POSITION_FLOAT_TO_INT_RATIO, MAX_POSITION_INTEGER) << (MASS_BITS_PER_CHANNEL - 1)
                | (massInteger >> MASS_BITS_PER_CHANNEL*2 & MASS_MASK)
            )
            outputNumbers[i*3 + 10] = binaryToOutput(
                ((massInteger >> (MASS_BITS - 5 - MASS_BITS_PER_CHANNEL) & 1) << 31)
                | fastFloatToInteger(targetPosition[2], MIN_POSITION, POSITION_FLOAT_TO_INT_RATIO, MAX_POSITION_INTEGER) << (MASS_BITS_PER_CHANNEL - 1)
                | (massInteger >> MASS_BITS_PER_CHANNEL & MASS_MASK)
            )
            outputNumbers[i*3 + 11] = binaryToOutput(
                ((massInteger >> (MASS_BITS - 5 - MASS_BITS_PER_CHANNEL*2) & 1) << 31)
                | fastFloatToInteger(targetPosition[3], MIN_POSITION, POSITION_FLOAT_TO_INT_RATIO, MAX_POSITION_INTEGER) << (MASS_BITS_PER_CHANNEL - 1)
                | (massInteger & MASS_MASK)
            )
        end
    end
    setOutputs()
end