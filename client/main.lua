local savedProofs, lastPed, savedRagdoll, downState=nil,nil,nil,{}
local function applyAppearance(ped,data)
    if not data then return end
    for _,v in pairs(data.components or {}) do SetPedComponentVariation(ped,v.id,v.drawable,v.texture,v.palette or 0) end
    for _,v in pairs(data.props or {}) do if v.drawable<0 then ClearPedProp(ped,v.id) else SetPedPropIndex(ped,v.id,v.drawable,v.texture,true) end end
    local h=data.head or {}
    if h.blend then local b=h.blend; SetPedHeadBlendData(ped,b.shapeFirst,b.shapeSecond,b.shapeThird,b.skinFirst,b.skinSecond,b.skinThird,b.shapeMix,b.skinMix,b.thirdMix,false) end
    for i,value in pairs(h.features or {}) do SetPedFaceFeature(ped,tonumber(i),value) end
    for i,v in pairs(h.overlays or {}) do SetPedHeadOverlay(ped,tonumber(i),v.index,v.opacity); SetPedHeadOverlayColor(ped,tonumber(i),v.colorType,v.color,v.secondColor) end
    if h.hair then SetPedHairColor(ped,h.hair[1],h.hair[2]) end
    if h.eyes then SetPedEyeColor(ped,h.eyes) end
    if Config.AppearanceResource and data.custom then pcall(function() exports[Config.AppearanceResource]:setPedAppearance(ped,data.custom) end) end
end
RegisterNetEvent('apex_pd:captureAppearance',function(nonce)
    local ped=cache.ped
    local data={components={},props={},head={features={},overlays={},hair={GetPedHairColor(ped),GetPedHairHighlightColor(ped)},eyes=GetPedEyeColor(ped)}}
    for i=0,11 do data.components[i+1]={drawable=GetPedDrawableVariation(ped,i),texture=GetPedTextureVariation(ped,i)} end
    for i=0,7 do data.props[i+1]={drawable=GetPedPropIndex(ped,i),texture=GetPedPropTextureIndex(ped,i)} end
    for i=0,19 do data.head.features[tostring(i)]=GetPedFaceFeature(ped,i) end
    for i=0,12 do local ok,index,colorType,color,secondColor,opacity=GetPedHeadOverlayData(ped,i); if ok then data.head.overlays[tostring(i)]={index=index,colorType=colorType,color=color,secondColor=secondColor,opacity=opacity} end end
    local ok,blend=GetPedHeadBlendData(ped)
    if ok then data.head.blend=blend end
    if Config.AppearanceResource then local success,value=pcall(function() return exports[Config.AppearanceResource]:getPedAppearance(ped) end); if success then data.custom=value end end
    TriggerServerEvent('apex_pd:appearance',nonce,data)
end)
local function cleanupSuspension()
    if lastPed and DoesEntityExist(lastPed) then
        FreezeEntityPosition(lastPed,false)
        if savedProofs then SetEntityProofs(lastPed,table.unpack(savedProofs)) end
        ClearPedTasksImmediately(lastPed)
        SetPedCanRagdoll(lastPed,savedRagdoll~=false)
    end
    savedProofs=nil; lastPed=nil; savedRagdoll=nil; downState={}
    LocalPlayer.state:set('invBusy',false,true)
    LocalPlayer.state:set('canUseWeapons',true,true)
    SendNUIMessage({action='suspension',remaining=0})
