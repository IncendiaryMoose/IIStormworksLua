-- Author: Incendiary Moose
-- GitHub: <GithubLink>
-- Workshop: https://steamcommunity.com/profiles/76561198050556858/myworkshopfiles/?appid=573090
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey


function newHistoryPoint(time, position)
    return {
        time,
        position:cloneVector(),
        IIVector(),
        IIVector()
    }
end

function newTarget (target)
    return {
        newHistoryPoint(0, target[3]),
        position = target[3]:cloneVector(),
        localPosition = target[2]:cloneVector(),
        velocity = IIVector(),
        acceleration = IIVector(),
        timeSinceLastSeen = 0,
        -- timesSeen = 0,
        newSighting = function (self, newTargetIndex)
            local possibleSighting = newTargets[newTargetIndex]
            if possibleSighting and self.timeSinceLastSeen > 0 then

                self.localPosition:copyVector(possibleSighting[2])

                self[#self+1] = newHistoryPoint(self.timeSinceLastSeen, possibleSighting[3])
                if #self > 1 then
                    self.velocity:copyVector(possibleSighting[3])
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

                self.timeSinceLastSeen = 0
                -- self.timesSeen = self.timesSeen + 1
                newTargets[newTargetIndex] = nil
            end
        end,
        update = function (self)
            self.position:copyVector(self[#self][2])
            if #self > 1 then
                self.velocity:setVector(0, 0, 0)
                self.acceleration:setVector(0, 0, 0)
                local totalWeight, correctedTime = 0, self.timeSinceLastSeen + RADAR_FACING_DELAY - 3
                for index, historyPoint in ipairs(self) do
                    self.velocity:setAdd(historyPoint[3], index * 2)
                    self.acceleration:setAdd(historyPoint[4], index * 2)
                    totalWeight = totalWeight + index * 2
                end

                self.velocity:setScale(1 / totalWeight)

                self.acceleration:setScale(1 / totalWeight)

                self.position:setAdd(self.velocity, correctedTime)
                self.position:setAdd(self.acceleration, correctedTime^2 / 2)
                self.localPosition:copyVector(self.position)
                self.localPosition:setAdd(radarPosition, -1)
                self.localPosition:matrixRotate(transposedRadarRotationMatrix)
                self.localPosition:setAdd(RADAR_OFFSET, -1)
            end
            self.distance = self.position:distanceTo(radarPosition)
            self.timeSinceLastSeen = self.timeSinceLastSeen + 1
        end
    }
end