import 'vectorsprite'

Cursor = {}
Cursor.__index = Cursor

local geom <const> = playdate.geometry

function Cursor:new()
    ---@class VectorSprite
    local self = VectorSprite:new(
        {
            -- Triangle (point at top, origin at center)
            0, -5,
            5, 5,
            -5, 5,
            0, -5
        }
    )
    self.type = "cursor"
    self.wraps = true

    function self:getNewVelocity(pixelsPerSecond)
        return {
            -- X velocity
            pixelsPerSecond * math.sin(math.rad(self.angle)),
            -- Y velocity
            -pixelsPerSecond * math.cos(math.rad(self.angle))
        }
    end

    function self:updateVelocity(pixelsPerSecond)
        local velocity = self:getNewVelocity(pixelsPerSecond)
        self:setVelocity(velocity[1], velocity[2])
    end

    return self
end
