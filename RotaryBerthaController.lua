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

require('II_IO')

fireTimer = 0
reloadTimer = 0
reloadDelayTimer = 0
fireIndex = 0
fireTime = property.getNumber('Fire Time')
reloadTime = property.getNumber('Reload Time')
reloadDelay = property.getNumber('Reload Delay')
burstRate = property.getNumber('Burst Rate')
rotors = {0, 0, 0, 0, 0}
reload = true
function onTick()
    clearOutputs()
    fire = input.getBool(1)
    burst = input.getBool(2)
    if not reloading and (fire or burst) then
        fireTimer = burst and ((fireTimer + 1) % burstRate) or (fireTimer + 1) % fireTime
        if fireTimer == 0 then
            local group = fireIndex % 4 + 1
            local gun = rotors[group]
            outputBools[group * 4 - 3 + gun] = true
            rotors[group] = (gun + 1) % 4
            rotors[5] = (rotors[5] + 1) % 4
            fireIndex = (fireIndex + 1) % 16
        end
    else
        fireTimer = 0
    end
    if reload then
        reloading = true
    end
    if reloading then
        outputBools[32] = true
        reloadDelayTimer = reloadDelayTimer + 1
        if reloadDelayTimer > reloadDelay then
            reloadTimer = (reloadTimer + 1) % reloadTime
            if reloadTimer == 0 then
                rotors[1] = (rotors[1] + 1) % 4
                rotors[2] = (rotors[2] + 1) % 4
                rotors[3] = (rotors[3] + 1) % 4
                rotors[4] = (rotors[4] + 1) % 4
            end
        end
        if reloadDelayTimer > reloadDelay + reloadTime * 3 then
            reloadDelayTimer = 0
            reloadTimer = 0
            reloading = false
        end
    end
    outputNumbers[1] = rotors[1] / 4
    outputNumbers[2] = rotors[2] / 4
    outputNumbers[3] = rotors[3] / 4
    outputNumbers[4] = rotors[4] / 4
    outputNumbers[5] = rotors[5] / 4
    setOutputs()
    reload = input.getBool(3)
end