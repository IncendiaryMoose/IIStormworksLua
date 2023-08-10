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
require('II_RenderEngine')
require('OldRadarConstants')

redOff = {100,0,0}
redOn = {150,0,0}
greenOff = {0,100,0}
greenOn = {0,150,0}
blueOff = {0,0,50}
blueOn = {0,0,150}
orangeOff = {110,30,0}
orangeOn = {180,70,0}
yellowOff = {110,110,0}
yellowOn = {160,160,0}
purpleOff = {90,0,20}
purpleOn = {120,0,50}
grey = {20, 20, 20}
lightGrey = {100, 100, 100}
paleBlueOff = {75,75,255}
paleBlueOn = {100,100,255}
whiteOff = {150,150,150}
whiteOn = {200,200,200}

buttonHeight = 10
buttonGroups = {}
toggleStart = 11

buttonGroups[1] = {
    newSlider(3, 21, 13, 9, 5, 20, lightGrey, whiteOff, 'TRK:', greenOn, grey),
    newSlider(3, 51, 13, 9, 5, 20, lightGrey, whiteOff, 'TRK:', greenOn, grey),
    newSlider(3, 81, 13, 9, 5, 20, lightGrey, whiteOff, 'TRK:', greenOn, grey),
    newSlider(3, 31, 13, 9, 5, 20, lightGrey, whiteOff, 'ATK:', redOn, grey),
    newSlider(3, 61, 13, 9, 5, 20, lightGrey, whiteOff, 'ATK:', redOn, grey),
    newSlider(3, 91, 13, 9, 5, 20, lightGrey, whiteOff, 'ATK:', redOn, grey),
    newPulseButton(36, 21, 6, 19, greenOff, whiteOff, 'ADD', greenOn, whiteOn),
    newPulseButton(36, 51, 6, 19, yellowOff, whiteOff, 'ADD', yellowOn, whiteOn),
    newPulseButton(36, 81, 6, 19, redOff, whiteOff, 'ADD', redOn, whiteOn),
    newSlider(3, 120, 13, 9, 5, 25, lightGrey, whiteOff, 'CMBT:', orangeOn, grey),
    newSlider(3, 130, 13, 9, 5, 25, lightGrey, whiteOff, 'MTRK:', orangeOn, grey),
    newSlider(3, 140, 13, 9, 5, 25, lightGrey, whiteOff, 'AATK:', orangeOn, grey)
}

buttonGroups[2] = {
    newSlider(1, 1, 196, 9, 5, 46, lightGrey, whiteOff, 'Zoom:', blueOn, blueOff, true),
    newSlider(1, 149, 196, 9, 5, 46, lightGrey, whiteOff, 'Range:', orangeOn, orangeOff, true)
}

buttonGroups[9] = {
    newSlider(SCREEN_WIDTH - 41, 94, 13, 9, 5, 25, lightGrey, whiteOff, 'WELD:', paleBlueOn, grey),
    newSlider(SCREEN_WIDTH - 41, 104, 13, 9, 5, 25, lightGrey, whiteOff, 'EXTN:', paleBlueOn, grey),
    newSlider(SCREEN_WIDTH - 41, 118, 13, 9, 5, 25, lightGrey, whiteOff, 'CAMS:', purpleOn, grey),
    newSlider(SCREEN_WIDTH - 41, 128, 13, 9, 5, 25, lightGrey, whiteOff, 'SCRN:', purpleOn, grey),
    newSlider(SCREEN_WIDTH - 41, 138, 13, 9, 5, 25, lightGrey, whiteOff, 'MASS:', purpleOn, grey),
    newSlider(SCREEN_WIDTH - 41, 148, 13, 9, 5, 25, lightGrey, whiteOff, 'DBG:', purpleOn, grey)
}


