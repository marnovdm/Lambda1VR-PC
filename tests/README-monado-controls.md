# Controller-path testing

Use Monado's existing remote driver to exercise real OpenXR actions. This is
test infrastructure, not a replacement input path or a normal launch dependency.
Reference checkout: Monado `107cd6c77`, with its remote driver enabled. The
default remote driver presents Index controllers. `monado-remote-touch.patch`
adds an opt-in Touch mapping to the same driver and unchanged packet protocol.

```sh
git -C /path/to/monado apply /path/to/tests/monado-remote-touch.patch
cmake --build /path/to/monado/build-sim --target monado-service -j2
P_OVERRIDE_ACTIVE_CONFIG=remote REMOTE_CONTROLLER_PROFILE=touch \
  XRT_COMPOSITOR_FORCE_XCB=1 XRT_COMPOSITOR_XCB_DISPLAY=1 \
  /path/to/monado/build-sim/src/xrt/targets/service/monado-service
```

Unset `REMOTE_CONTROLLER_PROFILE` for Index. Use a terminal for the service.
The upstream remote driver listens on TCP 4242 on all interfaces; use only on
a trusted/isolated test host and stop it after testing. Do not deploy it on the
game server or expose it publicly.

Run `python3 tests/monado-remote-input.py` in another terminal, then launch the
game against that runtime. The sender accepts JSON lines, retains the last
state, and uses the existing `mndrmt3` 376-byte protocol. Example press/release:

```json
{"right":{"trigger_value":1}}
{"right":{"trigger_value":0}}
```

Other fields: `thumbstick:[x,y]`, `thumbstick_click`, `squeeze_value`, `a_click`,
`b_click`, `system_click`, and `pose:[qx,qy,qz,qw,x,y,z]`. On Touch, the left
system field maps to menu, left A/B map to X/Y. On Index, both stick clicks
exercise the menu fallback without relying on runtime-reserved system buttons.

Acceptance is visible menu/dialog selection, actual server-side ammo changes
after firing, and a changed view angle after turning—not merely submitted poses
or action counters. Verify the actual interaction profile with OpenXR's current
profile query or the engine's developer-2 profile logs. Never send keyboard fire
commands as a substitute for the controller action under test.

The remote driver has no physical haptic output transport. Haptic calls and
simulated poses cannot establish physical tracking, controller ergonomics, or
headset comfort. Leave those checks for real hardware.
