import Foundation

public struct TimelineSession: Identifiable, Hashable {
    public let id: String
    public let appID: String
    public let appName: String
    public let appPath: String
    public let bundleIdentifier: String?
    public let startedAt: Date
    public let endedAt: Date
    public let durationSeconds: TimeInterval
    public let source: String
    public let isClipped: Bool

    public init(
        id: String,
        appID: String,
        appName: String,
        appPath: String,
        bundleIdentifier: String?,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: TimeInterval? = nil,
        source: String = "Measured",
        isClipped: Bool
    ) {
        self.id = id
        self.appID = appID
        self.appName = appName
        self.appPath = appPath
        self.bundleIdentifier = bundleIdentifier
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds ?? max(0, endedAt.timeIntervalSince(startedAt))
        self.source = source
        self.isClipped = isClipped
    }
}

public struct TimelineAppLane: Identifiable, Hashable {
    public let id: String
    public let appID: String
    public let appName: String
    public let appPath: String
    public let bundleIdentifier: String?
    public let dayStart: Date
    public let sessions: [TimelineSession]
    public let totalDurationSeconds: TimeInterval
    public let colorIndex: Int

    public init(
        id: String,
        appID: String,
        appName: String,
        appPath: String,
        bundleIdentifier: String?,
        dayStart: Date,
        sessions: [TimelineSession],
        totalDurationSeconds: TimeInterval,
        colorIndex: Int
    ) {
        self.id = id
        self.appID = appID
        self.appName = appName
        self.appPath = appPath
        self.bundleIdentifier = bundleIdentifier
        self.dayStart = dayStart
        self.sessions = sessions
        self.totalDurationSeconds = totalDurationSeconds
        self.colorIndex = colorIndex
    }
}

public struct TimelineDayGroup: Identifiable, Hashable {
    public let id: String
    public let dayStart: Date
    public let appLanes: [TimelineAppLane]
    public let totalDurationSeconds: TimeInterval
    public let sessionCount: Int
    public let activeAppCount: Int

    public init(
        dayStart: Date,
        appLanes: [TimelineAppLane],
        totalDurationSeconds: TimeInterval,
        sessionCount: Int,
        activeAppCount: Int
    ) {
        self.dayStart = dayStart
        self.appLanes = appLanes
        self.totalDurationSeconds = totalDurationSeconds
        self.sessionCount = sessionCount
        self.activeAppCount = activeAppCount
        self.id = String(Int(dayStart.timeIntervalSince1970))
    }
}

public struct TimelineDayTotal: Identifiable, Hashable {
    public let dayStart: Date
    public let durationSeconds: TimeInterval

    public var id: Date { dayStart }

    public init(dayStart: Date, durationSeconds: TimeInterval) {
        self.dayStart = dayStart
        self.durationSeconds = durationSeconds
    }
}

public struct TimelineMetricDelta: Hashable {
    public enum ValueKind: String, Hashable {
        case duration
        case count
    }

    public let currentValue: Double
    public let previousValue: Double
    public let kind: ValueKind

    public init(currentValue: Double, previousValue: Double, kind: ValueKind) {
        self.currentValue = currentValue
        self.previousValue = previousValue
        self.kind = kind
    }

    public var hasPriorData: Bool {
        previousValue > 0
    }

    public var absoluteDelta: Double {
        currentValue - previousValue
    }

    public var percentDelta: Double? {
        guard hasPriorData else { return nil }
        if kind == .duration, previousValue < 300 {
            return nil
        }
        return absoluteDelta / previousValue
    }
}

public struct TimelineSummary: Hashable {
    public let totalUsageSeconds: TimeInterval
    public let dailyAverageSeconds: TimeInterval
    public let longestSession: TimelineSession?
    public let mostActiveDay: TimelineDayTotal?
    public let sessionCount: Int
    public let totalUsageDelta: TimelineMetricDelta
    public let dailyAverageDelta: TimelineMetricDelta
    public let longestSessionDelta: TimelineMetricDelta
    public let mostActiveDayDelta: TimelineMetricDelta
    public let sessionCountDelta: TimelineMetricDelta

