import AppKit
import Combine
import NotchoraCore
import SwiftUI

struct AppsView: View {
    let model: AppModel

    @State private var tick = 0
    @State private var removeAllPresented = false

    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 218), spacing: 8, alignment: .top)]
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 10) {
                Text("Launch or switch to installed AI apps. NOTCHORA uses public app launching only and never reads another app's internal history.")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(model.launcherEntries) { entry in
                            appCard(entry)
                        }
                        addCard
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 14)
                }
            }
            .padding(.top, 10)
        }
        .onReceive(timer) { _ in tick += 1 }
        .alert("Reset app suggestions?", isPresented: $removeAllPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                model.resetLauncherSuggestions()
            }
        } message: {
            Text("This restores the suggested app list and removes your custom entries.")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                model.navigate(.chat)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.nTextSecondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.black))
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 1) {
                Text("AI Apps")
                    .font(.nHeadline)
                    .foregroundStyle(Color.nTextPrimary)
                Text("\(model.launcherEntries.count) apps in your launcher")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
            }
            Spacer()

            Menu {
                Button {
                    model.addLauncherApplication()
                } label: {
                    Label("Add Application…", systemImage: "plus")
                }
                Button {
                    removeAllPresented = true
                } label: {
                    Label("Reset Suggestions…", systemImage: "arrow.counterclockwise")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.nTextSecondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 13)
        .frame(height: 46)
        .background(Color.black)
    }

    private func appCard(_ entry: LauncherEntry) -> some View {
        let installed = model.launcherIsInstalled(entry)
        let running = model.launcherIsRunning(entry)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(nsImage: model.launcherService.icon(for: entry))
                    .resizable()
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.name)
                        .font(.nSmallMedium)
                        .foregroundStyle(Color.nTextPrimary)
                        .lineLimit(1)
                    Text(installed ? (running ? "Running" : "Installed") : "Not installed")
                        .font(.nCaptionRegular)
                        .foregroundStyle(installed ? (running ? Color.nSuccess : Color.nTextTertiary) : Color.nWarning)
                }
                Spacer(minLength: 0)
                if running {
                    StatusDot(color: .nSuccess, pulsing: false)
                        .padding(.top, 4)
                }
            }

            HStack(spacing: 6) {
                Button(installed ? (running ? "Switch" : "Open") : "Not Installed") {
                    model.openLauncherEntry(entry)
                }
                .buttonStyle(NButtonStyle(variant: installed ? .secondary : .ghost, compact: true))
                .disabled(!installed)
                Spacer()
                Menu {
                    Button {
                        model.openLauncherEntry(entry)
                    } label: {
                        Label(running ? "Switch to App" : "Open App", systemImage: "arrow.up.forward.app")
                    }
                    .disabled(!installed)
                    Divider()
                    Button(role: .destructive) {
                        model.removeLauncherEntry(entry)
                    } label: {
                        Label("Remove from Launcher", systemImage: "minus.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.nTextTertiary)
                        .frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
    }

    private var addCard: some View {
        Button {
            model.addLauncherApplication()
        } label: {
            VStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.nTextTertiary)
                Text("Add Application")
                    .font(.nCaption)
                    .foregroundStyle(Color.nTextSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 86)

        }
        .buttonStyle(.plain)
    }
}
