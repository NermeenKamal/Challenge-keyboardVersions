import UIKit

extension UIFont {
    static func tajawal(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let fontName: String
        switch weight {
        case .bold:
            fontName = "Tajawal-Bold"
        case .medium:
            fontName = "Tajawal-Medium"
        case .light:
            fontName = "Tajawal-Light"
        default:
            fontName = "Tajawal-Regular"
        }
        
        if let customFont = UIFont(name: fontName, size: size) {
            return customFont
        } else {
            print("⚠️ Warning: Font \(fontName) not found in keyboard extension, using system font")
            return UIFont.systemFont(ofSize: size, weight: weight)
        }
    }
} 