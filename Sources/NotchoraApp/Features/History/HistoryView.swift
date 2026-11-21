import NotchoraCore
import SwiftUI

struct HistoryView: View {
    @Bindable var model: AppModel

    @State private var deleteAllPresented = false

    private var filter: HistoryFilter {
        HistoryFilter(
            query: model.historyQuery,
            providerID: model.historyProviderFilter,
            pinnedOnly: model.historyPinnedOnly
        )
    }

    private var hits: [HistoryHit] {
        HistorySearch.hits(in: model.conversations, filter: filter)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 9) {
                HStack(spacing: 7) {
                    SearchInput(text: $model.historyQuery, placeholder: "Search chats and messages")
                    filterMenu
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 2)

                if hits.isEmpty {
                    EmptyStateView(
                        symbol: "clock.arrow.circlepath",
                        title: model.historyQuery.isEmpty ? "No history yet" : "No matches",
                        message: model.historyQuery.isEmpty
                            ? "Conversations you start will appear here, locally on this Mac."
                            : "Try a different phrase or clear the filters."
                    )
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 3) {
                            ForEach(hits) { hit in
                                row(hit)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .alert("Delete all history?", isPresented: $deleteAllPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                model.clearAllConversations()
                model.historyQuery = ""
                model.showToast(.success("History deleted"))
            }
        } message: {
            Text("This removes all local conversations. API keys and workflows are not affected.")
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
                    .background(Circle().fill(Color.primary.opacity(0.045)))
            }
            .buttonStyle(.borderless)
            .help("Back to chat")

            VStack(alignment: .leading, spacing: 1) {
                Text("History")
                    .font(.nHeadline)
                    .foregroundStyle(Color.nTextPrimary)
                Text("\(model.conversations.count) conversations · stored locally")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
            }
            Spacer()
            if !model.hasAnyAPIKey {
                Button("Connect Provider") {
                    model.requestSettings(.providers)
                }
                .buttonStyle(NButtonStyle(variant: .secondary, compact: true))
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 46)
        .background(Color.nPanel.opacity(0.30))
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var filterMenu: some View {
        Menu {
            Section("Provider") {
                Button("All providers") { model.historyProviderFilter = nil }
                ForEach(AIProviderID.allCases) { provider in
                    Button {
                        model.historyProviderFilter = provider
                    } label: {
                        if model.historyProviderFilter == provider {
                            Label(provider.displayName, systemImage: "checkmark")
                        } else {
                            Text(provider.displayName)
                        }
                    }
                }
            }
            Divider()
            Toggle("Pinned only", isOn: $model.historyPinnedOnly)
            Divider()
            Button("Delete All History…", role: .destructive) {
                deleteAllPresented = true
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isFiltering ? Color.nAccent : Color.nTextSecondary)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isFiltering ? Color.nAccentSoft : Color.primary.opacity(0.035))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.nHairline, lineWidth: 0.7)
                }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Filter history")
    }

    private var isFiltering: Bool {
        model.historyProviderFilter != nil || model.historyPinnedOnly
    }

    private func row(_ hit: HistoryHit) -> some View {
        Button {
            model.selectConversation(hit.conversation.id)
        } label: {
            HStack(alignment: .top, spacing: 9) {
                ProviderGlyph(provider: hit.conversation.providerID, size: 22)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        if hit.conversation.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 7.5))
                                .foregroundStyle(Color.nWarning)
                        }
                        Text(hit.conversation.title)
                            .font(.nSmallMedium)
                            .foregroundStyle(Color.nTextPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(hit.conversation.updatedAt, style: .relative)
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    if let excerpt = hit.excerpt {
                        Text(excerpt)
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextSecondary)
                            .lineLimit(2)
                    } else if !hit.conversation.preview.isEmpty {
                        Text(hit.conversation.preview)
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                            .lineLimit(2)
                    }
                    HStack(spacing: 4) {
                        Text(hit.conversation.providerID.shortName)
                        Text("·")
                        Text("\(hit.conversation.messages.count) messages")
                    }
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight(radius: 9)
        .contextMenu {
            Button {
                model.togglePin(hit.conversation.id)
            } label: {
                Label(hit.conversation.isPinned ? "Unpin" : "Pin", systemImage: "pin")
            }
            Button {
                model.selectConversation(hit.conversation.id)
            } label: {
                Label("Open", systemImage: "arrow.up.right")
            }
            Divider()
            Button(role: .destructive) {
                model.deleteConversation(hit.conversation.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
