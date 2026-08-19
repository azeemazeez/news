import SwiftUI

struct SettingsView: View {
    @State private var reminderOn = NotificationManager.shared.isEnabled
    @State private var permissionDenied = false

    var body: some View {
        Form {
                Section("Reading") {
                    Picker("Text size", selection: Bindable(Prefs.shared).textSize) {
                        ForEach(Prefs.TextSize.allCases) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Daily reminder", isOn: $reminderOn)
                        .onChange(of: reminderOn) { _, on in
                            Task {
                                let ok = await NotificationManager.shared.setEnabled(on)
                                if on && !ok {
                                    reminderOn = false
                                    permissionDenied = true
                                }
                            }
                        }

                    if reminderOn {
                        DatePicker(
                            "Time",
                            selection: Bindable(NotificationManager.shared).reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                } footer: {
                    if permissionDenied {
                        Text("Notifications are turned off for The Nuus. Enable them in Settings to get the daily reminder.")
                    } else {
                        Text("A quiet nudge each day when the new edition is ready.")
                    }
                }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
