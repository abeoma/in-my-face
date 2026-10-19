# In My Face（仮称）

会議直前に作業画面を覆う大きなアラートを表示する、macOSネイティブのメニューバー常駐アプリです。「In Your Face」に着想を得て、標準通知を見逃すことによる遅刻や参加忘れを減らします。既存製品との提携や互換性を表すものではありません。

## 主な機能

- EventKit経由で、macOS Calendarに登録された複数カレンダーの予定を参照。
- 対象カレンダーを選択し、開始0・1・3・5分前に独自オーバーレイを表示（初期値1分前）。
- 会議名・開始時刻・残り時間、Join / Dismissを表示。
- Google Meet、Zoom、Microsoft Teams、Webexの会議URLを検出。
- 次の予定・当日の予定、一時停止・再開、通知音、ログイン時起動を提供。

## 技術スタックと動作範囲

採用方針はSwift、SwiftUI、AppKit、EventKit、ServiceManagement、UserDefaults、Xcode、XCTestです。最小OSはmacOS 14を暫定基準とし、実装前の検証で確定します。SPMは必要になった場合に純粋ロジックを分離する選択肢です。

予定の読み取りにカレンダーのFull Accessが必要ですが、アプリは予定を編集しません。バックエンドや独自のカレンダー同期は設けず、カレンダーデータを外部送信しません。Joinの明示操作でブラウザー等を開きます。

フルスクリーン・Space・複数ディスプレイではOSの制御に従います。ロック画面、スリープ中、すべての他アプリ上での表示・定刻配信は保証しません。

## 開発ステータス

初期設計段階です。Swiftコード、Xcodeプロジェクト、ビルド・テストコマンドはまだありません。実行可能な構成の追加時に、対応Xcode版と再現可能なコマンドをここへ追記します。

## ドキュメント

- [プロダクト概要](docs/product-overview.md)：背景、価値、MVPの境界
- [要件](docs/requirements.md)：優先順位と受け入れ条件
- [アーキテクチャ](docs/architecture.md)：責務、処理フロー、永続化
- [技術判断](docs/technical-decisions.md)：ADR、公式資料、制約と未決事項
- [開発計画](docs/development-plan.md)：検証・実装順序と完了条件
- [開発ガイド](AGENTS.md)：コーディングエージェント向け指針
