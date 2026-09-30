-- Audit log: every card played (win or lose), including the full grid/bonus result, via oxmysql.
Log = {}

CreateThread(function()
  if not Config.EnableDatabaseLog then return end
  local ok = pcall(function()
    exports.oxmysql:execute([[
      CREATE TABLE IF NOT EXISTS `as_scratchcard_logs` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `identifier` VARCHAR(64) NOT NULL,
        `player_name` VARCHAR(128) NOT NULL,
        `tier_id` VARCHAR(16) NOT NULL,
        `price` INT NOT NULL,
        `win` INT NOT NULL DEFAULT 0,
        `bonus_win` INT NOT NULL DEFAULT 0,
        `total_win` INT NOT NULL DEFAULT 0,
        `cells` TEXT NULL,
        `bonus_icons` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL,
        `over_daily_cap` TINYINT(1) NOT NULL DEFAULT 0,
        `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `identifier_idx` (`identifier`)
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    ]])
  end)
  if not ok then
    print('^1[as-scratchcard]^7 Could not create as_scratchcard_logs table - is oxmysql started? Database logging disabled for this session.')
    Config.EnableDatabaseLog = false
    return
  end

  -- Self-heal: if this table already existed from before bonus_icons was made utf8mb4 (emoji need
  -- 4-byte-per-character support; most MySQL/MariaDB defaults are 3-byte utf8 and reject them with
  -- "Incorrect string value" on every insert that has an emoji), widen it now. Harmless/no-op if
  -- it's already utf8mb4.
  pcall(function()
    exports.oxmysql:execute([[
      ALTER TABLE `as_scratchcard_logs`
      MODIFY `bonus_icons` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL;
    ]])
  end)
end)

--- Fire-and-forget insert. Never throws into the caller if oxmysql/the table isn't available.
function Log.RecordPlay(data)
  if not Config.EnableDatabaseLog then return end
  pcall(function()
    exports.oxmysql:insert('INSERT INTO as_scratchcard_logs (identifier, player_name, tier_id, price, win, bonus_win, total_win, cells, bonus_icons, over_daily_cap) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
      data.identifier,
      data.playerName,
      data.tierId,
      data.price,
      data.win or 0,
      data.bonusWin or 0,
      data.totalWin or 0,
      json.encode(data.cells or {}),
      json.encode(data.bonusIcons or {}),
      data.overCap and 1 or 0,
    })
  end)
end
