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
        simulator:setInputNumber(1, 0)
        simulator:setInputNumber(2, 0)
        simulator:setInputNumber(3, 0)
        simulator:setInputNumber(4, 0)


        local MassInteger = floatToInteger(2000, MIN_MASS, MASS_RANGE, MAX_MASS_INTEGER)
        TargetPosition = {600, 0, 0}
        if pastRadarFacing == 0 then
            for J = 1, 4 do
                local BitMask = 1 << (MASS_BITS - J)
                simulator:setInputBool(J, MassInteger & BitMask == BitMask)
            end
            simulator:setInputNumber(9, binaryToOutput(((MassInteger >> (MASS_BITS - 5) & 1) << 31) | floatToInteger(TargetPosition[1], MIN_POSITION, POSITION_RANGE, MAX_POSITION_INTEGER) << (MASS_BITS_PER_CHANNEL - 1) | (MassInteger >> MASS_BITS_PER_CHANNEL*2 & MASS_MASK)))
            simulator:setInputNumber(10, binaryToOutput(((MassInteger >> (MASS_BITS - 5 - MASS_BITS_PER_CHANNEL) & 1) << 31) | floatToInteger(TargetPosition[2], MIN_POSITION, POSITION_RANGE, MAX_POSITION_INTEGER) << (MASS_BITS_PER_CHANNEL - 1) | (MassInteger >> MASS_BITS_PER_CHANNEL & MASS_MASK)))
            simulator:setInputNumber(11, binaryToOutput(((MassInteger >> (MASS_BITS - 5 - MASS_BITS_PER_CHANNEL*2) & 1) << 31) | floatToInteger(TargetPosition[3], MIN_POSITION, POSITION_RANGE, MAX_POSITION_INTEGER) << (MASS_BITS_PER_CHANNEL - 1) | (MassInteger & MASS_MASK)))
        else
            for J = 1, 4 do
                simulator:setInputBool(J, false)
            end
            simulator:setInputNumber(9,  0)
            simulator:setInputNumber(10, 0)
            simulator:setInputNumber(11, 0)
        end

        Click = screenConnection.isTouched
        ClickX = screenConnection.touchX
        ClickY = screenConnection.touchY
        ExternalControlSignalA = (Click and ClickX > 45 and ClickX < SCREEN_WIDTH-45 and 1 << 17 or 0) | ClickX << 8 | ClickY
        ExternalControlSignalB = floatToInteger(simulator:getSlider(1) * ZOOM_RANGE + MIN_ZOOM, MIN_ZOOM, ZOOM_RANGE, MAX_ZOOM_INTEGER) << 8 | floatToInteger(simulator:getSlider(2) * RANGE_RANGE + MIN_RANGE, MIN_RANGE,  RANGE_RANGE, MAX_RANGE_INTEGER)
        -- print(simulator:getSlider(1))
        ExternalControlSignalA = ExternalControlSignalA | (1 << 25)
        ExternalControlSignalA = ExternalControlSignalA | (1 << 24)
        ExternalControlSignalA = ExternalControlSignalA | (1 << 23)
        ExternalControlSignalA = ExternalControlSignalA | (1 << 22)
        ExternalControlSignalA = ExternalControlSignalA | (1 << 21)
        ExternalControlSignalA = ExternalControlSignalA | (1 << 20)
        simulator:setInputNumber(7, binaryToOutput(ExternalControlSignalA))
        simulator:setInputNumber(8, binaryToOutput(ExternalControlSignalB))
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
            Track targets using mass to reduce distance checks - Done
            Give targets a priority based on potential danger - Cancled for now
            Distribute target data to several weapon scripts based on what a weapon can aim at - Done for Spearhead only
                This can be done internally using a list of weapon position offsets and range of motion, or by allowing weapons to send requests for certain targets.
            Maybe allow aiming radar in a special single-target mode? -- Done

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
require('OldRadarTarget')

