---@section _SIMULATOR_ONLY_
simulator:setScreen(1, "9x5")
simulator:setProperty('Speed', 8)
simulator:setProperty('GPS Delay', 1)
simulator:setProperty('Weapons Range', 1500)
simulator:setProperty('Max Age', 100)
simulator:setProperty('Delay', 1)
simulator:setProperty('Sample', 5)
simulator:setProperty('Accel', 1)
simulator:setProperty('Jerk', 1)
simulator:setProperty('Max Prediction', 800)

testTargs = {
    50,
    150,
    250,
    350,
    450,
    550,
    650,
    750
}
onLBSimulatorTick = function(simulator, ticks)
    simulator:setInputNumber(1, 0)
    simulator:setInputNumber(2, 0)
    simulator:setInputNumber(3, 0)
    simulator:setInputNumber(4, 0)
    simulator:setInputNumber(5, 0)
    simulator:setInputNumber(6, 0.125)
    tickMod = ticks%10
    for ti = 0, 7 do
        simulator:setInputNumber(ti*3+7, 100 + ti*100 + tickMod*800 + ticks)
        simulator:setInputNumber(ti*3+8, 100 + ti*100 + tickMod*800)
        simulator:setInputNumber(ti*3+9, 100 + ti*100 + tickMod*800)
    end
    simulator:setInputNumber(31, 10101010)
    simulator:setInputNumber(32, 10101010)
end
---@endsection
require('II_BinaryIO')
require('II_SmallVectorMath')
require('II_RenderEngine')
require('OldRadarConstants')

minDist = 1750
minSeperation = 10
distanceSeperationRatio = 0.1
maxAge = 300
targetSize = 2

radarPosition = IIVector()

screenClickPos = IIVector()
worldClickPos = IIVector()

targets = {}
function onTick()
    -- screenClickPos:set(input.getNumber(8)%1000, math.floor((input.getNumber(8)%1000000)/1000))
    -- click = math.floor(input.getNumber(8)/1000000) == 1
    -- worldClick = click and screenClickPos.x > 45 and screenClickPos.x < SCREEN_WIDTH-45

    radarPosition:setVector(input.getNumber(8), input.getNumber(12), input.getNumber(16))

    -- radarRotation:setVector(input.getNumber(20), input.getNumber(24), input.getNumber(28) - PI/2)

    rawXRotation = input.getNumber(20)
    rawYRotation = input.getNumber(24)
    rawZRotation = input.getNumber(28) - PI/2

    local c1, s1, c2, s2, c3, s3 = math.cos(rawXRotation), math.sin(rawXRotation), math.cos(rawYRotation), math.sin(rawYRotation), math.cos(rawZRotation), math.sin(rawZRotation)
    local c3s1, c1s2 = c3*s1, c1*s2
    radarRotationMatrix = {
        IIVector(c3s1 - c1s2*s3,  -s1*s2*s3 - c1*c3, -c2*s3),
        IIVector(c1*c2,           c2*s1,            -s2),
        IIVector(s1*s3 + c1s2*c3, c3s1*s2 - c1*s3,   c2*c3)
    }

    radarRotation = math.atan(c1*c2, c3s1 - c1s2*s3)
    externalControlSignalB = inputToBinary(32)
    zoom = integerToFloat(externalControlSignalB >> 8, MIN_ZOOM, ZOOM_RANGE, MAX_ZOOM_INTEGER)
    range = integerToFloat(externalControlSignalB & 0xFF, MIN_RANGE, RANGE_RANGE, MAX_RANGE_INTEGER)

    timeSinceUpdate = input.getNumber(4)
    if timeSinceUpdate == 0 then
        for i = 0, 7, 1 do
            local distance, azimuth, elevation = input.getNumber(i*4+1), input.getNumber(i*4+2)*PI2, input.getNumber(i*4+3)*PI2
            if distance == 0 then
                break
            end
            if distance > minDist then
                local targetPosition = IIVector(
                    distance * math.sin(azimuth) * math.cos(elevation),
                    distance * math.cos(azimuth) * math.cos(elevation),
                    distance * math.sin(elevation)
                )
                targetPosition:matrixRotate(radarRotationMatrix)
                targetPosition:setAdd(radarPosition)
                for targetIndex, target in ipairs(targets) do
                    if targetPosition:distanceTo(target.position) < minSeperation + distance*distanceSeperationRatio then
                        target.age = 0
                        target.position:copyVector(targetPosition)
                        goto skipTarget
                    end
                end
                table.insert(targets, {position = targetPosition:cloneVector(), age = 0})
            end
            ::skipTarget::
        end
    end
    for i = #targets, 1, -1 do
        targets[i].age = targets[i].age + 1
        if targets[i].age > maxAge then
            table.remove(targets, i)
        end
    end
end
function onDraw()
    screen.setMapColorGrass(75, 75, 75)
	screen.setMapColorLand(50, 50, 50)
	screen.setMapColorOcean(25, 25, 75)
	screen.setMapColorSand(100, 100, 100)
	screen.setMapColorSnow(100, 100, 100)
	screen.setMapColorShallows(50, 50, 100)

	screen.drawMap(radarPosition[1], radarPosition[2], zoom)
    screen.setColor(0, 15, 100, 255)
    for targetIndex, target in ipairs(targets) do
        local pixelX, pixelY = map.mapToScreen(radarPosition[1], radarPosition[2], zoom, SCREEN_WIDTH, SCREEN_HEIGHT, target.position[1], target.position[2])
        screen.drawCircleF(pixelX, pixelY, targetSize)
    end
    screen.setColor(255, 0, 0, 50)
    screen.drawCircle(SCREEN_WIDTH/2, SCREEN_HEIGHT/2, toScreen(RANGE_RANGE + MIN_RANGE))
    screen.drawCircleF(SCREEN_WIDTH/2, SCREEN_HEIGHT/2, toScreen(range))
    screen.setColor(255, 255, 255)
    drawArrow(SCREEN_WIDTH/2, SCREEN_HEIGHT/2, 15, radarRotation)
end

function toScreen(n)
    return n*(SCREEN_WIDTH/(zoom*1000))
end