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
    simulator:setProperty("Weapon Type", 4)
    simulator:setProperty("Accel", 0.75)
    simulator:setProperty("Jerk", 0.1)
    simulator:setProperty("Sample", 2)
    simulator:setProperty('Turret Mount Roll Offset', 0)
    simulator:setProperty('Turret Mount Pitch Offset', 0)
    simulator:setProperty('Turret Mount Yaw Offset', 0)
    simulator:setProperty('Delay', 0)
    simulator:setProperty('Max Prediction', 60)
    simulator:setProperty('Target', 9)
    simulator:setProperty('Arc Resolution', 30)

    -- Runs every tick just before onTick; allows you to simulate the inputs changing
    ---@param simulator Simulator Use simulator:<function>() to set inputs etc.
    ---@param ticks     number Number of ticks since simulator started
    tarX = 1200
    tarY = 0
    tarZ = 500
    selfX = 0
    tarDist = 0
    function onLBSimulatorTick(simulator, tocks)
        tocks = (tocks%1000)/1000
        selfX = 1200*math.cos(tocks*math.pi*2)+1200
        if true then
            tarX = 500*math.cos(tocks*math.pi*2)+1000
            tarY = 50*math.cos(tocks*math.pi*2)
            tarZ = 500*math.sin(tocks*math.pi*2)+500
        end
        tarDist = (tarX^2+tarZ^2)^0.5
        -- touchscreen defaults
        elevationAngle = math.asin((tarZ)/tarDist)
        local screenConnection = simulator:getTouchScreen(1)
        simulator:setInputBool(1, screenConnection.isTouched)
        simulator:setInputNumber(1, 0)
        simulator:setInputNumber(2, 0)
        simulator:setInputNumber(3, 0)
        simulator:setInputNumber(4, 0)
        simulator:setInputNumber(5, 0)
        simulator:setInputNumber(6, math.pi*simulator:getSlider(1))
        simulator:setInputNumber(9, tarX)
        simulator:setInputNumber(10, 0)
        simulator:setInputNumber(11, tarZ)
        simulator:setInputBool(27, simulator:getIsToggled(1))
        simulator:setInputBool(32, true)
    end;
end
---@endsection

require('II_SmallVectorMath')
require('II_IO')
require('OldRadarConstants')
require('II_Ballistics')

function newHistoryPoint(time, position)
    return {
        time,
        position:cloneVector(),
        IIVector(),
        IIVector()
    }
end

TARGET_INDEX = property.getNumber('Target')
TURRET_ROLL_OFFSET = property.getNumber('Turret Mount Roll Offset')
TURRET_PITCH_OFFSET = property.getNumber('Turret Mount Pitch Offset')
TURRET_YAW_OFFSET = property.getNumber('Turret Mount Yaw Offset')
TURRET_OFFSET = IIVector(0, 0, 0)
LATENCY = 5

initialVelocity = IIVector()
initialPosition = IIVector()

turretOffsetVector = IIVector((PI2/4)*TURRET_ROLL_OFFSET, (PI2/4)*TURRET_PITCH_OFFSET, (PI2/4)*TURRET_YAW_OFFSET)

referenceRotation = IIVector()
adjustedRotation = IIVector()
relativeRotation = IIVector()
vehicleRotation = IIVector()

target = {
    position = IIVector(),
    predictedPosition = IIVector(),
    velocity = IIVector(),
    acceleration = IIVector(),
    timeSinceLastSeen = 0,
    positionInTicks = function (self, t)
        self.predictedPosition:copyVector(self.position)
        self.predictedPosition:setAdd(self.velocity, t + self.timeSinceLastSeen)
        self.predictedPosition:setAdd(self.acceleration, (t + self.timeSinceLastSeen)^2 / 2)
        self.predictedPosition:setAdd(turret.position, -1)
        self.predictedPosition:matrixRotate(transposedRadarRotationMatrix)
        self.predictedPosition:setAdd(TURRET_OFFSET)
    end
}

