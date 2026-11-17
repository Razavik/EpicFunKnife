# Fire Knife rework

Fire now has Blade and Shield modes, a shared target Heat meter, automatic Overheat on successful Blade melee hits, and separate cooldowns for Wave, Feast, Rush, and Zone.

| Control | Blade | Shield |
| --- | --- | --- |
| F | Switch to Shield | Switch to Blade |
| T | Toggle automatic Overheat | Toggle automatic Overheat for Blade |
| E | Cycle Heat / Burn / Heal | Burner Rush |
| R | Ember Feast | Inferno Zone |
| Mouse2 | Stab plus Inferno Wave when ready | Hold Cover |

Heat adds 50 Heat; Burn consumes current Heat for `round(11 + 0.225 * Heat)` extra damage; Heal consumes it for `round(17 + Heat / 3)` HP. Burn/Heal add no Heat and do not trigger ignition. Rounding is nearest integer with halves rounded upward. At 70 Heat these give 27 damage or 40 HP. Overheat cooldown starts after a successful hit, not a miss.

At 100 Heat, the meter resets and ignition starts for 6 seconds. Damage is exactly 1 HP per 0.2-second cycle; further accepted Heat extends it by 0.06 seconds per point, capped at 10 seconds. Overflow above 100 is discarded. Water clears Heat and ignition. After 3 seconds without heating, Heat decays at 10 points per second. Fractional ignition time is retained between applications; core timers use 0.2-second cycles.

Cooldowns are independent: Overheat 17 s, Wave 18 s, Rush 17 s, Feast 20 s, Zone 20 s. Mode switching preserves cooldowns and Cover charge. Feast radius is 250 units; Cover field and Zone radius are 200 units. Cover blocks a 90-degree front sector after 0.25 seconds. It has 5 seconds of protection, regenerates after a 1.5-second delay at 1 second per 3 seconds, and fully recharges after a 15-second exhaustion lock.

Wave travels 400 units at 800 units/s: 0.5 seconds, correcting the document's inconsistent 1-second travel time. Current tuning: half-width 100, height 32, painshock multiplier 0.5 for 0.3 s. Rush lasts 0.4 s at 750 units/s; hit push is 400 horizontal / 160 vertical. Rush hit/wall control uses speed multiplier 0.1 for 0.5 s and a 150-unit wall-impact radius. These presentation and control parameters need an in-client balance pass.

Rush and Zone consume 1 second of Cover. Below that amount Rush still pushes and applies impact control but adds no Heat/trail; Zone cannot activate. Zone has 90 HP, lasts 6 seconds, switches its owner to Blade, and prevents returning to Shield until expiry/destruction. Destruction adds a 10-second Shield lock; natural expiry does not.

## Installation and integration

Install the updated core, Fire, Acidtrap, Flash, Frost, Leap, Necro, Razor, and Wind plugins together. Update the shared includes and language file. Cover interception must run before each projectile's damage/debuffs; each knife retains its original projectile cleanup routine. Ongoing debuffs and damage over time are not generally cancelled by Cover. Direct melee, including NPC melee, bypasses Cover.

Existing Fire sprites/sounds/models and stock CS shield models are used. There are no newly authored art assets. Use `mp_roundtime 2.75` in the server configuration for the specified 165-second round; the knife plugin does not override global round settings.

The new core interfaces are documented in `src/include/efk_core.inc`. Existing ordinary burn sources keep their previous damage/critical behavior. Fixed ignition state is preserved by burn transfer and rewind. Live experimental installations may have different core changes: merge these source changes before deploying there, rather than overwriting such a core with a main-based binary.

Runtime regression instructions are in `tests/fire-rework/README.md`. Client-side visuals, stock shield animation transitions, map slopes, and real multiplayer balance still require an in-game pass.