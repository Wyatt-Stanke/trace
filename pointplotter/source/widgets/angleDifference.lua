import "CoreLibs/graphics"
import "CoreLibs/easing"

local gfx <const> = playdate.graphics
local geom <const> = playdate.geometry

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
            playdate.easingFunctions.inOutCubic(math.abs(difference), 0.25, 1.75, arrowChangeTime),
            0.25, 2)
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
