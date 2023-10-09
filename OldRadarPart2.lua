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


        local MassInteger = floatToInteger(2000, 0, MASS_RANGE, MAX_MASS_INTEGER)
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
    TODO: Test a version with a flattened list for targets, with the nested list only storing keys
        This might speed up some of the loops, and it will simplify selected targets
]]--

require('II_MathHelpers')
require('II_BinaryIO')
require('II_SmallVectorMath')
require('OldRadarConstants')

function newHistoryPoint(time, position)
    return {
        time,
        position:cloneVector(),
        IIVector(),
        IIVector()
    }
end

function outputTarget (startChannel, target)
    target = target or {newHistoryPoint(0, IIVector()), distance = 9999}
    for i = 0, 8 do
        output.setNumber(startChannel + i, target[#target][i // 3 + 2][i%3 + 1])
    end
    output.setBool(startChannel, externalControlBits[14] or externalControlBits[12] and target.distance < range)
end

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

radarPosition = IIVector()

localNewTargetPosition = IIVector()
newTargetPosition = IIVector()

classes = {}

targets = {{}} -- Data stored at key 'mass' should be a list of all targets with that mass

lowerMass = 1
upperMass = 1

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
        externalControlBits[i] = externalControlSignalA >> (17+i) & 1 == 1
    end

    operation = externalControlBits[7] and 1 or externalControlBits[8] and 2 or externalControlBits[9] and 3 or 0
    range = fastIntegerToFloat(externalControlSignalB & 2^8 - 1, MIN_RANGE, RANGE_INT_TO_FLOAT_RATIO)

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

        newMass = IIfloor(fastIntegerToFloat(newMass, 0, MASS_INT_TO_FLOAT_RATIO) * MASS_RESOLUTION + 0.5) / MASS_RESOLUTION

        if newMass > 0 and externalControlBits[classes[newMass] or 2] then
            for j = 1, 3 do
                newPos[j] = fastIntegerToFloat(newPos[j] >> MASS_BITS_PER_CHANNEL - 1 & POSITION_MASK, MIN_POSITION, POSITION_INT_TO_FLOAT_RATIO)
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
        targets[remainingTarget[1]][#targets[remainingTarget[1]] + 1] = { -- Fill the first empty spot with the new target
            newHistoryPoint(0, remainingTarget[3]),
            position = remainingTarget[3]:cloneVector(),
            localPosition = remainingTarget[2]:cloneVector(),
            velocity = IIVector(),
            acceleration = IIVector(),
            timeSinceLastSeen = 0,
            newSighting = function (self, newTargetIndex)
                local possibleSighting = newTargets[newTargetIndex]
                if possibleSighting and self.timeSinceLastSeen > 0 then

                    self.localPosition:copyVector(possibleSighting[2])

                    self[#self+1] = newHistoryPoint(self.timeSinceLastSeen, possibleSighting[3])
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
                    newTargets[newTargetIndex] = nil
                end
            end,
            update = function (self)
                self.position:copyVector(self[#self][2])
                if #self > 1 then
                    self.velocity:setVector(0, 0, 0)
                    self.acceleration:setVector(0, 0, 0)
                    local totalWeight, correctedTime = 0, self.timeSinceLastSeen + RADAR_FACING_DELAY - 3
                    for index, historyPoint in ipairs(self) do
                        self.velocity:setAdd(historyPoint[3], index * 2)
                        self.acceleration:setAdd(historyPoint[4], index * 2)
                        totalWeight = totalWeight + index * 2
                    end

                    self.velocity:setScale(1 / totalWeight)

                    self.acceleration:setScale(1 / totalWeight)

                    self.position:setAdd(self.velocity, correctedTime)
                    self.position:setAdd(self.acceleration, correctedTime^2 / 2)
                    self.localPosition:copyVector(self.position)
                    self.localPosition:setAdd(radarPosition, -1)
                    self.localPosition:matrixRotate(transposedRadarRotationMatrix)
                    self.localPosition:setAdd(RADAR_OFFSET, -1)
                end
                self.distance = self.position:distanceTo(radarPosition)
                self.timeSinceLastSeen = self.timeSinceLastSeen + 1
            end
        }
    end

    manualRadarFacing = nil
    for targetMass, targetMassGroup in pairs(targets) do
        for targetKey, target in pairs(targetMassGroup) do
            target:update()
            if userSelectedTargetKey == targetKey then
                manualRadarFacing = math.atan(target.localPosition[2], target.localPosition[1])/PI2
            end
            if externalControlBits[(classes[targetMass] or 2) + 3] then -- Check if target meets requirements for being fired upon
                -- Decide if any of the currently selected targets should be replaced with this one
                -- It is better to shoot a target that is slightly less important than to constantly swap and never shoot, so only switch targets if the current one is wrong enough

                if target.localPosition[3] > -5 and (targets[upperMass][upperKey] and (targets[upperMass][upperKey].localPosition[3] < -5 or target.distance < targets[upperMass][upperKey].distance - 100) or not targets[upperMass][upperKey]) then
                    upperMass = targetMass
                    upperKey = targetKey
                end

                if target.localPosition[3] < 5 and (targets[lowerMass][lowerKey] and (targets[lowerMass][lowerKey].localPosition[3] > 5 or target.distance < targets[lowerMass][lowerKey].distance - 100) or not targets[lowerMass][lowerKey]) then
                    lowerMass = targetMass
                    lowerKey = targetKey
                end
            end
            if target.timeSinceLastSeen > MAX_TIME_UNSEEN then -- If a target has not been seen for a long time, delete it
                targets[targetMass][targetKey] = nil
            end
        end
    end

    outputTarget(13, targets[upperMass][upperKey])
    outputTarget(22, targets[lowerMass][lowerKey])

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
            local drawSize, positionScreenX, positionScreenY = IImin(IImax(targetMass/10000, 2.5), 10), map.mapToScreen(radarPosition[1], radarPosition[2], fastIntegerToFloat(externalControlSignalB >> 8 & 2^8 - 1, MIN_ZOOM, ZOOM_INT_TO_FLOAT_RATIO), SCREEN_WIDTH, SCREEN_HEIGHT, target.position[1], target.position[2])
            screen.setColor(TARGET_COLORS[classes[targetMass] or 2]:getVector()) -- Color the target based on what class it falls into

            -- screen.drawText(positionScreenX, positionScreenY, string.format('%.0f', target.mass))
            screen.drawCircleF(positionScreenX, positionScreenY, drawSize)
            screen.setColor(userSelectedTargetKey == targetKey and 255 or 0, lowerKey == targetKey and 255 or 0, upperKey == targetKey and 255 or 0) -- Highlight Depending on current targets
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
