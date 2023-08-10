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

radarPosition = IIVector()

function onTick()
    radarPosition:setVector(input.getNumber(1), input.getNumber(2), input.getNumber(3))

    rawXRotation = input.getNumber(4)
    rawYRotation = input.getNumber(5)
    rawZRotation = input.getNumber(6) - PI/2

    local c1, s1, c2, s2, c3, s3 = math.cos(rawXRotation), math.sin(rawXRotation), math.cos(rawYRotation), math.sin(rawYRotation), math.cos(rawZRotation), math.sin(rawZRotation)
    vehicleHeading = math.atan(c1*c2, c3*s1 - c1*s2*s3)

    radarFacing = input.getNumber(7) * -PI2 + vehicleHeading

    externalControlSignalB = inputToBinary(8)
    zoom = integerToFloat(externalControlSignalB >> 8, MIN_ZOOM, ZOOM_RANGE, MAX_ZOOM_INTEGER)
    range = toScreen(integerToFloat(externalControlSignalB & 0xFF, MIN_RANGE, RANGE_RANGE, MAX_RANGE_INTEGER))
end

SCREEN_WIDTH_MID = SCREEN_WIDTH/2
SCREEN_HEIGHT_MID = SCREEN_HEIGHT/2
RADAR_FOV = 0.125 * PI

function onDraw()
    screen.setMapColorGrass(75, 75, 75)
	screen.setMapColorLand(50, 50, 50)
	screen.setMapColorOcean(25, 25, 75)
	screen.setMapColorSand(100, 100, 100)
	screen.setMapColorSnow(100, 100, 100)
	screen.setMapColorShallows(50, 50, 100)

	screen.drawMap(radarPosition[1], radarPosition[2], zoom)

    screen.setColor(255, 0, 0, 50)
    screen.drawCircle(SCREEN_WIDTH_MID, SCREEN_HEIGHT_MID, toScreen(RANGE_RANGE + MIN_RANGE))
    screen.drawCircleF(SCREEN_WIDTH_MID, SCREEN_HEIGHT_MID, range)

    screen.setColor(255, 255, 255)
    drawArrow(SCREEN_WIDTH_MID, SCREEN_HEIGHT_MID, 15, vehicleHeading)

    screen.setColor(0, 255, 0, 50)
    screen.drawTriangleF(
        SCREEN_WIDTH_MID, SCREEN_HEIGHT_MID,
        SCREEN_WIDTH_MID + math.cos(radarFacing - RADAR_FOV) * range, SCREEN_HEIGHT_MID - math.sin(radarFacing - RADAR_FOV) * range,
        SCREEN_WIDTH_MID + math.cos(radarFacing + RADAR_FOV) * range, SCREEN_HEIGHT_MID - math.sin(radarFacing + RADAR_FOV) * range
    )
end

function toScreen(n)
    return n*(SCREEN_WIDTH/(zoom*1000))
end