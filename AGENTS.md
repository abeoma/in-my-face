# Repository Guidelines

## 大原則

AGENTS.md自身は、見出し・空行を含めて常に60行以下に保ってください。変更時は行数を確認し、超える場合は内容を整理・統合します。この行数制限は他のドキュメントには適用しません。

## 開発範囲と設計原則

本リポジトリはmacOS向け会議リマインダーの初期実装段階です。アプリは`InMyFace.xcodeproj`、独立したEventKit試作は`Prototypes/EventKitProbe/`にあります。最小実装とMVP全体を区別してください。

小規模なネイティブアプリとして、公開API、ローカル処理、低負荷、通知の正確性を優先します。予定の編集、独自同期、バックエンド、不要な依存ライブラリはMVPに含めません。セキュリティ機構やユーザーの権限設定を回避しないでください。

## 構成と責務

[要件](docs/requirements.md)を振る舞いの基準、[アーキテクチャ](docs/architecture.md)を実装方針の基準とします。将来の配置は`InMyFace/App/`、`Services/`、`Models/`、`Views/`、`Resources/`、`InMyFaceTests/`です。CalendarService、ReminderScheduler、AlertCoordinator、MeetingURLExtractor、SettingsStore、AppLifecycleManagerの責務を分離し、汎用DI基盤などの過剰な抽象化を避けます。

## コーディング規約

実装時はSwiftの標準命名に従い、型を`UpperCamelCase`、関数・プロパティを`lowerCamelCase`、インデントを4スペースとします。UIとウィンドウ操作はMainActorに限定します。EventKitオブジェクトを並行処理間で共有せず、必要な値へ変換します。強制アンラップやエラーの握り潰しを避けてください。Xcodeは`.xcode-version`、整形・静的スタイル確認は同梱の`swift-format`と`.swift-format`を基準にします。個人の署名設定はGit管理外の`Configuration/Signing.local.xcconfig`で扱います。

## テスト方針と確認コマンド

XCTestを使用します。時刻と予定取得を差し替え、復帰・再起動・繰り返し・変更・削除・重複・時差を決定的に検証します。例：`testDismissedOccurrenceDoesNotReappear`。表示の検証は実機マトリクスを併用します。ビルドはREADMEのコマンドを使用し、`InMyFaceTests`をREADMEの`xcodebuild test`で実行し、`swift test`は使用しません。変更後は`git diff --check`、`git status --short`とリンク確認を行います。

## ドキュメント更新と変更レビュー

説明は日本語、API名は英語とします。要件には一意のIDを付け、振る舞いと実装案を区別します。仕様変更は要件・設計・ADR・開発計画へ同時に反映し、未確認事項は未確認と明記します。APIの判断にはApple公式資料のリンクと確認日を残してください。

READMEとdocsには、会話やPRを参照せず理解できるプロダクトの仕様・設計・計画・現在の実装状況を記載します。「今回はドキュメントのみ」「このPRでは実装しない」など、個別の作業依頼・成果物・変更範囲の説明はPR本文に記載してください。作業上の指示はAGENTS.mdで扱い、プロダクト文書へ転記しないでください。

ドキュメント変更のレビューでは、READMEとdocsの差分に会話依存の表現や作業指示が混入していないか確認します。「今回」「このPR」「依頼」などを検索の手掛かりとし、前後の文脈で判断してください。未実装・未検証という事実や、MVPの対象範囲・実装順序は必要な情報として残します。

既存のコミット慣行は未確立です。コミットは変更目的が分かる短い命令形とし、PRには目的、要件ID、検証結果、未検証事項、関連Issueを記載します。UI変更は画像を添えます。レビューでは権限拒否、再表示防止、ユーザーの終了操作、秘密情報や会議情報のログ混入、不要なネットワーク通信を確認してください。
