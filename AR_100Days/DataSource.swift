import UIKit

struct Day {
    let title: String
    let detail: String
    let classPrefix: String
    let enabled: Bool

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
            classPrefix: "Day1",
            enabled: true
        ),
        Day(
            title: "2: Space distortion",
            detail: "",
            classPrefix: "Day2",
            enabled: true
        ),
        Day(
            title: "4: LiDAR: Metal",
            detail: "",
            classPrefix: "Day4",
            enabled: true
        ),
        Day(
            title: "5: Camera background replace",
            detail: "",
            classPrefix: "Day5",
            enabled: true
        ),
        Day(
            title: "6: Multicamera(Landscape)",
            detail: "",
            classPrefix: "Day6",
            enabled: true
        ),
        Day(
            title: "10: LiDAR: Depth of field",
            detail: "",
            classPrefix: "Day10",
            enabled: true
        ),
        Day(
            title: "11: Only red and human color",
            detail: "",
            classPrefix: "Day11",
            enabled: true
        ),
        Day(
            title: "18: Slash multi camera(Landscape)",
            detail: "",
            classPrefix: "Day18",
            enabled: true
        ),
        Day(
            title: "20: LiDAR: Space Voxels",
            detail: "",
            classPrefix: "Day20",
            enabled: true
        ),
        Day(
            title: "21: LiDAR: Radar",
            detail: "",
            classPrefix: "Day21",
            enabled: true
        ),
        Day(
            title: "22: Blue portal",
            detail: "",
            classPrefix: "Day22",
            enabled: true
        ),
        Day(
            title: "26: Gaze tracking",
            detail: "",
            classPrefix: "Day26",
            enabled: true
        ),
        Day(
            title: "27: Kimetsu Eye",
            detail: "",
            classPrefix: "Day27",
            enabled: true
        ),
        Day(
            title: "28: Painting ball",
            detail: "",
            classPrefix: "Day28",
            enabled: true
        ),
        Day(
            title: "31: LiDAR: Ball physics",
            detail: "",
            classPrefix: "Day31",
            enabled: true
        ),
        Day(
            title: "36: Custom SCNGeometry",
            detail: "",
            classPrefix: "Day36",
            enabled: true
        ),
        Day(
            title: "37: LiDAR: Pink smog",
            detail: "",
            classPrefix: "Day37",
            enabled: true
        ),
        Day(
            title: "38: LiDAR: Wall Paint",
            detail: "",
            classPrefix: "Day38",
            enabled: true
        ),
//        Day(
//            title: "39: LiDAR: Real world Splatoon!",
//            detail: "",
//            classPrefix: "Day39",
//            enabled: false
//        ),
        Day(
            title: "40: Blue face map",
            detail: "",
            classPrefix: "Day40",
            enabled: true
        ),
        Day(
            title: "41: Draw on face map",
            detail: "",
            classPrefix: "Day41",
            enabled: true
        ),
        Day(
            title: "42: Black eye",
            detail: "",
            classPrefix: "Day42",
            enabled: true
        ),
        Day(
            title: "43: Only face map",
            detail: "",
            classPrefix: "Day43",
            enabled: true
        ),
    ]
}
