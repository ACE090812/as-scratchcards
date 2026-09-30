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
Config.DiscordWebhook = 'https://discord.com/api/webhooks/1554924936999600158/7e6P8khI3EA0DlLyPt_pxT9IaLHH-QR2vxZC9pDEb2eRK_3jR4vw206sTj0pjSIaFt4J'

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
-- prizes = { {value, weight}, ... } - weight is relative, doesn't need to add to 100.
-- winChance = chance [0-1] that Game 1 (match 3) lands a winning triple on a given card.
-- bonusChanceMult = Game 2's win chance is winChance * bonusChanceMult (kept lower than
--   Game 1 since it's a bonus on top).
Config.Tiers = {
  {
    id = 't1', item = 'scratchcard_1', name = 'Lucky Sevens', strap = 'Instant win',
    price = 1, color = '#c0392b', top = 500, symbol = '£',
    prizes = { { 1, 40 }, { 2, 25 }, { 5, 15 }, { 10, 10 }, { 20, 6 }, { 50, 2.5 }, { 100, 1 }, { 500, 0.15 } },
    winChance = 0.28, bonusChanceMult = 0.6,
  },
  {
    id = 't2', item = 'scratchcard_2', name = 'Cash Cascade', strap = 'Money drop',
    price = 2, color = '#1c4c82', top = 2000, symbol = '£',
    prizes = { { 2, 38 }, { 4, 24 }, { 10, 15 }, { 20, 10 }, { 50, 6.5 }, { 100, 3.5 }, { 250, 1.5 }, { 2000, 0.1 } },
    winChance = 0.26, bonusChanceMult = 0.6,
  },
  {
    id = 't3', item = 'scratchcard_3', name = 'Silver Spinner', strap = 'Spin to reveal',
    price = 3, color = '#3a4249', top = 5000, symbol = '£',
    prizes = { { 3, 36 }, { 6, 23 }, { 15, 15 }, { 30, 11 }, { 75, 7 }, { 150, 4 }, { 500, 1.8 }, { 5000, 0.08 } },
    winChance = 0.24, bonusChanceMult = 0.6,
  },
  {
    id = 't4', item = 'scratchcard_4', name = 'Diamond Sevens', strap = 'Premium edition',
    price = 5, color = '#4a2f8f', top = 20000, symbol = '£',
    prizes = { { 5, 35 }, { 10, 22 }, { 25, 16 }, { 50, 11 }, { 100, 7.5 }, { 250, 4.5 }, { 1000, 2 }, { 20000, 0.05 } },
    winChance = 0.22, bonusChanceMult = 0.6,
  },
  {
    id = 't5', item = 'scratchcard_5', name = 'Emerald Millions', strap = 'Top prize £250,000',
    price = 10, color = '#0f3d2a', top = 250000, symbol = '£',
    prizes = { { 10, 33 }, { 20, 21 }, { 50, 17 }, { 100, 12 }, { 250, 8 }, { 1000, 4.5 }, { 5000, 2 }, { 250000, 0.02 } },
    winChance = 0.20, bonusChanceMult = 0.6,
  },
}
