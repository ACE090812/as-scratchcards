-- Server-authoritative scratchcard outcomes. The card is fully decided here the instant the item
-- is used; the client only ever receives the final result to animate/reveal. Nothing about win/lose
-- is ever decided or trusted client-side.

local tiersById = {}
for _, tier in ipairs(Config.Tiers) do tiersById[tier.id] = tier end

-- [source] = { tierId, cells, win, bonusIcons, bonusPrize, bonusWin }
local pending = {}

-- Soft daily payout cap tracking. [identifier] = { day = 'YYYY-MM-DD', total = number }. In-memory
-- only (see the comment on Config.DailyPayoutCap in config.lua) - resets on restart or day change.
local dailyTotals = {}

math.randomseed(os.time() + GetGameTimer())

local function getIdentifier(src)
  local id = GetPlayerIdentifierByType(src, 'license')
  return id or ('src:' .. tostring(src))
end

local function today()
  return os.date('%Y-%m-%d')
end

--- Adds `amount` to the player's running total for today and returns true if that total is now
--- over Config.DailyPayoutCap (or if the cap is disabled, always returns false).
local function trackDailyPayout(identifier, amount)
  if Config.DailyPayoutCap <= 0 then return false end
  local d = today()
  local entry = dailyTotals[identifier]
  if not entry or entry.day ~= d then
    entry = { day = d, total = 0 }
    dailyTotals[identifier] = entry
  end
  entry.total = entry.total + amount
  return entry.total > Config.DailyPayoutCap
end

