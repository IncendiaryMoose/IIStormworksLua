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
        simulator:setInputNumber(17, (simulator:getSlider(1)) * math.pi*2)
        simulator:setInputNumber(19, (simulator:getSlider(2)) * math.pi*2)
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

animationRotationMatrix = IIMatrix()
animationUnitMatrix = IIMatrix()

currentVelocity = IIVector()
currentRotationalVelocity = IIVector()

camPos = IIVector(-20, 0, 15)
camRot = IIVector(0, PI/8, 0)
camMatrix = IIMatrix()
camAxis = IIMatrix()
camMatrix:XYZRotationToZYXMatrix(camRot)
camAxis:transpose(camMatrix)

animationTick = 0
ANIMATION_TIME = 120

currentAxisDisplay = IIMatrix()
targetAxisDisplay = IIMatrix()
animationAxisDisplay = IIMatrix()

currentAxisDisplayPoints = {
    IIVector(),
    IIVector(),
    IIVector(),
    IIVector(),
    IIVector()
}

targetAxisDisplayPoints = {
    IIVector(),
    IIVector(),
    IIVector(),
    IIVector(),
    IIVector()
}

animationAxisDisplayPoints = {
    IIVector(),
    IIVector(),
    IIVector(),
    IIVector(),
    IIVector()
}

DISPLAY_OFFSET = 75

ARROW = {
    IIVector(-5, 3, -3),
    IIVector(-5, 3, 3),
    IIVector(-5, -3, 3),
    IIVector(-5, -3, -3),
    IIVector(5, 0, 0)
}

arrow = {
    IIVector(-5, 5, -5),
    IIVector(-5, 5, 5),
    IIVector(-5, -5, 5),
    IIVector(-5, -5, -5),
    IIVector(5, 0, 0)
}

animationRotation = IIVector()

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

	pitch = -arcsin(animationUnitMatrix[3][1])
    animationRotation:setVector(
        arccos(animationUnitMatrix[3][3] / math.cos(pitch)) * (animationUnitMatrix[3][2] < 0 and -1 or 1),
        pitch,
        math.atan(animationUnitMatrix[2][1], animationUnitMatrix[1][1])
    )
    -- animationRotationMatrix:transpose(animationUnitMatrix)
    animationRotationMatrix:XYZRotationToZYXMatrix(animationRotation)
    for i = 1, 5 do
        currentAxisDisplayPoints[i]:copyVector(ARROW[i])
        targetAxisDisplayPoints[i]:copyVector(ARROW[i])
        animationAxisDisplayPoints[i]:copyVector(ARROW[i])
    end
    for i = 1, 5 do
        currentAxisDisplayPoints[i]:matrixRotate(currentRotationMatrix)
        targetAxisDisplayPoints[i]:matrixRotate(targetRotationMatrix)
        animationAxisDisplayPoints[i]:matrixRotate(animationRotationMatrix)
    end
    setOutputs()
end

function onDraw()
    currentScreenPoints = {}
    targetScreenPoints = {}
    animationScreenPoints = {}
    worldToScreenPoint(camPos, camAxis, currentAxisDisplayPoints, currentScreenPoints)
    worldToScreenPoint(camPos, camAxis, targetAxisDisplayPoints, targetScreenPoints)
    worldToScreenPoint(camPos, camAxis, animationAxisDisplayPoints, animationScreenPoints)

    -- for i = 1, 4 do
    --     screen.setColor((i == 1 or i == 4) and 255 or 0, (i == 2 or i == 4) and 255 or 0, (i == 3 or i == 4) and 255 or 0)
    --     screen.drawLine(currentScreenPoints[5][1] - DISPLAY_OFFSET, currentScreenPoints[5][2], currentScreenPoints[i][1] - DISPLAY_OFFSET, currentScreenPoints[i][2])
    --     screen.drawLine(targetScreenPoints[5][1], targetScreenPoints[5][2], targetScreenPoints[i][1], targetScreenPoints[i][2])
    --     screen.drawLine(animationScreenPoints[5][1] + DISPLAY_OFFSET, animationScreenPoints[5][2], animationScreenPoints[i][1] + DISPLAY_OFFSET, animationScreenPoints[i][2])
    -- end
    -- 1,2,3
    -- 3,4,1
    -- 5,1,2
    -- 5,2,3
    -- 5,3,4
    -- 5,4,1
    for i = 1, 5 do
        currentScreenPoints[i][1] = currentScreenPoints[i][1] - DISPLAY_OFFSET
        targetScreenPoints[i][1] = targetScreenPoints[i][1] + DISPLAY_OFFSET
    end
    drawArrow3D(currentScreenPoints)
    drawArrow3D(animationScreenPoints)
    drawArrow3D(targetScreenPoints)
end

function drawArrow3D(screenPoints)
    local drawTable = {}
    for i = 1, 4 do
        drawTable[#drawTable+1] = newTriangle(
            screenPoints[5],
            screenPoints[i],
            screenPoints[i%4+1],
            {(i == 1 or i == 4) and 255 or 0, (i == 2 or i == 4) and 255 or 0, (i == 3 or i == 4) and 255 or 0}
        )
    end
    for i = 1, 3, 2 do
        drawTable[#drawTable+1] = newTriangle(
            screenPoints[i],
            screenPoints[i + 1],
            screenPoints[(i+2)%4],
            {i == 1 and 0 or 255, i == 1 and 255 or 0, i == 1 and 255 or 125}
        )
    end
    table.sort(drawTable, function (a, b)
        return a[4] > b[4]
    end)
    for index, triangle in ipairs(drawTable) do
        drawTri(triangle)
    end
end