turret = {
    newHistoryPoint(0, IIVector()),
    position = IIVector(),
    velocity = IIVector(),
    acceleration = IIVector(),
    -- timesSeen = 0,
    update = function (self, newPosition)
        self[#self+1] = newHistoryPoint(1, newPosition)
        if #self > 1 then
            self.velocity:copyVector(newPosition)
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

        self.position:copyVector(self[#self][2])
        if #self > 1 then
            self.velocity:setVector(0, 0, 0)
            self.acceleration:setVector(0, 0, 0)
            local totalWeight = 0
            for index, historyPoint in ipairs(self) do
                self.velocity:setAdd(historyPoint[3], index * 2)
                self.acceleration:setAdd(historyPoint[4], index * 2)
                totalWeight = totalWeight + index * 2
            end

            self.velocity:setScale(1 / totalWeight)

            self.acceleration:setScale(1 / totalWeight)

            self.position:setAdd(self.velocity, LATENCY)
            self.position:setAdd(self.acceleration, LATENCY^2 / 2)
        end
    end
}

travelTime = 60
range = false
accuracy = 0
efficiency = 0
vehicleRotationVelocity = IIVector()
previousVehicleRotation = IIVector()
rotationDelay = property.getNumber('Rot Delay')
positionDelay = property.getNumber('Pos Delay')
accuracyLevel = property.getNumber('Accuracy')

radarPosition = IIVector()
transposedRadarRotationMatrix = {{},{},{}}

function onTick()
    clearOutputs()
    if true then
        radarPosition:setVector(input.getNumber(1), input.getNumber(2), input.getNumber(3))

        rawXRotation = input.getNumber(4)
        rawYRotation = input.getNumber(5)
        rawZRotation = input.getNumber(6) - PI/2

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

        -- windDir = input.getNumber(7)
        -- windSpd = input.getNumber(8) / 60
        -- terminalVelocity:setVector(math.sin(windDir)*windSpd, math.cos(windDir)*windSpd, g/drag)

        target.position:setVector(1500, 500, 800)
        target.velocity:setVector(5, 1, -2)
        target.acceleration:setVector(0, 0, 0)
        timeToTarget = target.predictedPosition:magnitude()/(MUZZLE_VELOCITY + turret.velocity:dot(target.predictedPosition) / target.predictedPosition:magnitude() - 1) -- TODO: Make this first guess better, include vehicle speed
        target:positionInTicks(timeToTarget)
        for j = 1, 8 do
            turretPitch, turretYaw, timeToTarget = newtonMethod(IIVector(1, 5, 9), target.predictedPosition, timeToTarget)
            print(timeToTarget)
            target:positionInTicks(timeToTarget)
        end

        if input.getBool(TARGET_INDEX) then
            target.position:setVector(input.getNumber(TARGET_INDEX), input.getNumber(TARGET_INDEX+1), input.getNumber(TARGET_INDEX+2))
            target.velocity:setVector(input.getNumber(TARGET_INDEX+3), input.getNumber(TARGET_INDEX+4), input.getNumber(TARGET_INDEX+5))
            target.acceleration:setVector(input.getNumber(TARGET_INDEX+6), input.getNumber(TARGET_INDEX+7), input.getNumber(TARGET_INDEX+8))
            target.timeSinceLastSeen = 0
        end
        target:positionInTicks(LATENCY)
        target.distance = target.predictedPosition:magnitude()

        referenceRotation:setVector(0, arcsin((target.predictedPosition[3]) / target.distance), math.atan(target.predictedPosition[2], target.predictedPosition[1]))
        adjustedRotation:copyVector(referenceRotation)
        canHit = false
        if target.distance < MAX_RANGE then
            
        end
        
        -- relativeRotation:setVector(1, -adjustedRotation.z, adjustedRotation.x)
        -- relativeRotation:toCartesian()
        -- relativeRotation:rotate3D(vehicleRotation, true)
        -- relativeRotation:rotate3D(turretOffsetVector)
        -- outputNumbers[32] = math.asin(relativeRotation.z)
        -- outputNumbers[31] = math.atan(relativeRotation.x, relativeRotation.y)
        -- outputNumbers[30] = target.distance
        -- outputBools[31] = canHit
    end
    setOutputs()
end
--[[
function onDraw()
    screen.setColor(255, 255, 255)
    screen.drawText(1, 2, string.format('Efficiency:%.0f%%', efficiency))
    screen.drawText(1, 9, string.format('Accuracy:%.3f', accuracy))
    screen.drawText(1, 16, string.format('Travel Time:%.3f', travelTime))
end
--]]
function ballistic()
    local attempts, finalError, finalTime = 0, 0, 0
    while true do
        attempts = attempts + 1
        if attempts > maxAttempts then break end

        initialVelocity:setVector(0, muzzleVelocity, 0)
        initialVelocity:rotate3D(adjustedRotation)

        initialPosition:setVector(0, barrelLength, 0)
        initialPosition:rotate3D(adjustedRotation)

        local bullet = newBullet(initialPosition, initialVelocity)
        local approxTime = 0
        local steps = 0

        while true do
            steps = steps + 1
            if steps > maxSteps or approxTime > lifespan then break end

            local previousTargetError, timeAdjust = bullet.targetError, bullet.targetError/bullet.speed
            bullet:positionInTicks(approxTime + timeAdjust)

            if previousTargetError - bullet.targetError <= 0 then break end

            approxTime = approxTime + timeAdjust
        end

        bullet:positionInTicks(approxTime)

        adjustedRotation.x = adjustedRotation.x + (referenceRotation.x - math.asin(bullet.position.z/bullet.distance))*1.05
        adjustedRotation.z = adjustedRotation.z - (referenceRotation.z + math.atan(bullet.position.x, bullet.position.y))

        finalError = bullet.targetError
        finalTime = approxTime

        if finalError < accuracyLevel then
            break
        end
    end
    return finalTime, finalError, attempts < maxAttempts, (maxAttempts - attempts)/maxAttempts*100
end