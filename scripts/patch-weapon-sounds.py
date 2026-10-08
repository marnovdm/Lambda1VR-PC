#!/usr/bin/env python3
"""Give Lambda1VR view models back the sound events the stock models have.

The Lambda1VR revolver (models/v_357.mdl, the same file in all three games) has no event in its reload animation,
so reloading it is silent: the stock model plays weapons/357_reload1.wav from the animation (event 5004 at frame 70),
and the game code's own fallback (CPython::m_flSoundDelay) never fires because nothing counts it down.

Usage: patch-weapon-sounds.py [ROOT]   (default ~/Games/lambda1vr-pc; patches valve, bshift, gearbox)
Run by install-linux-steamvr.sh on every install. Writes MODEL.orig once, then replaces the model via a new file
+ rename (safe while the game runs). Idempotent: a sequence that already has events is left alone."""
import os, struct, sys

ROOT = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/Games/lambda1vr-pc")
# model -> sequence -> [(frame, sound)], copied from the stock model (same frame count and speed)
EVENTS = {
    "v_357.mdl": {"reload": [(70, "weapons/357_reload1.wav")]},
}
SEQ_SIZE = 176   # mstudioseqdesc_t
EVENT_SIZE = 76  # mstudioevent_t: frame, event, type, options[64]
CL_EVENT_SOUND = 5004


def patch(data, sequences):
    """Append the events at the end of the file and point the sequences at them. Returns (data, patched names)."""
    data = bytearray(data)
    numseq, seqindex = struct.unpack_from("<2i", data, 164)
    done = []
    for i in range(numseq):
        o = seqindex + i * SEQ_SIZE
        label = data[o:o + 32].split(b"\0")[0].decode().lower()
        events = sequences.get(label)
        numevents, _ = struct.unpack_from("<2i", data, o + 48)
        if not events or numevents:
            continue
        data += b"\0" * (-len(data) % 4)
        index = len(data)
        for frame, sound in events:
            data += struct.pack("<3i64s", frame, CL_EVENT_SOUND, 0, sound.encode())
        struct.pack_into("<2i", data, o + 48, len(events), index)
        done.append(label)
    struct.pack_into("<i", data, 72, len(data))  # studiohdr_t.length
    return bytes(data), done


for game in ("valve", "bshift", "gearbox"):
    for model, sequences in EVENTS.items():
        path = os.path.join(ROOT, game, "models", model)
        if not os.path.isfile(path):
            continue
        data = open(path, "rb").read()
        if data[:4] != b"IDST":
            print(f"{path}: not a studio model, skipped")
            continue
        new, done = patch(data, sequences)
        if not done:
            print(f"{path}: sounds already in place")
            continue
        if not os.path.exists(path + ".orig"):
            open(path + ".orig", "wb").write(data)
        open(path + ".new", "wb").write(new)
        os.replace(path + ".new", path)
        print(f"{path}: sound events added to {', '.join(done)} (original: {path}.orig)")
