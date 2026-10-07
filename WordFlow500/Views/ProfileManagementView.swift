import SwiftUI

@MainActor
struct ProfileManagementView: View {
    let coordinator: AppCoordinator

    @State private var editor: ProfileEditorDestination?
    @State private var pendingDeletion: UserProfile?
    @State private var issueMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(coordinator.profiles.profiles) { profile in
                    Button {
                        _ = coordinator.selectProfile(id: profile.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.tint)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(profile.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(
                                    profile.id
                                        == coordinator.profiles.selectedProfileID
                                        ? "Текущий профиль"
                                        : "Отдельный прогресс и настройки"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if profile.id
                                == coordinator.profiles.selectedProfileID
                            {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.success)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        if coordinator.profiles.profiles.count > 1 {
                            Button(role: .destructive) {
                                pendingDeletion = profile
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }

                        Button {
                            editor = .rename(profile)
                        } label: {
                            Label("Переименовать", systemImage: "pencil")
                        }
                        .tint(AppTheme.tint)
                    }
                }
            } footer: {
                Text(
                    "У каждого человека свои слова, списки, прогресс, ошибки, рисунки, настройки и напоминания."
                )
            }
        }
        .navigationTitle("Профили")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editor = .add
                } label: {
                    Label("Новый профиль", systemImage: "person.badge.plus")
                }
                .accessibilityIdentifier("addProfileButton")
            }
        }
        .sheet(item: $editor) { destination in
            NavigationStack {
                ProfileNameEditor(
                    destination: destination,
                    coordinator: coordinator
                )
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog(
            "Удалить профиль «\(pendingDeletion?.name ?? "")»?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Удалить профиль и данные", role: .destructive) {
                guard let pendingDeletion else { return }
                if !coordinator.deleteProfile(id: pendingDeletion.id) {
                    issueMessage = "Последний профиль удалить нельзя."
                }
                self.pendingDeletion = nil
            }
            Button("Отмена", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text(
                "Локальные слова, прогресс и настройки этого профиля будут удалены с устройства."
            )
        }
        .alert(
            "Не удалось выполнить действие",
            isPresented: Binding(
                get: { issueMessage != nil },
                set: { if !$0 { issueMessage = nil } }
            )
        ) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text(issueMessage ?? "")
        }
    }
}

private struct ProfileNameEditor: View {
    @Environment(\.dismiss) private var dismiss

    let destination: ProfileEditorDestination
    let coordinator: AppCoordinator

    @State private var name: String
    @State private var showsInvalidName = false

    init(
        destination: ProfileEditorDestination,
        coordinator: AppCoordinator
    ) {
        self.destination = destination
        self.coordinator = coordinator
        _name = State(initialValue: destination.initialName)
    }

    var body: some View {
        Form {
            Section {
                TextField("Имя профиля", text: $name)
                    .textContentType(.name)
                    .submitLabel(.done)
                    .onSubmit(save)
            } footer: {
                Text("Имя должно отличаться от уже существующих профилей.")
            }
        }
        .navigationTitle(destination.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить", action: save)
                    .fontWeight(.semibold)
                    .disabled(
                        name.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
            }
        }
        .alert(
            "Такое имя использовать нельзя",
            isPresented: $showsInvalidName
        ) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Введите непустое уникальное имя профиля.")
        }
    }

    private func save() {
        let succeeded: Bool
        switch destination {
        case .add:
            succeeded = coordinator.createProfile(named: name) != nil
        case .rename(let profile):
            succeeded = coordinator.renameProfile(id: profile.id, to: name)
        }
        if succeeded {
            dismiss()
        } else {
            showsInvalidName = true
        }
    }
}

private enum ProfileEditorDestination: Identifiable {
    case add
    case rename(UserProfile)

    var id: String {
        switch self {
        case .add:
            "add"
        case .rename(let profile):
            "rename-\(profile.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .add:
            "Новый профиль"
        case .rename:
            "Имя профиля"
        }
    }

    var initialName: String {
        switch self {
        case .add:
            ""
        case .rename(let profile):
            profile.name
        }
    }
}
