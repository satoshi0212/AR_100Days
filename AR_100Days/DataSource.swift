import UIKit

struct Day {
    let title: String
    let detail: String
    let classPrefix: String

    func controller() -> UIViewController {
        let storyboard = UIStoryboard(name: classPrefix, bundle: nil)
        guard let controller = storyboard.instantiateInitialViewController() else { fatalError() }
        controller.title = title
        return controller
    }
}

struct DaysDataSource {
    let days = [
        Day(
            title: "1: 動画再生",
            detail: "",
            classPrefix: "Day1"
        ),
        Day(
            title: "2: 空間を歪ませる",
            detail: "",
            classPrefix: "Day2"
        ),
        Day(
            title: "4: LiDAR Metal(LiDAR Device only)",
            detail: "",
            classPrefix: "Day4"
        ),
    ]
}

