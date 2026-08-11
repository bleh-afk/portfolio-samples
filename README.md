# Code Samples

Four files from two Roblox projects I work on.

### Shattered Hopes

Asymmetric horror game. I do server-side scripting on it.

- `AdminPermissionService.luau`: admin checks live here so other services
  call `RequireAdmin` instead of each one reading the user-ID list.
- `DebugService.luau`: in-memory log buffer, capped at `MaxLogs`.

### Shotline

Studio plugin of mine. Keyframe timeline for camera cutscenes; exports to a
ModuleScript that runs without the plugin installed.

- `CutsceneController.luau`: writes a small helper module into
  ReplicatedStorage so exported cutscenes can be played with `Play(name)`.
- `Easing.luau`: easing curves, 9 styles x 3 directions.
