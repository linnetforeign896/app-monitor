import AppKit

enum AppBranding {
    private static let logoResourceName = "AppMonitorLogo"
    private static let appIconResourceName = "AppMonitorAppIcon"

    static func logoImage() -> NSImage? {
        image(named: logoResourceName)
    }

    static func appIconImage() -> NSImage? {
        image(named: appIconResourceName) ?? logoImage()
    }

    private static func image(named resourceName: String) -> NSImage? {
        if let image = NSImage(named: resourceName) {
            return image
        }

        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "png") else {
            return nil
        }

        return NSImage(contentsOf: url)
    }
}
