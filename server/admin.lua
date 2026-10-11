local limits={}
local function allowed(src)
    if not PD.ready or not PD.admin(src) then return false end
    return true
end
function PD.snapshot()
    local weapons, players, suspensions, bodies = {}, {}, {}, {}
    for _,row in pairs(PD.registry) do weapons[#weapons+1]={serial=row.serial,kind=row.kind,revoked=row.revoked,location=row.location} end
    table.sort(weapons,function(a,b) return a.serial<b.serial end)
    for _,id in ipairs(GetPlayers()) do
        local p=PD.getPlayer(tonumber(id))
        if p then players[#players+1]={id=tonumber(id),citizenid=p.PlayerData.citizenid,name=(p.PlayerData.charinfo.firstname or '')..' '..(p.PlayerData.charinfo.lastname or '')} end
    end
    for _,b in pairs(PD.corpses) do bodies[#bodies+1]={id=b.id,name=b.name,carrier=b.carrier,netId=b.netId} end
    local rows=MySQL.query.await('SELECT citizenid, expires_at FROM apex_pd_suspensions WHERE expires_at>?',{os.time()})
    for _,row in ipairs(rows) do
        local p=exports.qbx_core:GetPlayerByCitizenId(row.citizenid)
        suspensions[#suspensions+1]={citizenid=row.citizenid,expires=row.expires_at,id=p and p.PlayerData.source or false,name=p and ((p.PlayerData.charinfo.firstname or '')..' '..(p.PlayerData.charinfo.lastname or '')) or row.citizenid}
    end
    return {weapons=weapons,players=players,suspensions=suspensions,bodies=bodies,settings=PD.settings,serverTime=os.time(),logs=MySQL.query.await('SELECT id, actor, action, detail, created_at FROM apex_pd_audit ORDER BY id DESC LIMIT 80'),deaths=MySQL.query.await('SELECT citizenid, status, error, created_at FROM apex_pd_deaths ORDER BY created_at DESC LIMIT 50')}
end
lib.callback.register('apex_pd:adminSnapshot',function(src)
    if not allowed(src) then return {ok=false,error='Acesso negado'} end
    if limits[src] and GetGameTimer()-limits[src]<700 then return {ok=false,error='Aguarde um instante'} end
    limits[src]=GetGameTimer()
    return {ok=true,data=PD.snapshot()}
end)
local numeric={silverMinutes={1,1440},fireScale={0.1,2.0},lightningRed={0,255},lightningGreen={0,255},lightningBlue={0,255},rainMinutes={1,120},rainIntensity={0.1,1.0}}
local boolean={fire=true,lightning=true,rain=true}
local busy={}
lib.callback.register('apex_pd:adminAction',function(src,action,data)
    if not allowed(src) then return {ok=false,error='Acesso negado'} end
    if busy[src] then return {ok=false,error='Operação em andamento'} end
    if limits['act'..src] and GetGameTimer()-limits['act'..src]<800 then return {ok=false,error='Aguarde um instante'} end
    if type(action)~='string' or type(data)~='table' then return {ok=false,error='Dados inválidos'} end
    limits['act'..src]=GetGameTimer(); busy[src]=true
    local actor=PD.getPlayer(src); actor=actor and actor.PlayerData.citizenid or tostring(src)
    local success,result,message=pcall(function()
        if action=='issue' then return PD.issue(actor,tonumber(data.target),data.kind)
        elseif action=='ammo' then return PD.giveAmmo(actor,tonumber(data.target),data.kind,data.count)
        elseif action=='revoke' then return PD.revoke(actor,data.serial)
        elseif action=='settings' then
            local nextSettings={}
            for k,v in pairs(PD.settings) do nextSettings[k]=v end
            for k,range in pairs(numeric) do
                local n=tonumber(data[k]); if not n or n~=n or n<range[1] or n>range[2] then return false,'Valor inválido: '..k end
                nextSettings[k]=(k=='fireScale' or k=='rainIntensity') and n or math.floor(n)
            end
            for k in pairs(boolean) do if type(data[k])~='boolean' then return false,'Valor inválido: '..k end; nextSettings[k]=data[k] end
            MySQL.update.await('INSERT INTO apex_pd_settings (id, settings) VALUES (1, ?) ON DUPLICATE KEY UPDATE settings=VALUES(settings)',{json.encode(nextSettings)})
            PD.settings=nextSettings; GlobalState.apexPdSettings=nextSettings
            PD.audit(actor,'settings.update',nextSettings); return true,'Configurações salvas'
        elseif action=='release' then
            if type(data.citizenid)~='string' or #data.citizenid>50 then return false,'Personagem inválido' end
            MySQL.update.await('DELETE FROM apex_pd_suspensions WHERE citizenid=?',{data.citizenid})
            PD.suspensions[data.citizenid]=nil
            local p=exports.qbx_core:GetPlayerByCitizenId(data.citizenid)
            if p then Player(p.PlayerData.source).state:set('apexPdSuspended',false,true); TriggerClientEvent('apex_pd:suspension',p.PlayerData.source,0,os.time()) end
            PD.audit(actor,'silver.release',{citizenid=data.citizenid}); return true,'Suspensão encerrada'
        elseif action=='locate' then
            PD.refreshRegistry()
            local row=PD.registry[data.serial]
            local loc=row and row.location
            if not loc or not loc.coords then return false,'Sem coordenadas conhecidas para este inventário' end
            if loc.type=='player' and not PD.samePlayer(tonumber(loc.id),loc.citizenid) then return false,'Portador offline; posição histórica disponível na lista' end
            TriggerClientEvent('apex_pd:waypoint',src,loc.coords); return true,'Rota marcada no mapa'
        elseif action=='retryWipes' then PD.retryWipes(); PD.audit(actor,'pd.retry',{}); return true,'Pendências processadas'
        end
        return false,'Operação desconhecida'
    end)
    busy[src]=nil
    if not success then print('[Auren_Death] Admin: '..tostring(result)); return {ok=false,error='Falha na operação; consulte o console'} end
    return {ok=result==true,error=result~=true and message or nil,message=result==true and message or nil}
end)
RegisterCommand(Config.Command,function(src)
    if PD.admin(src) then TriggerClientEvent('apex_pd:openAdmin',src) else PD.notify(src,'Você não tem acesso a este painel','error') end
end,false)
AddEventHandler('playerDropped',function() busy[source]=nil; limits[source]=nil; limits['act'..source]=nil end)

-- A ACE do grupo acompanha a herança nativa: promoção/revogação vale na próxima
-- chamada, sem cache por jogador e sem conceder outras permissões da cidade.
local groupAce = 'apex.pd.groupAdmin'
local addedGroups = {}
for _, principal in ipairs(Config.AdminGroups or {}) do
    if not IsPrincipalAceAllowed(principal, groupAce) then
        lib.addAce(principal, groupAce, true)
        addedGroups[#addedGroups + 1] = principal
    end
end
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, principal in ipairs(addedGroups) do lib.removeAce(principal, groupAce, true) end
end)
