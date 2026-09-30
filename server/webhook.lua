-- Discord webhook: fires for every win (any size), per your call. Silently no-ops if
-- Config.DiscordWebhook is blank.
Webhook = {}

function Webhook.AnnounceWin(data)
  if not Config.DiscordWebhook or Config.DiscordWebhook == '' then return end
  if (data.totalWin or 0) <= 0 then return end

  local title = data.overCap and '🎟️ Scratchcard win (over daily cap)' or '🎟️ Scratchcard win'
  local desc = ('**%s** won **£%s** on a **%s** (£%s) card%s'):format(
    data.playerName or 'Unknown',
    data.totalWin,
    data.tierName or data.tierId,
    data.price or '?',
    data.overCap and ' — over their configured daily cap' or ''
  )

  PerformHttpRequest(Config.DiscordWebhook, function() end, 'POST', json.encode({
    embeds = { {
      title = title,
      description = desc,
      color = data.overCap and 15158332 or 3066993, -- red-ish if over cap, green otherwise
      timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    } },
  }), { ['Content-Type'] = 'application/json' })
end
