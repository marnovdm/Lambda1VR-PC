# Source repositories

The desktop port is maintained as small, reviewable forks rather than a new
engine/gameplay rewrite. These public branches are the source inputs for the
current Linux handoff:

| Component | Public source | Branch | Recorded commit |
| --- | --- | --- | --- |
| Xash3D FWGS engine/OpenXR host | <https://github.com/ObeseCatLord/xash3d-fwgs> | `pc-openxr-lambda-parity` | `b8d673d7` |
| Base Half-Life VR game code | <https://github.com/ObeseCatLord/hlsdk-portable> | `pc-openxr-lambda-parity` | `ccff5db9` |
| Blue Shift VR game code | <https://github.com/ObeseCatLord/hlsdk-portable> | `pc-openxr-bshift` | `c61372aa` |
| Opposing Force VR game code | <https://github.com/ObeseCatLord/hlsdk-portable> | `pc-openxr-opfor` | `861b4cc2` |
| They Hunger VR game code | <https://github.com/ObeseCatLord/hlsdk-portable> | `pc-openxr-theyhunger` | `db11ca05` |
| Sven/SevenKewp VR game code | <https://github.com/ObeseCatLord/SevenKewp> | `pc-openxr-lambda-parity` | `4facbc1b` |

Behavioral references retained during the port:

- <https://github.com/Team-Beef-Studios/Lambda1VR>
- <https://github.com/Team-Beef-Studios/xash3d-fwgs>
- <https://github.com/Team-Beef-Studios/hlsdk-xash3d>
- <https://github.com/Team-Beef-Studios/hlsdk-xash3d-opfor>
- <https://github.com/Team-Beef-Studios/hlsdk-xash3d_theyhunger>
- <https://github.com/Team-Beef-Studios/hlsdk-xash3d_aomdc>

Each source fork retains its upstream history and license. The Half-Life SDK
forks remain subject to Valve's SDK license. This packaging repository's own
scripts and documentation are MIT licensed. Game data, Lambda1VR model assets,
and Sven content are not covered by that MIT license and are not redistributed
by the public repository.
