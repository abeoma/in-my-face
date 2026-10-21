"""実アプリ・HOME・OS設定に触れず、配置スクリプトのファイル操作を検証する。"""
import pathlib
import plistlib
import subprocess
import tempfile
import unittest


class InstallLocalTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="inmyface-install-test-")
        self.addCleanup(temporary.cleanup)
        self.base = pathlib.Path(temporary.name)
        self.repo = self.base / "repo"
        (self.repo / "scripts").mkdir(parents=True)
        self.apps = self.base / "Applications"
        self.installed = self.apps / "InMyFace.app"
        (self.installed / "Contents").mkdir(parents=True)
        (self.installed / "Contents/Info.plist").write_bytes(
            plistlib.dumps({"CFBundleIdentifier": "com.abeoma.inmyface"})
        )
        (self.installed / "original").write_text("original app")
        (self.base / "other.plist").write_bytes(
            plistlib.dumps({"CFBundleIdentifier": "com.example.other"})
        )

    def run_scenario(self, scenario):
        source_path = pathlib.Path(__file__).resolve().parents[2] / "scripts/install-local.sh"
        source = source_path.read_text().replace(
            'app_dir="$HOME/Applications"', f'app_dir="{self.apps}"'
        )
        # 実ビルド・署名・プロセス確認を置換し、ファイル操作は一時領域で実行する。
        for original, replacement in [
            ("/usr/bin/xcodebuild", "fake_xcodebuild"),
            ("/usr/bin/codesign", "fake_codesign"),
            ("/usr/bin/pgrep", "fake_pgrep"),
            ("/usr/bin/ditto", "/bin/cp -R"),
        ]:
            source = source.replace(original, replacement)
        build_change = ""
        if scenario == "replacement":
            build_change = f'''
    /bin/cp "{self.base}/other.plist" "$installed_app/Contents/Info.plist"
    /bin/echo unrelated > "$installed_app/unrelated"
'''
        elif scenario == "symlink":
            build_change = f'''
    /bin/mv "$installed_app" "{self.base}/outside.app"
    /bin/ln -s "{self.base}/outside.app" "$installed_app"
'''
        mocks = '''
fake_pgrep() { return 1; }
fake_codesign() { return 0; }
fake_xcodebuild() {
    built="$repo_dir/.build/InMyFace/Build/Products/Release/InMyFace.app"
    /bin/mkdir -p "$built/Contents"
    /bin/cp "$installed_app/Contents/Info.plist" "$built/Contents/Info.plist"
    /bin/echo new > "$built/new"
''' + build_change + "\n}\n"
        if scenario == "signature-failure":
            mocks += '''
fake_codesign() {
    if [ "${!#}" = "$installed_app" ]; then return 1; fi
    return 0
}
'''
        if scenario in ("promotion-failure", "occupied-failure"):
            occupant = (
                '/bin/mkdir "$installed_app"\n'
                '/bin/echo unrelated > "$installed_app/occupant"'
                if scenario == "occupied-failure" else ":"
            )
            mocks += '''
mv() {
    if [ "$1" = "$staging_dir/InMyFace.app" ]; then
''' + occupant + '''
        return 1
    fi
    /bin/mv "$@"
}
'''
        script = self.repo / "scripts/install-local.sh"
        script.write_text(source.replace("set -euo pipefail", "set -euo pipefail\n" + mocks))
        return subprocess.run(["/bin/bash", str(script)], capture_output=True, text=True)

    def test_success_replaces_bundle_and_removes_temporary_backup(self):
        result = self.run_scenario("success")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.installed / "new").exists())
        self.assertFalse((self.installed / "original").exists())
        self.assertEqual(list(self.apps.glob(".InMyFace-install.*")), [])

    def test_different_bundle_created_during_build_is_preserved(self):
        result = self.run_scenario("replacement")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.installed / "unrelated").exists())
        self.assertFalse((self.installed / "new").exists())
        self.assertIn("別のアプリ", result.stderr)

    def test_symlink_created_during_build_is_preserved(self):
        result = self.run_scenario("symlink")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.installed.is_symlink())
        self.assertTrue((self.base / "outside.app/original").exists())
        self.assertIn("シンボリックリンク", result.stderr)

    def test_failed_promotion_restores_old_bundle(self):
        result = self.run_scenario("promotion-failure")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.installed / "original").exists())
        self.assertEqual(list(self.apps.glob(".InMyFace-install.*")), [])

    def test_occupied_restore_path_preserves_old_bundle_and_new_occupant(self):
        result = self.run_scenario("occupied-failure")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.installed / "occupant").exists())
        backups = list(self.apps.glob(".InMyFace-install.*/previous.app"))
        self.assertEqual(len(backups), 1)
        self.assertTrue((backups[0] / "original").exists())
        self.assertIn(str(backups[0]), result.stderr)

    def test_final_signature_failure_preserves_backup_for_manual_recovery(self):
        result = self.run_scenario("signature-failure")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.installed / "new").exists())
        backups = list(self.apps.glob(".InMyFace-install.*/previous.app"))
        self.assertEqual(len(backups), 1)
        self.assertTrue((backups[0] / "original").exists())
        self.assertIn(str(backups[0]), result.stderr)


if __name__ == "__main__":
    unittest.main()
