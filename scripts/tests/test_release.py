"""Exercise release failure gates without signing or uploading software.

Run on macOS: python3 -m unittest discover -s scripts/tests -v
"""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]

# Only external services/build tools are mocked. Bash, PlistBuddy, ditto, checksum
# generation, and the release script itself run normally in a temporary project.
MOCK = r'''
import os, pathlib, plistlib, shutil, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
mode = os.environ.get('TEST_FAILURE', '')
with open('calls.txt', 'a') as f:
    f.write(name + ' ' + ' '.join(args) + '\n')
if name == 'security':
    print('1) ABC "' + os.environ['SIGNING_IDENTITY'] + '"')
elif name == 'git':
    if args[0] == 'status' and mode == 'dirty': print(' M source.swift')
    if args[0] == 'rev-parse': print('123456789abcdef')
elif name == 'xcodebuild':
    if '-version' in args:
        print('Xcode fixture'); sys.exit(0)
    if '-exportArchive' in args:
        if mode == 'export': sys.exit(1)
        source = pathlib.Path(args[args.index('-archivePath') + 1]) / 'Products/Applications/SF Cymbal.app'
        target = pathlib.Path(args[args.index('-exportPath') + 1]) / 'SF Cymbal.app'
        shutil.copytree(source, target)
        sys.exit(0)
    if mode == 'build': sys.exit(1)
    tools = pathlib.Path(args[args.index('-derivedDataPath') + 1]) / 'SourcePackages/artifacts/sparkle/Sparkle/bin'
    tools.mkdir(parents=True)
    for tool in ['generate_keys', 'generate_appcast', 'sign_update']:
        (tools / tool).symlink_to(pathlib.Path(sys.argv[0]).resolve())
    app = pathlib.Path(args[args.index('-archivePath') + 1]) / 'Products/Applications/SF Cymbal.app/Contents'
    (app / 'MacOS').mkdir(parents=True)
    (app / 'MacOS/SF Cymbal').write_text('/Users/private-builder/source.swift' if mode == 'privacy' else 'fixture')
    with (app / 'Info.plist').open('wb') as f:
        plistlib.dump({'CFBundleShortVersionString': '2026.1', 'CFBundleVersion': '1',
                      'CFBundleIdentifier': 'io.deadpan.SFCymbal', 'SUPublicEDKey': 'fixture-public-key'}, f)
elif name == 'generate_keys':
    print('wrong-key' if mode == 'key' else 'fixture-public-key')
elif name == 'generate_appcast':
    if mode == 'appcast': sys.exit(1)
    prefix = args[args.index('--download-url-prefix') + 1]
    pathlib.Path(args[args.index('-o') + 1]).write_text(
        '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item>'
        '<enclosure sparkle:edSignature="fixture-signature" url="' + prefix + 'SF-Cymbal-2026.1.zip"/>'
        '</item></channel></rss>')
elif name == 'sign_update' and mode == 'signature': sys.exit(1)
elif name == 'codesign' and '--entitlements' in args:
    plistlib.dump({'com.apple.security.app-sandbox': mode != 'sandbox',
                  'com.apple.security.files.user-selected.read-write': True,
                  'com.apple.security.temporary-exception.mach-lookup.global-name': ['io.deadpan.SFCymbal-spks', 'io.deadpan.SFCymbal-spki'],
                  'com.apple.security.get-task-allow': mode == 'debugger'}, sys.stdout.buffer)
elif name == 'codesign' and '-d' in args:
    print('Authority=' + os.environ['SIGNING_IDENTITY'] + '\nflags=0x10000(runtime)\nTimestamp=fixture', file=sys.stderr)
elif name == 'spctl' and mode == 'gatekeeper': sys.exit(1)
elif name == 'xcrun':
    if args[0] == 'lipo' and mode == 'architecture': sys.exit(1)
    if args[0] == 'notarytool' and args[1] == 'submit':
        # notarytool can successfully return a response that rejects the app.
        plistlib.dump({'id': 'fixture-id', 'status': 'Invalid' if mode == 'notary' else 'Accepted'}, sys.stdout.buffer)
    if args[:2] == ['stapler', 'staple']:
        if mode == 'staple': sys.exit(1)
        (pathlib.Path(args[2]) / 'Contents/ticket').write_text('stapled')
'''


