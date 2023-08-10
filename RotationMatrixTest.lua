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

--[[
    Perhaps make this able to run in parallel with the weapon scripts?
    If the weapon script simply stores all 8 positions every tick, this script could give it a list of what indexes to match together to recreate a target once one has been found.
    This would reduce latency in the targeting script by 1 tick, on a scale of 4-6 ticks already, at the cost of doing more input decoding, storing more values, and making both scripts longer.
    Another bonus is that the targeting system would not need time to 'learn' a target after targets have switched.

    Option 1:
        Weapons (This script) will store all radar outputs every tick. Once targeting (The other script) has decided on a target, it will send an encoded list to the weapons script(s).
        This list will contain indexes to read from to re-create the chosen target, allowing the weapons to have full accsess to all past positions of the target the moment it is chosen.
        In order to actually get the reduced latency this allows for, the weapons script will need to move to full tracking once a target is chosen, as continuing to rely on the indexes given by
        the tracking script results in the same latency as running in series.

    Option 2:
        Weapons (This script) will run tracking code identical to what is in the targeting script. Once targeting has chosen a target, it will send the mass group and key for the target.
        Because the tracking code is identical, the weapons script(s) should have an identical target stored there.

    Problem:
        Weapons needs additional inputs for turret position and rotation, meaning it is likely that not all radar outputs can be kept.
        This whole system will add more computations, and at best save 1 tick of latency in a system that aims to lead 100s of ticks in the future.

    Conclusion:
        Parallel is not worth it unless there is some way around the additional inputs required by the weapons scripts.
        The re-learing period that comes with switching targets in the series system can be solved by using extra channels to transmit multiple past positions when targets are switched.

    Script requirements:
        This script must be capable of the following:
            Track targets using mass to reduce distance checks
            Give targets a priority based on potential danger
            Distribute target data to several weapon scripts based on what a weapon can aim at
                This can be done internally using a list of weapon position offsets and range of motion, or by allowing weapons to send requests for certain targets.
            Maybe allow aiming radar in a special single-target mode?

    Data output:
        How should the script deal with the need to output multiple targets to different weapons?
        Simple method is to divide avalible channels by #weapons and give each weapon that many channels worth of data,
        however this stops working with large quantities of weapons.
        One solution is to further split this script, giving each weapon its own targeting system. At that point, perhaps just give each weapon its own radar?
]]--

require('II_MathHelpers')
require('II_BinaryIO')
require('II_SmallVectorMath')
require('OldRadarConstants')


radarPosition = IIVector()
radarRotation = IIVector()


function onTick()
    rawXRotation = input.getNumber(4)
    rawYRotation = input.getNumber(5)
    rawZRotation = input.getNumber(6) - PI/2

    local c1, s1, c2, s2, c3, s3 = math.cos(rawXRotation), math.sin(rawXRotation), math.cos(rawYRotation), math.sin(rawYRotation), math.cos(rawZRotation), math.sin(rawZRotation)
    local c3s1, c1s2 = c3*s1, c1*s2
    radarRotationMatrix = {
        IIVector(c3s1 - c1s2*s3,  -s1*s2*s3 - c1*c3, -c2*s3),
        IIVector(c1*c2,           c2*s1,            -s2),
        IIVector(s1*s3 + c1s2*c3, c3s1*s2 - c1*s3,   c2*c3)
    }
	pitch = -math.asin(s1*s3 + c1*s2*c3)

    radarRotation:setVector(
        math.acos(c2*c3 / math.cos(pitch)) * (c3*s1*s2 - c1*s3 < 0 and -1 or 1),
        pitch,
        math.atan(c1*c2, c3*s1 - c1*s2*s3)
    )

    c3, s3, c2, s2, c1, s1 =
        math.cos(radarRotation[1]), math.sin(radarRotation[1]),
        math.cos(radarRotation[2]), math.sin(radarRotation[2]),
        math.cos(radarRotation[3]), math.sin(radarRotation[3])
    radarRotationMatrix = {
        IIVector(c1*c2, c1*s2*s3 - c3*s1, s1*s3 + c1*s2*c3),
        IIVector(c2*s1, c1*c3 + s1*s2*s3, c3*s1*s2 - c1*s3),
        IIVector(-s2, c2*s3, c2*c3)
    }
end

function onDraw()
    for i = 1, 3 do
        for j = 1, 3 do
            local x1, y1, x2, y2 = 1 + j * 50, 1 + i * 6, 1 + j * 50, 60 + i * 6
            screen.drawText(x1, y1, string.format('%.2f', radarRotationMatrix[i][j]))
            screen.drawText(x2, y2, string.format('%.2f', radarRotationMatrix[i][j]))
        end
    end
end