    public init(
        totalUsageSeconds: TimeInterval,
        dailyAverageSeconds: TimeInterval,
        longestSession: TimelineSession?,
        mostActiveDay: TimelineDayTotal?,
        sessionCount: Int,
        totalUsageDelta: TimelineMetricDelta,
        dailyAverageDelta: TimelineMetricDelta,
        longestSessionDelta: TimelineMetricDelta,
        mostActiveDayDelta: TimelineMetricDelta,
        sessionCountDelta: TimelineMetricDelta
    ) {
        self.totalUsageSeconds = totalUsageSeconds
        self.dailyAverageSeconds = dailyAverageSeconds
        self.longestSession = longestSession
        self.mostActiveDay = mostActiveDay
        self.sessionCount = sessionCount
        self.totalUsageDelta = totalUsageDelta
        self.dailyAverageDelta = dailyAverageDelta
        self.longestSessionDelta = longestSessionDelta
        self.mostActiveDayDelta = mostActiveDayDelta
        self.sessionCountDelta = sessionCountDelta
    }
}

public struct TimelineHourBucket: Identifiable, Hashable {
    public let id: String
    public let dayStart: Date
    public let hourStart: Date
    public let totalDurationSeconds: TimeInterval
    public let topAppID: String?
    public let topAppName: String?
    public let sessionCount: Int

    public init(
        dayStart: Date,
        hourStart: Date,
        totalDurationSeconds: TimeInterval,
        topAppID: String?,
        topAppName: String?,
        sessionCount: Int
    ) {
        self.dayStart = dayStart
        self.hourStart = hourStart
        self.totalDurationSeconds = totalDurationSeconds
        self.topAppID = topAppID
        self.topAppName = topAppName
        self.sessionCount = sessionCount
        self.id = "\(Int(dayStart.timeIntervalSince1970))|\(Int(hourStart.timeIntervalSince1970))"
    }
}

public enum TimelineDataBuilder {
    public static func clippedSessions(
        from rawSegments: [UsageSegment],
        interval: DateInterval,
        calendar: Calendar,
        allowedAppIDs: Set<String>? = nil
    ) -> [TimelineSession] {
        var sessions: [TimelineSession] = []

        for segment in rawSegments {
            if let allowedAppIDs, !allowedAppIDs.contains(segment.appID) {
                continue
            }

            let clippedStart = max(segment.startedAt, interval.start)
            let clippedEnd = min(segment.endedAt, interval.end)
            guard clippedEnd > clippedStart else { continue }

            var sliceStart = clippedStart
            while sliceStart < clippedEnd {
                let dayStart = calendar.startOfDay(for: sliceStart)
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
                let sliceEnd = min(clippedEnd, nextDay)
                guard sliceEnd > sliceStart else { break }

                let isClipped = sliceStart != segment.startedAt || sliceEnd != segment.endedAt
                sessions.append(TimelineSession(
                    id: "\(segment.id)|\(milliseconds(sliceStart))|\(milliseconds(sliceEnd))",
                    appID: segment.appID,
                    appName: segment.appName,
                    appPath: segment.appPath,
                    bundleIdentifier: segment.bundleIdentifier,
                    startedAt: sliceStart,
                    endedAt: sliceEnd,
                    source: "Measured",
                    isClipped: isClipped
                ))

                sliceStart = sliceEnd
            }
        }

        return sessions.sorted { lhs, rhs in
            if lhs.startedAt == rhs.startedAt {
                if lhs.appName == rhs.appName {
                    return lhs.id < rhs.id
                }
                return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
            }
            return lhs.startedAt > rhs.startedAt
        }
    }

