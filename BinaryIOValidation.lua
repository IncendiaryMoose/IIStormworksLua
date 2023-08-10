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

customExponentBits = 2
customMantissaBits = 22
customBias = -16
customUnsigned = true

--With 3 extra: 0 - 4096 = 2, 25, -8
--With 5 extra: 0 - 4096 = 2, 23, -8

-- 1-1000000: 2, 17, -16

inputMin = 1
inputMax = 10000000

inputRange = inputMax-inputMin
outputMin = 0
outputMax = 2^(28) - 1

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

if true then
    for i = testStart, testEnd, testStep do
        if IIfloor((i-testStart) / (testEnd-testStart) * 100) > progress then
            progress = progress + 1
            print(progress..'% Completed')
            print('Average Step Size: '..stepSize)
        end
        local outputFloat = binaryToFloat(i, customExponentBits, customMantissaBits, customBias, customUnsigned)
        if not bigStep and outputFloat - previousValue > 1 then
            bigStep = outputFloat
        end
        stepSize = (stepSize + (outputFloat - previousValue))/2
        previousValue = outputFloat
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
else
    for i = 0, outputMax, 1 do
        if IIfloor(i / outputMax * 100) > progress then
            progress = progress + 1
            print(progress..'% Completed')
            print('Average Step Size: '..stepSize)
        end
        local outputFloat = i/outputMax * inputRange
        stepSize = (stepSize + (outputFloat - previousValue))/2
        previousValue = outputFloat
        testCount = testCount + 1
    end
end
print('End')
print('Tests done: '..testCount)
print('Tests failed: '..failCount)
print('Average Step Size: '..stepSize..' m')
print('Average Speed Resolution: '..(stepSize * 60)..' m/s')
print('Starting Step Size: '..startingStepSize)
print('Ending Step Size: '..endingStepSize)


print('Near Speed Resolution: '..(startingStepSize * 60)..' m/s')
print('Far Speed Resolution: '..(endingStepSize * 60)..' m/s')
print('Smallest: '..smallestNumber)
print('Largest: '..largestNumber)
print('Integer Step Size: '..(inputRange/outputMax))
print('Sub 1 Steps Under: '..(bigStep or 'ALL'))