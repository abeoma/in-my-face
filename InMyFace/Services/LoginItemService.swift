import Combine
import ServiceManagement

/// OSの登録状態を正とし、明示操作のときだけログイン項目を変更する。
@MainActor
final class LoginItemService: ObservableObject {
    @Published private(set) var status: SMAppService.Status = .notRegistered
    @Published private(set) var isUpdating = false
    @Published private(set) var errorMessage: String?
    let isDemo: Bool
    private let readStatus: () -> SMAppService.Status
    private let register: () throws -> Void
    private let unregister: () async throws -> Void

    init(
        isDemo: Bool = false,
        readStatus: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
        register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
        unregister: @escaping () async throws -> Void = {
            try await SMAppService.mainApp.unregister()
        }
    ) {
        self.isDemo = isDemo
        self.readStatus = readStatus
        self.register = register
        self.unregister = unregister
        refresh()
    }

    var isRegistered: Bool { status == .enabled || status == .requiresApproval }

    var statusText: String {
        if isDemo { return "デモではログイン項目を変更しません。" }
        switch status {
        case .notRegistered: return "未登録：ログイン時に自動起動しません。"
        case .enabled: return "有効：次回のユーザーログイン時に起動します。"
        case .requiresApproval: return "承認待ち・OS側で無効：システム設定で許可してください。"
        case .notFound: return "アプリを確認できません。配置先と署名を確認してください。"
        @unknown default: return "OSの登録状態を確認できません。"
        }
    }

    func refresh() {
        guard !isDemo, !isUpdating else { return }
        let currentStatus = readStatus()
        // OS設定で状態が変わった場合、過去の操作エラーを現在の失敗と誤認させない。
        if currentStatus != status { errorMessage = nil }
        status = currentStatus
    }

    func setEnabled(_ enabled: Bool) async {
        guard !isDemo, !isUpdating else { return }
        isUpdating = true
        errorMessage = nil
        defer {
            status = readStatus()
            isUpdating = false
        }
        // 操作直前にも読み直し、OS側での変更と二重登録を尊重する。
        status = readStatus()
        do {
            if enabled {
                if status == .notRegistered || status == .notFound { try register() }
            } else if isRegistered {
                try await unregister()
            }
        } catch {
            errorMessage = "ログイン項目を変更できませんでした。配置先・署名とシステム設定を確認し、再試行してください。"
        }
    }
}
