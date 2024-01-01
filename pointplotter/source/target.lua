import 'vectorsprite'

Target = {}
Target.__index = Target

local geom <const> = playdate.geometry

function Target:new()
    ---@class VectorSprite
    local self = VectorSprite:new(
        {
            -- Octagon (point at top, origin at center)
            -- Bottom point
            0, 5,
            -- Bottom right
            3, 3,
            -- Right
            5, 0,
            -- Top right
            3, -3,
            -- Top
            0, -5,
            -- Top left
            -3, -3,
            -- Left
            -5, 0,
            -- Bottom left
            -3, 3,
            -- Bottom point
            0, 5
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
