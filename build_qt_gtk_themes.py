#!/usr/bin/env python3
"""Build Kvantum and GTK themes from design-tokens.json.

Usage: python build_qt_gtk_themes.py design-tokens.json KVANTUM_SRC OUT_DIR
  KVANTUM_SRC = Kvantum/Kvantum/themes/kvthemes (clone of github.com/tsujan/Kvantum)

Kvantum: recolors KvFlat (dark) and KvFlatLight (light) by remapping their
grays through anchor points and their blues to the accent. The result is a
GPL-3 derivative of KvFlat (upstream license) and must stay GPL-3.
GTK: libadwaita-style named-color overrides (gtk-3.0/gtk.css, gtk-4.0/gtk.css).
Output is NOT visually verified: no Plasma/GTK session was available."""
import colorsys, json, os, re, sys

def h2rgb(h):
    h = h.lstrip('#')
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]

def rgb2h(c):
    return '#%02x%02x%02x' % tuple(max(0, min(255, round(x))) for x in c)

def lum(c):
    return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255

def ramp(anchors, t):
    pts = sorted(anchors)
    if t <= pts[0][0]:
        return h2rgb(pts[0][1])
    for (t0, c0), (t1, c1) in zip(pts, pts[1:]):
        if t <= t1:
            f = (t - t0) / (t1 - t0) if t1 > t0 else 0
            a, b = h2rgb(c0), h2rgb(c1)
            return [x + (y - x) * f for x, y in zip(a, b)]
    return h2rgb(pts[-1][1])

def anchors_for(theme, c):
    if theme == 'dark':
        return [(0.0, '#000000'), (0.09, '#06080C'), (0.18, c['bg']), (0.24, c['surface']),
                (0.33, c['surface-raised']), (0.38, c['border']), (0.45, '#3A455C'),
                (0.80, c['text-dim']), (1.0, c['text'])]
    return [(0.0, c['text']), (0.35, c['text-dim']), (0.70, c['border']),
            (0.85, c['surface-raised']), (0.94, c['bg']), (1.0, c['surface'])]

def recolor(text, theme, c):
    acc = h2rgb(c['accent'])
    anchors = anchors_for(theme, c)
    def sub(m):
        rgb = h2rgb(m.group(0))
        r, g, b = [x / 255 for x in rgb]
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        if s < 0.12:                       # gray -> ramp
            return rgb2h(ramp(anchors, lum(rgb)))
        if 0.5 < h < 0.7 and s > 0.3:      # blue family -> accent shades
            k = v if theme == 'dark' else 1.0
            return rgb2h([x * min(1, 0.45 + 0.65 * k) for x in acc]) if lum(rgb) < 0.55 else c['accent']
        return m.group(0)                  # reds/greens etc. untouched
    return re.sub(r'#[0-9a-fA-F]{6}\b', sub, text)

def kvantum(tokens, src, out):
    for theme, srcname, name in (('dark', 'KvFlat', 'WorkingTitleDark'),
                                 ('light', 'KvFlatLight', 'WorkingTitleLight')):
        c = tokens['color'][theme]
        d = os.path.join(src, srcname)
        if not os.path.isdir(d):
            print('missing', d); continue
        cfg = open(os.path.join(d, srcname + '.kvconfig'), encoding='utf-8').read()
        svg = open(os.path.join(d, srcname + '.svg'), encoding='utf-8').read()
        cfg = recolor(cfg, theme, c)
        svg = recolor(svg, theme, c)
        cfg = re.sub(r'(?m)^comment=.*$', f'comment=Derived from {srcname} (GPL-3) with design tokens', cfg)
        gc = {
            'window.color': c['surface'], 'base.color': c['bg'] if theme == 'dark' else c['surface'],
            'alt.base.color': c['surface'] if theme == 'dark' else c['bg'],
            'button.color': c['surface-raised'], 'highlight.color': c['accent'],
            'inactive.highlight.color': c['border'], 'text.color': c['text'],
            'window.text.color': c['text'], 'button.text.color': c['text'],
            'highlight.text.color': c['on-accent'], 'link.color': c['accent'],
            'disabled.text.color': c['text-dim'],
        }
        for k, v in gc.items():
            cfg, n = re.subn(rf'(?m)^{re.escape(k)}=.*$', f'{k}={v}', cfg, count=1)
            if n == 0:
                cfg = cfg.replace('[GeneralColors]\n', f'[GeneralColors]\n{k}={v}\n', 1)
        od = os.path.join(out, 'Kvantum', name)
        os.makedirs(od, exist_ok=True)
        open(os.path.join(od, name + '.kvconfig'), 'w', encoding='utf-8', newline='\n').write(cfg)
        open(os.path.join(od, name + '.svg'), 'w', encoding='utf-8', newline='\n').write(svg)
        print('wrote', od)

