#!/usr/bin/env python3
"""Send test inputs through Monado's existing mndrmt3 remote-driver protocol.

Test utility only; never used by the game or normal launchers. Requires the
matching Monado r_interface.h layout (64-bit host). JSON lines on stdin update
left/right fields, e.g. {"right":{"trigger_value":1}}. 'pose' is [qx,qy,qz,qw,x,y,z].
"""
import ctypes as C
import json
import socket
import sys


class Controller(C.Structure):
    _fields_ = [
        ("pose", C.c_float * 7),
        ("linear_velocity", C.c_float * 3),
        ("angular_velocity", C.c_float * 3),
        ("hand_curl", C.c_float * 5),
        ("trigger_value", C.c_float), ("squeeze_value", C.c_float),
        ("squeeze_force", C.c_float), ("thumbstick", C.c_float * 2),
        ("trackpad_force", C.c_float), ("trackpad", C.c_float * 2),
    ] + [(name, C.c_bool) for name in (
        "hand_tracking_active", "active", "system_click", "system_touch",
        "a_click", "a_touch", "b_click", "b_touch", "trigger_click",
        "trigger_touch", "thumbstick_click", "thumbstick_touch", "trackpad_touch",
        "_pad0", "_pad1", "_pad2")]


class Head(C.Structure):
    _fields_ = [("views", C.c_ubyte * 96), ("pose", C.c_float * 7),
                ("per_view_data_valid", C.c_bool), ("padding", C.c_ubyte * 3)]


class Packet(C.Structure):
    _fields_ = [("header", C.c_uint64), ("head", Head),
                ("left", Controller), ("right", Controller)]


def receive(sock):
    data = bytearray()
    while len(data) < C.sizeof(Packet):
        part = sock.recv(C.sizeof(Packet) - len(data))
        if not part:
            raise RuntimeError("remote disconnected")
        data.extend(part)
    packet = Packet.from_buffer_copy(data)
    if bytes(data[:8]) != b"mndrmt3\0":
        raise RuntimeError("incompatible remote protocol")
    return packet


def main():
    assert C.sizeof(Controller) == 120 and C.sizeof(Packet) == 376
    with socket.create_connection(("127.0.0.1", 4242), timeout=5) as sock:
        receive(sock)  # reset state
        packet = receive(sock)
        packet.head.pose[:] = (0, 0, 0, 1, 0, 1.6, 0)
        packet.head.per_view_data_valid = False
        for hand, x in ((packet.left, -.2), (packet.right, .2)):
            hand.pose[:] = (0, 0, 0, 1, x, 1.3, -.5)
            hand.active = True
            hand.hand_tracking_active = False
        sock.sendall(bytes(packet))
        print("ready: Monado remote protocol, 376-byte packet", flush=True)
        for line in sys.stdin:
            update = json.loads(line)
            for device, values in update.items():
                if device not in ("head", "left", "right"):
                    raise ValueError("unknown device")
                target = getattr(packet, device)
                for key, value in values.items():
                    current = getattr(target, key)
                    if isinstance(current, C.Array):
                        current[:] = value
                    else:
                        setattr(target, key, value)
            sock.sendall(bytes(packet))
            print("sent " + json.dumps(update), flush=True)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
