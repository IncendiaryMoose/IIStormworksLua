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
require('II_IO')
require('II_SmallVectorMath')

targets = {} -- Data stored at key 'mass' should be a list of all targets with that mass

newTarget = function (initialPosition)
    return {
        position = IIVector(initialPosition:getVector()),
        velocity = IIVector(),
        acceleration = IIVector(),
        timeSinceLastSeen = 0,
        timesSeen = 0,
        threatScore = 0,
    }
end

radarPosition = IIVector()
radarRotation = IIVector()

newTargetPosition = IIVector()

SEARCH_PATTERN = { -- What order the radar scans in

}

WORST_MATCH_DISTANCE = 100 -- The largest allowed distance between an existing and a new target for them to be considered the same target
MAX_TIME_UNSEEN = 100 -- How many ticks a target can remain unseen before it is removed

function onTick()
    radarPosition:setVector(input.getNumber(1), input.getNumber(2), input.getNumber(3))
    radarRotation:setVector(input.getNumber(1), input.getNumber(2), input.getNumber(3))

    newTargets = {}
    possibleMatches = {}
    for i = 1, 8 do
        local newTargetMass = input.getNumber(2)

        newTargetPosition:setVector()
        newTargets[i] = {position = IIVector(newTargetPosition:getVector()), mass = newTargetMass}

        if not targets[newTargetMass] then -- There are no currently tracked targets with this mass, so skip trying to match them
            targets[newTargetMass] = {}
            goto TargetRegistered
        end

        if not possibleMatches[newTargetMass] then
            possibleMatches[newTargetMass] = {}
        end

        for matchIndex, target in pairs(targets[newTargetMass]) do
            local matchDistance = target.position:distanceTo(newTargetPosition)
            if matchDistance < WORST_MATCH_DISTANCE then
                hasMatched = false
                possibleMatches[newTargetMass][#possibleMatches[newTargetMass]+1] = {
                    matchDistance = matchDistance,
                    newTargetIndex = i,
                    matchIndex = matchIndex
                }
            end
        end

        ::TargetRegistered::
    end

    targetsRegistered = {}
    for targetMass, targetMassGroup in pairs(possibleMatches) do
        table.sort(targetMassGroup, function (a, b)
            return a.matchDistance < b.matchDistance
        end)
        for i, possibleMatch in ipairs(targetMassGroup) do -- Try applying matches, starting with the best one. If the match applies, the new target will be removed and the old one updated.
            targets[targetMass][possibleMatch.matchIndex]:newSighting(newTargets[possibleMatch.newTargetIndex])
        end
    end

    for key, remainingTarget in pairs(newTargets) do -- All targets in this table were unable to find a valid match, so add them as new targets.
        targets[remainingTarget.mass][remainingTarget.position[1] + remainingTarget.position[2]] = newTarget(remainingTarget.position)
    end

    for targetMass, targetMassGroup in pairs(newTargets) do
        for targetKey, target in pairs(targetMassGroup) do
            if target.timeSinceLastSeen > MAX_TIME_UNSEEN then
                targets[targetMass][targetKey] = nil
            end
            target:update()
        end
    end

end

function onDraw()
    screen.drawCircle(16,16,5)
end
