#if canImport(SwiftUI)
import SwiftUI

struct ProjectListView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Novel Writer")
          .font(.largeTitle.weight(.semibold))
        Spacer()
        Button("New Project") {
          model.createProject()
        }
      }

      List(model.projects) { project in
        VStack(alignment: .leading, spacing: 6) {
          Text(project.title)
            .font(.title3.weight(.semibold))
          Text("Updated \(DateFormatting.projectTimestamp.string(from: project.updatedAt))")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(24)
  }
}
#endif

