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
    function onLBSimulatorTick(simulator, ticks)

    end;
end
---@endsection

require('II_SmallVectorMath')
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

turretOffsetVector = IIVector((PI2/4)*TURRET_ROLL_OFFSET, (PI2/4)*TURRET_PITCH_OFFSET, (PI2/4)*TURRET_YAW_OFFSET)

target = {
    position = IIVector(),
    predictedPosition = IIVector(),
    velocity = IIVector(),
    acceleration = IIVector(),
    distance = 0,
    timeSinceLastSeen = 0,
    positionInTicks = function (self, t)
        self.predictedPosition:copyVector(self.position)
        self.predictedPosition:setAdd(self.velocity, t + self.timeSinceLastSeen)
        self.predictedPosition:setAdd(self.acceleration, (t + self.timeSinceLastSeen)^2 / 2)
        self.predictedPosition:setAdd(turret.position, -1)
        self.predictedPosition:matrixRotate(transposedRadarRotationMatrix)
        self.predictedPosition:setAdd(TURRET_OFFSET)
        self.distance = self.predictedPosition:magnitude()
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

turretRotationUnitVector = IIVector()
relativeElevation = 0
relativeAzimuth = 0

radarPosition = IIVector()
transposedRadarRotationMatrix = {{},{},{}}

-- TODO: Integrate with turret functions:
    -- Deadzones
    -- Range check
    -- Fire order
    -- Reloading
    -- Repairing

function onTick()
    canHit = false
    if input.getBool(1) then
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

        -- Make an initial guess for what time the bullet will hit the target.
        -- This is done by dividing the distance by the muzzle velocity offset by the dot of the turret's velocity and the distance.
        -- The solver uses Newton's method, so this guess only needs to be closer to the correct answer than the wrong one.
        if input.getBool(TARGET_INDEX) then
            target.position:setVector(input.getNumber(TARGET_INDEX), input.getNumber(TARGET_INDEX+1), input.getNumber(TARGET_INDEX+2))
            target.velocity:setVector(input.getNumber(TARGET_INDEX+3), input.getNumber(TARGET_INDEX+4), input.getNumber(TARGET_INDEX+5))
            target.acceleration:setVector(input.getNumber(TARGET_INDEX+6), input.getNumber(TARGET_INDEX+7), input.getNumber(TARGET_INDEX+8))
            target.timeSinceLastSeen = 0
        end
        target:positionInTicks(LATENCY)
        target.position:copyVector(target.predictedPosition)
        predictedTime = -IIlog(1 - DRAG * target.distance / (MUZZLE_VELOCITY + turret.velocity:dot(target.predictedPosition / target.distance))) / DRAG

        elevation, azimuth, predictedTime = newtonMethodBallistics(turret.velocity, target, predictedTime)
        canHit = predictedTime > 0
        if canHit then
            local elevationHorizontal = math.cos(elevation)
            turretRotationUnitVector:setVector(math.cos(azimuth) * elevationHorizontal, math.sin(azimuth) * elevationHorizontal, math.sin(elevation))
            turretRotationUnitVector:matrixRotate(transposedRadarRotationMatrix)
            relativeElevation = arcsin(turretRotationUnitVector[3])
            relativeAzimuth = math.atan(turretRotationUnitVector[2], turretRotationUnitVector[1])
        end
    end
    output.setNumber(1, relativeAzimuth)
    output.setNumber(2, relativeElevation)
    output.setBool(1, canHit and input.getBool(TARGET_INDEX + 1))
end