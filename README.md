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

個人利用向けの最小実装があります。選択カレンダーの会議を1分前に画面ごとのアラートで表示し、Dismiss・Escで閉じられます。カレンダー選択・一時停止・Dismiss履歴はローカル保存します。Meet・Zoom・Teams・Webexの対応URLを抽出し、参加先を選んでJoinできます。設定からログイン時起動を登録・解除できます。通知時刻の変更・通知音は未実装です。MVP全体は未完成です。

## アプリのビルドと起動

Xcode 27.1、Swift 6.4、macOS SDK 27.0を基準にします。Deployment TargetはmacOS 14.0で、最小OSの実機確認は未実施です。外部依存はありません。

```sh
xcodebuild -project InMyFace.xcodeproj -scheme InMyFace \
  -configuration Debug -derivedDataPath .build/InMyFace build
open .build/InMyFace/Build/Products/Debug/InMyFace.app
```

Apple Development署名を使う場合は、`Configuration/Signing.local.xcconfig.example`を`Configuration/Signing.local.xcconfig`へコピーし、`YOUR_TEAM_ID`を自分のTeam IDへ置き換えます。ローカル設定はGit管理外です。設定がない場合はAd Hoc署名です。Xcodeから実行する場合は`InMyFace.xcodeproj`を開き、InMyFace / My Macで⌘Rを使います。

初回はアプリの説明を確認してカレンダーへのアクセスを許可し、通知するカレンダーを選択してください。EventKitProbeとは別のBundle IDなので、試作での許可は引き継ぎません。設定画面を閉じてもメニューバーに常駐し、一時停止・終了はメニューバーから操作できます。終了後に自動復活しません。

### ログイン時起動

設定画面の「ログイン時起動を登録」でON/OFFを切り替えます。初期状態は未登録で、起動だけでは登録しません。OS上で既に登録されている場合は、その実状態を表示します。承認待ちやOS側で無効の場合、スイッチは登録済みを示していても自動起動は有効ではありません。「ログイン項目の設定を開く」からOS側で許可してください。OFFにすると承認待ちの登録も解除します。

登録には、継続して使う場所へ配置した署名済みアプリを使ってください。ビルド用フォルダーのアプリで登録したまま移動・削除すると起動先が不安定になる可能性があります。失敗時は画面のエラーを確認して再試行できます。OS設定から戻ると状態を再取得し、無効化された項目を自動で再登録しません。デモではログイン項目を読み書きしません。ログイン時も通常起動と同じ設定画面を表示します。

実ログイン・再起動での自動起動は未確認です。[ログイン時起動の検証記録](docs/validation/login-item.md)を参照してください。

```sh
xcodebuild -project InMyFace.xcodeproj -scheme InMyFace \
  -destination 'platform=macOS' -derivedDataPath .build/InMyFace test
xcrun swift-format lint --strict --recursive InMyFace InMyFaceTests
```

カレンダーにアクセスせず画面を試すには、ビルド後に次を実行します。サンプル2件が起動約30秒後に通知され、履歴・設定は保存しません。デモのJoinは成功を模擬し、外部URLを開きません。通常版との同時起動は避けてください。

```sh
open -n .build/InMyFace/Build/Products/Debug/InMyFace.app --args --demo
```

[最小リマインダーの確認結果と制限](docs/validation/minimal-reminder.md)を参照してください。

個人利用ではmacOS Calendarの通常通知も併用してください。Joinの候補番号はURL→場所→メモの順に対応します。参加先が不明な場合やリンクを正しく検出できない場合は、Calendarの元の招待から参加してください。画面共有・投影・ユーザー切替の前にはメニューバーで一時停止し、利用へ戻ってから再開します。Dismissした会議を検索範囲（現在＋48時間）より先へ延期し、元の保存期限（最後に取得した終了から7日）を過ぎると再通知される場合があります。その場合は新しい日時で再度Dismissしてください。無期限の重複排除やロック状態での秘匿は保証しません。[コード・セキュリティレビューと対応](docs/validation/code-security-review.md)に残課題を記載しています。

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

整形は同じコマンドの`lint --strict`を`format --in-place`へ変更します。試作にはXCTestターゲットはありません。製品のロジックテストは上記の`InMyFaceTests`で実行します。

## ドキュメント

- [プロダクト概要](docs/product-overview.md)：背景、価値、MVPの境界
- [要件](docs/requirements.md)：優先順位と受け入れ条件
- [アーキテクチャ](docs/architecture.md)：責務、処理フロー、永続化
- [技術判断](docs/technical-decisions.md)：ADR、公式資料、制約と未決事項
- [開発計画](docs/development-plan.md)：検証・実装順序と完了条件
- [開発ガイド](AGENTS.md)：コーディングエージェント向け指針
