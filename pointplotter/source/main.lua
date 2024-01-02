import "cursor"
import "drawing"
import "target"
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/easing"

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

-- Direction indicator: points up if user should crank up; down if user should crank down; is a circle if user is spot on. Length of arrow indicates how much the user should crank.
-- If you’re really close, the indicator is a stretched circle (stretched up or down in the direction you shoul dmove)
-- The widget should be drawn at the right edge of the screen to show that it relates to the crank
-- Constants:
-- How far off should the user be before the indicator is no longer a circle?
local circleThreshold = 5
-- How stretched should the circle be when the user is close?
local circleStretchFactor = 2
-- How far off should the user be before arrows are drawn?
local drawArrowThreshold = 20
function drawAngleDifferenceWidget(difference)
    gfx.pushContext()
    if math.abs(difference) <= circleThreshold then
        -- If the user is within the circle threshold, draw a circle
        gfx.setColor(gfx.kColorBlack)
        gfx.setLineWidth(2)
        gfx.drawCircleAtPoint(400 - 10, 120, 7)
    elseif math.abs(difference) <= drawArrowThreshold then
        -- If the user is within the stretch threshold, draw a stretched circle
        -- The stretched circle is drawn in 3 parts: the top, the middle, and the bottom
        -- The top and bottom are clipped circles, and the middle is two lines
        -- The top and bottom are drawn with a radius of 7, and the middle is drawn with a height relative to the difference

        local halfCircleSize = 7
        local middleHeight = (math.abs(difference) - circleThreshold) * circleStretchFactor
        local middleWidth = 14

        local bottomHalfCentered = difference > 0
        local topHalfCentered = difference < 0

        -- Draw bottom half
        gfx.setColor(gfx.kColorBlack)
        gfx.setLineWidth(2)
        local bottomHalfYOffset = (topHalfCentered and (
        -- If the top half is centered, the bottom half is drawn at the bottom of the widget, below the
        -- middle rectangle
            middleHeight - halfCircleSize
        ) or -(halfCircleSize))
        gfx.setClipRect(geom.rect.new(400 - 10 - halfCircleSize - 1, 120 + bottomHalfYOffset - 5 + halfCircleSize * 2,
            halfCircleSize * 2 + 2,
            halfCircleSize + 5))
        gfx.drawCircleAtPoint(400 - 10, 120 + (halfCircleSize) + bottomHalfYOffset, halfCircleSize)

        -- Draw top half
        gfx.setColor(gfx.kColorBlack)
        gfx.setLineWidth(2)
        local topHalfYOffset = (bottomHalfCentered and (
        -- If the bottom half is centered, the top half is drawn at the top of the widget, above the
        -- middle rectangle
            -middleHeight - halfCircleSize
        ) or -(halfCircleSize))
        gfx.setClipRect(geom.rect.new(400 - 10 - halfCircleSize - 1, 120 + topHalfYOffset - 5, halfCircleSize * 2 + 2,
            halfCircleSize + 5))
        gfx.drawCircleAtPoint(400 - 10, 120 + (halfCircleSize) + topHalfYOffset, halfCircleSize)


        -- Draw middle
        -- Bottom of the top half clip rect
        local startY = (120 + topHalfYOffset - 5) + (halfCircleSize + 5)
        -- Top of the bottom half clip rect
        local endY = 120 + bottomHalfYOffset - 5 + halfCircleSize * 2

        local leftLineX = 400 - 10 - middleWidth / 2
        local rightLineX = 400 - 10 + middleWidth / 2

        -- Draw 2 vertical lines from startY to endY
        gfx.setColor(gfx.kColorBlack)
        gfx.setLineWidth(2)
        gfx.clearClipRect()

        gfx.drawLine(leftLineX, startY, leftLineX, endY)
        gfx.drawLine(rightLineX, startY, rightLineX, endY)
    else
        -- If the user is outside the circle threshold, draw arrows
        -- The arrows are simpler, with only 2 parts: a tail (drawn as a rectangle) and a head (drawn as a triangle)
        -- The start of the tail is always at the center of the screen, and the end is relative to the difference

        local baseArrowHead = geom.polygon.new(
        -- Triangle (point at top, origin at bottom)
            0, -5,
            5, 5,
            -5, 5,
            0, -5
        )
        local arrowHeight = (math.abs(difference) - circleThreshold) * circleStretchFactor + 14

        local topHalfCentered = difference < 0
        local bottomHalfCentered = difference > 0
        local startOffset = topHalfCentered and -7 or 7

        -- t is elapsed time
        -- b is the beginning value
        -- c is the change (or end value - start value)
        -- d is the duration
        -- function playdate.easingFunctions.inOutCubic(t, b, c, d)
        local arrowChangeTime = 40
        local circleRoundness = clamp(playdate.easingFunctions.inOutCubic(math.abs(difference), 6, -6, arrowChangeTime),
            0, 6)
        local lineThickness = clamp(playdate.easingFunctions.inOutCubic(math.abs(difference), 14, -6.5, arrowChangeTime),
            14 - 6.5, 14)
        local arrowHeadScale = clamp(
            playdate.easingFunctions.inOutCubic(math.abs(difference), 0.5, 1.5, arrowChangeTime),
            0.5, 2)
        local arrowHeadTransform = geom.affineTransform.new()
        arrowHeadTransform:rotate(bottomHalfCentered and 0 or 180)
        -- arrowHeadTransform:scale(1, bottomHalfCentered and 1 or -1)
        arrowHeadTransform:scale(arrowHeadScale)
        arrowHeadTransform:translate(400 - 10, 120 + startOffset + (topHalfCentered and arrowHeight or -arrowHeight))
        local arrowHead = baseArrowHead * arrowHeadTransform

        -- Draw tail
        gfx.setColor(gfx.kColorBlack)
        gfx.setLineWidth(2)

        local tailStartY = topHalfCentered and 0 or -arrowHeight
        local tailEndY = bottomHalfCentered and 0 or arrowHeight
        gfx.drawRoundRect(400 - 10 - lineThickness / 2, 120 + tailStartY + startOffset, lineThickness, arrowHeight,
            circleRoundness)

        -- Draw head
        gfx.setColor(gfx.kColorBlack)
        gfx.setLineWidth(2)
        gfx.drawPolygon(arrowHead)
    end
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
end
