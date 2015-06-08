import UIKit

class DrawingView: UIView {

    var points: [CGPoint]!
    var context: CGContextRef!

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setup()
    }

    deinit {
        UIGraphicsEndImageContext()
    }

    func setup() {
        backgroundColor = UIColor.clearColor()
        layer.borderColor = UIColor.blueColor().colorWithAlphaComponent(0.5).CGColor
        layer.borderWidth = 10

        points = [CGPoint]()

        UIGraphicsBeginImageContext(bounds.size)
        context = UIGraphicsGetCurrentContext()
        CGContextSetStrokeColorWithColor(context, UIColor.redColor().colorWithAlphaComponent(0.75).CGColor)
        CGContextSetLineWidth(context, 3)
    }

    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
        points.removeAll(keepCapacity: false)

        let firstPoint = (touches.first as! UITouch).locationInView(self)

        points.append(firstPoint)

        CGContextBeginPath(context)
        CGContextMoveToPoint(context, firstPoint.x, firstPoint.y)
    }

    override func touchesMoved(touches: Set<NSObject>, withEvent event: UIEvent) {
        CGContextMoveToPoint(context, points.last!.x, points.last!.y)

        let point = (touches.first as! UITouch).locationInView(self)

        points.append(point)

        CGContextAddLineToPoint(context, point.x, point.y)
        CGContextStrokePath(context)

        let image = UIGraphicsGetImageFromCurrentImageContext()

        layer.contents = image.CGImage
    }

    override func touchesEnded(touches: Set<NSObject>, withEvent event: UIEvent) {
        let point = (touches.first as! UITouch).locationInView(self)

        println(points)
    }

}
