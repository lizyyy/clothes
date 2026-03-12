// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  UsageTracker.swift
//  Clothes
//
//  Created by lzy on 2026/1/6.
//

import Foundation

struct UsageTracker {
    private static let countsKey = "usage_counts"
    private static let datesKey = "usage_dates"
    private static let lock = NSLock()
    private static var cachedCounts: [String: Int]?
    private static var cachedDates: [String: [TimeInterval]]?

    static func increment(ids: [UUID], date: Date = Date()) {
        guard !ids.isEmpty else { return }
        var counts = loadCountsCached()
        var dates = loadDatesCached()

        for id in ids {
            let key = id.uuidString
            counts[key, default: 0] += 1
            dates[key, default: []].append(date.timeIntervalSince1970)
        }

        saveCountsCached(counts)
        saveDatesCached(dates)
        saveCounts(counts)
        saveDates(dates)
    }

    static func count(for id: UUID) -> Int {
        loadCountsCached()[id.uuidString] ?? 0
    }

    static func countsMap() -> [String: Int] {
        loadCountsCached()
    }

    static func lastUsedDate(for id: UUID) -> Date? {
        guard let times = loadDatesCached()[id.uuidString], let last = times.last else { return nil }
        return Date(timeIntervalSince1970: last)
    }

    static func reset() {
        lock.lock()
        cachedCounts = [:]
        cachedDates = [:]
        lock.unlock()
        UserDefaults.standard.removeObject(forKey: countsKey)
        UserDefaults.standard.removeObject(forKey: datesKey)
    }

    private static func loadCountsCached() -> [String: Int] {
        lock.lock()
        defer { lock.unlock() }
        if let cachedCounts {
            return cachedCounts
        }
        let loaded = loadCounts()
        cachedCounts = loaded
        return loaded
    }

    private static func loadDatesCached() -> [String: [TimeInterval]] {
        lock.lock()
        defer { lock.unlock() }
        if let cachedDates {
            return cachedDates
        }
        let loaded = loadDates()
        cachedDates = loaded
        return loaded
    }

    private static func saveCountsCached(_ counts: [String: Int]) {
        lock.lock()
        cachedCounts = counts
        lock.unlock()
    }

    private static func saveDatesCached(_ dates: [String: [TimeInterval]]) {
        lock.lock()
        cachedDates = dates
        lock.unlock()
    }

    private static func loadCounts() -> [String: Int] {
        (UserDefaults.standard.dictionary(forKey: countsKey) as? [String: Int]) ?? [:]
    }

    private static func loadDates() -> [String: [TimeInterval]] {
        (UserDefaults.standard.dictionary(forKey: datesKey) as? [String: [TimeInterval]]) ?? [:]
    }

    private static func saveCounts(_ counts: [String: Int]) {
        UserDefaults.standard.set(counts, forKey: countsKey)
    }

    private static func saveDates(_ dates: [String: [TimeInterval]]) {
        UserDefaults.standard.set(dates, forKey: datesKey)
    }
}
