import SwiftUI

/// Native sheets can activate an application even when their parent cannot become key.
/// Background snapshots render the same content inline; normal use and the explicit foreground
/// interaction runner retain real AppKit sheet presentation. Inline captures verify layout only.
private var captureSheetInline: Bool {
  ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil
    && ProcessInfo.processInfo.environment["SYNTHESIS_SELFTEST_DIR"] == nil
}

extension View {
  @ViewBuilder func studioSheet<Item: Identifiable, Sheet: View>(
    item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> Sheet
  ) -> some View {
    if captureSheetInline {
      overlay {
        if let value = item.wrappedValue {
          Color.black.opacity(0.35).ignoresSafeArea()
          content(value).clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.3), radius: 30)
        }
      }
    } else {
      sheet(item: item, content: content)
    }
  }

  @ViewBuilder func studioSheet<Sheet: View>(
    isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Sheet
  ) -> some View {
    if captureSheetInline {
      overlay {
        if isPresented.wrappedValue {
          Color.black.opacity(0.35).ignoresSafeArea()
          content().clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.3), radius: 30)
        }
      }
    } else {
      sheet(isPresented: isPresented, content: content)
    }
  }
}
