local cooldown, appearancePending, rainRestore = {}, {}, nil
local function publicBody(body)
    return {id=body.id, netId=body.netId, name=body.name, carrier=body.carrier, bucket=body.bucket, appearance=body.appearance}
end
function PD.publishBodies()
    local list = {}; for _, b in pairs(PD.corpses) do list[#list+1] = publicBody(b) end
    GlobalState.apexPdBodies = list
end
local function rain()
    if not PD.settings.rain then return end
    PD.rainUntil = os.time() + PD.settings.rainMinutes * 60
    if GetResourceState(Config.WeatherResource) == 'started' then
        if not rainRestore then
            local ok, state = pcall(function() return exports[Config.WeatherResource]:getWeatherState() end)
            if ok then rainRestore = state end
        end
        pcall(function() exports[Config.WeatherResource]:setWeather('THUNDER') end)
    end
    GlobalState.apexPdRainUntil = PD.rainUntil
end
PD.rain = rain
local function createBody(target, cid, name)
    local ped = GetPlayerPed(target)
    if ped == 0 then return end
    local c, heading, model = GetEntityCoords(ped), GetEntityHeading(ped), GetEntityModel(ped)
    local corpse = CreatePed(4, model, c.x, c.y, c.z, heading, true, true)
    if corpse == 0 then return end
    SetEntityOrphanMode(corpse, 2)
    local bucket = GetPlayerRoutingBucket(target)
    SetEntityRoutingBucket(corpse, bucket)
    local id = ('body-%s-%s'):format(os.time(), target)
    local body = {id=id, entity=corpse, netId=NetworkGetNetworkIdFromEntity(corpse), citizenid=cid, name=name, bucket=bucket}
    PD.corpses[id] = body
    Entity(corpse).state:set('apexPdBody', id, true)
    local nonce = ('%s-%d'):format(id, math.random(100000,999999))
    appearancePending[target] = {nonce=nonce, body=id, cid=cid}
    TriggerClientEvent('apex_pd:captureAppearance', target, nonce)
    PD.publishBodies()
    return body
end
RegisterNetEvent('apex_pd:appearance', function(nonce, data)
    local src, ticket = source, appearancePending[source]
    if not ticket or nonce ~= ticket.nonce or not PD.samePlayer(src, ticket.cid) or type(data) ~= 'table' then return end
    local body = PD.corpses[ticket.body]
    appearancePending[src] = nil
    if not body then return end
    local clean = {components={}, props={}, head={}}
    for i=1,12 do
        local v=data.components and data.components[i]
        if type(v)=='table' then clean.components[i]={id=i-1, drawable=math.min(1000,math.max(0,tonumber(v.drawable) or 0)), texture=math.min(100,math.max(0,tonumber(v.texture) or 0)), palette=0} end
    end
    for i=1,8 do
        local v=data.props and data.props[i]
        if type(v)=='table' then clean.props[i]={id=i-1, drawable=math.min(1000,math.max(-1,tonumber(v.drawable) or -1)), texture=math.min(100,math.max(0,tonumber(v.texture) or 0))} end
    end
    if type(data.head)=='table' and #json.encode(data.head)<6000 then clean.head=data.head end
    if Config.AppearanceResource and type(data.custom)=='table' and #json.encode(data.custom)<18000 then clean.custom=data.custom end
    body.appearance=clean; PD.publishBodies()
end)
local function permanentDeath(attacker, target, row, cid)
    if PD.locks[cid] or not PD.samePlayer(target,cid) then return end
    PD.locks[cid]=true
    local victim = PD.getPlayer(target).PlayerData
    local killer = PD.getPlayer(attacker)
    local attackerCid = killer and killer.PlayerData.citizenid or 'unknown'
    local inserted = MySQL.insert.await("INSERT IGNORE INTO apex_pd_deaths (citizenid, attacker, serial) VALUES (?, ?, ?)", {cid, attackerCid, row.serial})
    if not inserted then PD.locks[cid]=nil; return end
    if not PD.samePlayer(target,cid) then return end
    local name=(victim.charinfo.firstname or '')..' '..(victim.charinfo.lastname or '')
    local body=createBody(target,cid,name)
    local ped=GetPlayerPed(target); local c=GetEntityCoords(ped)
    TriggerClientEvent('apex_pd:sentence', -1, target, {x=c.x,y=c.y,z=c.z}, GetPlayerRoutingBucket(target), PD.settings)
    Player(target).state:set('apexPdDying', true, true)
    rain()
    PD.audit(attackerCid,'pd.sentence',{victim=cid,serial=row.serial,body=body and body.id})
    Wait(Config.DisconnectDelayMs)
    if PD.samePlayer(target,cid) then
        -- Logout retira da memória antes do WIPE, impedindo autosave de recriar a linha.
        exports.qbx_core:Logout(target)
        DropPlayer(tostring(target),Config.Message)
    end
    for _, owned in pairs(PD.registry) do
        if owned.location and owned.location.citizenid==cid then owned.revoked=true; MySQL.update.await('UPDATE apex_pd_weapons SET revoked=1 WHERE serial=?',{owned.serial}) end
    end
    local ok, result, err=pcall(PD.wipe,cid)
    if not ok or not result then
        local reason=tostring(ok and err or result)
        MySQL.update.await("UPDATE apex_pd_deaths SET status='failed', error=? WHERE citizenid=?",{reason,cid})
        PD.audit('system','pd.wipe_failed',{citizenid=cid,error=reason})
    end
end
local function suspend(attacker,target,row,cid)
    local killer=PD.getPlayer(attacker)
    local expires=os.time()+PD.settings.silverMinutes*60
    MySQL.update.await('INSERT INTO apex_pd_suspensions (citizenid, expires_at, attacker, serial) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE expires_at=GREATEST(expires_at, VALUES(expires_at)), attacker=VALUES(attacker), serial=VALUES(serial)',{cid,expires,killer and killer.PlayerData.citizenid or '',row.serial})
    expires=MySQL.scalar.await('SELECT expires_at FROM apex_pd_suspensions WHERE citizenid=?',{cid})
    PD.suspensions[cid]=expires
    if PD.samePlayer(target,cid) then Player(target).state:set('apexPdSuspended',expires,true); TriggerClientEvent('apex_pd:suspension',target,expires,os.time()) end
    PD.audit(killer and killer.PlayerData.citizenid,'silver.hit',{victim=cid,serial=row.serial,expires=expires})
end
AddEventHandler('weaponDamageEvent',function(sender,data)
    if not PD.ready or type(data)~='table' or type(data.weaponType)~='number' then return end
    local hitEntity=NetworkGetEntityFromNetworkId(data.hitGlobalId or 0)
    if hitEntity~=0 then
        for _,b in pairs(PD.corpses) do if b.entity==hitEntity then CancelEvent(); return end end
    end
    local row=PD.validWeapon(exports.ox_inventory:GetCurrentWeapon(sender))
    if not row then return end
    local weapon=Config.Weapons[row.kind]
    if (data.weaponType & 0xffffffff) ~= (weapon.hash & 0xffffffff) or data.damageType~=3 or data.hitEntityWeapon or data.hitWeaponAmmoAttachment then return end
    local entity=NetworkGetEntityFromNetworkId(data.hitGlobalId or 0)
    if entity==0 or not DoesEntityExist(entity) then return end
    local target=NetworkGetEntityOwner(entity)
    local shooter=GetPlayerPed(sender)
    if shooter==0 or entity==shooter or GetEntityType(entity)~=1 then return end
    if GetPlayerRoutingBucket(sender)~=GetEntityRoutingBucket(entity) then return end
    if #(GetEntityCoords(shooter)-GetEntityCoords(entity))>Config.HitRange then return end
    if (GetSelectedPedWeapon(shooter) & 0xffffffff)~=(weapon.hash & 0xffffffff) then return end
    if PD.isSuspended(sender) then CancelEvent(); return end
    -- NPCs podem pertencer ao próprio atirador; owner não identifica um jogador.
    if not target or target<=0 or GetPlayerPed(target)~=entity then
        if PD.isNpc(entity) then
            local key=sender..':npc:'..entity
            if cooldown[key] and GetGameTimer()-cooldown[key]<Config.HitCooldownMs then if row.kind=='silver' then CancelEvent() end; return end
            cooldown[key]=GetGameTimer()
            PD.hitNpc(sender,entity,row,data.willKill==true)
        end
        return
    end
    if target==sender then return end
    local victim=PD.getPlayer(target)
    if not victim then return end
    local cid=victim.PlayerData.citizenid
    if PD.locks[cid] or PD.isSuspended(sender) then CancelEvent(); return end
    local key=sender..':'..target
    if cooldown[key] and GetGameTimer()-cooldown[key]<Config.HitCooldownMs then if row.kind=='silver' then CancelEvent() end; return end
    cooldown[key]=GetGameTimer()
    if row.kind=='silver' then
        CancelEvent() -- o tiro aplica paralisia; não deixa o damage nativo matar a vítima.
        CreateThread(function() suspend(sender,target,row,cid) end)
    elseif data.willKill then
        -- willKill é enviado pelo cliente. Confirmar morte/laststand replicado antes do WIPE.
        CreateThread(function()
            for _=1,12 do
                Wait(150)
                if not PD.samePlayer(target,cid) then return end
                local p=PD.getPlayer(target)
                if GetEntityHealth(entity)<=0 or p.PlayerData.metadata.isdead or p.PlayerData.metadata.inlaststand then permanentDeath(sender,target,row,cid); return end
            end
        end)
    end
end)
function PD.restorePlayer(id)
    while not PD.ready do Wait(250) end
    local p=PD.getPlayer(id); if not p then return end
    local cid=p.PlayerData.citizenid
    if MySQL.scalar.await('SELECT 1 FROM apex_pd_deaths WHERE citizenid=?',{cid}) then
        if PD.samePlayer(id,cid) then exports.qbx_core:Logout(id); DropPlayer(tostring(id),Config.Message) end
        return
    end
    local expires=MySQL.scalar.await('SELECT expires_at FROM apex_pd_suspensions WHERE citizenid=?',{cid})
    PD.suspensions[cid]=expires
    if not PD.samePlayer(id,cid) then return end
    if expires and expires>os.time() then Player(id).state:set('apexPdSuspended',expires,true); TriggerClientEvent('apex_pd:suspension',id,expires,os.time())
    else Player(id).state:set('apexPdSuspended',false,true); MySQL.update('DELETE FROM apex_pd_suspensions WHERE citizenid=?',{cid}) end
    PD.scanInventory(exports.ox_inventory:GetInventory(id))
end
AddEventHandler('QBCore:Server:OnPlayerLoaded',function(player)
    local id=type(player)=='table' and player.PlayerData and player.PlayerData.source or tonumber(player) or source
    if id and id>0 then CreateThread(function() PD.restorePlayer(id) end) end
end)
local restoreLimit={}
RegisterNetEvent('apex_pd:requestSync',function()
    local id=source
    if restoreLimit[id] and GetGameTimer()-restoreLimit[id]<5000 then return end
    restoreLimit[id]=GetGameTimer(); CreateThread(function() PD.restorePlayer(id) end)
end)
lib.callback.register('apex_pd:carry',function(src,id)
    local b=PD.corpses[id]
    if not b or not DoesEntityExist(b.entity) or GetPlayerRoutingBucket(src)~=b.bucket or PD.isSuspended(src) or Player(src).state.apexPdDying then return false end
    local p=GetPlayerPed(src)
    if p==0 or #(GetEntityCoords(p)-GetEntityCoords(b.entity))>Config.CarryDistance then return false end
    for _, other in pairs(PD.corpses) do if other.carrier==src and other.id~=id then return false end end
    if b.carrier and b.carrier~=src then return false end
    b.carrier=b.carrier==src and nil or src
    Entity(b.entity).state:set('apexPdCarrier',b.carrier or false,true); PD.publishBodies()
    return true
end)
AddEventHandler('playerDropped',function()
    local id=source; appearancePending[id]=nil; restoreLimit[id]=nil
    for _, b in pairs(PD.corpses) do if b.carrier==id then b.carrier=nil; Entity(b.entity).state:set('apexPdCarrier',false,true) end end
    PD.publishBodies()
end)
CreateThread(function()
    while not PD.ready do Wait(250) end
    for _,id in ipairs(GetPlayers()) do PD.restorePlayer(tonumber(id)) end
    local tick=0
    while true do
        Wait(5000); tick=tick+1
        for _,id in ipairs(GetPlayers()) do
            id=tonumber(id)
            local p=PD.getPlayer(id)
            local expires=p and PD.suspensions[p.PlayerData.citizenid]
            if expires and expires>os.time() and Player(id).state.apexPdSuspended~=expires then Player(id).state:set('apexPdSuspended',expires,true) end
            if expires and expires<=os.time() then
                if p then PD.suspensions[p.PlayerData.citizenid]=nil end
                Player(id).state:set('apexPdSuspended',false,true)
                TriggerClientEvent('apex_pd:suspension',id,0,os.time())
                if p then MySQL.update('DELETE FROM apex_pd_suspensions WHERE citizenid=? AND expires_at<=?',{p.PlayerData.citizenid,os.time()}) end
            end
        end
        for _,b in pairs(PD.corpses) do
            if b.carrier then local p=GetPlayerPed(b.carrier); if p==0 or GetEntityHealth(p)<=0 or GetPlayerRoutingBucket(b.carrier)~=b.bucket then b.carrier=nil; Entity(b.entity).state:set('apexPdCarrier',false,true); PD.publishBodies() end end
        end
        if PD.rainUntil>0 and PD.rainUntil<=os.time() then
            PD.rainUntil=0; GlobalState.apexPdRainUntil=0
            if rainRestore and GetResourceState(Config.WeatherResource)=='started' then pcall(function() exports[Config.WeatherResource]:setWeather(rainRestore.weather or rainRestore) end) end
            rainRestore=nil
        end
        if tick%12==0 then cooldown={}; PD.retryWipes() end
    end
end)
AddEventHandler('onResourceStop',function(name)
    if name~=GetCurrentResourceName() then return end
    for _,b in pairs(PD.corpses) do if DoesEntityExist(b.entity) then DeleteEntity(b.entity) end end
    GlobalState.apexPdBodies={}; GlobalState.apexPdRainUntil=0
    if rainRestore and GetResourceState(Config.WeatherResource)=='started' then pcall(function() exports[Config.WeatherResource]:setWeather(rainRestore.weather or rainRestore) end) end
end)
