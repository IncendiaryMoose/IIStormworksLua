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

function simpleNewtonMethodBallistics(initialVelocity, target)
    local Z2, azimuthDifference, azimuthDifferencePrime, E, E1, Z, IV, predictedTime, p
    Z2 = TERMINAL_VELOCITY[3] - initialVelocity[3]

    -- Make an initial guess for what time the bullet will hit the target.
    -- This is done by dividing the distance by the muzzle velocity offset by the dot of the turret's velocity and the distance.
    -- The solver uses Newton's method, so this guess only needs to be closer to the correct answer than the wrong one.
    p = target.relativePosition:cloneVector()
    p:setScale(1 / target.distance)
    predictedTime = -IIlog(1 - DRAG * target.distance / (MUZZLE_VELOCITY + initialVelocity:dot(p))) / DRAG

    for i = 1, 5 do
        E = e^(-DRAG * predictedTime)
        E1 = 1 - E
        Z = target.relativePosition[3] - predictedTime * TERMINAL_VELOCITY[3]
        IV = E1 * (MUZZLE_VELOCITY^2 - Z2^2 - initialVelocity[1]^2 - initialVelocity[2]^2) + 2 * DRAG * (target.relativePosition[2] * initialVelocity[2] + target.relativePosition[1] * initialVelocity[1] - Z * Z2)

        -- This equation returns the difference between the azimuth angle calculated using the given time in the X-Z plane and the Y-Z plane.
        azimuthDifference = E1 * IV - DRAG^2 * (target.relativePosition[1]^2 + target.relativePosition[2]^2 + Z^2)

        -- This is the derivative of the previous equation. This is required for newton's method.
        azimuthDifferencePrime = 2 * (DRAG * (E * IV + TERMINAL_VELOCITY[3] * (E1 * Z2 - DRAG * Z)))

        -- Newton's method. The next guess is equal to the first guess, offset in the direction the graph is going. This results in the next guess resulting in a number closer to 0 than the current one.
        predictedTime = predictedTime - azimuthDifference / azimuthDifferencePrime

        if predictedTime > LIFESPAN or predictedTime < 0 then
            -- The prediction system is not going to find a solution, so don't waste time trying.
            return 0, 0, 0
        end
    end
    E1 = 1 - e^(-DRAG * predictedTime)
    return
        -- Compute elevation and azimuth angles based on the predictedTime
        arcsin((DRAG * (target.relativePosition[3] - predictedTime * TERMINAL_VELOCITY[3])) / (MUZZLE_VELOCITY * E1) + Z2 / MUZZLE_VELOCITY),
        math.atan(DRAG * target.relativePosition[2] / E1 - initialVelocity[2], DRAG * target.relativePosition[1] / E1 - initialVelocity[1]),
        predictedTime
end

TURRET_OFFSET = IIVector(property.getNumber('Turret Forward Offset'), property.getNumber('Turret Left Offset'), property.getNumber('Turret Up Offset'))
LASER_OFFSET = IIVector(property.getNumber('Laser Forward Offset'), property.getNumber('Laser Left Offset'), property.getNumber('Laser Up Offset'))

target = {
    position = IIVector(),
    relativePosition = IIVector(),
    distance = 0
}

turret = {
    position = IIVector(),
    predictedPosition = IIVector(),
    velocity = IIVector(),
    -- smoothedVelocity = IIVector()
}

turretRotationUnitVector = IIVector()
worldspaceTurretOffset = IIVector()

elevation = 0
azimuth = 0

gunPosition = IIVector()
transposedMountRotationMatrix = {{},{},{}}

laserPosition = IIVector()

