import Foundation

struct WorkspaceSelection: Equatable, Codable {
  var activeProjectID: UUID?
  var selectedChapterID: UUID?
  var selectedSceneID: UUID?
  var selectedChapterIDs: [UUID]
  var selectedSceneIDs: [UUID]

  static let empty = WorkspaceSelection(
    activeProjectID: nil,
    selectedChapterID: nil,
    selectedSceneID: nil,
    selectedChapterIDs: [],
    selectedSceneIDs: []
  )
}