function outputTarget (startChannel, target)
    target = target or EMPTY_TARGET
    for i = 0, 8 do
        output.setNumber(startChannel + i, target[#target][i // 3 + 2][i%3 + 1])
    end
    output.setBool(startChannel, externalControlBits[14] or externalControlBits[12] and target.distance < range)
end

-- function applyMassSettings(settingString, classValue)
--     for massValue in string.gmatch(settingString, "(%d+)") do
--         classes[tonumber(massValue)] = tonumber(classValue)
--     end
-- end

-- applyMassSettings(property.getText('M1'), 1)
-- applyMassSettings(property.getText('M2'), 3)
-- applyMassSettings(property.getText('M3'), 3)

--[[
    External Control Signal:
        Channel 7:
            Bit 18: Click
            Bit 9 - 17: Click X
            Bit 1 - 8: Click Y
        Channel 8:
            Bit 9 - 16: Zoom
            Bit 1 - 8: Range
]]--

POSITION_MASK = 2^24 - 1
EMPTY_TARGET = newTarget({0, IIVector(), IIVector()})
EMPTY_TARGET.distance = 5000

radarPosition = IIVector()

localNewTargetPosition = IIVector()
newTargetPosition = IIVector()

classes = {}

targets = {} -- Data stored at key 'mass' should be a list of all targets with that mass

userSelectedTargetMass = 0

externalControlBits = {}

searchPatternState = 1
pastRadarFacings = {0}

transposedRadarRotationMatrix = {
    {},
    {},
    {}
}

function onTick()
    radarPosition:setVector(input.getNumber(1), input.getNumber(2), input.getNumber(3))

    rawXRotation = input.getNumber(4)
    rawYRotation = input.getNumber(5)
    rawZRotation = input.getNumber(6) - PI/2

    for i = 1, 6 do
        output.setNumber(i, input.getNumber(i))
    end

    local c1, s1, c2, s2, c3, s3 = math.cos(rawXRotation), math.sin(rawXRotation), math.cos(rawYRotation), math.sin(rawYRotation), math.cos(rawZRotation), math.sin(rawZRotation)
    radarRotationMatrix = {
        IIVector(c3*s1 - c1*s2*s3, -s1*s2*s3 - c1*c3, -c2*s3),
        IIVector(c1*c2,            c2*s1,             -s2),
        IIVector(s1*s3 + c1*s2*c3, c3*s1*s2 - c1*s3,  c2*c3)
    }
    for i = 1, 3 do
        for j = 1, 3 do
            transposedRadarRotationMatrix[i][j] = radarRotationMatrix[j][i]
        end
    end

    externalControlSignalA = inputToBinary(7)
    externalControlSignalB = inputToBinary(8)

    for i = 1, 14 do
        externalControlBits[i] = externalControlSignalA & 1 << (17+i) == 1 << (17+i)
    end

    operation = externalControlBits[7] and 1 or externalControlBits[8] and 2 or externalControlBits[9] and 3 or 0
    range = integerToFloat(externalControlSignalB & 2^8 - 1, MIN_RANGE, RANGE_RANGE, MAX_RANGE_INTEGER)

    -- wasClicked = click
    -- click = externalControlSignalA >> 17 & 1 == 1
    -- clickX = externalControlSignalA >> 8 & 2^9 - 1
    -- clickY = externalControlSignalA & 2^8 - 1

    -- zoom = integerToFloat(externalControlSignalB >> 8 & 2^8 - 1, MIN_ZOOM, ZOOM_RANGE, MAX_ZOOM_INTEGER)

    pastRadarFacing = pastRadarFacings[1] * PI2 -- Account for delay between sending a new facing value, and getting values created after it has applied.
    -- All other signals are synced in logic
    searchPatternState = searchPatternState%SEARCH_PATTERN_SIZE + 1

    newTargets = {}
    possibleMatches = {}
    for i = 0, 7 do

        local newPos, newMass = {inputToBinary(i*3 + 9), inputToBinary(i*3 + 10), inputToBinary(i*3 + 11)}, 0

        for j = 1, 3 do
            newMass = newMass << MASS_BITS_PER_CHANNEL | newPos[j] >> 31 & 1 | newPos[j] & MASS_MASK
        end
        for j = 1, 4 do
            newMass = newMass | (input.getBool(j + i*4) and 1 << (MASS_BITS - j) or 0)
        end

        newMass = IIfloor(integerToFloat(newMass, MIN_MASS, MASS_RANGE, MAX_MASS_INTEGER) * MASS_RESOLUTION + 0.5) / MASS_RESOLUTION

        if newMass > 0 and externalControlBits[classes[newMass] or 2] then
            for j = 1, 3 do
                newPos[j] = integerToFloat(newPos[j] >> MASS_BITS_PER_CHANNEL - 1 & POSITION_MASK, MIN_POSITION, POSITION_RANGE, MAX_POSITION_INTEGER)
            end

            localNewTargetPosition:setVector(
                math.cos(pastRadarFacing) * newPos[1] - math.sin(pastRadarFacing) * newPos[2],
                math.cos(pastRadarFacing) * newPos[2] + math.sin(pastRadarFacing) * newPos[1],
                newPos[3]
            )

            newTargetPosition:copyVector(localNewTargetPosition)
            newTargetPosition:setAdd(RADAR_OFFSET)
            newTargetPosition:matrixRotate(radarRotationMatrix)
            newTargetPosition:setAdd(radarPosition)
            newTargets[i] = {newMass, localNewTargetPosition:cloneVector(), newTargetPosition:cloneVector()}

            if not targets[newMass] then -- There are no currently tracked targets with this mass, so skip trying to match them
                targets[newMass] = {} -- Because this is the first target of this mass, initialize the category it will be stored in
            else
                if not possibleMatches[newMass] then
                    possibleMatches[newMass] = {} -- Because this is the first new target of this mass, initialize the category it will be stored in
                end

                for matchIndex, target in pairs(targets[newMass]) do -- Loop through all currently tracked targets with the same mass as the new one
                    local matchDistance = target.position:distanceTo(newTargetPosition)
                    if matchDistance < WORST_MATCH_DISTANCE then
                        possibleMatches[newMass][#possibleMatches[newMass]+1] = {
                            matchDistance,
                            i,
                            matchIndex
                        }
                    end
                end
            end
        end
    end

    for targetMass, targetMassGroup in pairs(possibleMatches) do
        table.sort(targetMassGroup, function (a, b) -- Sort the possibleMatches by distance so that the best ones are tried first
            return a[1] < b[1]
        end)
        for i, possibleMatch in ipairs(targetMassGroup) do -- Loop through the matches, starting with the best one. If the match applies, the new target will be removed and the old one updated
            targets[targetMass][possibleMatch[3]]:newSighting(possibleMatch[2]) -- newSighting will update its parent and delete the newTarget if the match is applied
        end
    end

    for i, remainingTarget in pairs(newTargets) do -- All targets in this table were unable to find a valid match, so add them as new targets.
        targets[remainingTarget[1]][remainingTarget[3][1]] = newTarget(remainingTarget)
    end

    for targetMass, targetMassGroup in pairs(targets) do
        for targetKey, target in pairs(targetMassGroup) do
            target:update()
            if userSelectedTargetKey == targetKey then
                manualRadarFacing = math.atan(target.localPosition[2], target.localPosition[1])/PI2
            end
            if externalControlBits[(classes[targetMass] or 2) + 3] then -- Check if target meets requirements for being fired upon
                -- Decide if any of the currently selected targets should be replaced with this one
                -- It is better to shoot a target that is slightly less important than to constantly swap and never shoot, so only switch targets if the current one is wrong enough
                upperTarget = target.localPosition[3] > -5 and (upperTarget and target.distance < upperTarget.distance - 100 and target or upperTarget or target) or upperTarget
                lowerTarget = target.localPosition[3] < 5 and (lowerTarget and target.distance < lowerTarget.distance - 100 and target or lowerTarget or target) or lowerTarget
            end
            if target.timeSinceLastSeen > MAX_TIME_UNSEEN then -- If a target has not been seen for a long time, delete it
                targets[targetMass][targetKey] = nil
            end
        end
    end

    outputTarget(13, upperTarget)
    outputTarget(22, lowerTarget)

    radarFacing = externalControlBits[11] and manualRadarFacing or SEARCH_PATTERN[searchPatternState]
    pastRadarFacings[#pastRadarFacings+1] = radarFacing
    if #pastRadarFacings > RADAR_FACING_DELAY then
        table.remove(pastRadarFacings, 1)
    end
    output.setNumber(32, -radarFacing)
end

function onDraw()
    -- worldClickX, worldClickY = map.screenToMap(radarPosition[1], radarPosition[2], zoom, SCREEN_WIDTH, SCREEN_HEIGHT, clickX, clickY)
    nearestClickDistance = MAX_CLICK_DISTANCE
    for targetMass, targetMassGroup in pairs(targets) do
        for targetKey, target in pairs(targetMassGroup) do
            local drawSize, positionScreenX, positionScreenY = IImin(IImax(targetMass/10000, 2.5), 10), map.mapToScreen(radarPosition[1], radarPosition[2], integerToFloat(externalControlSignalB >> 8 & 2^8 - 1, MIN_ZOOM, ZOOM_RANGE, MAX_ZOOM_INTEGER), SCREEN_WIDTH, SCREEN_HEIGHT, target.position[1], target.position[2])
            screen.setColor(TARGET_COLORS[classes[targetMass] or 2]:getVector()) -- Color the target based on what class it falls into

            -- screen.drawText(positionScreenX, positionScreenY, string.format('%.0f', target.mass))
            screen.drawCircleF(positionScreenX, positionScreenY, drawSize)
            screen.setColor(userSelectedTargetKey == targetKey and 255 or 0, lowerTarget == target and 255 or 0, upperTarget == target and 255 or 0) -- Highlight Depending on current targets
            screen.drawCircle(positionScreenX, positionScreenY, drawSize + 1)

            if externalControlSignalA >> 17 & 1 == 1 then -- If the user has clicked the screen, check if this is the target that was clicked
                local clickDistance = ((positionScreenX - (externalControlSignalA >> 8 & 2^9 - 1))^2 + (positionScreenY - (externalControlSignalA & 2^8 - 1))^2)^0.5
                if clickDistance < nearestClickDistance then
                    nearestClickDistance = clickDistance
                    userSelectedTargetKey = targetKey
                    userSelectedTargetMass = targetMass
                end
            end
        end
    end

    if operation > 0 then -- Change the selected target's class
        classes[userSelectedTargetMass] = operation
    end
end
