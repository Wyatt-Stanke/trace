Drawing = {}
Drawing.__index = Drawing

local geom <const> = playdate.geometry
local ds <const> = playdate.datastore
local gfx <const> = playdate.graphics

-- Is a line partially contained in a rectangle?
function lineInRect(line, rect)
    -- Is either point in the rectangle?
    local x1, y1, x2, y2 = line:unpack()
    if rect:containsPoint(x1, y1) or rect:containsPoint(x2, y2) then
        return true
    end
    -- Does the line intersect any of the rectangle's sides?
    local intersects, _ = line:intersectsRect(rect);
    if intersects then
        return true
    end
end

-- Drawing load function
function Drawing.load(name)
    local self = Drawing:new()
    setmetatable(self, Drawing)


    local drawing = ds.read("drawings/" .. name:sub(1, -6))
    printTable(drawing)
    if drawing == nil then
        return nil
    end

    for i = 1, #drawing.segments do
        print("Adding point " .. drawing.segments[i].x .. ", " .. drawing.segments[i].y)
        local segment = drawing.segments[i]
        self:addPoint(geom.point.new(segment.x, segment.y))
    end

    self.name = drawing.meta.name
    self.meta = drawing.meta

    print("Loaded drawing " .. self.name .. " with #segments " .. #self.segments)

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
            print("Adding first segment " .. self.origin:unpack())
        elseif self.origin == point then
            print("Skipping segment " .. point:unpack())
        else
            print("origin: " .. self.origin:unpack() .. ", point: " .. point:unpack())
            table.insert(self.segments, self.origin .. point)
            print("Adding segment " .. point:unpack())
            print("There are now " .. #self.segments .. " segments")
            self.origin = point
        end
    end

    -- Draw a segment of the drawing in a bounding box
    function drawSegment(segment, bbox)
        if lineInRect(segment, bbox) then
            print("Drawing segment " .. segment:unpack())
            gfx.drawLine(segment)
        end
    end

    function self:draw(bbox)
        print("Drawing " .. self.name .. " with #segments " .. #self.segments)
        gfx.setClipRect(bbox)
        for i = 1, #self.segments do
            drawSegment(self.segments[i], bbox)
        end
        gfx.clearClipRect()
    end

    return self
end
