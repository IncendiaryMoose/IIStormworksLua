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
    simulator:setScreen(1, "9x5")
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
require('II_BinaryIO')

buttons = {}

for i = 1, 32 do
    buttons[i] = false
end

strToSend = '07tH_'

click = false
function onTick()
    wasClick = click
    click = input.getBool(1)
    clickX = input.getNumber(3)
    clickY = input.getNumber(4)

    binaryVal = 0
    for index, value in ipairs(buttons) do
        binaryVal = binaryVal << 1
        binaryVal = (value and 1 or 0) | binaryVal
        local bX, bY = (index-1)*5 + 1, 25
        if click and not wasClick and clickX >= bX and clickX <= bX + 4 and clickY >= bY and clickY <= bY + 8 then
            buttons[index] = not value
        end
    end

    encodedStr = stringTo6BitInts(strToSend, 1, 5)
    encodedVal = binaryToOutput(binaryVal)
    outputStr = binaryToOutput(encodedStr)
    output.setNumber(1, encodedVal)
    output.setNumber(2, outputStr)
end

function onDraw()
    screen.setColor(255, 255, 255)
    str = 'Encoded string:\n'
    -- for i = 31, 0, -1 do
    --     local mask = 1 << i
    --     str = str..((encodedStr & mask == mask) and '1' or '0')
    -- end
    screen.drawText(1, 1, str..strToSend)
    screen.drawText(1, 17, 'Encoded Number: '..encodedVal)
    for index, value in ipairs(buttons) do
        screen.drawText((index-1)*5 + 1, 25, value and '1' or '0')
    end
end