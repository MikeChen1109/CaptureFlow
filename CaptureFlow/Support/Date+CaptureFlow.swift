import Foundation

extension Date {
    func combiningTime(from time: Date?) -> Date {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent

        var dateComponents = calendar.dateComponents([.year, .month, .day], from: self)
        let timeComponents = time.map {
            calendar.dateComponents([.hour, .minute], from: $0)
        }

        dateComponents.hour = timeComponents?.hour ?? 9
        dateComponents.minute = timeComponents?.minute ?? 0

        return calendar.date(from: dateComponents) ?? self
    }
}
