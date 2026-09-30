Config = {}

-- Which account the win gets paid into: 'cash' or 'bank' (ESX also supports 'bank').
Config.Currency = 'cash'

-- 'auto' detects ox_inventory vs qb-inventory at startup (same pattern as the framework bridge).
-- Set to 'ox' or 'qb' to force one instead of auto-detecting.
Config.Inventory = 'auto'

-- Soft daily payout cap per player, in the currency above. 0 = disabled (no cap at all).
-- This is intentionally NOT a hard block: a card always plays and always pays out in full even
-- past the cap - going over it just gets flagged in the DB log and the Discord webhook (if set)
-- so admins can see if one player is running unusually hot. Raise/lower per your own economy.
-- Tracked in memory per player per calendar day; resets naturally at midnight server time and
-- also on a resource restart (fine for a soft/informational cap - see server/main.lua if you
-- want it backed by the DB instead so it survives restarts).
Config.DailyPayoutCap = 0

-- Paste a Discord webhook URL here to get a message for every win (any size). Leave blank ('')
-- to disable. This is a config field (not a separate file) to keep a free public release simple.
Config.DiscordWebhook = ''

-- oxmysql audit log of every card played (win or lose), including the full grid/bonus result.
-- Requires oxmysql; set to false to disable logging entirely.
Config.EnableDatabaseLog = true

-- Client-side scratch sound while dragging. Synthesized in the NUI with the Web Audio API (a short
-- filtered noise burst) rather than shipping/loading an audio file, so there's nothing external to
-- fetch and nothing that can go missing. No win/lose jingle, per your call - scratch sound only.
Config.ScratchSound = true

-- Emoji set used for Game 2 (Match 4 Symbols). Purely cosmetic - order doesn't matter.
Config.BonusIcons = { '🍀', '⭐', '💰', '🔔', '🍇', '7️⃣', '💎', '🎲' }

