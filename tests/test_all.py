"""Structure and contrast checks for the theme set.
Run: python -m unittest discover -s tests -v
These tests do NOT prove the themes look right in Plasma/GTK/SDDM/Plymouth; they catch broken files."""
import configparser, glob, json, os, re, subprocess, sys, tempfile, unittest
import xml.dom.minidom as minidom

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def p(*a):
    return os.path.join(ROOT, *a)


TOK = json.load(open(p('design-tokens.json'), encoding='utf-8'))


def read(*a):
    return open(p(*a), encoding='utf-8').read()


def lum(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    c = [x / 12.92 if x <= .03928 else ((x + .055) / 1.055) ** 2.4 for x in c]
    return .2126 * c[0] + .7152 * c[1] + .0722 * c[2]


def ratio(a, b):
    x, y = sorted([lum(a), lum(b)], reverse=True)
    return (x + .05) / (y + .05)


class Tokens(unittest.TestCase):
    def test_same_keys_in_both_themes(self):
        self.assertEqual(set(TOK['color']['dark']), set(TOK['color']['light']))

    def test_text_contrast_aa(self):
        pairs = [('text', 'bg'), ('text', 'surface'), ('text-dim', 'bg'), ('text-dim', 'surface-raised'),
                 ('accent', 'bg'), ('accent', 'surface'), ('on-accent', 'accent'),
                 ('success', 'surface'), ('warning', 'surface'), ('danger', 'surface')]
        for theme, c in TOK['color'].items():
            for fg, bg in pairs:
                with self.subTest(theme=theme, fg=fg, bg=bg):
                    self.assertGreaterEqual(ratio(c[fg], c[bg]), 4.5)

    def test_css_matches_json(self):
        css = read('design-tokens.css')
        for k, v in TOK['color']['dark'].items():
            self.assertIn('--%s: %s;' % (k, v), css)


class KdeScheme(unittest.TestCase):
    def test_schemes(self):
        files = glob.glob(p('kde', '*.colors'))
        self.assertEqual(len(files), 2)
        for f in files:
            c = configparser.RawConfigParser()
            c.optionxform = str
            c.read(f, encoding='utf-8')
            for s in ['Colors:Window', 'Colors:View', 'Colors:Button', 'Colors:Selection', 'General', 'WM']:
                self.assertIn(s, c.sections(), f)
            for s in c.sections():
                for k, v in c[s].items():
                    if k.startswith(('Background', 'Foreground', 'Decoration')):
                        parts = v.split(',')
                        self.assertEqual(len(parts), 3, (f, s, k))
                        self.assertTrue(all(0 <= int(x) <= 255 for x in parts), (f, s, k))


class Kvantum(unittest.TestCase):
    def test_files(self):
        dirs = glob.glob(p('themes', 'Kvantum', '*'))
        self.assertEqual(len(dirs), 2)
        for d in dirs:
            n = os.path.basename(d)
            minidom.parse(os.path.join(d, n + '.svg'))
            c = configparser.RawConfigParser(strict=False)
            c.optionxform = str
            c.read(os.path.join(d, n + '.kvconfig'), encoding='utf-8')
            self.assertIn('GeneralColors', c.sections())
            self.assertRegex(c['GeneralColors']['highlight.color'], r'^#[0-9A-Fa-f]{6}$')


class Gtk(unittest.TestCase):
    def test_css(self):
        files = glob.glob(p('themes', 'gtk', '*', 'gtk-*', 'gtk.css'))
        self.assertEqual(len(files), 4)
        for f in files:
            t = open(f, encoding='utf-8').read()
            self.assertEqual(t.count('{'), t.count('}'), f)
            for k in ['window_bg_color', 'window_fg_color', 'accent_bg_color', 'accent_fg_color', 'headerbar_bg_color']:
                self.assertIn('@define-color ' + k + ' ', t, f)


class LoginAndBoot(unittest.TestCase):
    def test_sddm(self):
        d = p('themes', 'sddm', 'WorkingTitle')
        q = open(os.path.join(d, 'Main.qml'), encoding='utf-8').read()
        self.assertEqual(q.count('{'), q.count('}'))
        self.assertNotIn('SddmComponents', q)
        meta = open(os.path.join(d, 'metadata.desktop'), encoding='utf-8').read()
        for k in ['MainScript=Main.qml', 'ConfigFile=theme.conf', 'QtVersion=6']:
            self.assertIn(k, meta)
        conf = open(os.path.join(d, 'theme.conf'), encoding='utf-8').read()
        for k in set(re.findall(r'config\.(\w+)', q)):
            self.assertRegex(conf, r'(?m)^%s=' % k)

    def test_plymouth(self):
        d = p('themes', 'plymouth', 'WorkingTitle')
        s = open(os.path.join(d, 'WorkingTitle.script'), encoding='utf-8').read()
        for k in ['SetBootProgressFunction', 'SetDisplayPasswordFunction', 'SetMessageFunction']:
            self.assertIn(k, s)
        self.assertEqual(s.count('{'), s.count('}'))
        for f in ['track.png', 'fill.png']:
            self.assertEqual(open(os.path.join(d, f), 'rb').read(8), b'\x89PNG\r\n\x1a\n')


class Generators(unittest.TestCase):
    def test_kde_and_login_are_reproducible(self):
        def norm(path):
            return open(path, 'rb').read().replace(b'\r\n', b'\n')
        with tempfile.TemporaryDirectory() as t:
            subprocess.check_call([sys.executable, '-I', p('build_kde_scheme.py'), p('design-tokens.json'),
                                   os.path.join(t, 'kde')], stdout=subprocess.DEVNULL)
            subprocess.check_call([sys.executable, '-I', p('build_login_boot_themes.py'), p('design-tokens.json'),
                                   os.path.join(t, 'th')], stdout=subprocess.DEVNULL)
            for f in glob.glob(os.path.join(t, 'kde', '*.colors')):
                self.assertEqual(norm(f), norm(p('kde', os.path.basename(f))), f)
            for rel in ['sddm/WorkingTitle/Main.qml', 'sddm/WorkingTitle/theme.conf',
                        'plymouth/WorkingTitle/WorkingTitle.script']:
                self.assertEqual(norm(os.path.join(t, 'th', *rel.split('/'))), norm(p('themes', *rel.split('/'))), rel)


class Scripts(unittest.TestCase):
    def test_firewall_allows_loopback(self):
        self.assertIn('iifname != "lo"', read('twopc', 'setup-pair.sh'))

    def test_ollama_models_listed(self):
        m = [l.strip() for l in open(p('ai', 'models.conf'), encoding='utf-8')
             if l.strip() and not l.startswith('#')]
        self.assertTrue(m)

    def test_firefox_policy(self):
        pol = json.loads(read('desktop', 'firefox-policies.json'))['policies']
        self.assertTrue(pol['DisableTelemetry'])
        self.assertTrue(pol['Preferences']['media.ffmpeg.vaapi.enabled']['Value'])

    def test_install_runs_every_step(self):
        s = read('install.sh')
        for k in ['setup-pair.sh', 'setup-desktop.sh', 'install-themes.sh', 'setup-ai.sh']:
            self.assertIn(k, s)

    def test_profiles_use_listed_models(self):
        models = {l.strip() for l in open(p('ai', 'models.conf'), encoding='utf-8') if l.strip() and not l.startswith('#')}
        for l in open(p('ai', 'profiles.conf'), encoding='utf-8'):
            if l.strip() and not l.startswith('#'):
                name, model, host = l.strip().split('|')
                self.assertIn(model, models, name)

    def test_assistant_installed_by_install_sh(self):
        self.assertIn('setup-assistant.sh', read('install.sh'))

    def test_assistant_uses_native_ollama_api(self):
        s = read('ai', 'setup-assistant.sh')
        self.assertNotIn('11434/v1', s)
        code = [l for l in s.splitlines() if not l.lstrip().startswith(('#', 'echo'))]
        self.assertFalse(any(re.search(r'curl[^|]*\|\s*(ba)?sh', l) for l in code))

    def test_ollama_local_only_by_default(self):
        self.assertIn('OLLAMA_HOST=127.0.0.1:11434', read('ai', 'setup-ai.sh'))


if __name__ == '__main__':
    unittest.main()
