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

local function buildGame1(tier)
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
  local cells, win = buildGame1(tier)
  local bonusIcons, bonusPrize, bonusWin = buildGame2(tier)
  return {
    tierId = tier.id,
    cells = cells,
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
    cells = result.cells,
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