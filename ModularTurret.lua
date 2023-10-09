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
    simulator:setProperty('Target', 13)
    simulator:setProperty('Barrel Length', 3)
    simulator:setProperty('Arc Resolution', 30)

    -- Runs every tick just before onTick; allows you to simulate the inputs changing
    ---@param simulator Simulator Use simulator:<function>() to set inputs etc.
    ---@param ticks     number Number of ticks since simulator started
    function onLBSimulatorTick(simulator, ticks)

        simulator:setInputNumber(1, -8190)
        simulator:setInputNumber(2, -21948)
        simulator:setInputNumber(3, 8)
        simulator:setInputNumber(4, 0)
        simulator:setInputNumber(5, 0)
        simulator:setInputNumber(6, 0)
        -- simulator:setInputNumber(13, -8077)
        -- simulator:setInputNumber(14, -21572)
        -- simulator:setInputNumber(15, 140)
        simulator:setInputNumber(13, 0)
        simulator:setInputNumber(14, 0)
        simulator:setInputNumber(15, 0)
        simulator:setInputBool(13, true)
    end;
end
---@endsection

require('II_SmallVectorMath')
require('OldRadarConstants')
require('II_Ballistics')

TARGET_INDEX = property.getNumber('Target')
TURRET_ROLL_OFFSET = property.getNumber('Turret Mount Roll Offset')
TURRET_PITCH_OFFSET = property.getNumber('Turret Mount Pitch Offset')
TURRET_YAW_OFFSET = property.getNumber('Turret Mount Yaw Offset')
TURRET_OFFSET = IIVector(-14.75, 0, property.getNumber('Turret Vertical Offset'))
LATENCY = 5

target = {
    position = IIVector(),
    predictedPosition = IIVector(),
    velocity = IIVector(),
    acceleration = IIVector(),
    distance = 0,
    timeSinceLastSeen = 0,
    positionInTicks = function (self, t)
        self.predictedPosition:copyVector(self.position)
        self.predictedPosition:setAdd(self.velocity, t + self.timeSinceLastSeen + LATENCY)
        self.predictedPosition:setAdd(self.acceleration, (t + self.timeSinceLastSeen + LATENCY)^2 / 2)
        self.predictedPosition:setAdd(turret.predictedPosition, -1)
        self.distance = self.predictedPosition:magnitude()
    end
}

turret = {
    position = IIVector(),
    predictedPosition = IIVector(),
    velocity = IIVector()
}

turretRotationUnitVector = IIVector()
turretBarrelOffset = IIVector()
worldspaceTurretOffset = IIVector()

elevation = 0
azimuth = 0

radarPosition = IIVector()
transposedRadarRotationMatrix = {{},{},{}}

-- TODO: Integrate with turret functions:
    -- Deadzones
    -- Range check
    -- Fire order
    -- Reloading
    -- Repairing

function onTick()
    target.distance = 1
    relativeElevation = 0
    relativeAzimuth = 0

    radarPosition:setVector(input.getNumber(1), input.getNumber(2), input.getNumber(3))
    positionUpdated = radarPosition:isNotZero()

    if positionUpdated then
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

        worldspaceTurretOffset:copyVector(TURRET_OFFSET)
        worldspaceTurretOffset:matrixRotate(radarRotationMatrix)

        elevationHorizontal = math.cos(elevation)
        turretBarrelOffset:setVector(math.cos(azimuth) * elevationHorizontal, math.sin(azimuth) * elevationHorizontal, math.sin(elevation))

        radarPosition:setAdd(worldspaceTurretOffset)
        -- radarPosition:setAdd(turretBarrelOffset, BARREL_LENGTH)

        turret.velocity:copyVector(radarPosition)
        turret.velocity:setAdd(turret.position, -1)

        turret.position:copyVector(radarPosition)

        turret.predictedPosition:copyVector(radarPosition)
        if positionWasUpdated then
            turret.predictedPosition:setAdd(turret.velocity, LATENCY)
        end
        if canHit then
            turret.predictedPosition:setAdd(turretBarrelOffset, BARREL_LENGTH)
        end
        canHit = false

        if input.getBool(TARGET_INDEX) then
            target.position:setVector(input.getNumber(TARGET_INDEX), input.getNumber(TARGET_INDEX+1), input.getNumber(TARGET_INDEX+2))
            target.velocity:setVector(input.getNumber(TARGET_INDEX+3), input.getNumber(TARGET_INDEX+4), input.getNumber(TARGET_INDEX+5))
            target.acceleration:setVector(input.getNumber(TARGET_INDEX+6), input.getNumber(TARGET_INDEX+7), input.getNumber(TARGET_INDEX+8))
            target.timeSinceLastSeen = 0
        end
        elevation, azimuth, finalGuess = newtonMethodBallistics(turret.velocity, target)
        canHit = finalGuess > 0
        if canHit then
            elevationHorizontal = math.cos(elevation)
            turretRotationUnitVector:setVector(math.cos(azimuth) * elevationHorizontal, math.sin(azimuth) * elevationHorizontal, math.sin(elevation))
            turretRotationUnitVector:matrixRotate(transposedRadarRotationMatrix)
            relativeElevation = arcsin(turretRotationUnitVector[3])
            relativeAzimuth = math.atan(turretRotationUnitVector[2], turretRotationUnitVector[1])
        end
        target.timeSinceLastSeen = target.timeSinceLastSeen + 1
    end
    output.setNumber(31, -relativeAzimuth)
    output.setNumber(32, relativeElevation)
    output.setNumber(30, target.distance)
    output.setBool(31, canHit and input.getBool(TARGET_INDEX) and target.timeSinceLastSeen < 60)
    positionWasUpdated = positionUpdated
end

-- function onDraw()
--     screen.drawText(1, 1, canHit and 'true' or 'false')
--     screen.drawText(1, 10, predictedTime)
-- end