def gtk(tokens, out):
    for theme, name in (('dark', 'WorkingTitleDark'), ('light', 'WorkingTitleLight')):
        c = tokens['color'][theme]
        defs = {
            'accent_color': c['accent'], 'accent_bg_color': c['accent'], 'accent_fg_color': c['on-accent'],
            'destructive_color': c['danger'], 'destructive_bg_color': c['danger'], 'destructive_fg_color': c['bg'] if theme == 'dark' else '#FFFFFF',
            'success_color': c['success'], 'success_bg_color': c['success'], 'success_fg_color': c['bg'] if theme == 'dark' else '#FFFFFF',
            'warning_color': c['warning'], 'warning_bg_color': c['warning'], 'warning_fg_color': c['bg'] if theme == 'dark' else '#FFFFFF',
            'error_color': c['danger'], 'error_bg_color': c['danger'], 'error_fg_color': c['bg'] if theme == 'dark' else '#FFFFFF',
            'window_bg_color': c['surface'], 'window_fg_color': c['text'],
            'view_bg_color': c['bg'] if theme == 'dark' else c['surface'], 'view_fg_color': c['text'],
            'headerbar_bg_color': c['bg'] if theme == 'dark' else c['surface-raised'], 'headerbar_fg_color': c['text'],
            'headerbar_border_color': c['border'], 'headerbar_backdrop_color': c['surface'],
            'sidebar_bg_color': c['bg'] if theme == 'dark' else c['bg'], 'sidebar_fg_color': c['text'],
            'sidebar_backdrop_color': c['surface'], 'sidebar_border_color': c['border'],
            'card_bg_color': c['surface-raised'], 'card_fg_color': c['text'],
            'dialog_bg_color': c['surface'], 'dialog_fg_color': c['text'],
            'popover_bg_color': c['surface-raised'], 'popover_fg_color': c['text'],
            'shade_color': 'rgba(0,0,0,0.36)', 'scrollbar_outline_color': c['border'],
        }
        body = '/* Generated from design-tokens.json. Works with libadwaita (GTK4) and Adwaita (GTK3.24+). */\n'
        body += ''.join(f'@define-color {k} {v};\n' for k, v in defs.items())
        body += '\n/* Sharp look: small radii (token radius.md = 4px) */\n'
        body += 'button, entry, .card, popover > contents, window.dialog { border-radius: 4px; }\n'
        for g in ('gtk-3.0', 'gtk-4.0'):
            d = os.path.join(out, 'gtk', name, g)
            os.makedirs(d, exist_ok=True)
            open(os.path.join(d, 'gtk.css'), 'w', encoding='utf-8', newline='\n').write(body)
        print('wrote', os.path.join(out, 'gtk', name))

if __name__ == '__main__':
    tokens = json.load(open(sys.argv[1], encoding='utf-8'))
    kvantum(tokens, sys.argv[2], sys.argv[3])
    gtk(tokens, sys.argv[3])
