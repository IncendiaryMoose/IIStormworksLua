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
    simulator:setProperty("Weapon Type", 2)
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

    function onLBSimulatorTick(simulator)
        local screenConnection = simulator:getTouchScreen(1)
        simulator:setInputBool(1, screenConnection.isTouched)
        simulator:setInputNumber(1, 0)
        simulator:setInputNumber(2, -math.pi/4)
        simulator:setInputNumber(3, 0)
    end;
end
---@endsection

require('II_MathHelpers')
require('II_SmallVectorMath')
require('II_IO')

BARREL_LENGTH = property.getNumber('Barrel Length')
WEAPON_TYPE = property.getNumber('Weapon Type')
WEAPON_DATA = {
	{800, 0.025, 300}, --MG
	{1000, 0.02, 300}, --LA
	{1000, 0.01, 300}, --RA
	{900, 0.005, 600}, --HA
	{800, 0.002, 3600}, --BA
	{700, 0.001, 3600}, --AR
	{600, 0.0005, 3600}, --BE
}
WEAPON = WEAPON_DATA[WEAPON_TYPE]
MUZZLE_VELOCITY = WEAPON[1]/60
DRAG = WEAPON[2]
LIFESPAN = WEAPON[3]

g = -30/3600 -- bullet gravity in meters/tick/tick

GRAVITY = IIVector(0, 0, g)
terminalVelocity = IIVector(0, 0, g / DRAG)

function newBullet(initialPosition, initialVelocity)
    return {
        position = IIVector(),
        initialPosition = initialPosition:cloneVector(),
        positionDelta = IIVector(),
        velocity = IIVector(),
        initialVelocity = initialVelocity:cloneVector(),
        acceleration = IIVector(),
        speed = MUZZLE_VELOCITY,
        distance = 0,
        positionInTicks = function (self, t)
            local A = e^(-DRAG * t) -- A term used in both the velocity and position functions, so if both are being computed it can be reused

            self.velocity:copyVector(self.initialVelocity) -- Reset velocity to starting point
            self.velocity:setScale(A) -- Scales velocity by A
            self.velocity:setAdd(terminalVelocity, 1 - A) -- adds terminal velocity scaled by 1 - A to velocity. V = V + tV * (1-A)

            self.position:copyVector(self.initialVelocity) -- Sets position to starting velocity
            self.position:setAdd(terminalVelocity, -1) -- Subtracts terminal velocity from position
            self.position:setScale((1 - A)/DRAG) -- Scales position
            self.position:setAdd(terminalVelocity, t) -- Adds terminal velocity * t to position. t is the time in ticks

            self.position:setAdd(self.initialPosition) -- Adds the starting position of the bullet to the computed position

            self.distance = self.position:magnitude()
            self.speed = self.velocity:magnitude()
        end,
        stepPositionInTicks = function (self, t)
            self.acceleration:setVector(0, 0, 0)
            self.velocity:copyVector(self.initialVelocity)
            self.position:copyVector(self.initialPosition)

            for i = 1, t do
                self.velocity:setAdd(self.acceleration)
                self.position:setAdd(self.velocity)
                self.acceleration:copyVector(self.velocity)
                -- self.acceleration:setScale(-1/self.velocity:magnitude())
                self.acceleration:setScale(-DRAG)
                self.acceleration:setAdd(GRAVITY)
            end

            self.distance = self.position:magnitude()
            self.speed = self.velocity:magnitude()
        end
    }
end


initialVelocity = IIVector()
initialPosition = IIVector()

turretRotation = IIVector()
turretRotationMatrix = IIMatrix()

function onTick()
    turretRotation:setVector(input.getNumber(1), input.getNumber(2), input.getNumber(3))
    turretRotationMatrix:XYZRotationToZYXMatrix(turretRotation)
end

zoom = 10
function onDraw()
    h = screen.getHeight()

    initialVelocity:setVector(MUZZLE_VELOCITY, 0, 0)
    initialVelocity:matrixRotate(turretRotationMatrix)

    initialPosition:setVector(BARREL_LENGTH, 0, 0)
    initialPosition:matrixRotate(turretRotationMatrix)

    local bullet = newBullet(initialPosition, initialVelocity)

    screen.setColor(255, 255, 255)
    for i = 1, LIFESPAN, 1 do
        bullet:positionInTicks(i)
        screen.drawCircleF(bullet.position[1]/zoom, h - bullet.position[3]/zoom, 0.5)
    end
    continuousPos = bullet.position:cloneVector()
    screen.drawTextBox(2, 2, 100, 80, string.format('Continuous:\n \nX:\n%.6f\n \nY:\n%.6f\n \nZ:\n%.6f', continuousPos:getVector()), -1, -1)

    screen.setColor(255, 0, 0)
    for i = 1, LIFESPAN, 1 do
        bullet:stepPositionInTicks(i)
        screen.drawCircleF(bullet.position[1]/zoom, h - bullet.position[3]/zoom, 0.5)
    end
    discretePos = bullet.position:cloneVector()
    continuousDiff = continuousPos:cloneVector()
    continuousDiff:setAdd(discretePos, -1)
    screen.drawText(92, 2, string.format('Error:\n%.6f', continuousDiff:magnitude()))
    screen.drawTextBox(222, 2, 100, 80, string.format('Discrete:\n \nX:\n%.6f\n \nY:\n%.6f\n \nZ:\n%.6f', discretePos:getVector()), -1, -1)
end