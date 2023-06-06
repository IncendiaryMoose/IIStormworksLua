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
require('II_MathHelpers')
require('II_PIDController')

PIVOT_PID_CONFIG = {
    PROPORTIONAL_GAIN = property.getNumber('Pivot P'),
    INTEGRAL_GAIN = property.getNumber('Pivot I'),
    DERIVATIVE_GAIN = property.getNumber('Pivot D'),
    MAX_PROPORTIONAL = property.getNumber('Pivot Max P'),
    MAX_INTEGRAL = property.getNumber('Pivot Max I'),
    MAX_DERIVATIVE = property.getNumber('Pivot Max D'),
    MAX_OUTPUT = property.getNumber('Pivot Max')
}

PIDs = {
    newPID(PIVOT_PID_CONFIG),
    newPID(PIVOT_PID_CONFIG),
    newPID(PIVOT_PID_CONFIG),
    newPID(PIVOT_PID_CONFIG),
    newPID(PIVOT_PID_CONFIG),
    newPID(PIVOT_PID_CONFIG),
    newPID(PIVOT_PID_CONFIG),
    newPID(PIVOT_PID_CONFIG)
}

function wrappedDifference(a, b)
    return (a - b + 0.5)%1 - 0.5
end

function onTick()
    for i = 1, 8 do
        output.setNumber((i-1)*3+1, PIDs[i]:update(wrappedDifference(input.getNumber((i-1)*2+9), input.getNumber((i-1)*2+1)), 0))
        local pitch = input.getNumber((i-1)*2+10)
        output.setNumber((i-1)*3+2, PIDs[i]:update(wrappedDifference(pitch, input.getNumber((i-1)*2+2)), 0))
        output.setNumber((i-1)*3+3, pitch*4)
    end
end

