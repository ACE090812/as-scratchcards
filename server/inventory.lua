-- qb-inventory usable-item registration (server-side, via qb-core). ox_inventory does NOT use this
-- module at all - its usable items are registered client-side (see client/main.lua's top-of-file
-- comment for why: current ox_inventory has no server-side RegisterUsableItem export, it's a
-- client export + exports.ox_inventory:useItem verification flow instead). This file only exists
-- for the qb-inventory/qb-core path.
Inventory = {}

local kind = Config.Inventory

-- Detection RETRIES for up to ~15s instead of checking once, in case qb-core/qb-inventory hasn't
-- finished starting yet when this script runs (this resource doesn't declare a hard `dependencies`
-- entry on it, since ox_inventory servers don't have it at all).
CreateThread(function()
  if kind ~= 'auto' then return end
  local waitedMs = 0
  while true do
    if GetResourceState('qb-inventory') == 'started' or GetResourceState('qb-core') == 'started' then
      kind = 'qb'
      return
    elseif GetResourceState('ox_inventory') == 'started' then
      -- Nothing to register here for ox - client/main.lua's exports handle it entirely.
      kind = 'ox'
      return
    elseif waitedMs >= 15000 then
      kind = nil
      return
    end
    Wait(250)
    waitedMs = waitedMs + 250
  end
end)

--- Registers `itemName` as a usable item on qb-inventory/qb-core. No-ops on ox_inventory (or if
--- neither was detected) - `handler(src)` is called with the using player's server id.
function Inventory.RegisterUsableItem(itemName, handler)
  CreateThread(function()
    while kind == 'auto' do Wait(0) end
    if kind ~= 'qb' then return end

    local ok, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok and QBCore then
      QBCore.Functions.CreateUseableItem(itemName, function(source)
        handler(source)
      end)
    end
  end)
end
