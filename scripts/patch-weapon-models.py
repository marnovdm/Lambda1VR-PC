#!/usr/bin/env python3
"""Fix Lambda1VR view models: silent sounds, and a shell left floating on the shotgun.

- The revolver (models/v_357.mdl, the same file in all three games) has no event in its reload animation: the stock
  model plays weapons/357_reload1.wav from it (event 5004 at frame 70), and the game code's own fallback
  (CPython::m_flSoundDelay) never fires because nothing counts it down.
- Opposing Force's Desert Eagle, M40A1 and M249 animations play sounds that exist nowhere (de_*.wav, scout_*.wav,
  SAW_*_new.wav, from the models' original mod). They get the stock Opposing Force sounds, at the stock frames.
  The game code plays these animations by index, so a Lambda sequence stands in for the stock one at the same index.
- The shotgun (Counter-Strike's M3, v_shotgun.mdl) has a loose shell mesh on the M3_SHELL bone that the hand carried
  into the loading port in CS. Without the CS hands, its parked position between reloads hangs visibly below the grip
  (start_reload/reload/pump move it about 12 units away and back). Its mesh is emptied, so the reload shows no shell
  either: the renderer walks the mesh's triangle commands until a 0 count (the
  numtris field is only statistics), so the first command becomes that 0 and numtris 0.

Usage: patch-weapon-models.py [ROOT]   (default ~/Games/lambda1vr-pc; patches valve, bshift, gearbox)
Run by install-linux-steamvr.sh on every install. Writes MODEL.orig once, then replaces the model via a new file
+ rename (safe while the game runs). Idempotent. A sequence whose events are neither the expected old ones nor the
new ones (a changed model) is left alone and reported."""
import os, struct, sys

ROOT = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/Games/lambda1vr-pc")
DE_OLD = ["weapons/de_clipout.wav", "weapons/de_clipin.wav", "weapons/de_sliderelease.wav"]
SCOUT_OLD = ["weapons/scout_clipout.wav", "weapons/scout_clipin.wav", "weapons/scout_clipin.wav"]
# (games, model) -> sequence -> (sounds it has now, [(frame, sound)] it gets)
RULES = {
    (("valve", "bshift", "gearbox"), "v_357.mdl"): {
        "reload": ([], [(70, "weapons/357_reload1.wav")]),
    },
    (("gearbox",), "v_desert_eagle.mdl"): {
        # stock: reload / reload_noshot, desert_eagle_reload.wav at frame 1
        "reload_1": (DE_OLD, [(1, "weapons/desert_eagle_reload.wav")]),
        "reload_2": (DE_OLD, [(1, "weapons/desert_eagle_reload.wav")]),
    },
    (("gearbox",), "v_m40a1.mdl"): {
        # empty magazine: stock reload1 (first_seq) then reload2 (second_seq); here index 5, the stock reload2, is a
        # 2-frame idle, so reload_1 carries both (second_seq where first_seq, 2.08 s, ends)
        "reload_1": (SCOUT_OLD, [(1, "weapons/sniper_reload_first_seq.wav"), (104, "weapons/sniper_reload_second_seq.wav")]),
        # rounds left: stock reload3, first_seq only
        "reload_2": (SCOUT_OLD, [(1, "weapons/sniper_reload_first_seq.wav")]),
    },
    (("gearbox",), "v_saw.mdl"): {
        # stock index 2 (M249_LAUNCH) saw_reload.wav at frame 1, index 3 (M249_RELOAD1) saw_reload2.wav at frame 0
        "reload1_1": (["weapons/SAW_reload_new.wav"], [(1, "weapons/saw_reload.wav")]),
        "reload1_2": (["weapons/SAW_reload2_new.wav"], [(0, "weapons/saw_reload2.wav")]),
    },
}
# (games, model) -> [(texture of the mesh to hide, its triangle count)]
HIDE = {
    (("valve", "bshift", "gearbox"), "v_shotgun.mdl"): [("SHELL.bmp", 84)],
}
SEQ_SIZE = 176   # mstudioseqdesc_t
EVENT_SIZE = 76  # mstudioevent_t: frame, event, type, options[64]
CL_EVENT_SOUND = 5004