end
RegisterNetEvent('apex_pd:suspension',function(expires,serverTime)
    APEX.suspended=expires; APEX.deadline=GetGameTimer()+math.max(0,expires-serverTime)*1000
    if expires==0 then cleanupSuspension() end
end)
AddEventHandler('QBCore:Client:OnPlayerLoaded',function() TriggerServerEvent('apex_pd:requestSync') end)
AddEventHandler('QBCore:Client:OnPlayerUnload',function() APEX.suspended=0; cleanupSuspension() end)
CreateThread(function()
    Wait(1500); TriggerServerEvent('apex_pd:requestSync')
    while true do
        local active=LocalPlayer.state.apexPdSuspended
        if active then
            local ped=cache.ped
            if lastPed~=ped then
                cleanupSuspension(); lastPed=ped
                savedRagdoll=CanPedRagdoll(ped)
                local ok,b,f,e,c,m,s,d,w=GetEntityProofs(ped)
                if ok then savedProofs={b,f,e,c,m,s,d,w} end
                TriggerEvent('ox_inventory:disarm',true)
                if IsPedInAnyVehicle(ped,false) then TaskLeaveVehicle(ped,GetVehiclePedIsIn(ped,false),16) end
            end
            LocalPlayer.state:set('invBusy',true,true); LocalPlayer.state:set('canUseWeapons',false,true)
            DisableAllControlActions(0)
            for _,control in ipairs({1,2,245,249,200}) do EnableControlAction(0,control,true) end
            SetEntityProofs(ped,true,true,true,true,true,true,true,true)
            if GetEntityHealth(ped)>0 and GetEntityHealth(ped)<150 then SetEntityHealth(ped,150) end
            APEX.keepDown(ped,downState)
            Wait(0)
        else
            if lastPed then cleanupSuspension() end
            Wait(250)
        end
    end
end)
CreateThread(function()
    while true do
        Wait(1000)
        if LocalPlayer.state.apexPdSuspended then
            SendNUIMessage({action='suspension',remaining=math.max(0,math.ceil((APEX.deadline-GetGameTimer())/1000))})
        end
    end
end)
local registered={}
CreateThread(function()
    lib.requestAnimDict('dead')
    lib.requestAnimDict('missfinale_c2mcs_1')
    while true do
        Wait(500)
        local present={}; local carrying=nil
        for _,b in ipairs(GlobalState.apexPdBodies or {}) do
            local ped=NetworkDoesEntityExistWithNetworkId(b.netId) and NetToPed(b.netId) or 0
            if ped~=0 and DoesEntityExist(ped) then
                present[b.id]=true
                local entry=registered[b.id]
                if not entry or entry.ped~=ped then
                    if entry then exports.ox_target:removeLocalEntity(entry.ped,{'apex_pd_carry_'..b.id}) end
                    entry={ped=ped,appearance=nil}; registered[b.id]=entry
                    exports.ox_target:addLocalEntity(ped,{{name='apex_pd_carry_'..b.id,icon='fa-solid fa-person-carry-box',label='Carregar / colocar corpo no chão',distance=Config.CarryDistance,onSelect=function() lib.callback.await('apex_pd:carry',false,b.id) end}})
                end
                local appearance=b.appearance and json.encode(b.appearance)
                if appearance and entry.appearance~=appearance then applyAppearance(ped,b.appearance); entry.appearance=appearance end
                -- Somente proprietário de rede movimenta/anima: evita disputar o ped entre clientes.
                if NetworkHasControlOfEntity(ped) then
                    SetEntityInvincible(ped,true); SetBlockingOfNonTemporaryEvents(ped,true); SetPedCanRagdoll(ped,false)
                    -- Ped cenográfico em animação de morto: health 0 cancela animações/carregamento.
                    SetPedDiesWhenInjured(ped,false); SetEntityHealth(ped,200)
                    if b.carrier then
                        FreezeEntityPosition(ped,false)
                        local player=GetPlayerFromServerId(b.carrier)
                        local carrier=player~=-1 and GetPlayerPed(player) or 0
                        if carrier~=0 and not IsEntityAttachedToEntity(ped,carrier) then AttachEntityToEntity(ped,carrier,GetPedBoneIndex(carrier,24818),0.15,0.15,0.0,0,0,90,false,false,false,false,2,true) end
                    elseif IsEntityAttached(ped) then DetachEntity(ped,true,true); local c=GetEntityCoords(ped); local ok,z=GetGroundZFor_3dCoord(c.x,c.y,c.z+2,false); if ok then SetEntityCoords(ped,c.x,c.y,z,false,false,false,false) end end
                    if not b.carrier then FreezeEntityPosition(ped,true); if not IsEntityPlayingAnim(ped,'dead','dead_a',3) then TaskPlayAnim(ped,'dead','dead_a',8,-8,-1,1,0,false,false,false) end end
                end
                if b.carrier==cache.serverId then carrying=b.id end
            end
        end
        for id,entry in pairs(registered) do if not present[id] then exports.ox_target:removeLocalEntity(entry.ped,{'apex_pd_carry_'..id}); registered[id]=nil end end
        if carrying then
            if not IsEntityPlayingAnim(cache.ped,'missfinale_c2mcs_1','fin_c2_mcs_1_camman',3) then TaskPlayAnim(cache.ped,'missfinale_c2mcs_1','fin_c2_mcs_1_camman',8,-8,-1,49,0,false,false,false) end
            lib.showTextUI('[E] Colocar corpo no chão')
        elseif APEX.carrying then ClearPedSecondaryTask(cache.ped); lib.hideTextUI() end
        APEX.carrying=carrying
    end
end)
CreateThread(function()
    while true do
        if APEX.carrying then
            DisableControlAction(0,21,true); DisableControlAction(0,22,true); DisableControlAction(0,23,true); DisablePlayerFiring(cache.playerId,true)
            if IsControlJustReleased(0,38) then lib.callback.await('apex_pd:carry',false,APEX.carrying) end
            Wait(0)
        else Wait(250) end
    end
end)
AddEventHandler('onResourceStop',function(name)
    if name~=GetCurrentResourceName() then return end
    cleanupSuspension(); SetPedCanRagdoll(cache.ped,true); lib.hideTextUI(); ClearPedSecondaryTask(cache.ped)
    for id,entry in pairs(registered) do exports.ox_target:removeLocalEntity(entry.ped,{'apex_pd_carry_'..id}) end
end)
