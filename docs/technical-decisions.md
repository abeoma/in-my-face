# 技術判断（ADR）

確認日：2026-10-15。Apple公式資料で確認できたAPIの意味と、本プロジェクトの採用方針を区別します。OS連携の実機確認の範囲は各検証記録に記載します。「採用」は設計上の判断であり、実装完了を意味しません。

2026-10-19追記：EventKit検証アプリのビルド・初期画面を確認しました。[検証記録](validation/eventkit-probe.md)を参照してください。権限許可後の取得やOS連携の実機検証は未実施です。

2026-10-20追記：利用者がApple Development署名のEventKit試作で起動・Full Access許可・選択カレンダーの予定取得を確認しました。変更追従・拒否・撤回の実機試験は未実施です。個人利用向けの[最小実装](validation/minimal-reminder.md)を追加し、未確認のOS挙動は引き続き制限として扱います。

## ADR-01：SwiftとネイティブUI

- 状態：採用。最小OS macOS 14は暫定。
- 背景：軽量な常駐とmacOS固有の権限・ウィンドウ制御が必要。
- 判断：SwiftUIでメニュー・設定・会議表示、AppKitでウィンドウとライフサイクルを制御する。`LSUIElement`を用いる。[Apple：LSUIElement](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement)
- 代替：AppKitのみはUI記述量が増える。Electron等は配布・常駐負荷が増えるため不採用。
- トレードオフ：二つのUI層の接続が必要。古いOS対応を削り権限APIの分岐を抑える。OS・Xcode・Swift版はP0で固定する。

## ADR-02：EventKitとFull Access

