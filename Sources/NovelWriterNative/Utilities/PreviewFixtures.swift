import Foundation

enum PreviewFixtures {
  static func seededModel() -> AppModel {
    let model = AppModel()
    model.createProject(title: "New Novel")
    return model
  }
}

