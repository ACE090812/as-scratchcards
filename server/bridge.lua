-- Framework-agnostic payout bridge: qbox (qbx_core), qb-core, or ESX. Detected once at resource
-- start from whichever core resource is actually running, so this one script works on all three.
Bridge = {}

local framework = nil
local ESX = nil

CreateThread(function()
  if GetResourceState('qbx_core') == 'started' then
    framework = 'qbox'
  elseif GetResourceState('qb-core') == 'started' then
    framework = 'qbcore'
  elseif GetResourceState('es_extended') == 'started' then
    framework = 'esx'
    ESX = exports['es_extended']:getSharedObject()
  else
    framework = nil
    print('^1[as-scratchcard]^7 No supported framework (qbx_core / qb-core / es_extended) detected - payouts will be skipped. Edit server/bridge.lua to add your own.')
  end
end)

--- Pay `amount` into the player's account. Never throws; logs and no-ops if the player can't be found.
function Bridge.AddMoney(src, amount, account)
  account = account or Config.Currency
  amount = math.floor(amount + 0.5)
  if amount <= 0 then return end

  if framework == 'qbox' then
    local Player = exports.qbx_core:GetPlayer(src)
    if Player then Player.Functions.AddMoney(account, amount, 'as-scratchcard-win') end

  elseif framework == 'qbcore' then
    local QBCore = exports['qb-core']:GetCoreObject()
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then Player.Functions.AddMoney(account, amount, 'as-scratchcard-win') end

  elseif framework == 'esx' then
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
      if account == 'bank' then
        xPlayer.addAccountMoney('bank', amount)
      else
        xPlayer.addMoney(amount)
      end
    end

  else
    print(('^1[as-scratchcard]^7 No framework bridge available - would have paid player %s $%s'):format(src, amount))
  end
end
