-- Author: Incendiary Moose
-- GitHub: <GithubLink>
-- Workshop: https://steamcommunity.com/profiles/76561198050556858/myworkshopfiles/?appid=573090
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey


--[====[ HOTKEYS ]====]
-- Press F6 to simulate this file
-- Press F7 to build the project, copyVector the output from /_build/out/ into the game to use
-- Remember to set your Author name etc. in the settings: CTRL+COMMA


--[====[ EDITABLE SIMULATOR CONFIG - *automatically removed from the F7 build output ]====]
---@section __LB_SIMULATOR_ONLY__
do
    ---@type Simulator -- Set properties and screen sizes here - will run once when the script is loaded
    simulator = simulator
    simulator:setScreen(1, "9x5")
    simulator:setProperty("Pitch Speed", 1)
    simulator:setProperty("Roll Speed", 1)
    simulator:setProperty("Yaw Speed", -1)
    simulator:setProperty("FOV", 15)

    -- Runs every tick just before onTick; allows you to simulate the inputs changing
    ---@param simulator Simulator Use simulator:<function>() to set inputs etc.
    ---@param ticks     number Number of ticks since simulator started
    function onLBSimulatorTick(simulator, ticks)

        -- touchscreen defaults
        local screenConnection = simulator:getTouchScreen(1)
        -- simulator:setInputBool(1, screenConnection.isTouched)
        -- simulator:setInputNumber(1, screenConnection.width)
        -- simulator:setInputNumber(2, screenConnection.height)
        -- simulator:setInputNumber(3, screenConnection.touchX)
        -- simulator:setInputNumber(4, screenConnection.touchY)

        -- NEW! button/slider options from the UI
        simulator:setInputBool(31, simulator:getIsClicked(1))
        simulator:setInputNumber(7, simulator:getSlider(1)*0.1)

        simulator:setInputBool(32, simulator:getIsToggled(2))
        simulator:setInputNumber(8, simulator:getSlider(2)*0.1)
        simulator:setInputNumber(1, 0)
        simulator:setInputNumber(2, 0)
        simulator:setInputNumber(3, 0)
        simulator:setInputNumber(4, (simulator:getSlider(3)+0.25) * math.pi*2)
        simulator:setInputNumber(5, (simulator:getSlider(4)) * math.pi*2)
        simulator:setInputNumber(6, (simulator:getSlider(5)+0.25) * math.pi*2)
    end;
end
---@endsection

require('II_MathHelpers')
require('II_SmallVectorMath')
require('II_PIDController')
require('II_IO')
-- require('II_RenderEngine')

Z_PID_CONFIG = {
    PROPORTIONAL_GAIN = property.getNumber('Z P'),
    INTEGRAL_GAIN = property.getNumber('Z I'),
    DERIVATIVE_GAIN = property.getNumber('Z D'),
    MAX_PROPORTIONAL = property.getNumber('Z Max P'),
    MAX_INTEGRAL = property.getNumber('Z Max I'),
    MAX_DERIVATIVE = property.getNumber('Z Max D'),
    MAX_OUTPUT = property.getNumber('Z Max'),
    OFFSET = property.getNumber('Z Offset')
}

XY_PID_CONFIG = {
    PROPORTIONAL_GAIN = property.getNumber('XY P'),
    INTEGRAL_GAIN = property.getNumber('XY I'),
    DERIVATIVE_GAIN = property.getNumber('XY D'),
    MAX_PROPORTIONAL = property.getNumber('XY Max P'),
    MAX_INTEGRAL = property.getNumber('XY Max I'),
    MAX_DERIVATIVE = property.getNumber('XY Max D'),
    MAX_OUTPUT = property.getNumber('XY Max')
}

DISTANCE_SPEED_RATIO = property.getNumber('Time Scale')
ROLL_SPEED = property.getNumber('Roll Speed')
PITCH_SPEED = property.getNumber('Pitch Speed')
YAW_SPEED = property.getNumber('Yaw Speed')
MAX_SPEED = property.getNumber('Max Speed') / DISTANCE_SPEED_RATIO