buttonGroups[1][1].pressed = true
buttonGroups[1][2].pressed = true
buttonGroups[1][3].pressed = true
buttonGroups[1][6].pressed = true
buttonGroups[2][1].onPercent = 0.1
zoom = buttonGroups[2][1].onPercent * ZOOM_RANGE + MIN_ZOOM
range = buttonGroups[2][2].onPercent * RANGE_RANGE + MIN_RANGE
buttonGroups[9][4].pressed = true

click = false

function onTick()
    clickX = input.getNumber(3)
    clickY = input.getNumber(4)
    wasClick = click
    click = input.getBool(1)

    externalControlSignalA = (click and clickX > 45 and clickX < SCREEN_WIDTH-45 and 1 << 17 or 0) | clickX << 8 | clickY
    externalControlSignalB = floatToInteger(zoom, MIN_ZOOM, ZOOM_RANGE, MAX_ZOOM_INTEGER) << 8 | floatToInteger(range, MIN_RANGE,  RANGE_RANGE, MAX_RANGE_INTEGER)

    for buttonIndex, button in ipairs(buttonGroups[1]) do
        externalControlSignalA = externalControlSignalA | (button.pressed and 1 << (17 + buttonIndex) or 0)
    end

    externalControlSignalA = externalControlSignalA | (input.getBool(3) and 1 << 31 or 0)
    -- externalControlSignalA = externalControlSignalA | (screenControls.massView.pressed
    -- outputBits[26] = input.getBool(3)
    output.setNumber(1, binaryToOutput(externalControlSignalA))
    output.setNumber(2, binaryToOutput(externalControlSignalB))
    output.setBool(1, buttonGroups[1][10].pressed)
    output.setBool(4, buttonGroups[9][1].pressed)
    output.setBool(5, buttonGroups[9][2].pressed)
    output.setBool(6, buttonGroups[9][3].pressed)
    output.setBool(2, buttonGroups[9][4].pressed)
    output.setBool(3, buttonGroups[9][6].pressed)
end

function onDraw()
    screen.setColor(15, 15, 25)
    screen.drawRectF(SCREEN_WIDTH - 45, 0, 45, SCREEN_HEIGHT)

    if not buttonGroups[9][3].pressed then
        screen.drawRectF(0, 0, 45, SCREEN_HEIGHT)

        setDrawColor(greenOff)
        screen.drawRect(1, toggleStart + 8, 42, 22)

        setDrawColor(yellowOff)
        screen.drawRect(1, toggleStart + 38, 42, 22)

        setDrawColor(redOff)
        screen.drawRect(1, toggleStart + 68, 42, 22)

        setDrawColor(orangeOff)
        screen.drawRect(1, 118, 42, 40)
        for B, buttonGroup in ipairs(buttonGroups) do
            for b, button in ipairs(buttonGroup) do
                button:update(click, wasClick, clickX, clickY)
            end
        end
        zoom = buttonGroups[2][1].onPercent * ZOOM_RANGE + MIN_ZOOM
        range = buttonGroups[2][2].onPercent * RANGE_RANGE + MIN_RANGE
        for i = 1, 3 do
            buttonGroups[1][i].pressed = buttonGroups[1][i].pressed or buttonGroups[1][i+3].pressed and buttonGroups[1][i+3].stateChange
            buttonGroups[1][i+3].pressed = buttonGroups[1][i+3].pressed and buttonGroups[1][i].pressed
        end

        setDrawColor(whiteOff)
        screen.drawText(1, toggleStart + 2, 'FRIENDLY:')
        screen.drawText(1, toggleStart + 2 + buttonHeight * 3, 'UNKNOWN:')
        screen.drawText(1, toggleStart + 2 + buttonHeight * 6, 'HOSTILE:')
    end

    setDrawColor(paleBlueOff)
    screen.drawRect(SCREEN_WIDTH - 44, 92, 42, 22)

    setDrawColor(purpleOff)
    screen.drawRect(SCREEN_WIDTH - 44, 116, 42, 42)

    for b, button in ipairs(buttonGroups[9]) do
        button:update(click, wasClick, clickX, clickY)
    end

end