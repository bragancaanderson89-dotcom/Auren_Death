local npcs, pending = {}, {}
function PD.isNpc(entity)
    if GetEntityType(entity) ~= 1 then return false end
    for _, id in ipairs(GetPlayers()) do if GetPlayerPed(tonumber(id)) == entity then return false end end
    return true
end
local function publish()
    local list = {}
    for _, entry in pairs(npcs) do
        list[#list+1] = { id=entry.id, netId=entry.netId, kind=entry.kind, expires=entry.expires, health=entry.health, bucket=entry.bucket }
    end
    GlobalState.apexPdNpcs = list
end
local function valid(entity, model)
    return DoesEntityExist(entity) and GetEntityModel(entity)==model and PD.isNpc(entity)
end
local function release(entity, entry)
    if valid(entity, entry.model) then
        Entity(entity).state:set('apexPdNpc', false, true)
        FreezeEntityPosition(entity, false)
        SetEntityOrphanMode(entity, 0)
    end
    npcs[entity] = nil
end
function PD.hitNpc(sender, entity, row, willKill)
    if not Config.NPC.enabled or not PD.isNpc(entity) then return end
    local existing = npcs[entity]
    if existing and existing.kind=='gold' then CancelEvent(); return end
    if row.kind=='silver' then CancelEvent() end
    local count=0;for _ in pairs(npcs) do count=count+1 end
    if not existing and count>=Config.NPC.maxActive then return end
    local model=GetEntityModel(entity)
    local bucket=GetEntityRoutingBucket(entity)
    local function record(kind)
        local entry=existing or {id=('npc-%s-%s-%s'):format(entity,GetGameTimer(),math.random(100000,999999)),entity=entity,model=model,netId=NetworkGetNetworkIdFromEntity(entity),bucket=bucket,health=math.max(150,GetEntityHealth(entity))}
        entry.kind=kind
        entry.expires=kind=='silver' and math.max(entry.expires or 0,os.time()+PD.settings.silverMinutes*60) or 0
        npcs[entity]=entry
        SetEntityOrphanMode(entity,2)
        Entity(entity).state:set('apexPdNpc',{id=entry.id,kind=kind,expires=entry.expires},true)
        publish()
        local killer=PD.getPlayer(sender)
        PD.audit(killer and killer.PlayerData.citizenid or 'unknown','npc.'..kind,{netId=entry.netId,model=model,serial=row.serial,expires=entry.expires})
        return entry
    end
    if row.kind=='silver' then
        if existing or GetEntityHealth(entity)>0 or willKill then record('silver') end
    elseif not pending[entity] then
        pending[entity]=true
        CreateThread(function()
            -- A indicação willKill não é confiável para todo dano em NPC.
            -- Observar a morte replicada também quando o acerto veio do owner.
            for _=1,20 do
                Wait(100)
                if not valid(entity,model) then break end
                if GetEntityHealth(entity)<=0 then
                    local entry=record('gold')
                    local c=GetEntityCoords(entity)
                    for _,id in ipairs(GetPlayers()) do
                        id=tonumber(id)
                        if GetPlayerRoutingBucket(id)==bucket then TriggerClientEvent('apex_pd:npcSentence',id,entry.netId,{x=c.x,y=c.y,z=c.z},bucket,PD.settings) end
                    end
                    PD.rain()
                    break
                end
            end
            pending[entity]=nil
        end)
    end
end
local localHitLimit={}
RegisterNetEvent('apex_pd:npcLocalHit',function(netId,weaponHash)
    local sender=source
    if not PD.ready or not Config.NPC.enabled or type(netId)~='number' or netId~=math.floor(netId) or netId<=0 or netId>2147483647 or type(weaponHash)~='number' or weaponHash~=math.floor(weaponHash) or weaponHash<-2147483648 or weaponHash>4294967295 then return end
    local now=GetGameTimer()
    if localHitLimit[sender] and now-localHitLimit[sender]<100 then return end
    localHitLimit[sender]=now
    local row=PD.validWeapon(exports.ox_inventory:GetCurrentWeapon(sender))
    if not row then return end
    local weapon=Config.Weapons[row.kind]
    if (weaponHash & 0xffffffff)~=(weapon.hash & 0xffffffff) or PD.isSuspended(sender) then return end
    local entity=NetworkGetEntityFromNetworkId(netId)
    local shooter=GetPlayerPed(sender)
    if entity==0 or not DoesEntityExist(entity) or shooter==0 or entity==shooter or not PD.isNpc(entity) then return end
    -- Apenas o owner pode relatar o dano local; nunca alcança o fluxo de WIPE.
    if NetworkGetEntityOwner(entity)~=sender or GetEntityRoutingBucket(entity)~=GetPlayerRoutingBucket(sender) then return end
    if #(GetEntityCoords(shooter)-GetEntityCoords(entity))>Config.HitRange or (GetSelectedPedWeapon(shooter) & 0xffffffff)~=(weapon.hash & 0xffffffff) then return end
    for _,body in pairs(PD.corpses) do if body.entity==entity then return end end
    PD.hitNpc(sender,entity,row,GetEntityHealth(entity)<=0)
end)
AddEventHandler('playerDropped',function()localHitLimit[source]=nil end)
CreateThread(function()
    while true do
        Wait(1000)
        local changed=false
        for entity,entry in pairs(npcs) do
            if not valid(entity,entry.model) or (entry.kind=='silver' and entry.expires<=os.time()) then release(entity,entry);changed=true
            else
                local state=Entity(entity).state.apexPdNpc
                if type(state)~='table' or state.id~=entry.id or state.kind~=entry.kind or state.expires~=entry.expires then Entity(entity).state:set('apexPdNpc',{id=entry.id,kind=entry.kind,expires=entry.expires},true) end
            end
        end
        if changed then publish() end
    end
end)
AddEventHandler('onResourceStop',function(resource)
    if resource~=GetCurrentResourceName() then return end
    for entity,entry in pairs(npcs) do release(entity,entry) end
    GlobalState.apexPdNpcs={}
end)
