#if canImport(SwiftUI)
import SwiftUI

struct WorkspaceView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    HSplitView {
      BinderSidebarView()
        .frame(minWidth: 240, idealWidth: 280)
      SceneEditorView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}
#endif