X_AXIS = IIVector(1, 0, 0)
Y_AXIS = IIVector(0, 1, 0)
Z_AXIS = IIVector(0, 0, 1)

UNIT_MATRIX = IIMatrix(X_AXIS, Y_AXIS, Z_AXIS)

function newRotor(x, y, z)
    return {
        OFFSET = IIVector(x, y, z),
        position = IIVector(),
        targetVector = IIVector(),
        targetDelta = IIVector(),
        xPID = newPID(XY_PID_CONFIG),
        yPID = newPID(XY_PID_CONFIG),
        zPID = newPID(Z_PID_CONFIG)
    }
end

rotors = {
    newRotor(10, 10, 0),
    newRotor(10, -10, 0),
    newRotor(-10, 10, 0),
    newRotor(-10, -10, 0)
}

currentPosition = IIVector()
targetPosition = IIVector()

currentRotation = IIVector()
currentRotationMatrix = IIMatrix()
currentUnitMatrix = IIMatrix()

targetRotation = IIVector()
targetRotationMatrix = IIMatrix()
targetUnitMatrix = IIMatrix()

halfwayRotationMatrix = IIMatrix()
halfwayUnitMatrix = IIMatrix()

animationUnitMatrix = IIMatrix()

currentVelocity = IIVector()
currentRotationalVelocity = IIVector()

seatRotationInput = IIVector()
seatRotationMatrix = IIMatrix()

xAxis = IIVector()
yAxis = IIVector()
zAxis = IIVector()

zRotationMatrix = IIMatrix()
zRotation = IIVector()

startupTimer = 0

