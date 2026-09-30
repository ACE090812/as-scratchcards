# as-scratchcard — Los Santos Lottery

Item-based instant-win scratchcards, branded as "Los Santos Lottery" (see `branding/`).
Server-authoritative RNG, framework-agnostic payout (qbox / qb-core / ESX auto-detected),
ox_inventory or qb-inventory (auto-detected), real drag-to-scratch UI (one continuous swipe can
scratch straight across several panels, like a real card - it's not locked to one square at a
time) with a synthesized scratch sound, a soft daily payout cap, an oxmysql audit log, and a
Discord webhook on every win.

Ten cards ship out of the box across six different Game 1 mechanics - not just the same match-3
recoloured ten times:

| Item | Card | Game 1 | Price | Top prize |
| --- | --- | --- | --- | --- |
| `scratchcard_1` | Lucky Sevens | Classic match 3 | £1 | £500 |
| `scratchcard_2` | Cash Cascade | Classic match 3 | £2 | £2,000 |
| `scratchcard_3` | Silver Spinner | Classic match 3 | £3 | £5,000 |
| `scratchcard_4` | Diamond Sevens | Classic match 3 | £5 | £20,000 |
| `scratchcard_5` | Emerald Millions | Classic match 3 | £10 | £250,000 |
| `scratchcard_star` | Find The Star | Find the ⭐ among 8 panels | £2 | £5,000 |
| `scratchcard_banker` | Beat The Banker | Your 3 numbers vs. the banker's 1 | £3 | £10,000 |
| `scratchcard_multiplier` | Cash Multiplier | Match 3, then multiply the win | £5 | £50,000 |
| `scratchcard_numbers` | Match Your Numbers | 20 of yours vs. 10 winning numbers | £3 | £15,000 |
| `scratchcard_bingo` | Jewel Bingo | 5x5 grid, complete a row/column/diagonal | £3 | £300,000 |

Every tier still gets the same Game 2 bonus panel (match 4 identical symbols) regardless of which
Game 1 mechanic it uses. Add, remove, or reprice any of these in `config.lua` - see the `game`
field comment at the top of `Config.Tiers` for how each mechanic is configured.

## Install

