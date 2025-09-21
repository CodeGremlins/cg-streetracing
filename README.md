# cg-streetracing

Base FiveM street racing script for ESX using `ox_lib` + `ox_target` with a minimal NUI to show:
- Overall race timer
- Top 3 positions (player names)
- Your current place
- Current lap / total laps

## Features
- Create, join, start races from commands
- Multi-lap support (per race laps setting)
- Server-managed checkpoint progression & finish order
- Auto DNF timer after winner finishes (configurable)
- Anti-exploit checkpoint validation (max distance + strict order)
- Player name display (ESX RP name or fallback)
- Best time persistence per race using `oxmysql` (automatic table creation)
- Basic payout to winner (ESX money) – easily extendable
- ox_target interaction placeholder (zone) to open future race menu
- Lightweight UI (HTML/CSS/JS) for position, lap & elapsed time
 - Late spectate support (join viewing after start)
 - Finish summary panel (placements, times, DNFs)

## Dependencies
Ensure these resources start **before** this resource:
- `es_extended` (legacy / compatible imports)
- `ox_lib`
- `ox_target`
- `oxmysql` (required for best time saving; script still runs without, but times won't persist)

## Installation
1. Place folder `cg-streetracing` in your server resources directory.
2. Add `ensure cg-streetracing` to your `server.cfg` after dependencies.
3. Adjust `config.lua` if desired (payout, checkpoints, positions, debug).

## Commands (Temp Dev)
- `/createrace test_loop` – creates a race instance from config key.
- Server returns race id like `test_loop-1695300000` (example).
- `/joinrace <raceId>` – join before it starts.
- `/startrace <raceId>` – only creator can start; checks min players.
- `/spectaterace <raceId>` – spectate an active race (no participation).
 - `/leaverace` – leave current race or spectate session and hide UI.
 - `/hideraceui` – manually hide race & summary UI (does not leave race).

## UI
Shows automatically when you join a race. Closes on race end.
Displays: timer, lap progress, top 3, your placement. Names pulled from ESX player object.
After race end a summary pop-up lists placements, finish times (formatted), and DNFs (dimmed). Auto-hides after 15s or close early with ESC / Backspace.

## Adding New Race
In `config.lua` add another entry under `Config.Races`:
```
Config.Races.my_new_race = {
  label = 'My New Race',
  laps = 1,
  payout = 3000,
  checkpoints = {
    vec3(x,y,z),
    vec3(x2,y2,z2)
  }
}
```
Then create with `/createrace my_new_race`.

## Roadmap Ideas
- Vehicle class / model restrictions
- Dynamic race builder (in-game checkpoint recorder)
- Ghost / replay or spectator mode
- Advanced penalty system (wrong way, collision tracking)
- Wider scoreboard (full ordering & split times)

## Export(s)
- `exports['cg-streetracing']:ListRaces()` returns current race table (debug)

## License
MIT (adjust as needed). This is a base starting point.
