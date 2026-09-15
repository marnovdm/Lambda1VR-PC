# Linux Sven handoff validation and senior-review disposition

Scope: a portable x86 Linux VR test client and a native ARM64 dedicated
Half-Life co-op campaign server. Not an exhaustive map sweep. Physical headset,
Windows, full campaign completion and save/load acceptance are not claimed.

## Observed checks

- Public UDP connection from the Linux OpenXR client to the dedicated server;
  tracked controller poses, stereo rendering and head-relative UI were submitted.
- Connected transitions between `c1a0`, `c1a0a`, `c0a0`, and back to `c1a0`.
  The rebuilt ARM64 server rejected foreign navigation caches and regenerated
  native caches. `c0a0` no longer reproduced the observed cache-load crash.
- A temporary `env_global` sentinel with state Dead survived `c1a0` to `c1a0a`
  with its original source-map name. Starting the separate `c0a0` series cleared
  the global table. The temporary map entity override was removed afterward.
- The final client requires no glibc symbol newer than 2.34; dependencies resolved
  in Ubuntu 22.04. A running process mapped the bundled 32-bit OpenXR loader.
- Engine build: 15/15 tests passed. All five package shell-test suites passed.
- ARM64's unsigned plain `char` also broke the legacy signed-byte route decoder.
  Explicit octet decoding retained the existing graph algorithm/cache format;
  focused tests passed with both char signedness modes. After deployment, the
  same `c1a0` native cache loaded without the previously recurring corrupt-route
  errors during a connected session.

## Controller behavior

Tests used Monado's remote driver, not engine-side injected commands. Index is
the upstream remote driver's profile; Touch uses the small test-only mapping in
`tests/monado-remote-touch.patch`. The actual left/right interaction profile was
verified using engine logs for Index and OpenXR profile queries for Touch.

| Behavior | Index | Oculus Touch |
| --- | --- | --- |
| Open/back out of menu | Both-stick fallback and system mapping exercised | Left menu button exercised |
| Point at Configuration and trigger-click into it | Observed in compositor | Observed in compositor |
| Dismiss Sven MOTD through controller pointer | Observed after VGUI fix | Observed after VGUI fix |
| Pistol primary fire | Server clip decreased 17 to 11 before the VGUI fix | Server clip decreased 17 to 13 after the VGUI fix |
| Snap turn | View yaw changed -90 to -135 degrees | View yaw changed 180 to 135 degrees |

The MOTD test exposed a real defect: VGUI keeps `key_game`, so checking only
key destination routed the trigger to gameplay. The fix reuses the engine's
cursor ownership and existing touch-to-VGUI dispatch. While the dialog was
active, the server player button mask remained zero under a held trigger; after
release, the dialog closed. Menu trigger presses remain blocked from firing
until released. Automated coverage checks cursor ownership and the consumption
latch across reset, UI dismissal, release and repress. Live coverage checks MOTD
release-dismissal and zero server buttons while held; focus loss was not replayed
with hardware. Final post-fix Index reconnect, MOTD and Configuration selection
were repeated, separately from the earlier Index firing measurement.

Simulation does not prove physical tracking quality, comfort or vibration. The
upstream remote driver does not implement physical haptic output. Pistol ammo
consumption and visible effects demonstrate firing; this is not a claim that
every weapon/damage interaction has been exercised on hardware.

## Astra senior review

Astra Max reviewed the deployment/ABI decision against source. Main integrated
the findings and performed the runtime checks; those checks were not independently
replayed by the reviewer. Retain the existing engine and SevenKewp architecture:
the demonstrated incompatibilities are boundary fixes, not grounds for a rewrite.

| Recommendation | Disposition |
| --- | --- |
| Replace host-Arch GLIBC 2.43 client artifacts | Adopted: Ubuntu 22.04 build, bundled Khronos loader, ELF/dependency checks. |
| Preserve signed engine string offsets and native callback widths | Adopted narrow ABI fixes; ARM64 campaign startup verified. Callback save/load remains unverified. |
| Reuse campaign parser, load it before first world activation, one series per line | Adopted; next-map and zero-timer behavior checked. |
| Let existing world/series policy own co-op global clearing | Adopted; actual global values preserved within series and cleared outside it. |
| Reject native-layout graph caches from other architectures and clear partial loads | Adopted; prior `c0a0` crash reproduction now passes. |
| Use server-side GoldSrc message compatibility and reachable host-network UDP port | Adopted; actual external VR client connected across transitions. |
| Separate serialized save sizes from native object sizes | Open: concrete EHANDLE/pointer storage defects in SevenKewp save/restore remain. Dedicated ordinary map transitions do not invoke the unsupported save command. No save/load readiness claim. |
| Correct `CPathTrack::m_hAltpath` save descriptor to EHANDLE | Open alongside save/restore acceptance; not evidence of failure in the demonstrated dedicated transition path. |
| Preserve consumed trigger across focus loss | Adopted after final Astra addendum: synthetic pointer-up no longer clears the latch; added reset/held/release/repress regression. |
| Narrow controller test claims and preserve build provenance | Adopted: distinguish pre-fix Index firing from post-fix menu checks; do not label reload/secondary-fire instructions as tested behavior. |

Acceptance remains a Linux **test handoff**, not certification of complete
Lambda1VR parity across all campaigns and platforms.

The private archive's SHA-256 is supplied in its adjacent `.sha256` file.
Its ten-binary manifest was verified after fresh extraction; that
extracted client connected in OpenXR to the rebuilt native server. Source
revisions are listed in `SOURCES.md` and repeated inside the bundle.
Final packaging inspection removed an unused absolute `valve/valve` symlink
back to the source workstation; no binaries changed. Packaging now excludes
unsafe Valve-data symlinks, with a regression fixture for that exact case.
