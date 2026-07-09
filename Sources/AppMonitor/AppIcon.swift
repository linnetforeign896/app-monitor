import AppKit
import SwiftUI

@MainActor
private final class AppIconCache {
    static let shared = AppIconCache()

    private var imagesByPath: [String: NSImage] = [:]

    func image(for path: String) -> NSImage {
        if let image = imagesByPath[path] {
            return image
        }

        let image = NSWorkspace.shared.icon(forFile: path)
        imagesByPath[path] = image
        return image
    }
}

struct AppIcon: View {
    let path: String
    let size: CGFloat
    @State private var image: NSImage?
    @State private var loadedPath: String?

    init(path: String, size: CGFloat) {
        self.path = path
        self.size = size
    }

    var body: some View {
        Group {
            if loadedPath == path, let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .onAppear(perform: loadIcon)
        .onChange(of: path) {
            loadIcon()
        }
    }

    private func loadIcon() {
        guard loadedPath != path || image == nil else { return }
        loadedPath = path
        image = AppIconCache.shared.image(for: path)
    }
}
