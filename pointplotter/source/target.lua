import 'vectorsprite'

Target = {}
Target.__index = Target

local geom <const> = playdate.geometry

function Target:new()
    ---@class VectorSprite
    local self = VectorSprite:new(
        {
            -- Octagon (origin at center)
            0, -5,
            5, 0,
            5, 5,
            0, 5,
            -5, 5,
            -5, 0,
            -5, -5,
            0, -5
        }
    )
    self.type = "target"
    self.wraps = true

    -- function self:updateVelocity(pixelsPerSecond)
    --     self:setVelocity(
    --     -- X velocity
    --         pixelsPerSecond * math.sin(math.rad(self.angle)),
    --         -- Y velocity
    --         -pixelsPerSecond * math.cos(math.rad(self.angle))
    --     )
    -- end

    return self
end
