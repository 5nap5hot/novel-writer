import Foundation

struct Chapter: Identifiable, Hashable, Codable {
  let id: UUID
  let projectID: UUID
  var title: String
  var order: Int
  var createdAt: Date
  var updatedAt: Date

  init(
    id: UUID = UUID(),
    projectID: UUID,
    title: String,
    order: Int,
    createdAt: Date = .now,
    updatedAt: Date = .now
  ) {
    self.id = id
    self.projectID = projectID
    self.title = title
    self.order = order
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

