import Foundation

public struct AppUninstallPlanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func plan(for app: MonitoredApp, storageItems: [StorageScanItem]) -> UninstallPlan {
        let protectionReason = protectionReason(for: app)
        var items: [UninstallPlanItem] = []
        var seenPaths = Set<String>()

        let bundlePath = standardizedPath(app.path)
        let bundleScanItem = storageItems.first {
            $0.category == .bundle && standardizedPath($0.path) == bundlePath
        }
        items.append(planItem(
            appID: app.id,
            role: .appBundle,
            category: .bundle,
            path: bundlePath,
            sizeBytes: bundleScanItem?.sizeBytes ?? sizeOfItem(atPath: bundlePath),
            warning: bundleScanItem?.warning,
            protectionReason: protectionReason,
            coveredByParentID: nil
        ))
        seenPaths.insert(bundlePath)

        for item in storageItems.sorted(by: storageSort) {
            let path = standardizedPath(item.path)
            guard seenPaths.insert(path).inserted else { continue }

            let parentID = coveringParentID(for: path, in: items)
            items.append(planItem(
                appID: app.id,
                role: .relatedPath,
                category: item.category,
                path: path,
                sizeBytes: item.sizeBytes,
                warning: item.warning,
                protectionReason: protectionReason,
                coveredByParentID: parentID
            ))
        }

        return UninstallPlan(
            app: app,
            items: items.sorted(by: planSort),
            protectionReason: protectionReason
        )
    }

    public func protectionReason(for app: MonitoredApp) -> String? {
        let path = standardizedPath(app.path)
        if path == Bundle.main.bundleURL.standardizedFileURL.path {
            return "App Monitor cannot uninstall itself."
        }
        if path.hasPrefix("/System/") {
            return "System applications are protected."
        }
        if let bundleID = app.bundleIdentifier?.lowercased(), bundleID == "com.jacob.appmonitor" {
            return "App Monitor cannot uninstall itself."
        }
        if let bundleID = app.bundleIdentifier?.lowercased(), bundleID.hasPrefix("com.apple.") {
            return "Apple system applications are protected."
        }
        return nil
    }

    public func risk(for category: StorageCategory, role: UninstallPlanItemRole, path: String) -> UninstallRiskLevel {
        if isSymbolicLink(path) {
            return .high
        }

        switch category {
        case .caches, .logs, .httpStorages, .savedApplicationState, .diagnosticReports:
            return .low
        case .bundle, .applicationSupport, .extensions, .launchAgents, .applicationScripts, .webKit, .cookies:
            return .medium
        case .containers, .groupContainers, .preferences:
            return .high
        }
    }

    private func planItem(
        appID: String,
        role: UninstallPlanItemRole,
        category: StorageCategory,
        path: String,
        sizeBytes: Int64,
        warning: String?,
        protectionReason: String?,
        coveredByParentID: String?
    ) -> UninstallPlanItem {
        let risk = protectionReason == nil ? risk(for: category, role: role, path: path) : .protected
        let defaultSelected = protectionReason == nil
            && coveredByParentID == nil
            && risk != .high
            && risk != .protected
        return UninstallPlanItem(
            id: stableID(appID: appID, path: path),
            appID: appID,
            role: role,
            category: category,
            path: path,
            sizeBytes: sizeBytes,
            warning: warning,
            risk: risk,
            defaultSelected: defaultSelected,
            coveredByParentID: coveredByParentID,
            rationale: rationale(for: role, category: category, risk: risk, coveredByParentID: coveredByParentID)
        )
    }

    private func rationale(
        for role: UninstallPlanItemRole,
        category: StorageCategory,
        risk: UninstallRiskLevel,
        coveredByParentID: String?
    ) -> String {
        if coveredByParentID != nil {
            return "Already covered by a selected parent folder."
        }

        if risk == .protected {
            return "Protected items are not uninstallable from App Monitor."
        }

        switch role {
        case .appBundle:
            return "The application bundle is required for uninstall."
        case .relatedPath:
            switch category {
            case .caches, .logs, .httpStorages, .savedApplicationState, .diagnosticReports:
                return "Usually rebuildable app data."
            case .applicationSupport, .extensions, .launchAgents, .applicationScripts, .webKit, .cookies:
                return "App-related support data. Review before trashing."
            case .containers, .groupContainers, .preferences:
                return "May contain settings, accounts, documents, or shared app state."
            case .bundle:
                return "Related app bundle path."
            }
        }
    }

    private func coveringParentID(for path: String, in items: [UninstallPlanItem]) -> String? {
        items.first { item in
            item.path != path && path.hasPrefix(item.path.withTrailingSlash)
        }?.id
    }

    private func storageSort(_ lhs: StorageScanItem, _ rhs: StorageScanItem) -> Bool {
        let lhsPath = standardizedPath(lhs.path)
        let rhsPath = standardizedPath(rhs.path)
        if lhsPath.count == rhsPath.count {
            return lhsPath < rhsPath
        }
        return lhsPath.count < rhsPath.count
    }

    private func planSort(_ lhs: UninstallPlanItem, _ rhs: UninstallPlanItem) -> Bool {
        if lhs.role != rhs.role {
            return lhs.role == .appBundle
        }
        if lhs.category != rhs.category {
            return lhs.category.rawValue < rhs.category.rawValue
        }
        return lhs.path < rhs.path
    }

    private func standardizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private func stableID(appID: String, path: String) -> String {
        "\(appID)|uninstall|\(path)"
    }

    private func isSymbolicLink(_ path: String) -> Bool {
        (try? fileManager.destinationOfSymbolicLink(atPath: path)) != nil
    }

    private func sizeOfItem(atPath path: String) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            let attributes = try? fileManager.attributesOfItem(atPath: path)
            return attributes?[.size] as? Int64 ?? 0
        }

        var total: Int64 = 0
        for case let child as URL in enumerator {
            guard (try? child.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }
            let values = try? child.resourceValues(forKeys: [.fileAllocatedSizeKey, .totalFileAllocatedSizeKey])
            total += Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
        return total
    }
}

private extension String {
    var withTrailingSlash: String {
        hasSuffix("/") ? self : self + "/"
    }
}
