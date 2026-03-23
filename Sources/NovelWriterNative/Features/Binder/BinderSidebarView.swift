#if canImport(SwiftUI)
import SwiftUI

struct BinderSidebarView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Binder")
        .font(.headline)
      Text("Chapter and scene tree goes here.")
        .foregroundStyle(.secondary)
      Spacer()
    }
    .padding(16)
  }
}
#endif

