import Foundation

public struct ReminderTime:Codable,Equatable,Sendable {
    public let hour:Int
    public let minute:Int
    public init?(hour:Int,minute:Int){guard (0...23).contains(hour),(0...59).contains(minute) else{return nil};self.hour=hour;self.minute=minute}
    public var components:DateComponents {DateComponents(hour:hour,minute:minute)}
    public func nextDate(after date:Date,calendar:Calendar = .current)->Date? {
        calendar.nextDate(after:date,matching:components,matchingPolicy:.nextTime,repeatedTimePolicy:.first,direction:.forward)
    }
}
