Drawing = {}
Drawing.__index = Drawing

local geom <const> = playdate.geometry
local ds <const> = playdate.datastore
local gfx <const> = playdate.graphics

-- Is a line partially contained in a rectangle?
function lineInRect(line, rect)
    -- TODO: What? I don't fully know why this is working.
    --       For some reason, the drawing is being drawn fine even though the
    --       intersection algorithm isn't correct.
    -- Is either point in the rectangle?
    local x1, y1, x2, y2 = line:unpack()
    if rect:containsPoint(x1, y1) then
        return true
    end
    -- -- Does the line intersect any of the rectangle's sides?
    -- local intersects, _ = line:intersectsRect(rect);
    -- if intersects then
    --     return true
    -- end
end

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

    -- Draw a segment of the drawing in a bounding box
    function drawSegment(segment, bbox)
        if lineInRect(segment, bbox) then
            gfx.drawLine(segment)
        end
    end

    function self:draw(bbox)
        gfx.setClipRect(bbox)
        for i = 1, #self.segments do
            drawSegment(self.segments[i], bbox)
        end
        gfx.clearClipRect()
    end

    return self
end
