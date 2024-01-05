import "cursor"
import "drawing"
import "target"
import "widgets/angleDifference"
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
local pixelsPerSecond = 10

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
target:setVisible(false)
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

function UpdateDrawing()
    gfx.clear()
    UpdateDrawingText()
end

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

local drawingTextSprite = gfx.sprite:new()
assert(drawingTextSprite)
drawingTextSprite:moveTo(4, 4)
drawingTextSprite:addSprite()

local controlsTextSprite = gfx.sprite:new()
assert(controlsTextSprite)
controlsTextSprite:moveTo(202, 360 - (4 + font:getHeight()))
controlsTextSprite:addSprite()


function UpdateDrawingText()
    local drawing = getDrawing();
    -- {name} -- {currentDrawing}/{#drawings}
    local drawingText = drawing.meta.name .. " -- " .. currentDrawing .. "/" .. #drawings

    local drawingTextImage = gfx.image.new(400, 240)
    local controlsTextImage = gfx.image.new(400, 240)

    gfx.pushContext(drawingTextImage)
    gfx.drawText(drawingText, 0, 0, font)
    gfx.popContext()
    gfx.pushContext(controlsTextImage)
    gfx.drawText("⬆️ Next ⬇️ Previous Ⓐ Start", 0, 0, font)
    gfx.popContext()

    drawingTextSprite:setImage(drawingTextImage)
    controlsTextSprite:setImage(controlsTextImage)
end

gfx.sprite.setBackgroundDrawingCallback(function(x, y, width, height)
    local bbox = geom.rect.new(x, y, width, height)
    gfx.pushContext()
    gfx.setPattern({ 0x55, 0xEA, 0x57, 0xAA, 0x55, 0xEA, 0x57, 0xAA })
    getDrawing():draw(bbox)
    gfx.popContext()
    gfx.pushContext()
    gfx.setColor(gfx.kColorBlack)
    local expandedBbox = geom.rect.new(bbox.x - 3, bbox.y - 3, bbox.width + 6, bbox.height + 6)
    for i = 1, #tracingPoints do
        local point = tracingPoints[i]
        if expandedBbox:containsPoint(point) then
            gfx.drawCircleAtPoint(point.x, point.y, 2)
        end
    end
    gfx.popContext()
end)

-- How far off is the cursor from pointing at the target?
-- negative = left, positive = right
function getAngleDifference(cursor, target)
    -- Get the vector from the cursor to the target
    local vector = geom.vector2D.new(target.x - cursor.x, target.y - cursor.y):normalized()
    -- Get the vector from the cursor, pointing in the direction of the cursor
    local cursorPos = { x = cursor.x, y = cursor.y }
    local cursorVel = cursor:getNewVelocity(1)
    local futureCursorPos = geom.point.new(cursorPos.x + cursorVel[1], cursorPos.y + cursorVel[2])
    local cursorVector = geom.vector2D.new(futureCursorPos.x - cursorPos.x, futureCursorPos.y - cursorPos.y):normalized()
    -- Get the angle between the two vectors
    local angle = vector:angleBetween(cursorVector)
    return angle
end

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
    target:moveTo(firstPoint.x, firstPoint.y)
    started = true
    cursor:setVisible(true)
    target:setVisible(true)
    tracingTimer:start()
end

function StopDrawing()
    started = false
    cursor:setVisible(false)
    target:setVisible(false)
    tracingTimer:pause()
end

function clamp(value, min, max)
    if value < min then
        return min
    elseif value > max then
        return max
    else
        return value
    end
end

local targetTetherLength = 50

local textImage = gfx.imageWithText

UpdateDrawingText()

function playdate.update()
    gfx.pushContext()

    local refreshRate = playdate.display.getRefreshRate()
    if started then
        cursor:updateVelocity(pixelsPerSecond / refreshRate)
    end

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

        local newSegmentProgress = segmentProgress
        local newDrawingProgress = drawingProgress

        -- Increment the segment progress
        newSegmentProgress = newSegmentProgress + segmentLength * (1 / refreshRate)
        -- If we've reached the end of the segment
        if newSegmentProgress > segmentLength then
            newDrawingProgress = newDrawingProgress + 1
            -- If we've reached the end of the drawing
            if newDrawingProgress > #drawing.segments - 1 then
                -- Reset the drawing progress
                newDrawingProgress = 1
                newSegmentProgress = 0
                -- Stop the drawing
                started = false
            else
                newSegmentProgress = 0
            end
        end

        -- Check if the target is within 10 pixels of the cursor
        local cursorPosition = cursor:getPosition()
        local targetPosition = target:getPosition()
        local distance = getLineLength(cursorPosition, targetPosition)
        if distance <= targetTetherLength then
            -- Move the target
            target:moveTo(point.x, point.y)
            -- Update the drawing progress
            drawingProgress = newDrawingProgress
            segmentProgress = newSegmentProgress
        end
    end

    gfx.popContext()

    gfx.sprite.update()
    playdate.timer.updateTimers()

    drawAngleDifferenceWidget(-getAngleDifference(cursor, target))
    playdate.drawFPS()
end
