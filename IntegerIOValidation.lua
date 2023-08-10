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
    simulator:setProperty("ExampleNumberProperty", 123)

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
-- require('II_BinaryIO')
-- binaryToValidate = 0
-- function onTick()
--     if binaryToValidate ~= inputToBinary(binaryToOutput(binaryToValidate)) then
--         print('fail')
--         print(binaryToValidate)
--     end
--     binaryToValidate = binaryToValidate + 1
-- end

-- function onDraw()
--     screen.drawText(1, 1, binaryToValidate)
-- end

require('II_BinaryIO')

--24 leaves 28
--25 leaves 25
INTEGER_BITS = 28
MAX_INTEGER = 2^INTEGER_BITS - 2^(INTEGER_BITS - 9) - 1
MAX_INTEGER = 2^INTEGER_BITS - 1

MIN_INPUT = 0
MAX_INPUT = MAX_INTEGER/100
INPUT_RANGE = MAX_INPUT - MIN_INPUT

testStepSize = 1

stepSize = INPUT_RANGE / MAX_INTEGER


maxValue = floatToInteger(MAX_INPUT, MIN_INPUT, INPUT_RANGE, MAX_INTEGER)
minValue = floatToInteger(-MAX_INPUT, MIN_INPUT, INPUT_RANGE, MAX_INTEGER)

print('Start')

worstError = 0
error = IIabs((MIN_INPUT) - (floatToInteger(-MAX_INPUT, MIN_INPUT, INPUT_RANGE, MAX_INTEGER) / MAX_INTEGER * INPUT_RANGE + MIN_INPUT))
for i = MIN_INPUT + testStepSize, MAX_INPUT, testStepSize do
    local outputValue = floatToInteger(i, MIN_INPUT, INPUT_RANGE, MAX_INTEGER) / MAX_INTEGER * INPUT_RANGE + MIN_INPUT
    local thisError = IIabs(i - outputValue)
    if thisError > worstError then
        worstError = thisError
    end
    error = (error + thisError)/2
end


print('Average Error: '..(error)..' m')
print('Worst Error: '..(worstError)..' m')
print('Average Speed Error: '..(error * 60)..' m/s')
print('Resolution: '..stepSize..' m')
print('Speed Resolution: '..(stepSize * 60)..' m/s')
-- print('Integer Step Size: '..(inputRange/outputMax))
str = ''
for j = 31, 0, -1 do
    local mask = 1 << j
    str = str..((maxValue & mask == mask) and '1' or '0')
end
print('Max: '..str)
print('Max: '..MAX_INPUT)
str = ''
for j = 31, 0, -1 do
    local mask = 1 << j
    str = str..((minValue & mask == mask) and '1' or '0')
end
print('Min: '..str)
print('Min: '..MIN_INPUT)
--[[
inputMin = 1
inputMax = 4000

inputRange = inputMax-inputMin
outputMin = 0
outputMax = 2^(26) - 1

smallestNumber = binaryToFloat(1, customExponentBits, customMantissaBits, customBias, customUnsigned)
largestNumber = binaryToFloat(0xFFFFFFFFFFFFFF, customExponentBits, customMantissaBits, customBias, customUnsigned)
print('Start')
failCount = 0
testCount = 0
progress = 0
testStart = floatToBinary(inputMin, customExponentBits, customMantissaBits, customBias, customUnsigned)
testEnd = floatToBinary(inputMax, customExponentBits, customMantissaBits, customBias, customUnsigned)--2^(customExponentBits + customMantissaBits + (customUnsigned and -1 or 0)) - 1
startingStepSize = binaryToFloat(testStart + 1, customExponentBits, customMantissaBits, customBias, customUnsigned) - binaryToFloat(testStart, customExponentBits, customMantissaBits, customBias, customUnsigned)
endingStepSize = binaryToFloat(testEnd, customExponentBits, customMantissaBits, customBias, customUnsigned) - binaryToFloat(testEnd - 1, customExponentBits, customMantissaBits, customBias, customUnsigned)

testStep = 1
previousValue = 0
stepSize = 0
bigStep = false

for i = testStart, testEnd, testStep do
    if IIfloor((i-testStart) / (testEnd-testStart) * 100) > progress then
        progress = progress + 1
        print(progress..'% Completed')
        print('Average Step Size: '..stepSize)
    end
    local outputFloat = binaryToFloat(i, customExponentBits, customMantissaBits, customBias, customUnsigned)
    local result = floatToBinary(outputFloat, customExponentBits, customMantissaBits, customBias, customUnsigned)
    if i ~= result then
        -- print('fail')
        str = ''
        for j = 31, 0, -1 do
            local mask = 1 << j
            str = str..((i & mask == mask) and '1' or '0')
        end
        print(str)
        str = ''
        for j = 31, 0, -1 do
            local mask = 1 << j
            str = str..((result & mask == mask) and '1' or '0')
        end
        print(str)
        print(outputFloat)
        print(i)
        failCount = failCount + 1
    end
    testCount = testCount + 1
end
print('End')
print('Tests done: '..testCount)
print('Tests failed: '..failCount)
print('Average Step Size: '..stepSize..' m')
print('Average Speed Resolution: '..(stepSize * 60)..' m/s')
print('Integer Step Size: '..(inputRange/outputMax))
]]--