@unittest.skipUnless(sys.platform == 'darwin', 'Requires macOS PlistBuddy and ditto')
class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='SF Cymbal release tests ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'scripts').mkdir()
        shutil.copy2(ROOT / 'scripts/release.sh', self.root / 'scripts/release.sh')
        shutil.copy2(ROOT / 'scripts/check_release_privacy.py', self.root / 'scripts/check_release_privacy.py')
        project = self.root / 'SF Cymbal.xcodeproj'
        project.mkdir()
        with (project / 'project.pbxproj').open('wb') as f:
            plistlib.dump({'objects': {'000000000000000112000000': {'buildSettings': {
                'MARKETING_VERSION': '2026.1', 'CURRENT_PROJECT_VERSION': '1',
                'DEVELOPMENT_TEAM': 'TESTTEAM01', 'PRODUCT_BUNDLE_IDENTIFIER': 'io.deadpan.SFCymbal'
            }}}}, f)
        bin_dir = self.root / 'bin'
        bin_dir.mkdir()
        mock = bin_dir / 'mock'
        mock.write_text('#!' + sys.executable + '\n' + MOCK)
        mock.chmod(0o755)
        for name in ['security', 'git', 'xcodebuild', 'codesign', 'spctl', 'xcrun']:
            (bin_dir / name).symlink_to(mock)
        self.env = dict(os.environ, PATH=str(bin_dir) + ':' + os.environ['PATH'],
                        SIGNING_IDENTITY='Developer ID Application: Fixture (TESTTEAM01)',
                        NOTARY_PROFILE='fixture', RELEASE_ROOT=str(self.root / 'release output'))

    def run_release(self, *args, failure=''):
        return subprocess.run(['bash', str(self.root / 'scripts/release.sh'), *args],
                              env=dict(self.env, TEST_FAILURE=failure), capture_output=True, text=True)

    def artifacts(self):
        return list(self.root.glob('release output/*/SF-Cymbal-2026.1.zip'))

    def test_success_packages_stapled_app_and_checksum(self):
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        artifact, = self.artifacts()
        with zipfile.ZipFile(artifact) as z:
            self.assertEqual(z.read('SF Cymbal.app/Contents/ticket'), b'stapled')
        result = subprocess.run(['shasum', '-a', '256', '-c', artifact.name + '.sha256'],
                                cwd=artifact.parent, capture_output=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn('123456789abcdef', (artifact.parent / 'release.txt').read_text())

    def test_check_does_not_build_or_submit(self):
        result = self.run_release('--check')
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = (self.root / 'calls.txt').read_text()
        self.assertNotIn('xcodebuild', calls)
        self.assertNotIn('notarytool submit', calls)
        self.assertFalse(self.artifacts())

    def test_failures_never_produce_download(self):
        for failure in ['dirty', 'build', 'privacy', 'export', 'key', 'architecture', 'sandbox', 'debugger', 'notary', 'staple', 'gatekeeper']:
            with self.subTest(failure=failure):
                result = self.run_release(failure=failure)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertFalse(self.artifacts())

    def test_appcast_failure_does_not_mark_release_ready(self):
        for failure in ['appcast', 'signature']:
            with self.subTest(failure=failure):
                result = self.run_release(failure=failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('Release ready:', result.stdout)
                self.assertFalse(list(self.root.glob('release output/*/release.txt')))

    def test_development_certificate_rejected(self):
        self.env['SIGNING_IDENTITY'] = 'Apple Development: Fixture (TESTTEAM01)'
        result = self.run_release('--check')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Developer ID Application certificate is required', result.stderr)


if __name__ == '__main__':
    unittest.main()
