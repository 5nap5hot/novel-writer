#if canImport(SwiftUI)
import SwiftUI

struct SceneEditorView: View {
  @State private var text = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Scene 1")
        .font(.title2.weight(.semibold))
      TextEditor(text: $text)
        .font(.body)
    }
    .padding(20)
  }
}
#endif