local function weightedPick(prizes)
  local total = 0
  for _, p in ipairs(prizes) do total = total + p[2] end
  local r = math.random() * total
  local acc = 0
  for _, p in ipairs(prizes) do
    acc = acc + p[2]
    if r <= acc then return p[1] end
  end
  return prizes[#prizes][1]
end

local function shuffledIndexes(n)
  local t = {}
  for i = 1, n do t[i] = i end
  for i = n, 2, -1 do
    local j = math.random(i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end

--- Fisher-Yates shuffle of a plain 1..n value array, in place. Used by the newer game types below
--- for pools bigger than the 9-cell grid shuffledIndexes() was written for.
local function shuffleValues(t)
  for i = #t, 2, -1 do
    local j = math.random(i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end

local function buildClassic(tier)
  local cells = {}
  local win = math.random() < tier.winChance
  if win then
    local prize = weightedPick(tier.prizes)
    local idx = shuffledIndexes(9)
    local winnerSlots = { idx[1], idx[2], idx[3] }
    local winnerSet = { [winnerSlots[1]] = true, [winnerSlots[2]] = true, [winnerSlots[3]] = true }
    for _, i in ipairs(winnerSlots) do cells[i] = prize end

    -- Filler values are picked from every OTHER prize amount, never the winning one. Picking from
    -- the full list (including `prize`) let a filler cell land on the same amount as the winning
    -- triple - e.g. 4 or 5 "£10" cells on screen when only 3 of them actually won anything, with no
    -- visual way to tell which 3 counted. Filtering the pool up front removes that ambiguity
    -- entirely instead of trying to reject duplicates after the fact.
    local fillerPrizes = {}
    for _, p in ipairs(tier.prizes) do
      if p[1] ~= prize then fillerPrizes[#fillerPrizes + 1] = p end
    end
    if #fillerPrizes == 0 then fillerPrizes = tier.prizes end -- degenerate 1-prize config fallback

    local counts = {}
    for i = 1, 9 do
      if not winnerSet[i] then
        local v, tries = nil, 0
        repeat
          v = weightedPick(fillerPrizes)
          tries = tries + 1
        until (counts[v] or 0) < 2 or tries >= 8
        counts[v] = (counts[v] or 0) + 1
        cells[i] = v
      end
    end
    return cells, prize
  else
    local counts = {}
    for i = 1, 9 do
      local v, tries = nil, 0
      repeat
        v = weightedPick(tier.prizes)
        tries = tries + 1
      until (counts[v] or 0) < 2 or tries >= 8
      counts[v] = (counts[v] or 0) + 1
      cells[i] = v
    end
    return cells, 0
  end
end

--- "Find The Star": 8 icon panels, at most one of which is the star. Filler icons are drawn from a
--- pool that never contains the star glyph at all, so a filler can never accidentally look like a
--- second star.
local STAR_FILLER_ICONS = { '🔔', '🍀', '💎', '🍇', '7️⃣', '💰', '🍒', '🔷' }
local STAR_ICON = '⭐'
local function buildStar(tier)
  local win = math.random() < tier.winChance
  local panels = {}
  if win then
    local prize = weightedPick(tier.prizes)
    local starIndex = math.random(8)
    for i = 1, 8 do
      panels[i] = (i == starIndex) and STAR_ICON or STAR_FILLER_ICONS[math.random(#STAR_FILLER_ICONS)]
    end
    return { panels = panels, starIndex = starIndex }, prize
  else
    for i = 1, 8 do
      panels[i] = STAR_FILLER_ICONS[math.random(#STAR_FILLER_ICONS)]
    end
    return { panels = panels, starIndex = 0 }, 0
  end
end

--- "Beat The Banker": your 3 numbers vs. the banker's 1 - beat it with any of yours to win. The
--- banker is capped at 90 (out of 1-99) so there's always headroom above it for a winning draw
--- regardless of where it lands. On a losing card every one of your numbers is drawn from strictly
--- below the banker's, so none of them can accidentally beat it.
local function buildBanker(tier)
  local win = math.random() < tier.winChance
  local banker = math.random(1, 90)
  local yours = {}
  if win then
    local beatSlot = math.random(3)
    for i = 1, 3 do
      if i == beatSlot then
        yours[i] = math.random(banker + 1, 99)
      else
        yours[i] = math.random(1, banker)
      end
    end
    local prize = weightedPick(tier.prizes)
    return { yourNumbers = yours, bankerNumber = banker }, prize
  else
    for i = 1, 3 do yours[i] = math.random(1, banker) end
    return { yourNumbers = yours, bankerNumber = banker }, 0
  end
end

--- "Cash Multiplier": a normal classic match-3 card, plus a separate multiplier panel that's only
--- meaningful when the match-3 itself won something - a multiplier on a £0 base is still £0.
local DEFAULT_MULTIPLIERS = { { 1, 50 }, { 2, 25 }, { 5, 15 }, { 10, 8 }, { 25, 2 } }
local function buildMultiplier(tier)
  local cells, baseWin = buildClassic(tier)
  local mult = weightedPick(tier.multipliers or DEFAULT_MULTIPLIERS)
  local total = baseWin > 0 and (baseWin * mult) or 0
  return { cells = cells, multiplier = mult }, total
end

--- "Match Your Numbers": 10 winning numbers + 20 of your own out of a 1-45 pool. How many of your
--- numbers land on the winning list is picked first (via matchWeights), then exactly that many
--- "your number" slots are filled from the winning list and every other slot is filled from the
--- remainder of the pool that was never drawn as a winning number - so a filler slot can never
--- accidentally bump the match count up by landing on a winning value it wasn't supposed to.
local DEFAULT_MATCH_WEIGHTS = { { 1, 50 }, { 2, 28 }, { 3, 14 }, { 4, 6 }, { 6, 0.15 } }
local DEFAULT_MATCH_PRIZES = { [1] = 0, [2] = 2, [3] = 15, [4] = 100, [6] = 15000 }
local function buildNumbers(tier)
  local pool = {}
  for i = 1, 45 do pool[i] = i end
  shuffleValues(pool)

  local winningNumbers = {}
  for i = 1, 10 do winningNumbers[i] = pool[i] end
  local restPool = {}
  for i = 11, 45 do restPool[#restPool + 1] = pool[i] end -- 35 numbers guaranteed NOT a winning number

  local matchWeights = tier.matchWeights or DEFAULT_MATCH_WEIGHTS
  local matchPrizes = tier.matchPrizes or DEFAULT_MATCH_PRIZES
  local matchCount = weightedPick(matchWeights)

  local winCopy = {}
  for i = 1, 10 do winCopy[i] = winningNumbers[i] end
  shuffleValues(winCopy)

  local yourNumbers = {}
  for i = 1, matchCount do yourNumbers[i] = winCopy[i] end
  for i = matchCount + 1, 20 do yourNumbers[i] = restPool[i - matchCount] end
  shuffleValues(yourNumbers)

  return { winningNumbers = winningNumbers, yourNumbers = yourNumbers }, matchPrizes[matchCount] or 0
end

--- "Jewel Bingo": a 5x5 grid with a free centre gem (index 13 in this 1-indexed layout). Scratch
--- the caller's numbers, then complete a row/column/diagonal for the prize printed alongside it -
--- a line through the gem panel pays double. Caller fillers (when there's no winning line, or to
--- pad out a winning line's caller numbers to a fixed count) are drawn only from the 51 numbers
--- that were never placed on the grid, so scratching them can never complete a second line by
--- accident - the same exclude-the-placed-pool pattern used by every other game type here.
local BINGO_ROW_PRIZE = { 2, 5, 10, 20, 50 }
local BINGO_COL_PRIZE = { 5, 10, 20, 50, 100 }
local BINGO_DIAG_PRIZE = { 20, 50 }
local BINGO_CENTER = 13
local function bingoLines()
  local rows, cols = {}, {}
  for r = 0, 4 do
    local row = {}
    for c = 1, 5 do row[c] = r * 5 + c end
    rows[#rows + 1] = row
  end
  for c = 1, 5 do
    local col = {}
    for r = 0, 4 do col[r + 1] = r * 5 + c end
    cols[#cols + 1] = col
  end
  local diags = { { 1, 7, 13, 19, 25 }, { 5, 9, 13, 17, 21 } }
  return rows, cols, diags
end
local function lineKey(line)
  return table.concat(line, ',')
end
local function buildBingo(tier)
  local rows, cols, diags = bingoLines()
  local linePrize, allLines = {}, {}
  for i, l in ipairs(rows) do linePrize[lineKey(l)] = BINGO_ROW_PRIZE[i]; allLines[#allLines + 1] = l end
  for i, l in ipairs(cols) do linePrize[lineKey(l)] = BINGO_COL_PRIZE[i]; allLines[#allLines + 1] = l end
  for i, l in ipairs(diags) do linePrize[lineKey(l)] = BINGO_DIAG_PRIZE[i]; allLines[#allLines + 1] = l end

  local pool = {}
  for n = 1, 75 do pool[n] = n end
  shuffleValues(pool)

  local grid = {}
  grid[BINGO_CENTER] = 'FREE'
  local gi = 1
  for i = 1, 25 do
    if i ~= BINGO_CENTER then
      grid[i] = pool[gi]
      gi = gi + 1
    end
  end
  local restPool = {}
  for i = 25, 75 do restPool[#restPool + 1] = pool[i] end -- 51 numbers guaranteed NOT on the grid

  local gemIndex
  repeat gemIndex = math.random(25) until gemIndex ~= BINGO_CENTER

  local winLine, winAmount = nil, 0
  if math.random() < tier.winChance then
    winLine = allLines[math.random(#allLines)]
    winAmount = linePrize[lineKey(winLine)]
    for _, idx in ipairs(winLine) do
      if idx == gemIndex then
        winAmount = winAmount * 2
        break
      end
    end
  end

  local callerCount = 20
  local caller = {}
  if winLine then
    local needed = 0
    for _, idx in ipairs(winLine) do
      if idx ~= BINGO_CENTER then
        needed = needed + 1
        caller[#caller + 1] = grid[idx]
      end
    end
    for i = 1, callerCount - needed do caller[#caller + 1] = restPool[i] end
  else
    for i = 1, callerCount do caller[#caller + 1] = restPool[i] end
  end
  shuffleValues(caller)

  return { grid = grid, caller = caller, gemIndex = gemIndex, winLine = winLine }, winAmount
end

local Games = {
  classic = buildClassic,
  star = buildStar,
  banker = buildBanker,
  multiplier = buildMultiplier,
  numbers = buildNumbers,
  bingo = buildBingo,
}

local function buildGame2(tier)
  local win = math.random() < (tier.winChance * tier.bonusChanceMult)
  local prize = weightedPick(tier.prizes)
  local icons = {}
  if win then
    local icon = Config.BonusIcons[math.random(#Config.BonusIcons)]
    for i = 1, 4 do icons[i] = icon end
  else
    repeat
      icons = {}
      for i = 1, 4 do icons[i] = Config.BonusIcons[math.random(#Config.BonusIcons)] end
    until not (icons[1] == icons[2] and icons[2] == icons[3] and icons[3] == icons[4])
  end
  return icons, prize, win
end

local function generateOutcome(tier)
  local builder = Games[tier.game] or Games.classic
  local game1, win = builder(tier)
  local bonusIcons, bonusPrize, bonusWin = buildGame2(tier)
  return {
    tierId = tier.id,
    game = tier.game or 'classic',
    game1 = game1,
    win = win,
    bonusIcons = bonusIcons,
    bonusPrize = bonusPrize,
    bonusWin = bonusWin,
  }
end

local function startCard(src, tier)
  if pending[src] then
    -- Already has a card open client-side; don't hand out a second one until it's resolved.
    return false
  end
  local result = generateOutcome(tier)
  pending[src] = result
  TriggerClientEvent('as-scratchcard:client:open', src, tier, result)
  return true
end

-- qb-inventory: qb-core's own usable-item registration, entirely server-side (see
-- server/inventory.lua). ox_inventory: the item's client export in client/main.lua verifies +
-- consumes the item via exports.ox_inventory:useItem, THEN fires the event below - see that file's
-- top-of-file comment for why ox_inventory doesn't get registered here the same way.
for _, tier in ipairs(Config.Tiers) do
  Inventory.RegisterUsableItem(tier.item, function(src)
    startCard(src, tier)
  end)
end

RegisterNetEvent('as-scratchcard:server:useItem', function(itemName)
  local src = source
  local tier = nil
  for _, t in ipairs(Config.Tiers) do
    if t.item == itemName then tier = t break end
  end
  if not tier then return end -- not one of our items - ignore
  startCard(src, tier)
end)

RegisterNetEvent('as-scratchcard:server:claim', function()
  local src = source
  local result = pending[src]
  if not result then return end
  pending[src] = nil

  local tier = tiersById[result.tierId]
  local total = (result.win or 0) + ((result.bonusWin and result.bonusPrize) or 0)
  local identifier = getIdentifier(src)
  local overCap = total > 0 and trackDailyPayout(identifier, total) or false

  if total > 0 then
    Bridge.AddMoney(src, total, Config.Currency)
  end
  TriggerClientEvent('as-scratchcard:client:claimed', src, total)

  local playerName = GetPlayerName(src) or ('Player ' .. src)
  Log.RecordPlay({
    identifier = identifier,
    playerName = playerName,
    tierId = result.tierId,
    price = tier and tier.price or 0,
    win = result.win,
    bonusWin = result.bonusWin and result.bonusPrize or 0,
    totalWin = total,
    cells = result.game1, -- the DB column is still named `cells` for compatibility, but now stores
                          -- whatever generic Game 1 payload this tier's `game` type produced.
    bonusIcons = result.bonusIcons,
    overCap = overCap,
  })
  Webhook.AnnounceWin({
    playerName = playerName,
    tierId = result.tierId,
    tierName = tier and tier.name,
    price = tier and tier.price,
    totalWin = total,
    overCap = overCap,
  })
end)

RegisterNetEvent('as-scratchcard:server:cancel', function()
  local src = source
  pending[src] = nil
end)

AddEventHandler('playerDropped', function()
  pending[source] = nil
end)