import Foundation

@MainActor
final class AppModel: ObservableObject {
  @Published var projects: [Project] = []
  @Published var chapters: [Chapter] = []
  @Published var scenes: [Scene] = []
  @Published var trashItems: [TrashItem] = []
  @Published var selection: WorkspaceSelection = .empty
  @Published var themeMode: ThemeMode = .dark

  var activeProject: Project? {
    guard let id = selection.activeProjectID else { return nil }
    return projects.first(where: { $0.id == id })
  }

  func createProject(title: String = "New Novel") {
    let project = Project(title: title)
    projects.append(project)
    selection.activeProjectID = project.id
  }
}