1. Drop this folder into your resources as `as-scratchcard`.
2. Make sure `oxmysql` is started before this resource (it's used for the audit log table).
3. Add one item per tier in your inventory's item file.

   **ox_inventory** (`ox_inventory/data/items.lua`) — current ox_inventory usable items are
   client-driven, so the item needs a `client.export` pointing at this resource's name + the item
   name (that export is already defined for you in `client/main.lua`, nothing else to wire up):

```lua
['scratchcard_1'] = { label = 'Lucky Sevens Scratchcard (£1)', weight = 1, stack = true, close = true, client = { export = 'as-scratchcard.scratchcard_1' } },
['scratchcard_2'] = { label = 'Cash Cascade Scratchcard (£2)', weight = 1, stack = true, close = true, client = { export = 'as-scratchcard.scratchcard_2' } },
['scratchcard_3'] = { label = 'Silver Spinner Scratchcard (£3)', weight = 1, stack = true, close = true, client = { export = 'as-scratchcard.scratchcard_3' } },
['scratchcard_4'] = { label = 'Diamond Sevens Scratchcard (£5)', weight = 1, stack = true, close = true, client = { export = 'as-scratchcard.scratchcard_4' } },
['scratchcard_5'] = { label = 'Emerald Millions Scratchcard (£10)', weight = 1, stack = true, close = true, client = { export = 'as-scratchcard.scratchcard_5' } },
['scratchcard_star'] = { label = 'Find The Star Scratchcard (£2)', weight = 1, stack = true, close = true, client = { export = 'as-scratchcard.scratchcard_star' } },
['scratchcard_banker'] = { label = 'Beat The Banker Scratchcard (£3)', weight = 1, stack = true, close = true, client = { export = 'as-scratchcard.scratchcard_banker' } },
['scratchcard_multiplier'] = { label = 'Cash Multiplier Scratchcard (£5)', weight = 1, stack = true, close = true, client = { export = 'as-scratchcard.scratchcard_multiplier' } },
['scratchcard_numbers'] = { label = 'Match Your Numbers Scratchcard (£3)', weight = 1, stack = true, close = true, client = { export = 'as-scratchcard.scratchcard_numbers' } },
['scratchcard_bingo'] = { label = 'Jewel Bingo Scratchcard (£3)', weight = 1, stack = true, close = true, client = { export = 'as-scratchcard.scratchcard_bingo' } },
```

   If you renamed this resource's folder to something other than `as-scratchcard`, change the
   `export = '...'` prefix to match the folder name exactly.

   **qb-inventory** (`qb-core/shared/items.lua`) — a normal usable item, no export field needed
   (this resource registers it server-side via qb-core automatically):

```lua
['scratchcard_1'] = { name = 'scratchcard_1', label = 'Lucky Sevens Scratchcard (£1)', weight = 100, type = 'item', image = 'scratchcard_1.png', unique = false, useable = true, shouldClose = true, combinable = nil, description = 'A £1 Lucky Sevens scratchcard.' },
-- ...and so on for every item in the table above (scratchcard_2 through scratchcard_5, plus
-- scratchcard_star, scratchcard_banker, scratchcard_multiplier, scratchcard_numbers, scratchcard_bingo)
```

   `close`/`shouldClose = true` closes the player's inventory when the item is used, since using one
   opens the scratchcard NUI full-screen.

4. Sell/give these items however you already sell items on your server (shop script, vending
   machine, admin give) — this resource does not sell anything itself.
5. `ensure as-scratchcard` after `oxmysql`, your inventory, and your framework in your server.cfg.
6. Open `config.lua` and adjust prices/prizes/odds/currency/webhook to taste.

## Config highlights (`config.lua`)

- `Config.Inventory` — `'auto'` (default) detects ox_inventory vs qb-inventory at startup, or force
  `'ox'` / `'qb'`.
- `Config.DailyPayoutCap` — a *soft* per-player daily limit. `0` disables it. Going over it never
  blocks or reduces a payout — the card still pays in full — it just gets flagged in the DB log and
  in the Discord webhook message so admins can see who's running hot. This is tracked in memory, so
  it resets on a resource restart; if you want it to survive restarts, back `dailyTotals` in
  `server/main.lua` with a DB table instead.
- `Config.DiscordWebhook` — paste a webhook URL to get a message for every win, any size. Leave
  blank to disable.
- `Config.EnableDatabaseLog` — logs every card played (win or lose) to an `as_scratchcard_logs`
  table (auto-created on first start via oxmysql), including the full grid and bonus result.
- `Config.ScratchSound` — toggles the scratch sound. It's synthesized in the browser with the Web
  Audio API (a short filtered noise burst), not an audio file, so there's nothing to ship or that
  can fail to load. No win/lose jingle by design — scratch sound only.

## How it works

- Using a `scratchcard_N` item triggers this resource's usable-item handling for whichever
  inventory you're on: on ox_inventory, a client export (`client/main.lua`) verifies + consumes the
  item via `exports.ox_inventory:useItem` and then tells the server; on qb-inventory, qb-core's own
  usable-item registration (`server/inventory.lua`) calls the server directly. Either way, the
  server (`server/main.lua`) is what rolls the full outcome for both games and stores it keyed to
  that player — nothing about win/lose is ever decided or trusted client-side.
- The client (`client/main.lua`) opens the NUI with that result and focuses it.
- The player scratches Game 1 (whichever mechanic this tier's `game` type uses - see the table
  above) and Game 2 (match 4 symbols) — this is just revealing values that were already fixed, not
  generating them. `html/script.js`'s `GAME1_RENDERERS` table has one renderer per `game` type; add
  a new one there (plus a matching builder in `server/main.lua`'s `Games` table) to add another
  mechanic of your own.
- Once both games are fully scratched, "Collect & close" tells the server to pay out via
  `server/bridge.lua` (qbox / qb-core / ESX) and closes the NUI. Pressing Escape before finishing
  forfeits that card — the server discards the pending result rather than re-rolling it later.

## The one hard rule for the HTML/CSS/JS in here

Never add an external font `<link>`, CDN script, or any other network call inside `html/*`. A
render-blocking request to an outside host has previously left an NUI page as a solid black screen
from the moment a resource starts (the browser texture stays opaque black until first paint, and
paint was stuck on that fetch) — with zero console error to point at it. Keep this page 100%
self-contained.

Also: `#app` in `index.html` starts with the `hidden` class and `script.js` never removes it except
inside the `'open'` NUI message handler. Don't add a default-visible state or a query-string branch
that shows it on load — that exact mistake is what made an earlier script's overlay render
full-screen for every player as soon as the resource started.

## Open items

This is a working build, not an escrowed release package. Still worth doing before a public
Tebex/Cfx listing: apply a house-edge pass to the prize tables against real playtesting data (the
current odds are estimates, not measured), decide on FiveM Escrow/obfuscation for the shipped copy,
and swap in the Los Santos Lottery branding (`branding/los-santos-lottery-logo.png`) on the listing
page and README screenshots.