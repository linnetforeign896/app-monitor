import CSQLite
import Foundation

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SQLiteValue: Equatable {
    case null
    case int64(Int64)
    case double(Double)
    case text(String)

    var string: String? {
        if case let .text(value) = self { return value }
        return nil
    }

    var int64: Int64? {
        if case let .int64(value) = self { return value }
        return nil
    }

    var double: Double? {
        if case let .double(value) = self { return value }
        if case let .int64(value) = self { return Double(value) }
        return nil
    }
}

enum SQLiteError: Error, LocalizedError {
    case open(String)
    case prepare(String)
    case step(String)
    case bind(String)

    var errorDescription: String? {
        switch self {
        case let .open(message), let .prepare(message), let .step(message), let .bind(message):
            return message
        }
    }
}

final class SQLiteDatabase {
    private var handle: OpaquePointer?

    init(url: URL) throws {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(url.path, &db, flags, nil) != SQLITE_OK {
            let message = db.flatMap { sqlite3_errmsg($0) }.map(String.init(cString:)) ?? "Unknown SQLite open error"
            sqlite3_close(db)
            throw SQLiteError.open(message)
        }
        self.handle = db
        try execute("PRAGMA journal_mode=WAL")
        try execute("PRAGMA foreign_keys=ON")
    }

    deinit {
        sqlite3_close(handle)
    }

    func execute(_ sql: String, _ values: [SQLiteValue] = []) throws {
        let statement = try prepare(sql, values)
        defer { sqlite3_finalize(statement) }

        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE {
                break
            }
            if result == SQLITE_ROW {
                continue
            }
            throw SQLiteError.step(lastErrorMessage())
        }
    }

    func query(_ sql: String, _ values: [SQLiteValue] = []) throws -> [[String: SQLiteValue]] {
        let statement = try prepare(sql, values)
        defer { sqlite3_finalize(statement) }

        var rows: [[String: SQLiteValue]] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE {
                break
            }
            guard result == SQLITE_ROW else {
                throw SQLiteError.step(lastErrorMessage())
            }

            var row: [String: SQLiteValue] = [:]
            for column in 0..<sqlite3_column_count(statement) {
                let name = String(cString: sqlite3_column_name(statement, column))
                switch sqlite3_column_type(statement, column) {
                case SQLITE_INTEGER:
                    row[name] = .int64(sqlite3_column_int64(statement, column))
                case SQLITE_FLOAT:
                    row[name] = .double(sqlite3_column_double(statement, column))
                case SQLITE_TEXT:
                    row[name] = sqlite3_column_text(statement, column).map { .text(String(cString: $0)) } ?? .null
                case SQLITE_NULL:
                    row[name] = .null
                default:
                    row[name] = .null
                }
            }
            rows.append(row)
        }
        return rows
    }

    private func prepare(_ sql: String, _ values: [SQLiteValue]) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepare(lastErrorMessage())
        }

        do {
            try bind(values, to: statement)
        } catch {
            sqlite3_finalize(statement)
            throw error
        }

        return statement
    }

    private func bind(_ values: [SQLiteValue], to statement: OpaquePointer?) throws {
        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            let result: Int32
            switch value {
            case .null:
                result = sqlite3_bind_null(statement, position)
            case let .int64(value):
                result = sqlite3_bind_int64(statement, position, value)
            case let .double(value):
                result = sqlite3_bind_double(statement, position, value)
            case let .text(value):
                result = sqlite3_bind_text(statement, position, value, -1, sqliteTransient)
            }

            guard result == SQLITE_OK else {
                throw SQLiteError.bind(lastErrorMessage())
            }
        }
    }

    private func lastErrorMessage() -> String {
        guard let handle else { return "SQLite database is closed" }
        return String(cString: sqlite3_errmsg(handle))
    }
}