    public static func dayGroups(from sessions: [TimelineSession], calendar: Calendar) -> [TimelineDayGroup] {
        let sessionsByDay = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startedAt)
        }

        return sessionsByDay.map { dayStart, daySessions in
            let sessionsByApp = Dictionary(grouping: daySessions, by: \.appID)
            let lanes = sessionsByApp.compactMap { appID, appSessions -> TimelineAppLane? in
                guard let first = appSessions.sorted(by: { $0.startedAt < $1.startedAt }).first else {
                    return nil
                }
                let sortedSessions = appSessions.sorted { lhs, rhs in
                    if lhs.startedAt == rhs.startedAt { return lhs.id < rhs.id }
                    return lhs.startedAt < rhs.startedAt
                }
                return TimelineAppLane(
                    id: "\(appID)|\(Int(dayStart.timeIntervalSince1970))",
                    appID: appID,
                    appName: first.appName,
                    appPath: first.appPath,
                    bundleIdentifier: first.bundleIdentifier,
                    dayStart: dayStart,
                    sessions: sortedSessions,
                    totalDurationSeconds: sortedSessions.reduce(0) { $0 + $1.durationSeconds },
                    colorIndex: stableColorIndex(for: appID)
                )
            }
            .sorted { lhs, rhs in
                if lhs.totalDurationSeconds == rhs.totalDurationSeconds {
                    return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
                }
                return lhs.totalDurationSeconds > rhs.totalDurationSeconds
            }

            return TimelineDayGroup(
                dayStart: dayStart,
                appLanes: lanes,
                totalDurationSeconds: daySessions.reduce(0) { $0 + $1.durationSeconds },
                sessionCount: daySessions.count,
                activeAppCount: lanes.count
            )
        }
        .sorted { lhs, rhs in
            lhs.dayStart > rhs.dayStart
        }
    }

    public static func hourBuckets(from sessions: [TimelineSession], calendar: Calendar) -> [TimelineHourBucket] {
        struct BucketAccumulator {
            var totalDurationSeconds: TimeInterval = 0
            var appTotals: [String: TimeInterval] = [:]
            var appNames: [String: String] = [:]
            var sessionIDs: Set<String> = []
        }

        var buckets: [Date: BucketAccumulator] = [:]

        for session in sessions {
            var cursor = calendar.dateInterval(of: .hour, for: session.startedAt)?.start ?? session.startedAt
            while cursor < session.endedAt {
                guard let nextHour = calendar.date(byAdding: .hour, value: 1, to: cursor) else { break }
                let sliceStart = max(session.startedAt, cursor)
                let sliceEnd = min(session.endedAt, nextHour)

                if sliceEnd > sliceStart {
                    let duration = sliceEnd.timeIntervalSince(sliceStart)
                    var bucket = buckets[cursor] ?? BucketAccumulator()
                    bucket.totalDurationSeconds += duration
                    bucket.appTotals[session.appID, default: 0] += duration
                    bucket.appNames[session.appID] = session.appName
                    bucket.sessionIDs.insert(session.id)
                    buckets[cursor] = bucket
                }

                cursor = nextHour
            }
        }

        return buckets.map { hourStart, bucket in
            let topApp = bucket.appTotals.max { lhs, rhs in
                if lhs.value == rhs.value {
                    return (bucket.appNames[lhs.key] ?? lhs.key) > (bucket.appNames[rhs.key] ?? rhs.key)
                }
                return lhs.value < rhs.value
            }

            return TimelineHourBucket(
                dayStart: calendar.startOfDay(for: hourStart),
                hourStart: hourStart,
                totalDurationSeconds: bucket.totalDurationSeconds,
                topAppID: topApp?.key,
                topAppName: topApp.flatMap { bucket.appNames[$0.key] },
                sessionCount: bucket.sessionIDs.count
            )
        }
        .sorted { lhs, rhs in
            if lhs.dayStart == rhs.dayStart { return lhs.hourStart < rhs.hourStart }
            return lhs.dayStart > rhs.dayStart
        }
    }

    public static func summary(
        sessions: [TimelineSession],
        previousSessions: [TimelineSession],
        interval: DateInterval,
        previousInterval: DateInterval,
        calendar: Calendar
    ) -> TimelineSummary {
        let total = sessions.reduce(0) { $0 + $1.durationSeconds }
        let previousTotal = previousSessions.reduce(0) { $0 + $1.durationSeconds }
        let dayCount = representedDayCount(in: interval, calendar: calendar)
        let previousDayCount = representedDayCount(in: previousInterval, calendar: calendar)
        let dailyAverage = total / TimeInterval(dayCount)
        let previousDailyAverage = previousTotal / TimeInterval(previousDayCount)
        let longestSession = sessions.max { $0.durationSeconds < $1.durationSeconds }
        let previousLongest = previousSessions.map(\.durationSeconds).max() ?? 0
        let mostActiveDay = dayTotals(for: sessions, calendar: calendar).max { lhs, rhs in
            if lhs.durationSeconds == rhs.durationSeconds { return lhs.dayStart < rhs.dayStart }
            return lhs.durationSeconds < rhs.durationSeconds
        }
        let previousMostActiveDaySeconds = dayTotals(for: previousSessions, calendar: calendar)
            .map(\.durationSeconds)
            .max() ?? 0

        return TimelineSummary(
            totalUsageSeconds: total,
            dailyAverageSeconds: dailyAverage,
            longestSession: longestSession,
            mostActiveDay: mostActiveDay,
            sessionCount: sessions.count,
            totalUsageDelta: TimelineMetricDelta(currentValue: total, previousValue: previousTotal, kind: .duration),
            dailyAverageDelta: TimelineMetricDelta(currentValue: dailyAverage, previousValue: previousDailyAverage, kind: .duration),
            longestSessionDelta: TimelineMetricDelta(currentValue: longestSession?.durationSeconds ?? 0, previousValue: previousLongest, kind: .duration),
            mostActiveDayDelta: TimelineMetricDelta(currentValue: mostActiveDay?.durationSeconds ?? 0, previousValue: previousMostActiveDaySeconds, kind: .duration),
            sessionCountDelta: TimelineMetricDelta(currentValue: Double(sessions.count), previousValue: Double(previousSessions.count), kind: .count)
        )
    }

    public static func previousInterval(
        for period: ReportingPeriod,
        currentInterval: DateInterval,
        calendar: Calendar
    ) -> DateInterval {
        let component: Calendar.Component
        switch period {
        case .today:
            component = .day
        case .week:
            component = .weekOfYear
        case .month:
            component = .month
        case .year:
            component = .year
        }

        guard
            let previousStart = calendar.date(byAdding: component, value: -1, to: currentInterval.start),
            let previousFullInterval = calendar.dateInterval(of: component, for: previousStart)
        else {
            let duration = max(currentInterval.duration, 1)
            return DateInterval(start: currentInterval.start.addingTimeInterval(-duration), end: currentInterval.start)
        }

        let elapsed = max(currentInterval.end.timeIntervalSince(currentInterval.start), 1)
        let elapsedEnd = previousFullInterval.start.addingTimeInterval(elapsed)
        let previousEnd = min(elapsedEnd, previousFullInterval.end)
        return DateInterval(start: previousFullInterval.start, end: previousEnd)
    }

    private static func dayTotals(for sessions: [TimelineSession], calendar: Calendar) -> [TimelineDayTotal] {
        Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startedAt)
        }
        .map { dayStart, sessions in
            TimelineDayTotal(
                dayStart: dayStart,
                durationSeconds: sessions.reduce(0) { $0 + $1.durationSeconds }
            )
        }
    }

    private static func representedDayCount(in interval: DateInterval, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: interval.start)
        let end = calendar.startOfDay(for: interval.end)
        let dayDifference = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(1, dayDifference + 1)
    }

    private static func stableColorIndex(for key: String, paletteSize: Int = 12) -> Int {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for scalar in key.unicodeScalars {
            hash ^= UInt64(scalar.value)
            hash = hash &* 1_099_511_628_211
        }
        return Int(hash % UInt64(max(1, paletteSize)))
    }

    private static func milliseconds(_ date: Date) -> Int {
        Int((date.timeIntervalSince1970 * 1_000).rounded())
    }
}
