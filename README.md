# Code Samples

Nine files from two Roblox projects I work on.

### Shattered Hopes

Asymmetric horror game. I do server-side scripting on it.

- `ServiceLocator.luau`: service registry. Services resolve each other by
  name at runtime instead of requiring each other directly.
- `StateMachineDefinitions.luau`: the 15 character states and every legal
  transition between them, as data. No logic in the file, so the rules can
  be read without tracing code.
- `CombatStateMachine.luau`: per-character combat state and cancel windows.
  State mirrors onto character attributes so the client can read it without
  a remote.
- `AbilityRegistry.luau`: loads ability definitions out of the definition
  folders, validates each one, then serves them by ID. Balance values are
  deliberately not in here.
- `StatusService.luau`: applies, stacks and expires status effects, and
  replicates them to clients. Each kind of modifier stacks its own way.
- `AdminPermissionService.luau`: admin checks live here so other services
  call `RequireAdmin` instead of each one reading the user-ID list.
- `DebugService.luau`: in-memory log buffer, capped at `MaxLogs`.

### Shotline

Studio plugin of mine. Keyframe timeline for camera cutscenes; exports to a
ModuleScript that runs without the plugin installed.

- `CutsceneController.luau`: writes a small helper module into
  ReplicatedStorage so exported cutscenes can be played with `Play(name)`.
- `Easing.luau`: easing curves, 9 styles x 3 directions.
