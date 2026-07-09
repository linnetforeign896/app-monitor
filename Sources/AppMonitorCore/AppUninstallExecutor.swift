import Foundation

public typealias UninstallExecutionProgressHandler = (Int, Int, UninstallPlanItem, [UninstallItemResult]) -> Void

public protocol UninstallTrashManaging {
    func appMonitorFileExists(atPath path: String) -> Bool
    func appMonitorTrashItem(at url: URL) throws -> URL?
}

extension FileManager: UninstallTrashManaging {
    public func appMonitorFileExists(atPath path: String) -> Bool {
        fileExists(atPath: path)
    }

    public func appMonitorTrashItem(at url: URL) throws -> URL? {
        var result: NSURL?
        try trashItem(at: url, resultingItemURL: &result)
        return result as URL?
    }
}

public struct AppUninstallExecutor {
    private let trashManager: UninstallTrashManaging

    public init(trashManager: UninstallTrashManaging = FileManager.default) {
        self.trashManager = trashManager
    }

    public func execute(
        plan: UninstallPlan,
        selectedItemIDs: Set<String>,
        runID: String = UUID().uuidString,
        startedAt: Date = Date(),
        progress: UninstallExecutionProgressHandler? = nil
    ) -> UninstallExecutionSummary {
        var trashedParentPaths: [String] = []
        var bundleTrashFailed = false
        var results: [UninstallItemResult] = []
        let orderedItems = plan.items.sorted { lhs, rhs in
            if lhs.role != rhs.role { return lhs.role == .appBundle }
            return lhs.path.count < rhs.path.count
        }
        let selectedItems = orderedItems.filter { selectedItemIDs.contains($0.id) && $0.risk != .protected && $0.coveredByParentID == nil }

        for (index, item) in orderedItems.enumerated() {
            let result: UninstallItemResult
            if let coveredParent = trashedParentPaths.first(where: { item.path != $0 && item.path.hasPrefix($0.withTrailingSlash) }) {
                result = itemResult(
                    runID: runID,
                    item: item,
                    status: .coveredByParent,
                    message: "Covered by \(coveredParent)"
                )
            } else if !selectedItemIDs.contains(item.id) {
                result = itemResult(runID: runID, item: item, status: .notSelected, message: "Not selected")
            } else if bundleTrashFailed && item.role != .appBundle {
                result = itemResult(runID: runID, item: item, status: .skipped, message: "Skipped because app bundle was not moved to Trash")
            } else if !trashManager.appMonitorFileExists(atPath: item.path) {
                result = itemResult(runID: runID, item: item, status: .missing, message: "Path no longer exists")
            } else {
                do {
                    let trashedURL = try trashManager.appMonitorTrashItem(at: URL(fileURLWithPath: item.path))
                    trashedParentPaths.append(item.path)
                    result = itemResult(
                        runID: runID,
                        item: item,
                        status: .trashed,
                        message: trashedURL?.path
                    )
                } catch {
                    if item.role == .appBundle {
                        bundleTrashFailed = true
                    }
                    result = itemResult(runID: runID, item: item, status: .failed, message: error.localizedDescription)
                }
            }

            results.append(result)
            progress?(index + 1, orderedItems.count, item, results)
        }

        let failedCount = results.filter { $0.status == .failed }.count
        let trashedCount = results.filter { $0.status == .trashed }.count
        let skippedCount = results.count - failedCount - trashedCount
        let status: UninstallRunStatus
        if bundleTrashFailed {
            status = .failed
        } else if failedCount > 0 {
            status = .partial
        } else {
            status = .completed
        }

        let run = UninstallRunRecord(
            id: runID,
            appID: plan.app.id,
            appName: plan.app.name,
            appPath: plan.app.path,
            bundleIdentifier: plan.app.bundleIdentifier,
            status: status,
            startedAt: startedAt,
            completedAt: Date(),
            selectedItemCount: selectedItems.count,
            trashedItemCount: trashedCount,
            failedItemCount: failedCount,
            skippedItemCount: skippedCount,
            selectedBytes: selectedItems.reduce(0) { $0 + $1.sizeBytes },
            message: status == .completed ? nil : "Review item results for failures or skipped paths."
        )

        return UninstallExecutionSummary(run: run, itemResults: results)
    }

    private func itemResult(
        runID: String,
        item: UninstallPlanItem,
        status: UninstallItemResultStatus,
        message: String?
    ) -> UninstallItemResult {
        UninstallItemResult(
            runID: runID,
            itemID: item.id,
            appID: item.appID,
            path: item.path,
            category: item.category,
            role: item.role,
            sizeBytes: item.sizeBytes,
            risk: item.risk,
            status: status,
            message: message
        )
    }
}

private extension String {
    var withTrailingSlash: String {
        hasSuffix("/") ? self : self + "/"
    }
}