function onTick()
    clearOutputs()
    isAbsoluteControl = input.getBool(2) -- If control should be based on world coord system instead of the vehicle's coord system

    if startupTimer < 5 then -- When loading the script, initialize target position and rotation to the vehicle's location
        startupTimer = startupTimer + 1
        targetPosition:copyVector(currentPosition)
        targetRotationMatrix:copyMatrix(currentRotationMatrix)
    end

    currentVelocity:copyVector(currentPosition)
    currentPosition:setVector(input.getNumber(1), input.getNumber(3), input.getNumber(2))
    currentVelocity:setAdd(currentPosition, -1)
    currentVelocity:setScale(-1)

    -- Compute Vehicle Rotation
    rawXRotation = input.getNumber(4)
    rawYRotation = input.getNumber(5)
    rawZRotation = input.getNumber(6) - PI/2

    local c1, s1, c2, s2, c3, s3 = math.cos(rawXRotation), math.sin(rawXRotation), math.cos(rawYRotation), math.sin(rawYRotation), math.cos(rawZRotation), math.sin(rawZRotation)
    local c1s2, c3s1 = c1*s2, c3*s1

	pitch = -arcsin(s1*s3 + c1s2*c3)

    currentRotationalVelocity:copyVector(currentRotation)
    currentRotation:setVector(
        arccos(c2*c3 / math.cos(pitch)) * (c3s1*s2 - c1*s3 < 0 and -1 or 1),
        pitch,
        math.atan(c1*c2, c3s1 - c1s2*s3)
    )

    for i = 1, 3 do
        currentRotationalVelocity[i] = wrappedDifference(currentRotationalVelocity[i], currentRotation[i])
    end

    currentRotationMatrix:XYZRotationToZYXMatrix(currentRotation)
    -- Vehicle Rotation Computed

    seatAD = input.getNumber(7)
    seatWS = input.getNumber(8)
    seatLR = input.getNumber(9)
    seatUD = input.getNumber(10)

    if spinning and not (isSeatAD or isSeatLR or isSeatWS) then
        spinning = false
        targetRotationMatrix:copyMatrix(currentRotationMatrix)
    end

    seatRotationInput:setVector(0, 0, 0)

    isSeatAD = math.abs(seatAD) > 0.05
    if isSeatAD then
        spinning = true
        seatRotationInput[1] = seatAD * ROLL_SPEED
    end

    isSeatWS = math.abs(seatWS) > 0.05
    if isSeatWS then
        spinning = true
        seatRotationInput[2] = seatWS * PITCH_SPEED
    end

    isSeatLR = math.abs(seatLR) > 0.05
    if isSeatLR then
        spinning = true
        seatRotationInput[3] = seatLR * YAW_SPEED
    end

    if moving and currentVelocity:magnitude() < 0.025 then
        moving = false
        targetPosition:copyVector(currentPosition)
    end

    isSeatUD = math.abs(seatUD) > 0.05
    if isSeatUD then
        moving = true
        xAxis:copyVector(X_AXIS)
        xAxis:matrixRotate(targetRotationMatrix)
        targetPosition:setAdd(xAxis, seatUD * MAX_SPEED)
    end

    if isSeatAD or isSeatLR or isSeatWS then
        seatRotationMatrix:XYZRotationToZYXMatrix(seatRotationInput)
        local seatUnitMatrix = IIMatrix()
        seatUnitMatrix:transpose(seatRotationMatrix)
        targetRotationMatrix:transposedMultiply(seatUnitMatrix)
    end

    currentUnitMatrix:transpose(currentRotationMatrix)
    targetUnitMatrix:transpose(targetRotationMatrix)

    for i = 1, 3 do
        halfwayUnitMatrix[i]:copyVector(targetUnitMatrix[i])
        halfwayUnitMatrix[i]:setAdd(currentUnitMatrix[i])
        halfwayUnitMatrix[i]:setScale(0.5)
        halfwayUnitMatrix[i]:setScale(1 / halfwayUnitMatrix[i]:magnitude())
    end

    halfwayRotationMatrix:transpose(halfwayUnitMatrix)

    pitch = -arcsin(targetUnitMatrix[1][3])

    targetRotation:setVector(
        arccos(targetUnitMatrix[3][3] / math.cos(pitch)) * (targetUnitMatrix[2][3] < 0 and -1 or 1),
        pitch,
        math.atan(targetUnitMatrix[1][2], targetUnitMatrix[1][1])
    )

    zRotation:setVector(0, 0, -currentRotation[3])
    zRotationMatrix:XYZRotationToZYXMatrix(zRotation)
    for i, rotor in ipairs(rotors) do
        rotor.position:copyVector(rotor.OFFSET)
        rotor.position:matrixRotate(currentRotationMatrix)
        rotor.position:setAdd(currentPosition)

        rotor.targetDelta:copyVector(rotor.targetVector)

        rotor.targetVector:copyVector(rotor.OFFSET)
        rotor.targetVector:matrixRotate(halfwayRotationMatrix)
        rotor.targetVector:setAdd(targetPosition)
        rotor.targetVector:setAdd(rotor.position, -1)
        rotor.targetVector:matrixRotate(zRotationMatrix)

        rotor.targetDelta:setAdd(rotor.targetVector, -1)

        rotor.xPID:update(rotor.targetVector[1] / DISTANCE_SPEED_RATIO, rotor.targetDelta[1])
        rotor.yPID:update(rotor.targetVector[2] / DISTANCE_SPEED_RATIO, rotor.targetDelta[2])
        rotor.zPID:update(rotor.targetVector[3] / DISTANCE_SPEED_RATIO, rotor.targetDelta[3])

        local outputIndex, invert = (i-1)*2, rotor.zPID.output < 0 and -1 or 1
        outputNumbers[outputIndex + 1] = rotor.zPID.output
        outputNumbers[outputIndex + 2] = -rotor.zPID.output
        outputNumbers[outputIndex + 9] = rotor.yPID.output * invert + currentRotation[1]/PI2
        outputNumbers[outputIndex + 10] = -rotor.xPID.output * invert + currentRotation[2]/PI2
    end

    for i = 1, 3 do
        outputNumbers[16 + i] = currentRotation[i]

        outputNumbers[19 + i] = targetRotation[i]
    end
    setOutputs()
end

-- function onDraw()
-- end