def sound_events(data, numevents, index):
    out = []
    for e in range(numevents):
        frame, event = struct.unpack_from("<2i", data, index + e * EVENT_SIZE)
        if event == CL_EVENT_SOUND:
            opts = data[index + e * EVENT_SIZE + 12: index + (e + 1) * EVENT_SIZE].split(b"\0")[0].decode(errors="replace")
            out.append((frame, opts))
    return out


def hide_meshes(data, meshes):
    """Empty each mesh drawn with one of the given textures. Returns (data, hidden, problems)."""
    data = bytearray(data)
    numtex, texindex = struct.unpack_from("<2i", data, 180)
    numskinref, _, skinindex = struct.unpack_from("<3i", data, 192)
    textures = [data[texindex + 80 * i: texindex + 80 * i + 64].split(b"\0")[0].decode() for i in range(numtex)]
    numbodyparts, bodypartindex = struct.unpack_from("<2i", data, 204)
    hidden, problems = [], []
    for texture, tris in meshes:
        found = False
        for b in range(numbodyparts):
            nummodels, _, modelindex = struct.unpack_from("<3i", data, bodypartindex + 76 * b + 64)
            for m in range(nummodels):
                nummesh, meshindex = struct.unpack_from("<2i", data, modelindex + 112 * m + 72)
                for k in range(nummesh):
                    o = meshindex + 20 * k
                    numtris, triindex, skinref = struct.unpack_from("<3i", data, o)
                    tex = struct.unpack_from("<h", data, skinindex + 2 * skinref)[0] if skinref < numskinref else -1
                    if not 0 <= tex < numtex or textures[tex] != texture:
                        continue
                    found = True
                    if numtris == tris:
                        struct.pack_into("<i", data, o, 0)
                        struct.pack_into("<h", data, triindex, 0)  # end of the triangle commands
                        hidden.append(texture)
                    elif numtris != 0 or struct.unpack_from("<h", data, triindex)[0] != 0:
                        problems.append(f"{texture} mesh has {numtris} triangles, expected {tris}")
        if not found:
            problems.append(f"no mesh with texture {texture}")
    return bytes(data), hidden, problems


def patch(data, rules):
    """Write each changed sequence's new event list at the end of the file. Returns (data, changed, problems)."""
    data = bytearray(data)
    numseq, seqindex = struct.unpack_from("<2i", data, 164)
    changed, problems = [], []
    for i in range(numseq):
        o = seqindex + i * SEQ_SIZE
        label = data[o:o + 32].split(b"\0")[0].decode().lower()
        if label not in rules:
            continue
        old, new = rules[label]
        numevents, index = struct.unpack_from("<2i", data, o + 48)
        have = sound_events(data, numevents, index)
        if have == new and numevents == len(new):
            continue
        if [s for _, s in have] != old or numevents != len(old):
            problems.append(f"{label} has {[s for _, s in have] or 'no events'}, expected {old or 'none'}")
            continue
        data += b"\0" * (-len(data) % 4)
        index = len(data)
        for frame, sound in new:
            data += struct.pack("<3i64s", frame, CL_EVENT_SOUND, 0, sound.encode())
        struct.pack_into("<2i", data, o + 48, len(new), index)
        changed.append(label)
    struct.pack_into("<i", data, 72, len(data))  # studiohdr_t.length
    return bytes(data), changed, problems


def apply(games, model, fix, done_text, changed_text):
    for game in games:
        path = os.path.join(ROOT, game, "models", model)
        if not os.path.isfile(path):
            continue
        data = open(path, "rb").read()
        if data[:4] != b"IDST":
            print(f"{path}: not a studio model, skipped")
            continue
        new, changed, problems = fix(data)
        for problem in problems:
            print(f"{path}: {problem} - left alone")
        if not changed:
            if not problems:
                print(f"{path}: {done_text}")
            continue
        if not os.path.exists(path + ".orig"):
            open(path + ".orig", "wb").write(data)
        open(path + ".new", "wb").write(new)
        os.replace(path + ".new", path)
        print(f"{path}: {changed_text} {', '.join(changed)} (original: {path}.orig)")


for (games, model), rules in RULES.items():
    apply(games, model, lambda data: patch(data, rules), "sounds already in place", "sound events set for")
for (games, model), meshes in HIDE.items():
    apply(games, model, lambda data: hide_meshes(data, meshes), "stray meshes already hidden", "hidden mesh")
