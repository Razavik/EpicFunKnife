# Fire runtime regression fixture

Run only on an isolated HLDS instance. This fixture creates two fake clients and shuts the server down after reporting the result. Never install it on a public or live server.

1. Generate the test source with `pwsh -File tests/fire-rework/build-fixture.ps1 -OutputDirectory <compiler-directory>`.
2. Compile it with AMXX 1.10 and the current repository includes: `amxxpc.exe efk_knife_fire_test.sma`.
3. Load the updated `efk_core.amxx` followed by `efk_knife_fire_test.amxx`. Do not also load the production Fire plugin. Other knife plugins may be loaded to check integration.
4. Use ReGameDLL/ReAPI, an empty map `35hp_2efk`, at least two player slots, `mp_freezetime 0`, `mp_autoteambalance 0`, `mp_limitteams 0`, and `mp_round_infinite 1`. Install the usual EFK resources and AMXX gamedata. This is a map-specific fixture: it finds an open nearby area for two opposing players.
5. Read the `[FireTest]` lines in the console log. Expected result: `48 passed, 0 failed`.

The cases exercise heat thresholds/overflow, decay, water, burn duration/cap/ticks, rounded Burn/Heal, hit cooldowns, melee timing/property restoration, Feast, Cover angle/raising/exhaustion, mode switching, projectile interception, Zone health/destruction/expiry/line of sight, Rush resource/direction/interruption/movement cleanup, and single-hit/jumpable Wave volume. They call some internal functions to isolate behavior; they do not replace an in-client check of animations, visuals, slopes, and all projectile trajectories.