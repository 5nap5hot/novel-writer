import Foundation

enum TrashItemKind: String, Codable {
  case chapter
  case scene
}

struct TrashItem: Identifiable, Hashable, Codable {
  let id: UUID
  let kind: TrashItemKind
  let originalProjectID: UUID
  let originalChapterID: UUID?
  let originalIndex: Int
  let payload: Data
  let deletedAt: Date
}

