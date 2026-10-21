import ServiceManagement
import SwiftUI

struct LoginItemSettingsView: View {
    @ObservedObject var service: LoginItemService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle(
                    "ログイン時起動を登録",
                    isOn: Binding(
                        get: { service.isRegistered },
                        set: { enabled in Task { await service.setEnabled(enabled) } })
                )
                .disabled(service.isDemo || service.isUpdating)
                if service.isUpdating { ProgressView().controlSize(.small) }
                Spacer()
                if !service.isDemo {
                    Button("ログイン項目の設定を開く") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                }
            }
            Text(service.statusText).font(.caption).foregroundStyle(.secondary)
            if let error = service.errorMessage {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
        }
    }
}
