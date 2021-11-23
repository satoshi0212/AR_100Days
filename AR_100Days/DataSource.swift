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
            title: "4: LiDAR Landscape: Metal",
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
        Day(
            title: "44: Copy facemap wip",
            detail: "",
            classPrefix: "Day44",
            enabled: true
        ),
        Day(
            title: "45: Floor pit",
            detail: "",
            classPrefix: "Day45",
            enabled: true
        ),
        Day(
            title: "46: Failed: AR Camera to SCNScene",
            detail: "",
            classPrefix: "Day46",
            enabled: true
        ),
        Day(
            title: "47: Display words",
            detail: "",
            classPrefix: "Day47",
            enabled: true
        ),
        Day(
            title: "48: Dio Knifes",
            detail: "",
            classPrefix: "Day48",
            enabled: true
        ),
        Day(
            title: "50: Image to movie",
            detail: "",
            classPrefix: "Day50",
            enabled: true
        ),
        Day(
            title: "51: Extract 2D FaceMap",
            detail: "",
            classPrefix: "Day51",
            enabled: true
        ),
        Day(
            title: "52: Audio reactive FaceMap",
            detail: "",
            classPrefix: "Day52",
            enabled: true
        ),
        Day(
            title: "53: Audio reactive Shader face",
            detail: "",
            classPrefix: "Day53",
            enabled: true
        ),
        Day(
            title: "54: Change Face color by distance",
            detail: "",
            classPrefix: "Day54",
            enabled: true
        ),
        Day(
            title: "55: Simple AR Nazotoki",
            detail: "",
            classPrefix: "Day55",
            enabled: true
        ),
        Day(
            title: "56: Point clouds",
            detail: "",
            classPrefix: "Day56",
            enabled: true
        ),
        Day(
            title: "57: Free-D only attitude (WIP)",
            detail: "",
            classPrefix: "Day57",
            enabled: true
        ),
        Day(
            title: "58: Nearby Interaction, set plane",
            detail: "",
            classPrefix: "Day58",
            enabled: true
        ),
        Day(
            title: "59: Nearby Interaction, auto set planes",
            detail: "",
            classPrefix: "Day59",
            enabled: true
        ),
        Day(
            title: "62: Image board",
            detail: "",
            classPrefix: "Day62",
            enabled: true
        ),
        Day(
            title: "63: Nearby Interaction, peer position",
            detail: "",
            classPrefix: "Day63",
            enabled: true
        ),
        Day(
            title: "64: Find faces with rear camera",
            detail: "",
            classPrefix: "Day64",
            enabled: true
        ),
        Day(
            title: "66: Detect body by Vision",
            detail: "",
            classPrefix: "Day66",
            enabled: true
        ),
        Day(
            title: "68: Paprika",
            detail: "",
            classPrefix: "Day68",
            enabled: true
        ),
        Day(
            title: "69: Realtime Paprika",
            detail: "",
            classPrefix: "Day69",
            enabled: true
        ),
        Day(
            title: "70: Plot 3D Body segments (wip)",
            detail: "",
            classPrefix: "Day70",
            enabled: true
        ),
    ]
}
