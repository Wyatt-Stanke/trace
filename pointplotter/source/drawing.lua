Drawing = {}
Drawing.__index = Drawing

local geom <const> = playdate.geometry
local ds <const> = playdate.datastore
local gfx <const> = playdate.graphics

-- Drawing load function
function Drawing.load(name)
    local self = Drawing:new()
    setmetatable(self, Drawing)


    local drawing = ds.read("drawings/" .. name:sub(1, -6))
    if drawing == nil then
        return nil
    end

    for i = 1, #drawing.segments do
        local segment = drawing.segments[i]
        self:addPoint(geom.point.new(segment.x, segment.y))
    end

    self.name = drawing.meta.name
    self.meta = drawing.meta

    return self
end

function Drawing:new()
    local self = {}
    setmetatable(self, Drawing)

    self.origin = nil
    self.segments = {}
    self.name = "drawing"
    self.meta = {}

    function self:setOrigin(point)
        self.origin = point
    end

    function self:addPoint(point)
        assert(point ~= nil, "Point cannot be nil")
        -- x1, y1, x2, y2
        if self.origin == nil then
            self.origin = point
        elseif self.origin == point then
        else
            table.insert(self.segments, self.origin .. point)
            self.origin = point
        end
    end

    function self:draw()
        for i = 1, #self.segments do
            gfx.drawLine(self.segments[i])
        end
    end

    return self
end