function onTick()
    relativeElevation = 0
    relativeAzimuth = 0

    gunPosition:setVector(input.getNumber(1), input.getNumber(3), input.getNumber(2))

    rawXRotation = input.getNumber(4)
    rawYRotation = input.getNumber(5)
    rawZRotation = input.getNumber(6) - PI/2

    c1, s1, c2, s2, c3, s3 = math.cos(rawXRotation), math.sin(rawXRotation), math.cos(rawYRotation), math.sin(rawYRotation), math.cos(rawZRotation), math.sin(rawZRotation)
    mountRotationMatrix = {
        IIVector(c3*s1 - c1*s2*s3, -s1*s2*s3 - c1*c3, -c2*s3),
        IIVector(c1*c2,            c2*s1,             -s2),
        IIVector(s1*s3 + c1*s2*c3, c3*s1*s2 - c1*s3,  c2*c3)
    }

    for i = 1, 3 do
        for j = 1, 3 do
            transposedMountRotationMatrix[i][j] = mountRotationMatrix[j][i]
        end
    end

    laserPosition:setVector(input.getNumber(7), input.getNumber(9), input.getNumber(8))
    laserDistance = input.getNumber(13) + LASER_OFFSET[1]
    laserAzimuth = arcsin(LASER_OFFSET[2]/laserDistance) / PI2 * 4
    laserElevation = arcsin(LASER_OFFSET[3]/laserDistance) / PI2 * 4

    rawXRotation = input.getNumber(10)
    rawYRotation = input.getNumber(11)
    rawZRotation = input.getNumber(12) - PI/2

    c1, s1, c2, s2, c3, s3 = math.cos(rawXRotation), math.sin(rawXRotation), math.cos(rawYRotation), math.sin(rawYRotation), math.cos(rawZRotation), math.sin(rawZRotation)
    laserRotationMatrix = {
        IIVector(c3*s1 - c1*s2*s3, -s1*s2*s3 - c1*c3, -c2*s3),
        IIVector(c1*c2,            c2*s1,             -s2),
        IIVector(s1*s3 + c1*s2*c3, c3*s1*s2 - c1*s3,  c2*c3)
    }

    worldspaceTurretOffset:copyVector(TURRET_OFFSET)
    worldspaceTurretOffset:matrixRotate(mountRotationMatrix)
    gunPosition:setAdd(worldspaceTurretOffset)

    -- turret.smoothedVelocity:copyVector(turret.velocity)

    turret.velocity:copyVector(gunPosition)
    turret.velocity:setAdd(turret.position, -1)

    -- turret.smoothedVelocity:setAdd(turret.velocity)
    -- turret.smoothedVelocity:setScale(0.5)

    turret.position:copyVector(gunPosition)

    turret.predictedPosition:copyVector(gunPosition)

    turret.predictedPosition:setAdd(turret.velocity)

    target.position:setVector(laserDistance, 0, 0)
    target.position:matrixRotate(laserRotationMatrix)
    target.position:setAdd(laserPosition)
    target.relativePosition:copyVector(target.position)
    target.relativePosition:setAdd(turret.predictedPosition, -1)
    target.distance = target.relativePosition:magnitude()

    elevation, azimuth, finalGuess = simpleNewtonMethodBallistics(turret.velocity, target)
    canHit = finalGuess > 0
    if canHit then
        elevationHorizontal = math.cos(elevation)
        turretRotationUnitVector:setVector(math.cos(azimuth) * elevationHorizontal, math.sin(azimuth) * elevationHorizontal, math.sin(elevation))
        turretRotationUnitVector:matrixRotate(transposedMountRotationMatrix)
        relativeElevation = arcsin(turretRotationUnitVector[3])
        relativeAzimuth = math.atan(turretRotationUnitVector[2], turretRotationUnitVector[1])
    end

    output.setNumber(1, laserAzimuth)
    output.setNumber(2, laserElevation)
    output.setNumber(3, relativeAzimuth / PI2)
    output.setNumber(4, relativeElevation / PI2)
    output.setNumber(5, target.relativePosition[1])
    output.setNumber(6, target.relativePosition[2])
    output.setNumber(7, target.relativePosition[3])
    output.setBool(1, canHit)
end

-- function onDraw()
--     screen.drawText(1, 1, canHit and 'true' or 'false')
--     screen.drawText(1, 10, predictedTime)
-- end