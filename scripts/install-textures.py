#!/usr/bin/env python3
"""Install the curated HD texture mix (textures/picks.tsv) into a Lambda1VR-PC game folder.

usage: install-textures.py --root DIR [--hlvr DIR] [--resrced DIR] [--bmskies DIR] [--picks FILE] [--force] [--dry-run]

  --hlvr DIR     Half-Life: VR mod textures: <mod>/valve/textures/game (Steam app 1908720)
  --resrced DIR  Half-Life: ReSrced, the folder holding "STEP 4" (or STEP 4 itself)
  --bmskies DIR  BM SKYBOXES: Rework, the unpacked "BM Skyboxes" folder

The pick list names, per game, which pack each world texture, model texture set and sky comes from. A pick whose
pack is not given falls back to the other pack when it has that texture, else the game's original is used.

World textures: <game>/materials/common becomes a folder of links into the packs (nothing is copied).
Model textures: <game>/materials/models/<model> links to ReSrced's folder. Skies: the six faces are copied into
<game>/gfx/env (the engine prefers them over the original .bmp files).

Folders this script made carry a marker file and are rebuilt on every run; a materials/common or materials/models
folder without the marker (made by hand) is left alone unless --force is given (it is then kept as *.bak).
"""
import argparse, os, shutil, sys, time

MARKER = '.lambda1vr-textures'
GAMES = {'valve': 'Half-Life', 'bshift': 'Blue Shift', 'gearbox': 'Opposing Force'}
RESRCED_DIR = {'valve': 'valve', 'bshift': 'blueshift_unlocked', 'gearbox': 'gearbox'}
PACK_NAMES = {'hlvr': 'Half-Life: VR', 'resrced': 'ReSrced', 'bmskies': 'BM skies'}
FACES = ('bk', 'dn', 'ft', 'lf', 'rt', 'up')

ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
ap.add_argument('--root', required=True)
ap.add_argument('--hlvr')
ap.add_argument('--resrced')
ap.add_argument('--bmskies')
ap.add_argument('--picks', default=os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'textures', 'picks.tsv'))
ap.add_argument('--force', action='store_true')
ap.add_argument('--dry-run', action='store_true')
args = ap.parse_args()

packs = {}
if args.hlvr and os.path.isdir(args.hlvr):
    packs['hlvr'] = os.path.abspath(args.hlvr)
if args.resrced:
    step4 = args.resrced if os.path.basename(args.resrced.rstrip('/')) == 'STEP 4' else os.path.join(args.resrced, 'STEP 4')
    if not os.path.isdir(os.path.join(step4, 'valve')):
        sys.exit(f'--resrced: no "STEP 4/valve" in {args.resrced}')
    packs['resrced'] = os.path.abspath(step4)
if args.bmskies and os.path.isdir(args.bmskies):
    packs['bmskies'] = os.path.abspath(args.bmskies)


def index(folder):
    """{UPPER-CASE STEM: file name} of the images in a folder."""
    if not os.path.isdir(folder):
        return {}
    return {os.path.splitext(f)[0].upper(): f for f in os.listdir(folder)
            if f.lower().endswith(('.png', '.tga', '.dds'))}


def fallbacks(game):
    """World-texture folders to try when the picked pack is missing, best first: [(pack, folder, index)]."""
    out = []
    if 'resrced' in packs:
        for d in dict.fromkeys([RESRCED_DIR[game], 'valve']):
            folder = os.path.join(packs['resrced'], d, 'materials/common')
            out.append(('resrced', folder, index(folder)))
    if 'hlvr' in packs:
        out.append(('hlvr', packs['hlvr'], index(packs['hlvr'])))
    return out


def replace_folder(target, links):
    """Swap `target` for a new folder of links {name: source} (with the marker); True when done."""
    if os.path.isdir(target) and not os.path.islink(target) and not os.path.exists(os.path.join(target, MARKER)):
        if not args.force:
            return False
        if not args.dry_run:
            os.rename(target, f'{target}.bak-{time.strftime("%Y%m%d-%H%M")}')
    if args.dry_run:
        return True
    new = target + '.new'
    if os.path.lexists(new):
        shutil.rmtree(new)
    os.makedirs(new)
    open(os.path.join(new, MARKER), 'w').write('made by install-textures.py; rebuilt on every install\n')
    for name, src in sorted(links.items()):
        os.symlink(src, os.path.join(new, name))
    if os.path.islink(target) or os.path.isfile(target):
        os.remove(target)
    elif os.path.isdir(target):
        shutil.rmtree(target)  # only links and the marker: rmtree does not follow links
    os.rename(new, target)
    return True


picks = {}
for line in open(args.picks):
    if line.startswith('#') or not line.strip():
        continue
    game, kind, name, pack, path = line.rstrip('\n').split('\t')
    picks.setdefault((game, kind), []).append((name, pack, path))

print('  packs: ' + (', '.join(PACK_NAMES[p] for p in packs) or 'none'))
for game, title in GAMES.items():
    gdir = os.path.join(args.root, game)
    if not os.path.isdir(gdir):
        continue
    report = []

    # world textures
    links, used, original = {}, {}, 0
    fb = fallbacks(game)
    for name, pack, path in picks.get((game, 'world'), []):
        stem = os.path.splitext(name)[0].upper()
        src = None
        if pack in packs and os.path.isfile(os.path.join(packs[pack], path)):
            src, got = os.path.join(packs[pack], path), pack
        else:
            for got, folder, idx in fb:
                if stem in idx:
                    src = os.path.join(folder, idx[stem])
                    break
        if not src:
            original += 1
            continue
        links[os.path.splitext(name)[0] + os.path.splitext(src)[1]] = src
        used[got] = used.get(got, 0) + 1
    if links:
        if replace_folder(os.path.join(gdir, 'materials/common'), links):
            report.append('world textures ' + ', '.join(f'{n} {PACK_NAMES[p]}' for p, n in sorted(used.items())))
        else:
            report.append('world textures: your own materials/common kept (--force replaces it)')
            original = 0
    if original:
        report.append(f'{original} keep the original look (their pack is not installed)')

    # model textures (ReSrced only)
    if 'resrced' in packs:
        mlinks = {name: os.path.join(packs['resrced'], path) for name, pack, path in picks.get((game, 'model'), [])
                  if os.path.isdir(os.path.join(packs['resrced'], path))}
        if mlinks:
            if replace_folder(os.path.join(gdir, 'materials/models'), mlinks):
                report.append(f'{len(mlinks)} models')
            else:
                report.append('models: your own materials/models kept')

    # skies
    skies = 0
    for name, pack, path in picks.get((game, 'sky'), []):
        if pack not in packs:
            continue
        faces = [(os.path.join(packs[pack], path + f + '.tga'), os.path.join(gdir, 'gfx/env', name + f + '.tga'))
                 for f in FACES]
        if not all(os.path.isfile(s) for s, _ in faces):
            continue
        if not args.dry_run:
            os.makedirs(os.path.join(gdir, 'gfx/env'), exist_ok=True)
            for s, d in faces:
                shutil.copyfile(s, d + '.new')
                os.replace(d + '.new', d)
        skies += 1
    if skies:
        report.append(f'{skies} skies')
    print(f'  {title}: ' + ('; '.join(report) if report else 'nothing to install'))
