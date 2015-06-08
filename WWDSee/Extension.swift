import UIKit

extension UIImage {

    func imageTintedWithColor(color: UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, self.scale)
        let c = UIGraphicsGetCurrentContext()
        self.drawInRect(rect)
        CGContextSetBlendMode(c, kCGBlendModeSourceIn)
        CGContextSetFillColorWithColor(c, color.CGColor)
        CGContextFillRect(c, rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }

}
