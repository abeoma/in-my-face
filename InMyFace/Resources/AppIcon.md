# アプリアイコン

`AppIcon.png`は組み込みのimage_genで生成した元画像です。`scripts/generate-app-icon.sh`で16〜1024pxのPNGを含む`AppIcon.icns`を作成し、アプリのリソースとして組み込みます。メニューバーは既存のSF Symbolを使います。

生成プロンプト：

> Use case: logo-brand. Create one polished macOS application icon for In My Face, a meeting reminder app that gets your attention. A bold friendly sculpted ivory notification bell with a small coral-red exclamation badge, centered on a deep midnight indigo rounded-square tile. Contemporary native Mac icon, subtle dimensional material and soft studio lighting, restrained depth, crisp silhouette readable at 32px. Straight-on orthographic view. Single icon only, square 1024x1024 canvas. Tile occupies about 85% of canvas with even padding, transparent outside the rounded tile. No lettering, no wordmark, no mockup, no extra decorative objects, no watermark.

`CFBundleIconFile`でICNSを指定します。[Apple公式資料](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleiconfile)を2026-10-21に確認しています。
