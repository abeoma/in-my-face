# In My Face（仮称）

会議直前に作業画面を覆う大きなアラートを表示する、macOSネイティブのメニューバー常駐アプリです。「In Your Face」に着想を得て、標準通知を見逃すことによる遅刻や参加忘れを減らします。既存製品との提携や互換性を表すものではありません。

## MVPの予定機能

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

P0の技術検証段階です。`Prototypes/EventKitProbe/`に、カレンダー権限・選択日の予定・繰り返し回の識別情報を確認するmacOSアプリがあります。製品のメニューバー・通知・Join・永続化は未実装です。

## 検証アプリのビルドと起動

開発基準はXcode 27.1（27A9275）、Swift 6.4、macOS SDK 27.0です。Deployment TargetはmacOS 14.0ですが、最小OSの実機確認は未実施です。外部依存やプロジェクト生成ツールは不要です。

```sh
xcodebuild -project Prototypes/EventKitProbe/EventKitProbe.xcodeproj \
  -scheme EventKitProbe -configuration Debug \
  -derivedDataPath .build/EventKitProbe build
open .build/EventKitProbe/Build/Products/Debug/EventKitProbe.app
```

初期設定はAd Hoc署名とApp Sandboxです。Apple Development署名で権限の挙動を検証する場合は、Xcodeでプロジェクトを開き、Signing & Capabilitiesで自分のTeamと署名を設定してください。署名・Bundle IDの変更前後では権限状態の同一性を仮定しません。

起動だけでは権限を要求しません。「Full Accessを要求」を押し、許可後に検証用カレンダーを選択します。予定はメモリ内だけに保持し、アプリからの編集・通信・ログ出力は行いません。検証手順と結果は[EventKit検証記録](docs/validation/eventkit-probe.md)を参照してください。

```sh
xcrun swift-format lint --strict --recursive Prototypes/EventKitProbe/Sources
git diff --check
```

整形は同じコマンドの`lint --strict`を`format --in-place`へ変更します。XCTestターゲットは未作成です。

## ドキュメント

- [プロダクト概要](docs/product-overview.md)：背景、価値、MVPの境界
- [要件](docs/requirements.md)：優先順位と受け入れ条件
- [アーキテクチャ](docs/architecture.md)：責務、処理フロー、永続化
- [技術判断](docs/technical-decisions.md)：ADR、公式資料、制約と未決事項
- [開発計画](docs/development-plan.md)：検証・実装順序と完了条件
- [開発ガイド](AGENTS.md)：コーディングエージェント向け指針
