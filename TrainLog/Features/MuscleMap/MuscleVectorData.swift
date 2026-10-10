import SwiftUI
import TrainLogCore

enum BodyView: String, CaseIterable, Identifiable {
    case front, back
    var id: String { rawValue }
    var name: String { self == .front ? "正面" : "背面" }
}
enum BodySide: String { case left, right, center }
struct MuscleRegion: Identifiable {
    var id: String
    var muscleGroup: MuscleGroup
    var bodyView: BodyView
    var side: BodySide
    var vectorPath: [CGPoint]
    var displayPriority: Int = 0
}
enum MuscleVectorData {
    // All stored points are normalized. The design grid is 200 × 440; rendering always keeps its aspect ratio.
    private static func points(_ coordinates: [(Double, Double)]) -> [CGPoint] { coordinates.map { CGPoint(x: $0.0 / 200, y: $0.1 / 440) } }
    static func contour(_ points: [CGPoint], in rect: CGRect, rounding: CGFloat = 0.20) -> Path {
        guard let first = points.first, let last = points.last else { return Path() }
        func scaled(_ p: CGPoint) -> CGPoint { CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height) }
        func along(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x + (b.x - a.x) * rounding, y: a.y + (b.y - a.y) * rounding) }
        var path = Path(); path.move(to: scaled(along(first, last)))
        for index in points.indices {
            let current = points[index], previous = points[(index + points.count - 1) % points.count], next = points[(index + 1) % points.count]
            path.addLine(to: scaled(along(current, previous)))
            path.addQuadCurve(to: scaled(along(current, next)), control: scaled(current))
        }
        path.closeSubpath(); return path
    }
    static let outline = points([
        (89, 48), (88, 63), (72, 68), (54, 73), (42, 86), (36, 112), (33, 144), (22, 174), (15, 201), (12, 222),
        (17, 233), (26, 230), (31, 216), (31, 200), (43, 173), (51, 151), (60, 122), (65, 148), (69, 176), (66, 202),
        (58, 220), (58, 252), (63, 288), (69, 314), (67, 341), (72, 378), (78, 408), (72, 425), (91, 428), (98, 416),
        (93, 395), (93, 364), (94, 339), (92, 310), (97, 275), (100, 239), (103, 275), (108, 310), (106, 339),
        (107, 364), (107, 395), (102, 416), (109, 428), (128, 425), (122, 408), (128, 378), (133, 341), (131, 314),
        (137, 288), (142, 252), (142, 220), (134, 202), (131, 176), (135, 148), (140, 122), (149, 151), (157, 173),
        (169, 200), (169, 216), (174, 230), (183, 233), (188, 222), (185, 201), (178, 174), (167, 144), (164, 112),
        (158, 86), (146, 73), (128, 68), (112, 63), (111, 48)
    ])
    private static func pair(_ muscle: MuscleGroup, _ view: BodyView, _ coordinates: [(Double, Double)], priority: Int = 0) -> [MuscleRegion] {
        let p = points(coordinates)
        return [MuscleRegion(id: "\(view.rawValue).\(muscle.rawValue).left", muscleGroup: muscle, bodyView: view, side: .left, vectorPath: p, displayPriority: priority),
                MuscleRegion(id: "\(view.rawValue).\(muscle.rawValue).right", muscleGroup: muscle, bodyView: view, side: .right, vectorPath: p.map { CGPoint(x: 1 - $0.x, y: $0.y) }, displayPriority: priority)]
    }
    static let front: [MuscleRegion] =
        pair(.chest, .front, [(97, 82), (80, 77), (65, 84), (62, 105), (74, 120), (96, 117)]) +
        pair(.frontDeltoid, .front, [(62, 76), (49, 82), (42, 96), (43, 113), (53, 109), (58, 94)]) +
        pair(.sideDeltoid, .front, [(43, 99), (38, 113), (38, 126), (44, 122), (48, 111)]) +
        pair(.biceps, .front, [(46, 117), (55, 111), (55, 131), (49, 151), (39, 154), (37, 141)]) +
        pair(.forearms, .front, [(38, 158), (46, 157), (40, 177), (29, 204), (23, 207), (26, 185)]) +
        pair(.abs, .front, [(97, 124), (81, 123), (79, 139), (80, 177), (85, 197), (97, 207)]) +
        pair(.obliques, .front, [(70, 123), (77, 131), (76, 176), (82, 194), (73, 199), (69, 176), (67, 151)]) +
        pair(.quadriceps, .front, [(69, 212), (83, 214), (96, 232), (92, 261), (88, 292), (81, 306), (72, 297), (66, 273), (62, 242)]) +
        pair(.tibialis, .front, [(80, 324), (88, 325), (90, 349), (88, 375), (87, 401), (81, 391), (74, 356), (73, 337)])
    static let back: [MuscleRegion] =
        pair(.trapezius, .back, [(98, 63), (86, 67), (72, 76), (85, 91), (97, 112)]) +
        pair(.rearDeltoid, .back, [(66, 77), (54, 79), (44, 91), (42, 110), (53, 111), (65, 98)]) +
        pair(.sideDeltoid, .back, [(42, 104), (38, 116), (39, 130), (45, 121), (48, 113)]) +
        pair(.upperBack, .back, [(71, 88), (82, 98), (96, 119), (94, 133), (79, 126), (68, 109)]) +
        pair(.lats, .back, [(65, 115), (76, 131), (94, 141), (86, 170), (76, 184), (69, 161)]) +
        pair(.triceps, .back, [(48, 117), (57, 112), (54, 136), (48, 156), (38, 155), (38, 143)]) +
        pair(.forearms, .back, [(38, 161), (46, 160), (39, 181), (29, 206), (23, 207), (28, 181)]) +
        pair(.lowerBack, .back, [(96, 146), (91, 171), (78, 188), (79, 199), (97, 205)]) +
        pair(.glutes, .back, [(77, 204), (97, 211), (97, 239), (83, 249), (63, 238), (61, 220)]) +
        pair(.hamstrings, .back, [(66, 249), (83, 257), (94, 249), (92, 276), (86, 309), (76, 310), (69, 288)]) +
        pair(.calves, .back, [(76, 324), (86, 324), (92, 341), (90, 365), (84, 382), (76, 368), (69, 345)])
    static func regions(for view: BodyView) -> [MuscleRegion] { (view == .front ? front : back).sorted { $0.displayPriority < $1.displayPriority } }
}
struct MuscleRegionShape: Shape {
    var region: MuscleRegion
    func path(in rect: CGRect) -> Path { MuscleVectorData.contour(region.vectorPath, in: rect) }
}
enum MuscleRegionInteraction {
    static func hit(at point: CGPoint, size: CGSize, view: BodyView) -> MuscleGroup? {
        let rect = CGRect(origin: .zero, size: size), regions = MuscleVectorData.regions(for: view)
        // Exact visible surface always wins; nearby small regions have a conservative 10 pt tolerance.
        if let hit = regions.reversed().first(where: { MuscleRegionShape(region: $0).path(in: rect).contains(point) }) { return hit.muscleGroup }
        let nearby = regions.compactMap { region -> (MuscleRegion, CGFloat)? in
            let path = MuscleRegionShape(region: region).path(in: rect)
            guard path.strokedPath(StrokeStyle(lineWidth: 20)).contains(point) else { return nil }
            let box = path.boundingRect
            return (region, hypot(point.x - box.midX, point.y - box.midY))
        }.min { $0.1 < $1.1 }
        return nearby?.0.muscleGroup
    }
}

