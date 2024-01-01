import "cursor"
import "drawing"
import "target"
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

local gfx <const> = playdate.graphics
local ds <const> = playdate.datastore
local fs <const> = playdate.file
local geom <const> = playdate.geometry

local drawingNames = fs.listFiles("drawings")
local drawings = {}
local currentDrawing = 1
local tracingPoints = {}

for i = 1, #drawingNames do
    local drawing = Drawing.load(drawingNames[i])
    if drawing ~= nil then
        table.insert(drawings, drawing)
    else
        print("Failed to load drawing " .. drawingNames[i])
    end
end

local started = false
-- The progress of the current drawing (1 - #segments)
local drawingProgress = 1
-- The progress of the current segment (0 - segment length)
local segmentProgress = 0
local pixelsPerSecond = 3

local cursor = Cursor:new()
assert(cursor)
cursor:moveTo(64, 64)
-- cursor:setScale(1.5)
cursor:setFillColor(gfx.kColorBlack)
cursor:addSprite()
cursor:setVisible(false)
-- cursor:setStrokeWidth(4)

local target = Target:new()
assert(target)
target:setFillColor(gfx.kColorBlack)
target:setFillPattern({ 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA })
target:setScale(1.5)
target:addSprite()

local function getDrawing()
    return drawings[currentDrawing]
end

local function getPointOnSegment(point1, point2, progress)
    local x = point1.x + (point2.x - point1.x) * progress
    local y = point1.y + (point2.y - point1.y) * progress
    return { x = x, y = y }
end

local function getLineLength(point1, point2)
    local x = point2.x - point1.x
    local y = point2.y - point1.y
    return math.sqrt(x * x + y * y)
end

-- Example drawing
-- {
--     "segments": [
--         {"x": 64, "y": 62, "segment": 0},
--         {"x": 90, "y": 179, "segment": 1}
--         // ...
--     ],
--     "name": "drawing"
-- }



function IncrementCounter()
    currentDrawing = currentDrawing + 1
    if currentDrawing > #drawings then
        currentDrawing = 1
    end
    UpdateDrawing()
end

function DecrementCounter()
    currentDrawing = currentDrawing - 1
    if currentDrawing < 1 then
        currentDrawing = #drawings
    end
    UpdateDrawing()
end

function playdate.downButtonDown()
    DecrementCounter()
end

function playdate.upButtonDown()
    IncrementCounter()
end

function playdate.AButtonDown()
    if started then
        return
    end
    print("Starting drawing " .. currentDrawing)
    StartDrawing()
end

function playdate.cranked(change)
    cursor:setAngle(playdate.getCrankPosition())
end

local font = gfx.font.new("fonts/Pedallica/font-pedallica-fun-14")
gfx.setFont(font, "14")
gfx.setLineWidth(5)

function UpdateDrawingText()
    local drawing = getDrawing();
    -- {name} -- {currentDrawing}/{#drawings}
    local drawingText = drawing.meta.name .. " -- " .. currentDrawing .. "/" .. #drawings

    gfx.drawText(drawingText, 4, 4, font)
    gfx.drawText("⬆️ Next ⬇️ Previous Ⓐ Start", 4, 240 - (4 + font:getHeight()), font)
end

gfx.sprite.setBackgroundDrawingCallback(function(x, y, width, height)
    local bbox = geom.rect.new(x, y, width, height)
    gfx.pushContext()
    gfx.setPattern({ 0x55, 0xEA, 0x57, 0xAA, 0x55, 0xEA, 0x57, 0xAA })
    print("Drawing background (" .. x .. ", " .. y .. ", " .. width .. ", " .. height .. ")")
    getDrawing():draw(bbox)
    gfx.popContext()
    gfx.pushContext()
    gfx.setColor(gfx.kColorBlack)
    local expandedBbox = geom.rect.new(bbox.x - 3, bbox.y - 3, bbox.width + 6, bbox.height + 6)
    for i = 1, #tracingPoints do
        local point = tracingPoints[i]
        print(point)
        if expandedBbox:containsPoint(point) then
            gfx.drawCircleAtPoint(point.x, point.y, 2)
        end
    end
    gfx.popContext()
end)


local tracingInterval = 100
local tracingTimer = playdate.timer.new(tracingInterval, function()
    if started then
        table.insert(tracingPoints, cursor:getPosition())
    end
end)
tracingTimer.repeats = true
tracingTimer:pause()

function StartDrawing()
    local firstPoint = getDrawing().segments[1]
    cursor:moveTo(firstPoint.x, firstPoint.y)
    started = true
    cursor:setVisible(true)
    tracingTimer:start()
end

function StopDrawing()
    started = false
    cursor:setVisible(false)
    tracingTimer:pause()
end

function playdate.update()
    UpdateDrawingText()
    gfx.pushContext()

    local refreshRate = playdate.display.getRefreshRate()
    cursor:updateVelocity(pixelsPerSecond / refreshRate)

    gfx.setColor(gfx.kColorBlack)

    if started then
        local drawing = getDrawing()
        -- Get the current segment
        local segment = drawing.segments[drawingProgress]
        local nextSegment = drawing.segments[drawingProgress + 1]

        -- Get the length of the current segment
        local segmentLength = getLineLength(segment, nextSegment)
        -- Get the current point on the segment
        local point = getPointOnSegment(segment, nextSegment, segmentProgress / segmentLength)

        -- Increment the segment progress
        segmentProgress = segmentProgress + segmentLength * (1 / refreshRate)
        -- If we've reached the end of the segment
        if segmentProgress > segmentLength then
            drawingProgress = drawingProgress + 1
            -- If we've reached the end of the drawing
            if drawingProgress > #drawing.segments - 1 then
                -- Reset the drawing progress
                drawingProgress = 1
                segmentProgress = 0
                -- Stop the drawing
                started = false
            else
                segmentProgress = 0
            end
        end

        -- Draw the target
        target:moveTo(point.x, point.y)
    end



    gfx.popContext()

    gfx.sprite.update()
    playdate.timer.updateTimers()
end
