import SwiftUI
import UserNotifications
import TrailCore

@MainActor final class ReminderService:NSObject,ObservableObject,UNUserNotificationCenterDelegate {
    static let requestID="wordtrails.daily-reminder"
    @Published private(set) var enabled:Bool
    @Published private(set) var hour:Int
    @Published private(set) var minute:Int
    @Published private(set) var busy=false
    @Published private(set) var permissionDenied=false
    @Published var message:String?
    private let center=UNUserNotificationCenter.current()
    override init(){
        let defaults=UserDefaults.standard
        enabled=defaults.bool(forKey:"dailyReminderEnabled")
        let savedHour=defaults.object(forKey:"dailyReminderHour") as? Int ?? 19
        let savedMinute=defaults.object(forKey:"dailyReminderMinute") as? Int ?? 0
        hour=(0...23).contains(savedHour) ? savedHour:19
        minute=(0...59).contains(savedMinute) ? savedMinute:0
        super.init()
        center.delegate=self
    }
    var date:Date {Calendar.current.date(bySettingHour:hour,minute:minute,second:0,of:Date()) ?? Date()}
    func refresh() async {
        guard !busy else{return}
        let settings=await center.notificationSettings()
        permissionDenied=settings.authorizationStatus == .denied
        if enabled && permissionDenied{center.removePendingNotificationRequests(withIdentifiers:[Self.requestID]);enabled=false;persist()}
        else if enabled{await setEnabled(true)}
    }
    func setEnabled(_ value:Bool) async {
        guard !busy else{return}
        busy=true;defer{busy=false}
        if !value{center.removePendingNotificationRequests(withIdentifiers:[Self.requestID]);enabled=false;message=nil;persist();return}
        do{
            var settings=await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined{
                let granted=try await center.requestAuthorization(options:[.alert,.sound])
                guard granted else{permissionDenied=true;enabled=false;persist();message="Reminders are off. You can allow notifications in Settings.";return}
                settings=await center.notificationSettings()
            }
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral else{
                permissionDenied=true;enabled=false;persist();message="Allow notifications in Settings, then turn on the daily reminder.";return
            }
            try await schedule()
            permissionDenied=false;enabled=true;message=nil;persist()
        }catch{message="The reminder couldn’t be scheduled. \(error.localizedDescription)"}
    }
    func changeTime(_ value:Date) async {
        guard !busy else{return}
        busy=true;defer{busy=false}
        let components=Calendar.current.dateComponents([.hour,.minute],from:value)
        let previousHour=hour,previousMinute=minute
        hour=components.hour ?? 19;minute=components.minute ?? 0
        do{if enabled{try await schedule()};persist();message=nil}
        catch{hour=previousHour;minute=previousMinute;message="The new time couldn’t be saved. \(error.localizedDescription)"}
    }
    private func schedule() async throws {
        let content=UNMutableNotificationContent()
        content.title="A little wordplay awaits"
        content.body="Take a few quiet minutes for today’s Word Trails puzzle."
        content.sound = .default
        let trigger=UNCalendarNotificationTrigger(dateMatching:ReminderTime(hour:hour,minute:minute)!.components,repeats:true)
        // Reusing this identifier replaces the old time; it never stacks daily reminders.
        try await center.add(UNNotificationRequest(identifier:Self.requestID,content:content,trigger:trigger))
    }
    func sendTest() async {
        guard enabled,!busy else{return}
        let content=UNMutableNotificationContent();content.title="Your Word Trails reminder";content.body="This is how your daily reminder will look.";content.sound = .default
        do{try await center.add(UNNotificationRequest(identifier:"wordtrails.reminder-test",content:content,trigger:UNTimeIntervalNotificationTrigger(timeInterval:2,repeats:false)));message="Test reminder scheduled for a moment from now."}
        catch{message=error.localizedDescription}
    }
    private func persist(){
        let d=UserDefaults.standard;d.set(enabled,forKey:"dailyReminderEnabled");d.set(hour,forKey:"dailyReminderHour");d.set(minute,forKey:"dailyReminderMinute")
    }
    nonisolated func userNotificationCenter(_ center:UNUserNotificationCenter,willPresent notification:UNNotification,withCompletionHandler completionHandler:@escaping(UNNotificationPresentationOptions)->Void){completionHandler([.banner,.sound,.list])}
}

struct ReminderSettingsView:View {
    @EnvironmentObject private var reminders:ReminderService
    var body:some View {
        List{
            Section{
                Toggle("Daily reminder",isOn:Binding(get:{reminders.enabled},set:{value in Task{await reminders.setEnabled(value)}})).disabled(reminders.busy).accessibilityIdentifier("dailyReminderToggle")
                DatePicker("Reminder time",selection:Binding(get:{reminders.date},set:{value in Task{await reminders.changeTime(value)}}),displayedComponents:.hourAndMinute).disabled(reminders.busy || !reminders.enabled).accessibilityIdentifier("dailyReminderTime")
                Text("A daily notification at your chosen local time. Reminders are off until you opt in, and you can change the time or turn them off here. Your device schedules them; no internet connection is needed.").font(.subheadline).foregroundStyle(.secondary)
            }
            if reminders.enabled{Section{Button("Send a test notification"){Task{await reminders.sendTest()}}.disabled(reminders.busy)}}
            if reminders.permissionDenied{Section{Text("Notifications are disabled for Word Trails in Settings.");Button("Open Settings"){if let url=URL(string:UIApplication.openSettingsURLString){UIApplication.shared.open(url)}}}}
            if let message=reminders.message{Section{Text(message).foregroundStyle(.secondary)}}
        }.trailListWidth().navigationTitle("Daily reminder").task{await reminders.refresh()}
    }
}
