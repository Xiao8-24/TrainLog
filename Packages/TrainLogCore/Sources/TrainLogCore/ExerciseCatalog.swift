import Foundation

public enum ExerciseCatalog {
    public static func id(_ index: UInt8) -> UUID { UUID(uuid: (0x54, 0x4C, 0x01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, index)) }
    private static func make(_ i: UInt8, _ name: String, _ english: String, _ primary: [MuscleGroup], _ secondary: [MuscleGroup] = [], _ equipment: Equipment = .barbell, _ pattern: MovementPattern? = nil, _ estimate: Bool = false, _ tracking: TrackingMode = .weightReps, _ loading: LoadingConvention = .total) -> Exercise {
        Exercise(id: id(i), name: name, englishName: english, primary: primary, secondary: secondary, equipment: equipment, tracking: tracking, loading: loading, pattern: pattern, allowsEstimate: estimate)
    }
    public static let exercises: [Exercise] = [
        make(1, "杠铃卧推", "Barbell bench press", [.chest], [.triceps, .frontDeltoid], .barbell, .horizontalPush, true),
        make(2, "哑铃卧推", "Dumbbell bench press", [.chest], [.triceps, .frontDeltoid], .dumbbell, .horizontalPush, false, .weightReps, .perHand),
        make(3, "上斜杠铃卧推", "Incline bench press", [.chest], [.frontDeltoid, .triceps], .barbell, .horizontalPush, true),
        make(4, "俯卧撑", "Push-up", [.chest], [.triceps, .frontDeltoid], .bodyweight, .horizontalPush, false, .bodyweightReps, .bodyweight),
        make(5, "绳索夹胸", "Cable fly", [.chest], [], .cable),
        make(6, "蝴蝶机夹胸", "Pec deck", [.chest], [], .machine),
        make(7, "引体向上", "Pull-up", [.lats], [.biceps, .upperBack], .bodyweight, .verticalPull, false, .bodyweightReps, .bodyweight),
        make(8, "高位下拉", "Lat pulldown", [.lats], [.biceps, .upperBack], .cable, .verticalPull),
        make(9, "杠铃划船", "Barbell row", [.upperBack, .lats], [.biceps, .rearDeltoid], .barbell, .horizontalPull, true),
        make(10, "单臂哑铃划船", "One-arm dumbbell row", [.lats, .upperBack], [.biceps, .rearDeltoid], .dumbbell, .horizontalPull),
        make(11, "坐姿划船", "Seated cable row", [.upperBack, .lats], [.biceps, .rearDeltoid], .cable, .horizontalPull),
        make(12, "直臂下压", "Straight-arm pulldown", [.lats], [], .cable),
        make(13, "杠铃推举", "Overhead press", [.frontDeltoid, .sideDeltoid], [.triceps], .barbell, .verticalPush, true),
        make(14, "哑铃肩推", "Dumbbell shoulder press", [.frontDeltoid, .sideDeltoid], [.triceps], .dumbbell, .verticalPush, false, .weightReps, .perHand),
        make(15, "哑铃侧平举", "Lateral raise", [.sideDeltoid], [], .dumbbell, nil, false, .weightReps, .perHand),
        make(16, "哑铃前平举", "Front raise", [.frontDeltoid], [], .dumbbell, nil, false, .weightReps, .perHand),
        make(17, "反向飞鸟", "Reverse fly", [.rearDeltoid], [.upperBack], .dumbbell, nil, false, .weightReps, .perHand),
        make(18, "面拉", "Face pull", [.rearDeltoid, .upperBack], [.trapezius], .cable),
        make(19, "杠铃弯举", "Barbell curl", [.biceps], [.forearms]),
        make(20, "哑铃弯举", "Dumbbell curl", [.biceps], [.forearms], .dumbbell, nil, false, .weightReps, .perHand),
        make(21, "锤式弯举", "Hammer curl", [.biceps, .forearms], [], .dumbbell, nil, false, .weightReps, .perHand),
        make(22, "绳索下压", "Triceps pushdown", [.triceps], [], .cable),
        make(23, "仰卧臂屈伸", "Skull crusher", [.triceps]),
        make(24, "杠铃深蹲", "Back squat", [.quadriceps, .glutes], [], .barbell, .squat, true),
        make(25, "腿举", "Leg press", [.quadriceps, .glutes], [], .machine, .squat),
        make(26, "罗马尼亚硬拉", "Romanian deadlift", [.hamstrings, .glutes], [.lowerBack], .barbell, .hinge, true),
        make(27, "保加利亚分腿蹲", "Bulgarian split squat", [.quadriceps, .glutes], [], .dumbbell, .squat),
        make(28, "腿屈伸", "Leg extension", [.quadriceps], [], .machine),
        make(29, "腿弯举", "Leg curl", [.hamstrings], [], .machine),
        make(30, "器械提踵", "Calf raise", [.calves], [], .machine),
        make(31, "卷腹", "Crunch", [.abs], [], .bodyweight, nil, false, .bodyweightReps, .bodyweight),
        make(32, "平板支撑", "Plank", [.abs], [.obliques], .bodyweight, nil, false, .duration, .timeOnly),
        make(33, "悬垂举腿", "Hanging leg raise", [.abs], [], .bodyweight, nil, false, .bodyweightReps, .bodyweight),
        make(34, "绳索卷腹", "Cable crunch", [.abs], [], .cable),
        make(35, "辅助引体向上", "Assisted pull-up", [.lats], [.biceps, .upperBack], .machine, .verticalPull, false, .assistedReps, .assistance),
        make(36, "传统硬拉", "Deadlift", [.glutes, .hamstrings], [.lowerBack, .quadriceps, .trapezius], .barbell, .hinge, true),
        make(37, "上斜哑铃卧推", "Incline dumbbell press", [.chest], [.frontDeltoid, .triceps], .dumbbell, .horizontalPush, false, .weightReps, .perHand)
    ]
    public static let templates: [TrainingTemplate] = [
        TrainingTemplate(name: "Push · 胸肩三头", items: [1, 14, 15, 22].map { TemplateItem(exerciseID: id($0)) }),
        TrainingTemplate(name: "Pull · 背部二头", items: [8, 9, 18, 19].map { TemplateItem(exerciseID: id($0)) }),
        TrainingTemplate(name: "Legs · 腿部核心", items: [24, 26, 29, 30, 32].map { TemplateItem(exerciseID: id($0)) })
    ]
    public static func session(from template: TrainingTemplate, catalog: [Exercise], date: Date = Date()) throws -> Session {
        var session = Session(mode: .detailed, date: date)
        session.exercises = try template.items.map { item in
            guard let exercise = catalog.first(where: { $0.id == item.exerciseID }) else { throw ValidationError("模板中的动作已不存在，请编辑模板。") }
            guard (1...30).contains(item.setCount) else { throw ValidationError("模板默认组数应为 1–30。") }
            return ExerciseEntry(exercise: exercise, sets: (0..<item.setCount).map { _ in TrainingSet(weightKg: item.weightKg, reps: item.reps) })
        }
        return session
    }
}

