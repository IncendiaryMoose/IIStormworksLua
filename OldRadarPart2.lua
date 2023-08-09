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


        local massInteger = floatToInteger(2000, MIN_MASS, MASS_RANGE, MAX_MASS_INTEGER)
        targetPosition = {ticks%200, 0, 0}
        for j = 1, 4 do
            local bitMask = 1 << (MASS_BITS - j)
            simulator:setInputBool(j, massInteger & bitMask == bitMask)
        end
        simulator:setInputNumber(9, binaryToOutput(((massInteger >> (MASS_BITS - 5) & 1) << 31) | floatToInteger(targetPosition[1], MIN_POSITION, POSITION_RANGE, MAX_POSITION_INTEGER) << (MASS_BITS_PER_CHANNEL - 1) | (massInteger >> MASS_BITS_PER_CHANNEL*2 & MASS_MASK)))
        simulator:setInputNumber(10, binaryToOutput(((massInteger >> (MASS_BITS - 5 - MASS_BITS_PER_CHANNEL) & 1) << 31) | floatToInteger(targetPosition[2], MIN_POSITION, POSITION_RANGE, MAX_POSITION_INTEGER) << (MASS_BITS_PER_CHANNEL - 1) | (massInteger >> MASS_BITS_PER_CHANNEL & MASS_MASK)))
        simulator:setInputNumber(11, binaryToOutput(((massInteger >> (MASS_BITS - 5 - MASS_BITS_PER_CHANNEL*2) & 1) << 31) | floatToInteger(targetPosition[3], MIN_POSITION, POSITION_RANGE, MAX_POSITION_INTEGER) << (MASS_BITS_PER_CHANNEL - 1) | (massInteger & MASS_MASK)))


        Click = screenConnection.isTouched
        clickX = screenConnection.touchX
        clickY = screenConnection.touchY
        externalControlSignalA = (Click and clickX > 45 and clickX < SCREEN_WIDTH-45 and 1 << 17 or 0) | clickX << 8 | clickY
        externalControlSignalB = floatToInteger(simulator:getSlider(1) + MIN_ZOOM, MIN_ZOOM, ZOOM_RANGE, MAX_ZOOM_INTEGER) << 8 | floatToInteger(simulator:getSlider(1) + MIN_RANGE, MIN_RANGE,  RANGE_RANGE, MAX_RANGE_INTEGER)

        externalControlSignalA = externalControlSignalA | (1 << 25)
        externalControlSignalA = externalControlSignalA | (1 << 24)
        externalControlSignalA = externalControlSignalA | (1 << 23)
        externalControlSignalA = externalControlSignalA | (1 << 22)
        externalControlSignalA = externalControlSignalA | (1 << 21)
        externalControlSignalA = externalControlSignalA | (1 << 20)
        simulator:setInputNumber(7, binaryToOutput(externalControlSignalA))
        simulator:setInputNumber(8, binaryToOutput(externalControlSignalB))
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

targets = {} -- Data stored at key 'mass' should be a list of all targets with that mass

