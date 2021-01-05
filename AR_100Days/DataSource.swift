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
            title: "1: Play movie",
            detail: "",
            classPrefix: "Day1"
        ),
        Day(
            title: "2: Space distortion",
            detail: "",
            classPrefix: "Day2"
        ),
        Day(
            title: "4: LiDAR Metal(LiDAR Device only)",
            detail: "",
            classPrefix: "Day4"
        ),
        Day(
            title: "5: Camera background replace",
            detail: "",
            classPrefix: "Day5"
        ),
    ]
}

