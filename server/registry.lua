PD.registry, PD.observed = {}, {}
local ox = exports.ox_inventory
function PD.loadRegistry()
    for _, row in ipairs(MySQL.query.await('SELECT * FROM apex_pd_weapons')) do
        row.location = json.decode(row.location or '{}')
        row.revoked = row.revoked == 1
        PD.registry[row.serial] = row
    end
end
function PD.weaponKind(item)
    for kind, def in pairs(Config.Weapons) do if item == def.item then return kind end end
end
function PD.validWeapon(item)
    if not item or not item.metadata then return end
    local serial = item.metadata.apexSerial
    local row = serial and PD.registry[serial]
    if row and not row.revoked and Config.Weapons[row.kind].item == item.name then return row end
end
function PD.location(inv, slot)
    local loc = { id = inv.id, type = inv.type, owner = inv.owner, label = inv.label, slot = slot }
    if inv.type == 'player' then
        local p = PD.getPlayer(inv.id)
        if not p then return end
        loc.citizenid = p.PlayerData.citizenid
        loc.label = (p.PlayerData.charinfo.firstname or '') .. ' ' .. (p.PlayerData.charinfo.lastname or '')
        local ped = GetPlayerPed(inv.id)
        if ped ~= 0 then local c = GetEntityCoords(ped); loc.coords = { x=c.x, y=c.y, z=c.z }; loc.bucket = GetPlayerRoutingBucket(inv.id) end
    elseif inv.coords then
        loc.coords = { x=inv.coords.x, y=inv.coords.y, z=inv.coords.z }
    end
    loc.seenAt = os.time()
    return loc
end
function PD.scanInventory(inv)
    if not inv or not inv.items then return end
    for slot, item in pairs(inv.items) do
        local serial = item.metadata and item.metadata.apexSerial
        local row = serial and PD.registry[serial]
        if row then
            if row.revoked then
                ox:RemoveItem(inv.id, item.name, item.count, item.metadata, slot)
            else
                local loc = PD.location(inv, slot)
                if loc then
                    row.location = loc
                    MySQL.update('UPDATE apex_pd_weapons SET location = ? WHERE serial = ?', { json.encode(loc), serial })
                end
            end
        end
    end
end
function PD.refreshRegistry()
    local scanned = {}
    local function scan(inv) if inv and not scanned[inv.id] then scanned[inv.id] = true; PD.scanInventory(inv) end end
    for _, id in ipairs(GetPlayers()) do scan(ox:GetInventory(tonumber(id))) end
    -- Export presente em versões novas; versões antigas recebem IDs observados por hook.
    for _, t in ipairs({ 'stash', 'trunk', 'glovebox', 'drop', 'container' }) do
        local ok, inventories = pcall(function() return ox:GetInventories(t, true) end)
        if ok and type(inventories) == 'table' then for _, inv in ipairs(inventories) do scan(inv) end end
    end
    for id in pairs(PD.observed) do
        local ok, inv = pcall(function() return ox:GetInventory(id) end)
        if ok then scan(inv) end
    end
end
function PD.issue(actor, target, kind)
    local player = PD.getPlayer(target)
    local def = Config.Weapons[kind]
    if not def or not player then return false, 'Jogador ou revólver inválido' end
    if not ox:CanCarryItem(target, def.item, 1) then return false, 'Inventário sem espaço' end
    local serial = ('APEX-%s-%s'):format(kind:upper(), exports.qbx_core:GenerateUniqueIdentifier('SerialNumber'))
    MySQL.insert.await('INSERT INTO apex_pd_weapons (serial, kind) VALUES (?, ?)', {serial, kind})
    PD.registry[serial] = { serial=serial, kind=kind, revoked=false, location={} }
    local ok, response = ox:AddItem(target, def.item, 1, { serial=serial, apexSerial=serial, apexKind=kind, label=def.label, image=def.image, description=kind == 'gold' and 'Sentença de morte permanente • Série '..serial or 'Suspensão e fogo ritual • Série '..serial, ammo=0, durability=100, registered=false, components={}, tint=0 })
    if not ok then
        PD.registry[serial] = nil
        MySQL.update.await('DELETE FROM apex_pd_weapons WHERE serial = ?', {serial})
        return false, tostring(response)
    end
    PD.scanInventory(ox:GetInventory(target))
    PD.audit(actor, 'weapon.issue', {target=player.PlayerData.citizenid, serial=serial, kind=kind})
    return true, serial
end
function PD.revoke(actor, serial)
    local row = PD.registry[serial]
    if not row then return false, 'Série não encontrada' end
    -- Revogar primeiro impede uso durante a remoção e cobre inventários fechados/offline.
    MySQL.update.await('UPDATE apex_pd_weapons SET revoked = 1 WHERE serial = ?', {serial})
    row.revoked = true
    PD.refreshRegistry()
    PD.audit(actor, 'weapon.revoke', {serial=serial, location=row.location})
    return true, 'Revólver revogado; inventários offline serão limpos ao carregar'
end
function PD.giveAmmo(actor,target,kind,count)
    local def=Config.Weapons[kind]
    count=tonumber(count)
    if not def or not PD.getPlayer(target) or not count or count~=count or count%1~=0 or count<1 or count>250 then return false,'Jogador, munição ou quantidade inválida' end
    if not ox:CanCarryItem(target,def.ammo,count) then return false,'Inventário sem espaço' end
    local ok,response=ox:AddItem(target,def.ammo,count)
    if not ok then return false,tostring(response) end
    PD.audit(actor,'ammo.issue',{target=target,kind=kind,item=def.ammo,count=count})
    return true,('%d munições entregues'):format(count)
end
CreateThread(function()
    while not PD.ready do Wait(250) end
    local filter = {}
    for _, def in pairs(Config.Weapons) do filter[def.item] = true end
    ox:registerHook('swapItems', function(payload)
        local m = payload.fromSlot and payload.fromSlot.metadata
        local row = m and PD.registry[m.apexSerial]
        if row and row.revoked then return false end
        -- Não presumir que a troca teve sucesso. Reconciliar inventários reais depois.
        SetTimeout(250, function()
            for _, id in ipairs({payload.fromInventory, payload.toInventory}) do
                if type(id) == 'table' then id = id.id end
                if id then PD.observed[id] = true; local ok, inv = pcall(function() return ox:GetInventory(id) end); if ok then PD.scanInventory(inv) end end
            end
        end)
    end, {itemFilter=filter})
    ox:registerHook('usingItem', function(payload)
        local m = payload.item and payload.item.metadata
        if m and m.apexSerial and not PD.validWeapon(payload.item) then return false end
        if PD.isSuspended(payload.source) then return false end
    end, {itemFilter=filter})
    while true do PD.refreshRegistry(); Wait(Config.RegistryRefreshMs) end
end)
