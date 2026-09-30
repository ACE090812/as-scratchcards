local uiOpen = false

-- ox_inventory's current usable-item API is CLIENT-driven: an item's data/items.lua entry points at
-- a client export (`client = { export = 'as-scratchcard.scratchcard_1' }`), ox_inventory calls that
-- export when the item is used, and the export is expected to call `exports.ox_inventory:useItem`
-- itself to verify + consume the item server-side before doing anything. There is no
-- `RegisterUsableItem` server export in current ox_inventory - that was wrong in an earlier version
-- of this file and threw "No such export" for every use. This is unconditional and harmless if
-- you're on qb-inventory instead: ox_inventory is the only thing that would ever call these
-- exports, so on a qb-inventory server they simply never fire (qb-core's own usable-item
-- registration in server/inventory.lua handles that case separately, server-side, unaffected by
-- any of this).
for _, tier in ipairs(Config.Tiers) do
  exports(tier.item, function(data, slot)
    local ok, invExport = pcall(function() return exports.ox_inventory end)
    if not ok or not invExport or not invExport.useItem then return end
    invExport:useItem(data, function(verified)
      if not verified then return end
      TriggerServerEvent('as-scratchcard:server:useItem', tier.item)
    end)
  end)
end

RegisterNetEvent('as-scratchcard:client:open', function(tier, result)
  if uiOpen then return end
  uiOpen = true
  SetNuiFocus(true, true)
  SendNUIMessage({
    action = 'open',
    tier = tier,
    result = result,
    scratchSound = Config.ScratchSound,
  })
end)

RegisterNetEvent('as-scratchcard:client:claimed', function(total)
  SendNUIMessage({ action = 'claimed', total = total })
end)

local function closeUi(cancel)
  if not uiOpen then return end
  uiOpen = false
  SetNuiFocus(false, false)
  if cancel then TriggerServerEvent('as-scratchcard:server:cancel') end
end

RegisterNUICallback('close', function(_, cb)
  closeUi(false)
  cb('ok')
end)

RegisterNUICallback('cancel', function(_, cb)
  closeUi(true)
  cb('ok')
end)

RegisterNUICallback('claim', function(_, cb)
  TriggerServerEvent('as-scratchcard:server:claim')
  cb('ok')
end)

-- Safety net: if the resource gets restarted/stopped while a card is open, don't leave the player
-- stuck with NUI focus and an unclickable screen.
AddEventHandler('onResourceStop', function(resName)
  if resName == GetCurrentResourceName() and uiOpen then
    SetNuiFocus(false, false)
  end
end)
