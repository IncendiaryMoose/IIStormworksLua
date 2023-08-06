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

targets = {} -- Data stored at key 'mass' should be a list of all targets with that mass

newTarget = function (initialPosition)
    return {
        position = IIVector(initialPosition:getVector()),
        velocity = IIVector(),
        acceleration = IIVector(),
        history = {},
        timeSinceLastSeen = 0,
        timesSeen = 0,
        threatScore = 0,
        newSighting = function (self, possibleSighting)
            if possibleSighting and self.timeSinceLastSeen > 0 then

                self.history[#self.history+1] = {
                    self.timeSinceLastSeen,
                    IIVector(possibleSighting:getVector())
                }
                if #self.history > 1 then
                    self.velocity:setVector(possibleSighting:getVector())
                    self.velocity:setAdd(self.history[#self.history - 1][2], -1)
                    self.velocity:setScale(1/self.timeSinceLastSeen)
                    self.history[#self.history][3] = IIVector(self.velocity:getVector())

                    if #self.history > 2 then
                        self.acceleration:setVector(self.velocity:getVector())
                        self.acceleration:setAdd(self.history[#self.history - 1][3], -1)
                        self.acceleration:setScale(1/self.timeSinceLastSeen)
                        self.history[#self.history][4] = IIVector(self.acceleration:getVector())
                    end
                end

                self.timeSinceLastSeen = 0
                self.timesSeen = self.timesSeen + 1

                return true
            end
            return false
        end,
        update = function (self)
            self:setPositionInTicks(self.timeSinceLastSeen)
            self.timeSinceLastSeen = self.timeSinceLastSeen + 1
        end,
        setPositionInTicks = function (self, ticks)
            self.position:setVector(self.history[#self.history][2]:getVector())
            if #self.history > 1 then
                self.velocity:setVector(0, 0, 0)
                self.acceleration:setVector(0, 0, 0)
                local totalVelocityWeight, totalAccelerationWeight = 0, 0
                for index, historyPoint in ipairs(self.history) do
                    if historyPoint[3] then
                        self.velocity:setAdd(historyPoint[3], index * 2)
                        totalVelocityWeight = totalVelocityWeight + index * 2
                    end
                    if historyPoint[4] then
                        self.acceleration:setAdd(historyPoint[4], index * 2)
                        totalAccelerationWeight = totalAccelerationWeight + index * 2
                    end
                end
                if totalVelocityWeight > 0 then
                    self.velocity:setScale(1 / totalVelocityWeight)
                end

                if totalAccelerationWeight > 0 then
                    self.acceleration:setScale(1 / totalAccelerationWeight)
                end

                self.position:setAdd(self.velocity, ticks)
                self.position:setAdd(self.acceleration, ticks^2 / 2)
            end
        end
    }
end

radarPosition = IIVector()
radarRotation = IIVector()

newTargetPosition = IIVector()

classes = {}
track = {}
attack = {}

function applyMassSettings(settingString, classValue)
    for massValue in string.gmatch(settingString, "(%d+)") do
        classes[tonumber(massValue)] = tonumber(classValue)
    end
end

applyMassSettings(property.getText('M1'), 0)
applyMassSettings(property.getText('M2'), 2)
applyMassSettings(property.getText('M3'), 2)

SEARCH_PATTERN = { -- What order the radar scans in

}

WORST_MATCH_DISTANCE = 100 -- The largest allowed distance between an existing and a new target for them to be considered the same target
MAX_TIME_UNSEEN = 100 -- How many ticks a target can remain unseen before it is removed
MASS_BITMASK = 2^4 - 1 -- Bitmask for the last 4 bits of a number, used in extracting the encoded mass values for each target
POSITION_MEMORY_LENGTH = 10 -- How many past positions of a target to keep in memory

SCREEN_HEIGHT = 160
SCREEN_WIDTH = 288

MAX_CLICK_DISTANCE = 20

TARGET_COLORS = {
    IIVector(0, 255, 0),
    IIVector(0, 0, 255),
    IIVector(255, 0, 0),
    IIVector(255, 255, 255)
}

click = false

--[[
    External Control Signal:
        Channel 7:
            Bit 7: Track Friendly
            Bit 8: Attack Friendly
            Bit 9: Track Unkown
            Bit 10: Attack Unkown
            Bit 11: Track Hostile
            Bit 12: Attack Hostile
            Bit 13 - 14: Class to apply to next clicked target
            Bit 15: Click
            Bit 16 - 24: Click X
            Bit 25 - 32: Click Y
        Channel 8:
            Bit 17 - 24: Zoom
            Bit 25 - 32: Range
]]--

function onTick()
    radarPosition:setVector(input.getNumber(1), input.getNumber(2), input.getNumber(3))
    radarRotation:setVector(input.getNumber(1), input.getNumber(2), input.getNumber(3))

    externalControlSignalA = inputToBinary(input.getNumber(7))
    externalControlSignalB = inputToBinary(input.getNumber(8))

    operation = externalControlSignalA >> 18 & 3
    wasClicked = click
    click = externalControlSignalA >> 17 & 1 == 1
    clicked = click and not wasClicked
    clickX = externalControlSignalA >> 8 & 2^9 - 1
    clickY = externalControlSignalA & 2^8 - 1

    zoom = binaryToFloat(externalControlSignalB >> 8, 3, 5, 3, 1) + 25
    range = binaryToFloat(externalControlSignalB, 3, 5, 3, 1) * 2000 + 500

    newTargets = {}
    possibleMatches = {}
    for i = 0, 7 do
        local massBinary = 0
        for j = 1, 4 do
            massBinary = massBinary | (input.getBool(j + i*4) and 1 << (4 - j) or 0)
        end

        local zBinary = inputToBinary(input.getNumber(i*3 + 11))
        massBinary = zBinary & MASS_BITMASK | massBinary << 4
        zBinary = zBinary >> 4

        local yBinary = inputToBinary(input.getNumber(i*3 + 10))
        massBinary = yBinary & MASS_BITMASK | massBinary << 4
        yBinary = yBinary >> 4

        local xBinary = inputToBinary(input.getNumber(i*3 + 9))
        massBinary = xBinary & MASS_BITMASK | massBinary << 4
        xBinary = xBinary >> 4


        local newTargetMass = binaryToFloat(massBinary, 4, 12, -4, 1)

        if track[classes[newTargetMass]] then

            newTargetPosition:setVector(
                binaryToFloat(xBinary, 4, 23, 0),
                binaryToFloat(yBinary, 4, 23, 0),
                binaryToFloat(zBinary, 4, 23, 0)
            )
            newTargets[i] = {position = IIVector(newTargetPosition:getVector()), mass = newTargetMass}

            if not targets[newTargetMass] then -- There are no currently tracked targets with this mass, so skip trying to match them
                targets[newTargetMass] = {} -- Because this is the first target of this mass, initialize the category it will be stored in
                goto TargetRegistered
            end

            if not possibleMatches[newTargetMass] then
                possibleMatches[newTargetMass] = {} -- Because this is the first new target of this mass, initialize the category it will be stored in
            end

            for matchIndex, target in pairs(targets[newTargetMass]) do -- Loop through all currently tracked targets with the same mass as the new one
                local matchDistance = target.position:distanceTo(newTargetPosition)
                if matchDistance < WORST_MATCH_DISTANCE then
                    possibleMatches[newTargetMass][#possibleMatches[newTargetMass]+1] = {
                        matchDistance = matchDistance,
                        newTargetIndex = i,
                        matchIndex = matchIndex
                    }
                end
            end
        end
        ::TargetRegistered::
    end

    for targetMass, targetMassGroup in pairs(possibleMatches) do
        table.sort(targetMassGroup, function (a, b) -- Sort the possibleMatches by distance so that the best ones are tried first
            return a.matchDistance < b.matchDistance
        end)
        for i, possibleMatch in ipairs(targetMassGroup) do -- Loop through the matches, starting with the best one. If the match applies, the new target will be removed and the old one updated
            if targets[targetMass][possibleMatch.matchIndex]:newSighting(newTargets[possibleMatch.newTargetIndex]) then -- newSighting will update its parent and return true if the match is applied
                newTargets[possibleMatch.newTargetIndex] = nil -- If the match applied, delete the new target to avoid creating a duplicate later
            end
        end
    end

    for key, remainingTarget in pairs(newTargets) do -- All targets in this table were unable to find a valid match, so add them as new targets.
        targets[remainingTarget.mass][remainingTarget.position[1] + remainingTarget.position[2]] = newTarget(remainingTarget.position)
    end

    for targetMass, targetMassGroup in pairs(newTargets) do
        for targetKey, target in pairs(targetMassGroup) do
            target:update()
            if attack[classes[targetMass]] and radarPosition:distanceTo(target.position) < range then -- Check if target meets requirements for being fired upon
                -- Convert to local coords
                -- It is better to shoot a target that is slightly less important than to constantly swap and never shoot, so only switch targets if the current one is wrong enough
                -- Decide if any of the currently selected targets should be replaced with this one
            end
            if target.timeSinceLastSeen > MAX_TIME_UNSEEN then -- If a target has not been seen for a long time, delete it
                targets[targetMass][targetKey] = nil
            end
        end
    end

end

function onDraw()
    worldClickX, worldClickY = map.screenToMap(radarPosition[1], radarPosition[2], zoom, SCREEN_WIDTH, SCREEN_HEIGHT, clickX, clickY)
    nearestClickDistance = MAX_CLICK_DISTANCE
    nearestClickedTargetMass = nil
    for targetMass, targetMassGroup in pairs(newTargets) do
        for targetKey, target in pairs(targetMassGroup) do
            local positionScreenX, positionScreenY = map.mapToScreen(radarPosition[1], radarPosition[2], zoom, SCREEN_WIDTH, SCREEN_HEIGHT, target.position[1], target.position[2])
            screen.setColor(TARGET_COLORS[targetMass]:getVector()) -- Color the target based on what class it falls into
            if debugMass then -- Use the mass of the target as the marker instead of a dot
                screen.drawText(positionScreenX, positionScreenY, string.format('%.0f', target.mass))
            else
                screen.drawCircleF(positionScreenX, positionScreenY, IImax(IImin(target.mass/10000, 10), 2.5))
            end
            if userSelectedTargetKey and targetKey == userSelectedTargetKey then -- Highlight if this is the user selected target
                screen.setColor(TARGET_COLORS[4]:getVector())
                screen.drawCircle(positionScreenX, positionScreenY, IImax(IImin(target.mass/10000, 10), 2.5))
            end
            if clicked then -- If the user has clicked the screen, check if this is the target that was clicked
                local clickDistance = ((positionScreenX - clickX)^2 + (positionScreenY - clickY)^2)^0.5
                if clickDistance < nearestClickDistance then
                    nearestClickDistance = clickDistance
                    nearestClickedTargetMass = targetMass
                    userSelectedTargetKey = targetKey
                end
            end
        end
    end

    if clicked and operation > 0 and nearestClickedTargetMass then -- If a target was clicked while in class edit mode, change the target's class to the selected one
        classes[nearestClickedTargetMass] = operation
    end
end
