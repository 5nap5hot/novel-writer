import Foundation

struct Scene: Identifiable, Hashable, Codable {
  let id: UUID
  let projectID: UUID
  let chapterID: UUID
  var title: String
  var order: Int
  var body: String
  var wordCount: Int
  var characterCount: Int
  var revision: Int
  var createdAt: Date
  var updatedAt: Date

  init(
    id: UUID = UUID(),
    projectID: UUID,
    chapterID: UUID,
    title: String,
    order: Int,
    body: String = "",
    revision: Int = 0,
    createdAt: Date = .now,
    updatedAt: Date = .now
  ) {
    self.id = id
    self.projectID = projectID
    self.chapterID = chapterID
    self.title = title
    self.order = order
    self.body = body
    self.wordCount = body.split(whereSeparator: \.isWhitespace).count
    self.characterCount = body.count
    self.revision = revision
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

