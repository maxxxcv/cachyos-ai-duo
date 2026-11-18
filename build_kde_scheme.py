#!/usr/bin/env python3
"""Generate KDE color schemes (.colors) from design-tokens.json.
Usage: python build_kde_scheme.py design-tokens.json out_dir
Output goes to ~/.local/share/color-schemes/ on Linux."""
import json, os, sys

def rgb(h):
    return ",".join(str(int(h[i:i + 2], 16)) for i in (1, 3, 5))

def mix(a, b, t):
    ca = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    cb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return ",".join(str(round(x * (1 - t) + y * t)) for x, y in zip(ca, cb))

def group(name, c, bg, alt, fg):
    return f"""[Colors:{name}]
BackgroundNormal={rgb(bg)}
BackgroundAlternate={rgb(alt)}
ForegroundNormal={rgb(fg)}
ForegroundInactive={rgb(c['text-dim'])}
ForegroundActive={rgb(c['accent'])}
ForegroundLink={rgb(c['accent'])}
ForegroundVisited={mix(c['accent'], c['text-dim'], .5)}
ForegroundNegative={rgb(c['danger'])}
ForegroundNeutral={rgb(c['warning'])}
ForegroundPositive={rgb(c['success'])}
DecorationFocus={rgb(c['accent'])}
DecorationHover={rgb(c['accent'])}
"""

def scheme(label, c, light):
    sel_bg = c['accent']; sel_fg = c['on-accent']
    out = group('Window', c, c['bg'], c['surface'], c['text'])
    out += "\n" + group('View', c, c['surface'], c['surface-raised'], c['text'])
    out += "\n" + group('Button', c, c['surface-raised'], c['surface'], c['text'])
    out += "\n" + group('Tooltip', c, c['surface-raised'], c['surface'], c['text'])
    out += "\n" + group('Complementary', c, c['bg'], c['surface'], c['text'])
    out += "\n" + group('Header', c, c['surface'], c['bg'], c['text'])
    sel = group('Selection', c, sel_bg, sel_bg, sel_fg)
    sel = sel.replace(f"ForegroundInactive={rgb(c['text-dim'])}", f"ForegroundInactive={rgb(sel_fg)}")
    sel = sel.replace(f"ForegroundActive={rgb(c['accent'])}", f"ForegroundActive={rgb(sel_fg)}")
    sel = sel.replace(f"ForegroundLink={rgb(c['accent'])}", f"ForegroundLink={rgb(sel_fg)}")
    sel = sel.replace(f"DecorationFocus={rgb(c['accent'])}", f"DecorationFocus={rgb(c['text'])}")
    out += "\n" + sel
    out += f"""
[ColorEffects:Disabled]
Color={rgb(c['text-dim'])}
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color={rgb(c['text-dim'])}
ColorAmount=0.025
ColorEffect=2
ContrastAmount=0.1
ContrastEffect=2
Enable=false
IntensityAmount=0
IntensityEffect=0

[General]
ColorScheme={label.replace(' ', '')}
Name={label}
shadeSortColumn=true

[KDE]
contrast=4

[WM]
activeBackground={rgb(c['surface'])}
activeBlend={rgb(c['text'])}
activeForeground={rgb(c['text'])}
inactiveBackground={rgb(c['bg'])}
inactiveBlend={rgb(c['text-dim'])}
inactiveForeground={rgb(c['text-dim'])}
"""
    return out

def main():
    tokens = json.load(open(sys.argv[1], encoding='utf-8'))
    outdir = sys.argv[2]
    os.makedirs(outdir, exist_ok=True)
    for theme, label in (('dark', 'WorkingTitle Dark'), ('light', 'WorkingTitle Light')):
        path = os.path.join(outdir, label.replace(' ', '') + '.colors')
        with open(path, 'w', encoding='utf-8', newline='\n') as f:
            f.write(scheme(label, tokens['color'][theme], theme == 'light'))
        print('wrote', path)

if __name__ == '__main__':
    main()
