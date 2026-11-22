import NotchoraCore
import SwiftUI

struct WorkspaceView: View {
    let model: AppModel

    @State private var conversationSearch = ""

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: Metric.sidebarWidth)

            Rectangle()
                .fill(Color.nHairline)
                .frame(width: 0.8)

            routeContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            Button {
                _ = model.createConversation(navigate: true)
            } label: {
                Label("New Chat", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(NButtonStyle(variant: .primary, fullWidth: true))
            .padding(.horizontal, 12)
            .padding(.top, 14)

            VStack(spacing: 2) {
                navItem(.chat, symbol: "bubble.left.and.bubble.right")
                navItem(.multiAI, symbol: "square.split.2x2")
                navItem(.workflows, symbol: "point.3.connected.trianglepath.dotted")
                navItem(.history, symbol: "clock.arrow.circlepath")
                navItem(.tasks, symbol: "checklist", badge: model.runningTaskCount)
                navItem(.apps, symbol: "square.grid.2x2")
            }
            .padding(.horizontal, 8)
            .padding(.top, 12)

            Rectangle()
                .fill(Color.nHairline)
                .frame(height: 0.7)
                .padding(.horizontal, 14)
                .padding(.top, 8)

            HStack {
                Text("CONVERSATIONS")
                    .font(.system(size: 8.5, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Color.nTextTertiary)
                Spacer()
                Text("\(filteredConversations.count)")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 5)

            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.nTextTertiary)
                TextField("Find a chat", text: $conversationSearch)
                    .textFieldStyle(.plain)
                    .font(.nCaption)
            }
            .padding(.horizontal, 8)
            .frame(height: 25)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(white: 0.18)).frame(height: 0.7)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 1) {
                    ForEach(filteredConversations) { conversation in
                        conversationRow(conversation)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                HStack(spacing: 7) {
                    Text("PROVIDERS")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(0.7)
                        .foregroundStyle(Color.nTextTertiary)
                    Spacer()
                    ForEach(AIProviderID.allCases) { provider in
                        Circle()
                            .fill(model.hasAPIKey(provider) ? Color.providerTint(provider) : Color.nTextTertiary.opacity(0.25))
                            .frame(width: 6, height: 6)
                            .help("\(provider.displayName): \(model.hasAPIKey(provider) ? "Connected" : "No key")")
                    }
                }
                .padding(.horizontal, 14)

                HStack(spacing: 5) {
                    Button {
                        model.requestSettings(.general)
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(NButtonStyle(variant: .ghost, compact: true))

                    Button {
                        model.setPresentation(.expanded)
                    } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 10, weight: .medium))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.borderless)
                    .help("Compact panel")

                    Button {
                        model.collapse()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.borderless)
                    .help("Close to notch")
                }
                .foregroundStyle(Color.nTextSecondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color.black)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(white: 0.14))
                .frame(width: 0.7)
        }
    }

    private func navItem(_ route: AppRoute, symbol: String, badge: Int = 0) -> some View {
        Button {
            model.navigate(route)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(model.route == route ? Color.nAccent : Color.nTextSecondary)
                    .frame(width: 17)
                Text(route.title)
                    .font(.nSmall)
                    .foregroundStyle(model.route == route ? Color.nTextPrimary : Color.nTextSecondary)
                Spacer()
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.nAccent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Color.nAccentSoft))
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 29)
            .overlay(alignment: .leading) {
                if model.route == route {
                    Capsule().fill(Color.nAccent).frame(width: 2, height: 13)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight(radius: 7)
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        Button {
            model.selectConversation(conversation.id)
        } label: {
            HStack(spacing: 7) {
                if conversation.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(Color.nWarning)
                } else {
                    ProviderGlyph(provider: conversation.providerID, size: 13)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(conversation.title)
                        .font(.nCaption)
                        .foregroundStyle(
                            conversation.id == model.selectedConversationID && model.route == .chat
                                ? Color.nTextPrimary : Color.nTextSecondary
                        )
                        .lineLimit(1)
                    if !conversation.preview.isEmpty {
                        Text(conversation.preview)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.nTextTertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                model.togglePin(conversation.id)
            } label: {
                Label(conversation.isPinned ? "Unpin" : "Pin", systemImage: "pin")
            }
            Divider()
            Button(role: .destructive) {
                model.deleteConversation(conversation.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var filteredConversations: [Conversation] {
        let query = conversationSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.conversationsSorted }
        return model.conversationsSorted.filter {
            $0.searchableText.localizedCaseInsensitiveContains(query)
        }
    }

    @ViewBuilder
    private var routeContent: some View {
        switch model.route {
        case .chat:
            ChatView(model: model)
        case .history:
            HistoryView(model: model)
        case .tasks:
            TasksView(model: model)
        case .apps:
            AppsView(model: model)
        case .workflows:
            WorkflowsView(model: model)
        case .multiAI:
            MultiAIView(model: model)
        case .settings:
            SettingsRootView(model: model, embedded: true)
        }
    }
}
