import Foundation

public class Easing {
    public static func quadraticEaseOut(point: Float) -> Float {
        return -point * (point - 2)
    }

    public static func quadraticEaseInOut(point: Float) -> Float {
        if point < 0.5 {
            return 8 * point * point * point * point
        }
        let flip = point - 1
        return -8 * flip * flip * flip * flip + 1
    }

    public static func quadraticEaseOut(point: Double) -> Double {
        return -point * (point - 2)
    }

    public static func quadraticEaseInOut(point: Double) -> Double {
        if point < 0.5 {
            return 8 * point * point * point * point
        }
        let flip = point - 1
        return -8 * flip * flip * flip * flip + 1
    }
}
