# 技術判断（ADR）

確認日：2026-10-15。Apple公式資料で確認できたAPIの意味と、本プロジェクトの採用方針を区別します。製品のOS連携の実機検証は未実施です。「採用」は設計上の判断であり、実装完了を意味しません。

2026-10-19追記：EventKit検証アプリのビルド・初期画面を確認しました。[検証記録](validation/eventkit-probe.md)を参照してください。権限許可後の取得やOS連携の実機検証は未実施です。

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

## ADR-05：設定・ログイン起動・プライバシー

- 状態：採用。
- 判断：設定はUserDefaults、処理済み台帳はApplication SupportのJSON。ログイン起動は`SMAppService.mainApp`の登録・解除を使い、statusを表示する。
- 根拠：SMAppServiceはmacOS 13以降の仕組みで、登録は利用者の承認に従う。[Apple：SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
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
