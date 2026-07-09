import CoreServices
import Foundation

public struct SpotlightUsageImporter {
    private let useCountAttribute = "kMDItemUseCount" as CFString
    private let usedDatesAttribute = "kMDItemUsedDates" as CFString
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func importHistory(for apps: [MonitoredApp]) -> [ImportedUsageHistory] {
        let importedAt = Date()
        return apps.map { app in
            let metadata = metadata(for: app.path)
            return ImportedUsageHistory(
                appID: app.id,
                lastUsed: metadata.lastUsed,
                useCount: metadata.useCount,
                usedDays: normalizeDays(metadata.usedDates),
                importedAt: importedAt
            )
        }
    }

    private func metadata(for path: String) -> SpotlightMetadata {
        guard let item = MDItemCreate(kCFAllocatorDefault, path as CFString) else {
            return SpotlightMetadata()
        }

        let lastUsed = copyAttribute(kMDItemLastUsedDate, from: item) as? Date
        let useCount = int64Attribute(useCountAttribute, from: item)
        let usedDates = dateArrayAttribute(usedDatesAttribute, from: item)
        return SpotlightMetadata(lastUsed: lastUsed, useCount: useCount, usedDates: usedDates)
    }

    private func copyAttribute(_ attribute: CFString, from item: MDItem) -> Any? {
        MDItemCopyAttribute(item, attribute)
    }

    private func int64Attribute(_ attribute: CFString, from item: MDItem) -> Int64? {
        let value = copyAttribute(attribute, from: item)
        if let number = value as? NSNumber {
            return number.int64Value
        }
        if let string = value as? String {
            return Int64(string)
        }
        return nil
    }

    private func dateArrayAttribute(_ attribute: CFString, from item: MDItem) -> [Date] {
        guard let values = copyAttribute(attribute, from: item) as? [Any] else {
            return []
        }
        return values.compactMap { $0 as? Date }
    }

    private func normalizeDays(_ dates: [Date]) -> [Date] {
        let uniqueDays = Set(dates.map { calendar.startOfDay(for: $0) })
        return uniqueDays.sorted()
    }
}

private struct SpotlightMetadata {
    var lastUsed: Date?
    var useCount: Int64?
    var usedDates: [Date] = []
}