-- Each tier = one ox_inventory item. Add a matching entry to your ox_inventory items.lua
-- (see README.md in this resource for a ready-to-paste snippet) using the same `item` name.
--
-- `game` picks which Game 1 mechanic this tier plays - see server/main.lua's Games table for the
-- exact rules of each. Game 2 (Match 4 Symbols, the bonus panel) is the same for every tier
-- regardless of `game`, driven by winChance * bonusChanceMult below.
--
--   'classic'    - match 3 identical amounts in a 3x3 grid.
--   'star'       - 8 panels, find the single ⭐ to win the prize it's hiding.
--   'banker'     - your 3 numbers vs. the banker's 1 - beat it with any of yours to win.
--   'multiplier' - classic match-3 plus a separate multiplier panel; the match-3 prize (if any)
--                  is multiplied by whatever the multiplier panel reveals.
--   'numbers'    - scratch 10 winning numbers and 20 of your own; the prize is set by how many
--                  of your numbers matched (see matchWeights/matchPrizes below).
--   'bingo'      - a 5x5 grid with a free centre gem; scratch the caller's numbers, then complete
--                  a row/column/diagonal for the prize printed alongside it (lines through the
--                  gem pay double).
--
-- prizes = { {value, weight}, ... } - weight is relative, doesn't need to add to 100. Used by
--   'classic', 'star', 'banker' and 'multiplier' (as the match-3 prize before any multiplier).
-- winChance = chance [0-1] that Game 1 lands a win on a given card. For 'numbers' and 'bingo' this
--   only affects Game 2 (the bonus panel) - their own win odds come from matchWeights/matchPrizes
--   or the line-completion roll described in server/main.lua instead.
-- bonusChanceMult = Game 2's win chance is winChance * bonusChanceMult (kept lower than
--   Game 1 since it's a bonus on top).
Config.Tiers = {
  {
    id = 't1', item = 'scratchcard_1', name = 'Lucky Sevens', strap = 'Instant win', game = 'classic',
    price = 1, color = '#c0392b', top = 500, symbol = '£',
    prizes = { { 1, 40 }, { 2, 25 }, { 5, 15 }, { 10, 10 }, { 20, 6 }, { 50, 2.5 }, { 100, 1 }, { 500, 0.15 } },
    winChance = 0.28, bonusChanceMult = 0.6,
  },
  {
    id = 't2', item = 'scratchcard_2', name = 'Cash Cascade', strap = 'Money drop', game = 'classic',
    price = 2, color = '#1c4c82', top = 2000, symbol = '£',
    prizes = { { 2, 38 }, { 4, 24 }, { 10, 15 }, { 20, 10 }, { 50, 6.5 }, { 100, 3.5 }, { 250, 1.5 }, { 2000, 0.1 } },
    winChance = 0.26, bonusChanceMult = 0.6,
  },
  {
    id = 't3', item = 'scratchcard_3', name = 'Silver Spinner', strap = 'Spin to reveal', game = 'classic',
    price = 3, color = '#3a4249', top = 5000, symbol = '£',
    prizes = { { 3, 36 }, { 6, 23 }, { 15, 15 }, { 30, 11 }, { 75, 7 }, { 150, 4 }, { 500, 1.8 }, { 5000, 0.08 } },
    winChance = 0.24, bonusChanceMult = 0.6,
  },
  {
    id = 't4', item = 'scratchcard_4', name = 'Diamond Sevens', strap = 'Premium edition', game = 'classic',
    price = 5, color = '#4a2f8f', top = 20000, symbol = '£',
    prizes = { { 5, 35 }, { 10, 22 }, { 25, 16 }, { 50, 11 }, { 100, 7.5 }, { 250, 4.5 }, { 1000, 2 }, { 20000, 0.05 } },
    winChance = 0.22, bonusChanceMult = 0.6,
  },
  {
    id = 't5', item = 'scratchcard_5', name = 'Emerald Millions', strap = 'Top prize £250,000', game = 'classic',
    price = 10, color = '#0f3d2a', top = 250000, symbol = '£',
    prizes = { { 10, 33 }, { 20, 21 }, { 50, 17 }, { 100, 12 }, { 250, 8 }, { 1000, 4.5 }, { 5000, 2 }, { 250000, 0.02 } },
    winChance = 0.20, bonusChanceMult = 0.6,
  },
  {
    id = 't6', item = 'scratchcard_star', name = 'Find The Star', strap = 'Spot the ⭐', game = 'star',
    price = 2, color = '#1b1b1b', top = 5000, symbol = '£',
    prizes = { { 2, 40 }, { 5, 25 }, { 10, 15 }, { 25, 10 }, { 50, 6 }, { 100, 2.5 }, { 500, 1 }, { 5000, 0.1 } },
    winChance = 0.24, bonusChanceMult = 0.6,
  },
  {
    id = 't7', item = 'scratchcard_banker', name = 'Beat The Banker', strap = 'You vs. the banker', game = 'banker',
    price = 3, color = '#4a1f6b', top = 10000, symbol = '£',
    prizes = { { 3, 38 }, { 6, 24 }, { 15, 15 }, { 30, 11 }, { 75, 6.5 }, { 150, 3.5 }, { 750, 1.8 }, { 10000, 0.08 } },
    winChance = 0.30, bonusChanceMult = 0.6,
  },
  {
    id = 't8', item = 'scratchcard_multiplier', name = 'Cash Multiplier', strap = 'Multiply your win', game = 'multiplier',
    price = 5, color = '#7c2d8f', top = 50000, symbol = '£',
    prizes = { { 5, 35 }, { 10, 22 }, { 25, 16 }, { 50, 11 }, { 100, 7.5 }, { 250, 4.5 }, { 1000, 2 }, { 5000, 0.08 } },
    winChance = 0.24, bonusChanceMult = 0.6,
    -- The match-3 prize above gets multiplied by whichever of these lands (only rolled when the
    -- match-3 itself won something - see buildMultiplier in server/main.lua).
    multipliers = { { 1, 50 }, { 2, 25 }, { 5, 15 }, { 10, 8 }, { 25, 2 } },
  },
  {
    id = 't9', item = 'scratchcard_numbers', name = 'Match Your Numbers', strap = 'Match & win', game = 'numbers',
    price = 3, color = '#0f6659', top = 15000, symbol = '£',
    -- `prizes` isn't used to build Game 1 for this game type (matchWeights/matchPrizes below do
    -- that) - it's only here to give Game 2 (the bonus panel, shared by every tier) something to
    -- draw its own prize amount from.
    prizes = { { 2, 38 }, { 5, 24 }, { 15, 15 }, { 30, 11 }, { 75, 6.5 }, { 150, 3.5 }, { 750, 1.8 }, { 15000, 0.08 } },
    winChance = 0.24, bonusChanceMult = 0.6, -- only used for Game 2 here, see the comment above
    -- How many of your 20 numbers land on the 10 winning numbers, and what each count pays.
    matchWeights = { { 1, 50 }, { 2, 28 }, { 3, 14 }, { 4, 6 }, { 6, 0.15 } },
    matchPrizes = { [1] = 0, [2] = 2, [3] = 15, [4] = 100, [6] = 15000 },
  },
  {
    id = 't10', item = 'scratchcard_bingo', name = 'Jewel Bingo', strap = 'Scratch to win', game = 'bingo',
    price = 3, color = '#7a0f1f', top = 300000, symbol = '£',
    -- Same note as above: only feeds Game 2's bonus prize, not the bingo grid itself.
    prizes = { { 2, 38 }, { 5, 24 }, { 15, 15 }, { 30, 11 }, { 75, 6.5 }, { 150, 3.5 }, { 750, 1.8 }, { 300000, 0.05 } },
    winChance = 0.32, bonusChanceMult = 0.6, -- chance a card contains ANY completed line
  },
}