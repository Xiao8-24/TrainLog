import AppIntents
import Foundation
import TrainLogCore

struct TrainingDraftEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "进行中的训练"
    static var defaultQuery = TrainingDraftQuery()
    var id: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "正在训练") }
}
struct TrainingDraftQuery: EntityQuery {
    func suggestedEntities() async throws -> [TrainingDraftEntity] {
        WidgetSnapshotStorage.read()?.draftID.map { [TrainingDraftEntity(id: $0.uuidString)] } ?? []
    }
    func entities(for identifiers: [String]) async throws -> [TrainingDraftEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }
}
struct TrainingTemplateEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "训练模板"
    static var defaultQuery = TrainingTemplateQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}
struct TrainingTemplateQuery: EntityStringQuery {
    func suggestedEntities() async throws -> [TrainingTemplateEntity] {
        (WidgetSnapshotStorage.read()?.templates ?? []).map { TrainingTemplateEntity(id: $0.id.uuidString, name: $0.name) }
    }
    func entities(for identifiers: [String]) async throws -> [TrainingTemplateEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }
    func entities(matching string: String) async throws -> [TrainingTemplateEntity] {
        try await suggestedEntities().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
}
struct ContinueTrainingIntent: AppIntent {
    static var title: LocalizedStringResource = "继续训练"
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @Parameter(title: "训练") var workout: TrainingDraftEntity?
    init() {}
    init(sessionID: UUID) { workout = TrainingDraftEntity(id: sessionID.uuidString) }
    func perform() async throws -> some IntentResult & OpensIntent {
        let id = workout.flatMap { UUID(uuidString: $0.id) } ?? WidgetSnapshotStorage.read()?.draftID
        let route = id.map { WorkoutDeepLink.workout($0) } ?? .training
        return .result(opensIntent: OpenURLIntent(route.url))
    }
}
struct OpenTrainingCalendarIntent: AppIntent {
    static var title: LocalizedStringResource = "打开健身日历"
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(WorkoutDeepLink.calendar.url))
    }
}
struct StartTrainingTemplateIntent: AppIntent {
    static var title: LocalizedStringResource = "按模板开始训练"
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @Parameter(title: "模板") var template: TrainingTemplateEntity
    static var parameterSummary: some ParameterSummary { Summary("使用 \(\.$template) 开始训练") }
    init() {}
    init(template: WorkoutWidgetSnapshot.Template) { self.template = TrainingTemplateEntity(id: template.id.uuidString, name: template.name) }
    func perform() async throws -> some IntentResult & OpensIntent {
        guard let id = UUID(uuidString: template.id) else { throw ValidationError("模板标识无效，请重新选择。") }
        return .result(opensIntent: OpenURLIntent(WorkoutDeepLink.template(id).url))
    }
}
struct EndTrainingRestIntent: AppIntent {
    static var title: LocalizedStringResource = "结束当前组间休息"
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @Parameter(title: "训练") var workout: TrainingDraftEntity?
    init() {}
    init(sessionID: UUID) { workout = TrainingDraftEntity(id: sessionID.uuidString) }
    func perform() async throws -> some IntentResult & OpensIntent {
        let id = workout.flatMap { UUID(uuidString: $0.id) } ?? WidgetSnapshotStorage.read()?.draftID
        let route = id.map(WorkoutDeepLink.endRest) ?? .training
        return .result(opensIntent: OpenURLIntent(route.url))
    }
}
