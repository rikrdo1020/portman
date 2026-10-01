import SwiftUI

struct SettingsView: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        VStack(spacing: 0) {
            // Title bar area
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Services Panel")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Preferences")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "server.rack")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            Form {
                // Port range
                Section {
                    LabeledContent("Dev port range") {
                        HStack(spacing: 6) {
                            TextField("Min", value: $prefs.portRangeMin, format: .number)
                                .frame(width: 64)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                            Text("–")
                                .foregroundStyle(.secondary)
                            TextField("Max", value: $prefs.portRangeMax, format: .number)
                                .frame(width: 64)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                        }
                    }
                } header: {
                    Text("Detection")
                } footer: {
                    Text("Ports outside this range without a recognized dev command are shown under Other.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                // Idle alert
                Section {
                    LabeledContent("Inactive time") {
                        HStack(spacing: 6) {
                            TextField("min", value: $prefs.idleMinutesThreshold, format: .number)
                                .frame(width: 56)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                            Text("minutes")
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("Min CPU to alert") {
                        HStack(spacing: 6) {
                            TextField("%", value: $prefs.idleCPUThreshold, format: .number)
                                .frame(width: 56)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                            Text("%")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Idle alert")
                } footer: {
                    Text("If a service has no active connections for N minutes and CPU exceeds the threshold, the menu bar icon turns orange and a notification is sent.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                // Visibility
                Section {
                    Toggle("Show system ports under Other", isOn: $prefs.showNonDevPorts)
                } header: {
                    Text("Visibility")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Text("Services Panel v1.0")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
                Spacer()
                Button("Save") {
                    prefs.save()
                }
                .controlSize(.small)
                .keyboardShortcut(.return)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
