# Decisions

Open decisions from [architecture.md](architecture.md) ("Risks and decisions needed"). Fill in a row when a decision is made; add new rows at the bottom.

| Date | Decision | Chosen | Decided by |
| --- | --- | --- | --- |
|  | Phase 1 forgot-password method (Face ID / passcode, or another check) |  |  |
| 2026-11-02 | Phase 1: one user per phone, or several local users | Several local users; devices belong to a user | Nandu Viswanathan |
|  | Phase 1 → Phase 2: migrate local accounts and data, or start fresh |  |  |
|  | Phase 2 uploader: C++ cloud library (Option A) or Flutter sync module (Option B) |  |  |
|  | Cloud API contract and backend (decided by the cloud team) |  |  |
|  | Heartbeat interval per device, and whether each device accepts a new interval from the app |  |  |
| 2026-11-02 | Android auto-backup of app data | Off (`android:allowBackup="false"`): the encrypted DB stays on the phone, and a restored copy would be unreadable without its Keystore key | Nandu Viswanathan |
| 2026-11-02 | Failed-login lock-out (Phase 1 local accounts) | None: wrong passwords do not lock the account. Departs from the architecture Security design ("failed-login lock-out"); the pre-release security review must accept this. `failedLoginCount` / `lockedUntil` columns stay unused | Nandu Viswanathan |
| 2026-11-02 | How long a local session lasts | Until the user logs out; survives app restarts | Nandu Viswanathan |
| 2026-11-02 | Turning on Face ID login | Offered once after the first password login (if `features.faceIdLogin` and biometrics are enrolled); one Face ID user per phone, the latest to turn it on | Nandu Viswanathan |
