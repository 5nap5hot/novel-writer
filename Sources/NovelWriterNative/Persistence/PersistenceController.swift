import Foundation

struct AppSnapshot: Codable {
  var projects: [Project]
  var chapters: [Chapter]
  var scenes: [Scene]
  var trashItems: [TrashItem]
  var selection: WorkspaceSelection
  var themeMode: ThemeMode
}

final class PersistenceController {
  private let saveURL: URL
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(baseURL: URL? = nil) {
    let directory = baseURL
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    self.saveURL = directory.appendingPathComponent("novel-writer-native.json")
  }

  func load() throws -> AppSnapshot? {
    guard FileManager.default.fileExists(atPath: saveURL.path) else {
      return nil
    }
    let data = try Data(contentsOf: saveURL)
    return try decoder.decode(AppSnapshot.self, from: data)
  }

  func save(snapshot: AppSnapshot) throws {
    let directory = saveURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let data = try encoder.encode(snapshot)
    try data.write(to: saveURL, options: .atomic)
  }
}