newTarget = function (target)
    return {
        {
            0,
            target[3]:cloneVector(),
            IIVector(),
            IIVector()
        },
        position = target[3]:cloneVector(),
        localPosition = target[2]:cloneVector(),
        velocity = IIVector(),
        acceleration = IIVector(),
        timeSinceLastSeen = 0,
        -- timesSeen = 0,
        newSighting = function (self, newTargetIndex)
            local possibleSighting = newTargets[newTargetIndex]
            if possibleSighting and self.timeSinceLastSeen > 0 then

                self.localPosition:copyVector(possibleSighting[2])

                self[#self+1] = {
                    self.timeSinceLastSeen,
                    possibleSighting[3]:cloneVector(),
                    IIVector(),
                    IIVector()
                }
                if #self > 1 then
                    self.velocity:copyVector(possibleSighting[3])
                    self.velocity:setAdd(self[#self - 1][2], -1)
                    self.velocity:setScale(1/self.timeSinceLastSeen)
                    self[#self][3]:copyVector(self.velocity)

                    if #self > 3 then
                        self.acceleration:copyVector(self.velocity)
                        self.acceleration:setAdd(self[#self - 1][3], -1)
                        self.acceleration:setScale(1/self.timeSinceLastSeen)
                        self[#self][4]:copyVector(self.acceleration)
                    end
                end

                self.timeSinceLastSeen = 0
                -- self.timesSeen = self.timesSeen + 1
                newTargets[newTargetIndex] = nil
            end
        end,
        update = function (self, radar)
            self.position:copyVector(self[#self][2])
            if #self > 1 then
                self.velocity:setVector(0, 0, 0)
                self.acceleration:setVector(0, 0, 0)
                local totalVelocityWeight, totalAccelerationWeight = 0, 0
                for index, historyPoint in ipairs(self) do
                    if historyPoint[3] then
                        self.velocity:setAdd(historyPoint[3], index * 2)
                        totalVelocityWeight = totalVelocityWeight + index * 2
                    end
                    if historyPoint[4] then
                        self.acceleration:setAdd(historyPoint[4], index * 2)
                        totalAccelerationWeight = totalAccelerationWeight + index * 2
                    end
                end

                self.velocity:setScale(1 / (totalVelocityWeight > 0 and totalVelocityWeight or 1))

                self.acceleration:setScale(1 / (totalAccelerationWeight > 0 and totalAccelerationWeight or 1))

                self.position:setAdd(self.velocity, self.timeSinceLastSeen + RADAR_FACING_DELAY - 3)
                self.position:setAdd(self.acceleration, (self.timeSinceLastSeen + RADAR_FACING_DELAY)^2 / 2)
            end
            self.distance = self.position:distanceTo(radar)
            self.timeSinceLastSeen = self.timeSinceLastSeen + 1
        end,
        outputSelf = function (self, startChannel)
            local latestSighting = self[#self]
            for i = 0, 8 do
                print(i%3 + 1)
                output.setNumber(startChannel + i, latestSighting[i // 3 + 2][i%3 + 1])
            end
            output.setBool(startChannel, externalControlSignalA >> 26 & 1 == 1)
        end
    }
end

-- function replaceTargetIfBetter(currentTarget, possibleTarget)
--     currentTarget = currentTarget and (possibleTarget.distance < currentTarget.distance - 100 and possibleTarget or currentTarget) or possibleTarget
-- end

radarPosition = IIVector()

localNewTargetPosition = IIVector()
newTargetPosition = IIVector()

classes = {}
track = {}
attack = {}
userSelectedTargetMass = 0

-- function applyMassSettings(settingString, classValue)
--     for massValue in string.gmatch(settingString, "(%d+)") do
--         classes[tonumber(massValue)] = tonumber(classValue)
--     end
-- end

-- applyMassSettings(property.getText('M1'), 1)
-- applyMassSettings(property.getText('M2'), 3)
-- applyMassSettings(property.getText('M3'), 3)

searchPatternState = 1
pastRadarFacings = {0}

-- click = false

--[[
    External Control Signal:
        Channel 7:
            Bit 28: Combat
            Bit 27: Auto Attack
            Bit 26: Track Friendly
            Bit 25: Attack Friendly
            Bit 24: Track Unkown
            Bit 23: Attack Unkown
            Bit 22: Track Hostile
            Bit 21: Attack Hostile
            Bit 19 - 20: Class to apply to next clicked target
            Bit 18: Click
            Bit 9 - 17: Click X
            Bit 1 - 8: Click Y
        Channel 8:
            Bit 9 - 16: Zoom
            Bit 1 - 8: Range
]]--

POSITION_MASK = 2^24 - 1
RADAR_OFFSET = {-5, 0, 0}

function onTick()
    radarPosition:setVector(input.getNumber(1), input.getNumber(2), input.getNumber(3))

    rawXRotation = input.getNumber(4)
    rawYRotation = input.getNumber(5)
    rawZRotation = input.getNumber(6) - PI/2

    local c1, s1, c2, s2, c3, s3 = math.cos(rawXRotation), math.sin(rawXRotation), math.cos(rawYRotation), math.sin(rawYRotation), math.cos(rawZRotation), math.sin(rawZRotation)
    radarRotationMatrix = {
        IIVector(c3*s1 - c1*s2*s3,  -s1*s2*s3 - c1*c3, -c2*s3),
        IIVector(c1*c2,           c2*s1,            -s2),
        IIVector(s1*s3 + c1*s2*c3, c3*s1*s2 - c1*s3,   c2*c3)
    }

    pastRadarFacing = pastRadarFacings[1] * -PI2 -- Account for delay between sending a new facing value, and getting values created after it has applied.
    -- All other signals are synced in logic
    searchPatternState = searchPatternState%SEARCH_PATTERN_SIZE + 1
    radarFacing = SEARCH_PATTERN[searchPatternState]
    pastRadarFacings[#pastRadarFacings+1] = radarFacing
    if #pastRadarFacings > RADAR_FACING_DELAY then
        table.remove(pastRadarFacings, 1)
    end
    output.setNumber(32, radarFacing)

    externalControlSignalA = inputToBinary(7)
    for i = 1, 3 do
        track[i] = externalControlSignalA & TRACK_BITS[i] == TRACK_BITS[i]
        attack[i] = externalControlSignalA & ATTACK_BITS[i] == ATTACK_BITS[i]
    end
    externalControlSignalB = inputToBinary(8)

    operation = externalControlSignalA >> 18 & 3
    -- wasClicked = click
    -- click = externalControlSignalA >> 17 & 1 == 1
    -- clickX = externalControlSignalA >> 8 & 2^9 - 1
    -- clickY = externalControlSignalA & 2^8 - 1

    -- zoom = integerToFloat(externalControlSignalB >> 8 & 2^8 - 1, MIN_ZOOM, ZOOM_RANGE, MAX_ZOOM_INTEGER)
    -- range = integerToFloat(externalControlSignalB & 2^8 - 1, MIN_RANGE, RANGE_RANGE, MAX_RANGE_INTEGER)

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

        if newMass > 0.1 and track[classes[newMass] or 2] then
            for j = 1, 3 do
                newPos[j] = integerToFloat(newPos[j] >> MASS_BITS_PER_CHANNEL - 1 & POSITION_MASK, MIN_POSITION, POSITION_RANGE, MAX_POSITION_INTEGER)
            end

            localNewTargetPosition:setVector(
                math.cos(pastRadarFacing) * newPos[1] - math.sin(pastRadarFacing) * newPos[2],
                math.cos(pastRadarFacing) * newPos[2] + math.sin(pastRadarFacing) * newPos[1],
                newPos[3]
            )
            localNewTargetPosition:setAdd(RADAR_OFFSET)
            newTargetPosition:copyVector(localNewTargetPosition)
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
            target:update(radarPosition)
            if attack[classes[targetMass] or 2] and target.distance < integerToFloat(externalControlSignalB & 2^8 - 1, MIN_RANGE, RANGE_RANGE, MAX_RANGE_INTEGER) then -- Check if target meets requirements for being fired upon
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

    if upperTarget then
        upperTarget:outputSelf(13)
    end
    if lowerTarget then
        lowerTarget:outputSelf(22)
    end
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
