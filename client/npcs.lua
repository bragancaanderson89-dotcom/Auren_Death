local controlled={}
local function resolve(netId)
    return NetworkDoesEntityExistWithNetworkId(netId) and NetToPed(netId) or 0
end
-- weaponDamageEvent não existe para dano aplicado ao próprio NPC de rede.
-- entityDamaged fornece os parâmetros sem depender dos índices de cada build.
local reported={}
AddEventHandler('entityDamaged',function(victim,culprit,weapon,baseDamage)
    if not Config.NPC.enabled or culprit~=cache.ped or victim==cache.ped or not DoesEntityExist(victim) or not IsEntityAPed(victim) or IsPedAPlayer(victim) then return end
    if not NetworkGetEntityIsNetworked(victim) or not NetworkHasControlOfEntity(victim) or IsPedPerformingMeleeAction(cache.ped) then return end
    local current=exports.ox_inventory:getCurrentWeapon()
    local metadata=current and current.metadata
    local definition=metadata and Config.Weapons[metadata.apexKind]
    if not definition or not metadata.apexSerial or current.name~=definition.item or type(weapon)~='number' or (weapon & 0xffffffff)~=(definition.hash & 0xffffffff) then return end
    local now=GetGameTimer()
    if reported[victim] and now-reported[victim]<100 then return end
    reported[victim]=now
    TriggerServerEvent('apex_pd:npcLocalHit',PedToNet(victim),weapon)
end)
RegisterNetEvent('apex_pd:npcSentence',function(netId,coords,bucket,settings)
    -- O evento só é enviado pelo servidor para jogadores do bucket da vítima.
    -- Coordenadas são suficientes para o raio; NetToPed pode ainda retornar 0.
    APEX.lightning(function()
        local ped=resolve(netId)
        return ped~=0 and not IsPedAPlayer(ped) and ped or 0
    end,coords,settings,netId*29)
end)
local function cleanup(id,entry)
    local ped=entry.ped
    if DoesEntityExist(ped) and NetworkHasControlOfEntity(ped) and not IsPedAPlayer(ped) then
        FreezeEntityPosition(ped,false)
        SetPedCanRagdoll(ped,entry.ragdoll)
        SetBlockingOfNonTemporaryEvents(ped,false)
        ClearPedTasksImmediately(ped)
    end
    APEX.stopFlame('npc:'..id)
    controlled[id]=nil
end
CreateThread(function()
    while true do
        Wait(250)
        local present={}
        local settings=GlobalState.apexPdSettings or Config.Defaults
        for _,npc in ipairs(GlobalState.apexPdNpcs or {}) do
            local ped=resolve(npc.netId)
            local state=ped~=0 and Entity(ped).state.apexPdNpc
            if ped~=0 and DoesEntityExist(ped) and not IsPedAPlayer(ped) and type(state)=='table' and state.id==npc.id and npc.kind=='silver' then
                present[npc.id]=true
                local entry=controlled[npc.id]
                if entry and entry.ped~=ped then cleanup(npc.id,entry);entry=nil end
                if not entry then entry={ped=ped,ragdoll=CanPedRagdoll(ped)};controlled[npc.id]=entry end
                if settings.fire and #(GetEntityCoords(cache.ped)-GetEntityCoords(ped))<Config.EffectsDistance then APEX.flame('npc:'..npc.id,ped,settings)
                else APEX.stopFlame('npc:'..npc.id) end
                if NetworkHasControlOfEntity(ped) then
                    -- CancelEvent impede replicação do dano, mas o owner pode já
                    -- ter aplicado um headshot local. A prata não mata nesse acerto.
                    if not entry.applied then
                        if GetEntityHealth(ped)<=0 then ResurrectPed(ped);SetEntityHealth(ped,npc.health or 150) end
                        entry.applied=true
                    end
                    if GetEntityHealth(ped)>0 then
                        SetBlockingOfNonTemporaryEvents(ped,true)
                        APEX.keepDown(ped,entry)
                    end
                end
            end
        end
        for id,entry in pairs(controlled) do if not present[id] then cleanup(id,entry) end end
        for ped,time in pairs(reported) do if GetGameTimer()-time>5000 then reported[ped]=nil end end
    end
end)
AddEventHandler('onResourceStop',function(resource)
    if resource~=GetCurrentResourceName() then return end
    for id,entry in pairs(controlled) do cleanup(id,entry) end
end)