- 状態：採用。
- 背景：既存予定の読み取りが中核。writeOnlyでは満たせない。
- 判断：macOS 14以降の`requestFullAccessToEvents`、`NSCalendarsFullAccessUsageDescription`を使用し、fullAccessのみで取得する。OSの許可は書き込みも含むがアプリは読み取り専用と説明する。[Apple：TN3152](https://developer.apple.com/documentation/technotes/tn3152-migrating-to-the-latest-calendar-access-levels)
- 代替：独自OAuth/API同期はネットワークと秘密情報管理を増やすため不採用。カレンダーDB直接参照も不採用。
- トレードオフ：OSの同期遅延と利用者の許可に依存する。変更通知には個別差分がないため再取得し、古いオブジェクトを使わない。[Apple：変更通知](https://developer.apple.com/documentation/eventkit/ekeventstorechangednotification)
- 検証：Sandboxを有効にする場合はCalendars entitlementを含め、署名済みアプリで許可・拒否・撤回を確認する。[Apple：Calendars entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.personal-information.calendars)
- 検証構成（2026-10-19）：独立した試作でFull Access要求、全権限状態の表示、明示選択したカレンダーの期間検索、変更時の再取得を実装。App SandboxとCalendars entitlementを有効化。TN3152本文とSDKヘッダーでAPI・Usage Descriptionを再確認。権限ダイアログと許可後の挙動は未確認。

## ADR-03：公開APIのオーバーレイと表示保証の境界

- 状態：方式候補を採用、具体的フラグと対応範囲は検証待ち。
- 背景：独自の大きな表示が必要だがOSの保護機構を回避しない。
- 判断：AppKitウィンドウを画面ごとに作り、Spaceへの参加を指定する。通常デスクトップはMust、他アプリのフルスクリーン等はShouldとする。
- 確認できた仕様：`canJoinAllSpaces`は全Spaceに表示可能とする指定。CollectionBehaviorはOSのウィンドウ管理に対する表示方針で、一部は排他的。[Apple：canJoinAllSpaces](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallspaces)、[Apple：CollectionBehavior](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct)
- 候補：`fullScreenAuxiliary`はフルスクリーンと同じSpaceへの表示用。Appleの旧ガイドで確認できるが、他アプリ上の普遍的保証とは解釈しない。[Apple：Full-Screen Experience（アーカイブ）](https://developer.apple.com/library/archive/documentation/General/Conceptual/MOSXAppProgrammingGuide/FullScreenApp/FullScreenApp.html)
- 追加候補：`canJoinAllApplications`はStage Managerと適格なフルスクリーンSpaceへの参加用。`primary`・`auxiliary`と排他的。利用可能OSと他フラグとの組合せは実装SDKで確認する。[Apple：canJoinAllApplications](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallapplications)
- 保証しない挙動：ロック・ログイン画面、スクリーンセーバー、他の高レベルウィンドウ、排他的表示中のアプリの上への強制表示。Space移動中、Stage Manager、画面ごとに個別Spaceを使う構成の結果は未確認。これらは現時点の対応保証から除外する判断であり、すべてで表示不可能と断定するものではない。
- 代替：通常通知は要件を満たさない。非公開API、Accessibilityによる操作強制、画面収録、システム用levelの流用は不採用。
- トレードオフ：安全性と利用者の制御を優先するため全面保証はできない。実機で失敗した表示構成は既知制限として公開し、必要なら対象OSまたはMVP要件を見直す。

## ADR-04：ローカルスケジューラーと回ごとの台帳

- 状態：方式採用、回識別の確定は検証待ち。
- 判断：直近のタイマー1本とイベント駆動の再評価、処理済み台帳を使う。復帰時は開始後2分未満までを救済し、終了済みは除外する。閾値はプロダクト判断でありOS仕様ではない。
- 代替：繰り返し全件の長期予約は変更追従が難しい。UserNotificationsだけでは独自表示できず、常時秒ポーリングは負荷が増える。
- 制約：`eventIdentifier`はカレンダー移動で変わり得る。単独で永続的な同一性を保証しない。[Apple：eventIdentifier](https://developer.apple.com/documentation/eventkit/ekevent/eventidentifier)
- 検証：期間検索の繰り返し各回、例外回の移動、シリーズ編集、カレンダー移動、アカウント再同期で回キーを確認する。EventKitの取得結果は明示ソートする。[Apple：TN3130](https://developer.apple.com/documentation/technotes/tn3130-changes-to-eventkit-in-macos13-ventura)
- トレードオフ：変更後も同一回を追える範囲ではDismissを維持する。識別子の全面置換やクラッシュ直前では完全な一度限りの保証はできない。類似タイトルの誤統合で必要な通知を失わないことを優先する。
- 最小実装（2026-10-20）：回キーはカレンダー識別子＋eventIdentifier＋繰り返しのoccurrenceDate（単発はnil）。単発の開始時刻変更は識別子が同じ間は同一回として扱い、繰り返し例外は元日時で区別する。初回観測日時の対応表は追加しない。occurrenceDateの意味は[Apple公式資料](https://developer.apple.com/documentation/eventkit/ekevent/occurrencedate)とSDKヘッダーで再確認した。識別子・元日時が変わるシリーズ編集やカレンダー移動は未検証で、再表示防止の保証対象を広げない。
- 時刻・ライフサイクル（確認日：2026-10-20）：時計変更は[NSSystemClockDidChange](https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/nssystemclockdidchange)、画面スリープは[screensDidSleepNotification](https://developer.apple.com/documentation/appkit/nsworkspace/screensdidsleepnotification)を契機とする。これらはロック状態の完全な判定手段ではない。固定時刻での通知判定・停止・再評価はXCTest、OSの表示・権限は実機で別に確認する。
- レビュー後の判断（2026-10-20）：[screensDidWakeNotification](https://developer.apple.com/documentation/appkit/nsworkspace/screensdidwakenotification)と[sessionDidBecomeActiveNotification](https://developer.apple.com/documentation/appkit/nsworkspace/sessiondidbecomeactivenotification)は独立した復帰契機であり、画面復帰だけでセッションの停止理由を解除しない。履歴の書き込み失敗は再試行し、起動時の削除もディスクへ反映する。破損バックアップは最大1件・発見後7日までとする。
- 保留：Dismiss後に現在＋48時間より先へ移動した回は、再取得前に最後に観測した終了＋7日の期限を迎えると履歴を失う。無期限保存は保持方針と矛盾し、全件取得は負荷を増やすため採用しない。対象指定取得の検証は配布前の課題とし、個人利用では再通知時に再Dismissする運用で扱う。REL-02は未合格の範囲を残す。

- 取得欠落への対応（確認日：2026-10-21）：繰り返し・例外回の`occurrenceDate`がnilでも予定を除外せず、取得した開始日時を回キーの代替値にする。元日時がある場合はそちらを優先する。代替値を使う回は開始日時の変更後に再通知される可能性がある。[Apple：occurrenceDate](https://developer.apple.com/documentation/eventkit/ekevent/occurrencedate)は元日時の意味を示すが、代替値の選択はアプリの実装方針である。

## ADR-05：設定・ログイン起動・プライバシー

- 状態：採用。
- 判断：設定はUserDefaults、処理済み台帳はApplication SupportのJSON。ログイン起動は`SMAppService.mainApp`の登録・解除を使い、statusを表示する。
- 根拠：SMAppServiceはmacOS 13以降の仕組みで、登録は利用者の承認に従う。[Apple：SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- 実装確認（2026-10-21）：SDKの`SMAppService.h`と[mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp)、[register()](https://developer.apple.com/documentation/servicemanagement/smappservice/register())、[unregister()](https://developer.apple.com/documentation/servicemanagement/smappservice/unregister())、[openSystemSettingsLoginItems()](https://developer.apple.com/documentation/servicemanagement/smappservice/opensystemsettingsloginitems())を確認。mainAppの解除は現在のアプリを終了させず、次回ログインの起動を解除する。実登録・実ログインは未確認。
- 実装方針：登録状態はOSを正とし、起動時や承認待ちで自動登録しない。解除の完了まで新しい変更を受け付けず、失敗時もstatusを再取得する。デモの操作は無効にする。
- 代替：独自LaunchAgent、特権ヘルパー、外部DBは不要。Boolean設定だけで登録成功を推定しない。
- トレードオフ：OS設定で無効化され得る。自動起動は利用者のログイン時であり、OS起動直後や終了後の常時復活を意味しない。Joinを除く独自通信は不要とし、OSのカレンダー同期は制御対象外とする。

## ADR-06：ビルドとテスト

- 状態：採用方針。
- 判断：XcodeのmacOSアプリターゲットを主体にする。XCTestで純粋ロジックと永続化を検証し、OS表示挙動は実機で補う。SPMは必要時のみ追加。
- 代替：Swift Testingも候補だが、初期はUIテストと同じツール群のXCTestへ統一。SPM単独ではアプリ署名・entitlements・配布を別途管理する必要がある。
- トレードオフ：Xcode版の固定とmacOS実機が必要。コードカバレッジ率の数値だけを合格基準にせず、境界条件と要件IDの検証を優先する。
- P0の開発基準（2026-10-19）：Xcode 27.1（27A9275）、同梱Swift 6.4、macOS SDK 27.0。`.xcode-version`でXcode版を記録し、同梱`swift-format`を整形・スタイル確認に使用する（設定は`.swift-format`）。外部リンターは導入しない。Deployment Targetは14.0の暫定値。Ad Hoc署名でビルド可能だが、Apple Development署名での権限検証は別途必要。

## 実装前に確定する事項

| 項目 | 暫定方針 | 決定期限 |
| --- | --- | --- |
| OS・Xcode・Swift版 | macOS 14以上、使用SDKでAPI可用性を確認 | P0終了 |
| オーバーレイとフォーカス | NSPanel、画面ごと表示、過剰な再アクティブ化なし | P0終了 |
| 回キーと保持期限 | 識別子＋元回日時、終了後7日 | P0終了 |
| 会議URLのホスト・パス | 4サービスのHTTPS、短縮URL展開なし | P0終了 |
| 配布とSandbox | Developer ID＋公証を初期候補、Sandbox有効を検証 | P0終了 |
| 正式名称・Bundle ID・署名チーム | 未決定 | P1着手前 |
| 性能予算・試験機 | NFR-03の暫定値を実測で見直す | P0終了 |

配布方式の決定時に公証・Sandbox・Login Itemの要件を公式資料と署名済み試作で再確認します。現時点ではMac App Storeでの承認や配布可能性を保証しません。

## ADR-07：会議URLの抽出とJoin

- 状態：初期実装で採用。対応形式は[アーキテクチャ](architecture.md#url抽出の現在の対応範囲)に固定し、実予定の各サービス形式との照合は未確認。
- 判断：副作用なしの`MeetingURLExtractor`でホストとパスを検証し、候補をメモリ内のSnapshotへ変換する。抽出時の通信・短縮URL展開は行わない。
- Joinの成功はOSによるオープン要求の受理とする。同期Bool APIを使い、falseなら履歴を更新せず再試行可能にする。trueなら既存の履歴保存と再表示抑止を使用する。
- Apple公式資料：[NSWorkspace.open(_:)](https://developer.apple.com/documentation/appkit/nsworkspace/open(_:))。確認日：2026-10-21。SDKでビルドし、失敗・再試行・成功時の処理を差し替えたオープン関数で検証する。実ブラウザーへの引き渡しは未確認。
- レビュー反映（2026-10-21）：URL型入力の原文保持、Webexのパスの完全一致、制御文字の拒否、候補番号による区別を採用。クエリ値は表示しない。デモは外部オープンを模擬する。
- 制限：完全なHTMLパーサーや任意の会議サービスへの対応ではない。TeamsのラッパーURL、リダイレクト形式、表外のパスは検出しない。対応表は実サンプル検証後に拡張する。
