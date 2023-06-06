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
require('II_RenderEngine')

X_AXIS = IIVector(1, 0, 0)
Y_AXIS = IIVector(0, 1, 0)
Z_AXIS = IIVector(0, 0, 1)

UNIT_MATRIX = IIMatrix(X_AXIS, Y_AXIS, Z_AXIS)

currentPosition = IIVector()
targetPosition = IIVector()

currentRotation = IIVector()
currentRotationMatrix = IIMatrix()
currentUnitMatrix = IIMatrix()

targetRotation = IIVector()
targetRotationMatrix = IIMatrix()
targetUnitMatrix = IIMatrix()

animationUnitMatrix = IIMatrix()

currentVelocity = IIVector()
currentRotationalVelocity = IIVector()

camPos = IIVector(15, 12, 20)
camRot = IIVector(0, PI/4, math.atan(-12,-15))
camMatrix = IIMatrix()
camAxis = IIMatrix()
camMatrix:XYZRotationToZYXMatrix(camRot)
camAxis:transpose(camMatrix)

animationTick = 0
ANIMATION_TIME = 120

currentAxisDisplay = IIMatrix()
targetAxisDisplay = IIMatrix()
animationAxisDisplay = IIMatrix()

currentAxisDisplayPoints = IIMatrix()
targetAxisDisplayPoints = IIMatrix()
animationAxisDisplayPoints = IIMatrix()

DISPLAY_OFFSET = 0

function onTick()
    clearOutputs()
    currentPosition:setVector(input.getNumber(23), input.getNumber(24), input.getNumber(25))

    currentRotationalVelocity:copyVector(currentRotation)
    currentRotation:setVector(input.getNumber(17), input.getNumber(18), input.getNumber(19))

    targetRotation:setVector(input.getNumber(20), input.getNumber(21), input.getNumber(22))

    for i = 1, 3 do
        currentRotationalVelocity[i] = wrappedDifference(currentRotationalVelocity[i], currentRotation[i])
    end

    currentRotationMatrix:XYZRotationToZYXMatrix(currentRotation)
    targetRotationMatrix:XYZRotationToZYXMatrix(targetRotation)

    currentUnitMatrix:transpose(currentRotationMatrix)
    targetUnitMatrix:transpose(targetRotationMatrix)

    for i = 1, 3 do
        animationUnitMatrix[i]:copyVector(targetUnitMatrix[i])
        animationUnitMatrix[i]:setAdd(currentUnitMatrix[i], -1)
        animationUnitMatrix[i]:setScale(animationTick/ANIMATION_TIME)
        animationUnitMatrix[i]:setAdd(currentUnitMatrix[i])
        animationUnitMatrix[i]:setScale(1 / animationUnitMatrix[i]:magnitude())
    end

    animationTick = (animationTick + 1) % ANIMATION_TIME
    currentAxisDisplay:copyMatrix(currentUnitMatrix)
    targetAxisDisplay:copyMatrix(targetUnitMatrix)
    animationAxisDisplay:copyMatrix(animationUnitMatrix)

    for i = 1, 3 do
        currentAxisDisplay[i]:setScale(10)

        targetAxisDisplay[i]:setScale(10)

        animationAxisDisplay[i]:setScale(10)
    end

    currentAxisDisplayPoints:copyMatrix(currentAxisDisplay)
    targetAxisDisplayPoints:copyMatrix(targetAxisDisplay)
    animationAxisDisplayPoints:copyMatrix(animationAxisDisplay)

    currentAxisDisplayPoints[4] = IIVector()
    targetAxisDisplayPoints[4] = IIVector()
    animationAxisDisplayPoints[4] = IIVector()

    setOutputs()
end

function onDraw()
    currentScreenPoints = {}
    targetScreenPoints = {}
    animationScreenPoints = {}
    worldToScreenPoint(camPos, camAxis, currentAxisDisplayPoints, currentScreenPoints)
    worldToScreenPoint(camPos, camAxis, targetAxisDisplayPoints, targetScreenPoints)
    worldToScreenPoint(camPos, camAxis, animationAxisDisplayPoints, animationScreenPoints)

    for i = 1, 3 do
        screen.setColor(i == 1 and 255 or 0, i == 2 and 255 or 0, i == 3 and 255 or 0)
        screen.drawLine(currentScreenPoints[4][1] - DISPLAY_OFFSET, currentScreenPoints[4][2], currentScreenPoints[i][1] - DISPLAY_OFFSET, currentScreenPoints[i][2])
        screen.drawLine(targetScreenPoints[4][1], targetScreenPoints[4][2], targetScreenPoints[i][1], targetScreenPoints[i][2])
        screen.drawLine(animationScreenPoints[4][1] + DISPLAY_OFFSET, animationScreenPoints[4][2], animationScreenPoints[i][1] + DISPLAY_OFFSET, animationScreenPoints[i][2])
    end
end