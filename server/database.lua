PD = { ready = false, settings = {}, corpses = {}, locks = {}, suspensions = {}, rainUntil = 0 }
local schema = {
    [[CREATE TABLE IF NOT EXISTS apex_pd_settings (id TINYINT PRIMARY KEY, settings LONGTEXT NOT NULL)]],
    [[CREATE TABLE IF NOT EXISTS apex_pd_weapons (serial VARCHAR(80) PRIMARY KEY, kind VARCHAR(12) NOT NULL, location LONGTEXT, revoked TINYINT NOT NULL DEFAULT 0, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)]],
    [[CREATE TABLE IF NOT EXISTS apex_pd_suspensions (citizenid VARCHAR(50) PRIMARY KEY, expires_at BIGINT NOT NULL, attacker VARCHAR(50), serial VARCHAR(80))]],
    [[CREATE TABLE IF NOT EXISTS apex_pd_deaths (citizenid VARCHAR(50) PRIMARY KEY, status VARCHAR(20) NOT NULL DEFAULT 'pending', attacker VARCHAR(50), serial VARCHAR(80), error TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)]],
    [[CREATE TABLE IF NOT EXISTS apex_pd_audit (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, actor VARCHAR(60), action VARCHAR(50) NOT NULL, detail LONGTEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)]]
}
function PD.audit(actor, action, detail)
    MySQL.insert('INSERT INTO apex_pd_audit (actor, action, detail) VALUES (?, ?, ?)', { tostring(actor or 'system'), action, json.encode(detail or {}) })
end
function PD.getPlayer(id) return exports.qbx_core:GetPlayer(tonumber(id)) end
function PD.samePlayer(id, cid)
    local p = PD.getPlayer(id)
    return p and p.PlayerData.citizenid == cid
end
function PD.isSuspended(id)
    local p=PD.getPlayer(id)
    local expires=p and PD.suspensions[p.PlayerData.citizenid]
    return expires and expires>os.time() or false
end
function PD.admin(id)
    id = tonumber(id)
    if not id or id <= 0 or id % 1 ~= 0 then return false end
    local src = tostring(id)
    if IsPlayerAceAllowed(src, Config.AdminAce) or IsPlayerAceAllowed(src, 'apex.pd.groupAdmin') then return true end
    for _, permission in ipairs(Config.AdminPermissions or {}) do
        if IsPlayerAceAllowed(src, permission) then return true end
    end
    return false
end
function PD.notify(id, text, kind)
    TriggerClientEvent('ox_lib:notify', id, { title = 'Auren Death', description = text, type = kind or 'inform' })
end
function PD.wipe(cid)
    -- Nunca deletar enquanto o core ainda pode salvar este personagem.
    if exports.qbx_core:GetPlayerByCitizenId(cid) then return false, 'Personagem ainda carregado' end
    local ok, err = pcall(function() exports.qbx_core:DeleteCharacter(cid) end)
    if not ok then return false, tostring(err) end
    -- O export oficial é assíncrono e não retorna sucesso. Confirmar no SQL.
    for _ = 1, 40 do
        if not MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ? LIMIT 1', { cid }) then break end
        Wait(250)
    end
    if MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ? LIMIT 1', { cid }) then
        return false, 'DeleteCharacter não concluiu em 10 segundos'
    end
    local queries = {}
    for _, entry in ipairs(Config.ExtraWipeTables) do
        assert(entry.table:match('^[%w_]+$') and entry.column:match('^[%w_]+$'), 'Identificador SQL inválido')
        local exists = MySQL.scalar.await('SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ? LIMIT 1', { entry.table, entry.column })
        if exists then queries[#queries + 1] = { query = ('DELETE FROM `%s` WHERE `%s` = ?'):format(entry.table, entry.column), values = { cid } } end
    end
    queries[#queries + 1] = { query = 'DELETE FROM apex_pd_suspensions WHERE citizenid = ?', values = { cid } }
    queries[#queries + 1] = { query = "UPDATE apex_pd_deaths SET status = 'complete', error = NULL WHERE citizenid = ?", values = { cid } }
    if not MySQL.transaction.await(queries) then return false, 'Falha na transação de tabelas adicionais' end
    return true
end
function PD.retryWipes()
    local jobs = MySQL.query.await("SELECT citizenid FROM apex_pd_deaths WHERE status != 'complete'")
    for _, job in ipairs(jobs) do
        local ok, result, err = pcall(PD.wipe, job.citizenid)
        if not ok or not result then
            local reason = tostring(ok and err or result)
            MySQL.update.await("UPDATE apex_pd_deaths SET status = 'failed', error = ? WHERE citizenid = ?", { reason, job.citizenid })
            print(('[Auren_Death] WIPE pendente %s: %s'):format(job.citizenid, reason))
        end
    end
end
MySQL.ready(function()
    for _, q in ipairs(schema) do MySQL.query.await(q) end
    PD.settings = json.decode(MySQL.scalar.await('SELECT settings FROM apex_pd_settings WHERE id = 1') or '{}')
    for k, v in pairs(Config.Defaults) do if PD.settings[k] == nil then PD.settings[k] = v end end
    PD.ready = true
    GlobalState.apexPdSettings = PD.settings
    PD.loadRegistry()
    PD.retryWipes()
end)
