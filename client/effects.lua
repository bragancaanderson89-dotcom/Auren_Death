APEX = { suspended=0, deadline=0, flames={}, bodies={}, carrying=nil, hiddenVictims={} }
function APEX.keepDown(ped,entry)
    -- Congelar antes da queda deixa a vítima em pé/flutuando. A física deve
    -- assentá-la no chão; o ragdoll nativo relaxado mantém a pose de morto.
    FreezeEntityPosition(ped,false)
    SetPedCanRagdoll(ped,true)
    local now=GetGameTimer()
    if IsPedInAnyVehicle(ped,false) then
        if not entry.exitAt or now-entry.exitAt>2000 then TaskLeaveVehicle(ped,GetVehiclePedIsIn(ped,false),16);entry.exitAt=now end
        return
    end
    if not entry.downStarted then ClearPedTasksImmediately(ped);entry.downStarted=true end
    if not IsPedRagdoll(ped) or now>=(entry.ragdollUntil or 0)-2000 then
        SetPedToRagdoll(ped,15000,15000,0,false,false,false)
        entry.ragdollUntil=now+15000
    end
end
local function ptfxReady()
    if HasNamedPtfxAssetLoaded(Config.Fire.asset) then return true end
    RequestNamedPtfxAsset(Config.Fire.asset)
    local deadline=GetGameTimer()+3000
    while not HasNamedPtfxAssetLoaded(Config.Fire.asset) and GetGameTimer()<deadline do Wait(25) end
    return HasNamedPtfxAssetLoaded(Config.Fire.asset)
end
function APEX.stopFlame(id)
    local entry=APEX.flames[id]
    if entry then for _,h in ipairs(entry.handles) do StopParticleFxLooped(h,false) end; APEX.flames[id]=nil end
end
function APEX.flame(id,ped,settings)
    local entry=APEX.flames[id]
    if entry and (entry.ped~=ped or entry.scale~=settings.fireScale) then APEX.stopFlame(id); entry=nil end
    if not entry and ptfxReady() then
        local handles={}
        -- Partículas visuais: fogo contínuo sem dano ou propagação que mataria o jogador.
        for _,bone in ipairs({24818,11816,57005,18905}) do
            UseParticleFxAssetNextCall(Config.Fire.asset)
            local handle=StartParticleFxLoopedOnEntityBone(Config.Fire.effect,ped,0,0,0,0,0,0,GetPedBoneIndex(ped,bone),settings.fireScale,false,false,false)
            if handle and handle~=0 then handles[#handles+1]=handle end
        end
        if #handles>0 then APEX.flames[id]={ped=ped,handles=handles,scale=settings.fireScale} end
    end
end
local function boltStrip(a,b,width,r,g,blue,alpha,camera)
    local dx,dy,dz=b.x-a.x,b.y-a.y,b.z-a.z
    local vx,vy,vz=camera.x-a.x,camera.y-a.y,camera.z-a.z
    local nx,ny,nz=dy*vz-dz*vy,dz*vx-dx*vz,dx*vy-dy*vx
    local length=math.sqrt(nx*nx+ny*ny+nz*nz)
    if length<0.001 then nx,ny,nz,length=1,0,0,1 end
    local scale=width/(2*length);nx=nx*scale;ny=ny*scale;nz=nz*scale
    local ax,ay,az=a.x-nx,a.y-ny,a.z-nz
    local bx,by,bz=a.x+nx,a.y+ny,a.z+nz
    local cx,cy,cz=b.x+nx,b.y+ny,b.z+nz
    local ex,ey,ez=b.x-nx,b.y-ny,b.z-nz
    -- Faces dos dois lados: espessura real em metros, em qualquer câmera.
    DrawPoly(ax,ay,az,bx,by,bz,cx,cy,cz,r,g,blue,alpha)
    DrawPoly(ax,ay,az,cx,cy,cz,ex,ey,ez,r,g,blue,alpha)
    DrawPoly(cx,cy,cz,bx,by,bz,ax,ay,az,r,g,blue,alpha)
    DrawPoly(ex,ey,ez,cx,cy,cz,ax,ay,az,r,g,blue,alpha)
end
function APEX.boltShape(seed,height)
    local state=math.floor(math.abs(seed or 1))%2147483646+1
    local function random()state=(state*16807)%2147483647;return state/2147483647 end
    local function split(a,b,depth,path)
        if depth==0 then path[#path+1]=a;return end
        local dx,dy,dz=b.x-a.x,b.y-a.y,b.z-a.z
        local length=math.sqrt(dx*dx+dy*dy+dz*dz)
        local amplitude=length*.18*(.7+random()*.6)
        local middle=vector3((a.x+b.x)/2+(random()*2-1)*amplitude,(a.y+b.y)/2+(random()*2-1)*amplitude,(a.z+b.z)/2+(random()*2-1)*math.abs(dz)*.045)
        split(a,middle,depth-1,path);split(middle,b,depth-1,path)
    end
    local function path(a,b,depth)
        local result={};split(a,b,depth,result);result[#result+1]=b;return result
    end
    local sky=vector3((random()*2-1)*height*.12,(random()*2-1)*height*.08,height)
    local main=path(vector3(0,0,0),sky,6)
    local branches={}
    for _,index in ipairs({5,10,17,26,38,51}) do
        local start=main[index]
        local angle=random()*math.pi*2
        local reach=math.min(height*.18,8+start.z*.18)*(0.7+random()*.6)
        local finish=vector3(start.x+math.cos(angle)*reach,start.y+math.sin(angle)*reach,math.max(.5,start.z-math.min(start.z*.7,height*.16)*(.6+random()*.4)))
        local fork=path(start,finish,3)
        branches[#branches+1]=fork
        if index==17 or index==38 then
            local sub=fork[5];local subEnd=vector3(sub.x+math.cos(angle+.8)*reach*.45,sub.y+math.sin(angle+.8)*reach*.45,math.max(.5,sub.z-reach*.3))
            branches[#branches+1]=path(sub,subEnd,2)
        end
    end
    return main,branches
end
function APEX.boltIntensity(elapsed)
    if elapsed<180 then return .05*(elapsed/180) end
    local value=0
    for _,pulse in ipairs({{215,65},{390,38},{595,32},{830,24}}) do
        local strength=math.max(0,1-math.abs(elapsed-pulse[1])/pulse[2])
        value=math.max(value,strength*strength)
    end
    return value
end
function APEX.lightning(resolvePed,coords,settings,seed)
    local distance=#(GetEntityCoords(cache.ped)-vector3(coords.x,coords.y,coords.z))
    if distance>=Config.EffectsDistance or not settings.lightning then return end
    CreateThread(function()
        local style=Config.Lightning or {}
        local height=math.max(100,math.min(800,style.height or 300))
        local width=math.max(0.2,math.min(5,style.width or 1.6))
        local duration=math.max(1000,math.min(5000,style.durationMs or 2200))
        local points,branches=APEX.boltShape(seed,height)
        local started=GetGameTimer();local impact=false
        local r,g,b=settings.lightningRed,settings.lightningGreen,settings.lightningBlue
        while GetGameTimer()-started<duration do
            Wait(0)
            local elapsed=GetGameTimer()-started
            local ped=resolvePed()
            local head=ped~=0 and DoesEntityExist(ped) and GetPedBoneCoords(ped,31086,0,0,0) or vector3(coords.x,coords.y,coords.z+.8)
            local camera=GetFinalRenderedCamCoord()
            local intensity=APEX.boltIntensity(elapsed)
            local function drawPath(path,scale)
                local first=math.max(1,math.floor((#path-1)*(1-math.min(1,elapsed/180))))
                for i=first,#path-1 do
                    local a,c=path[i],path[i+1]
                    local wa=vector3(head.x+a.x,head.y+a.y,head.z+a.z)
                    local wc=vector3(head.x+c.x,head.y+c.y,head.z+c.z)
                    local taper=scale*(.55+.45*math.abs(math.sin(i*1.73+seed)))
                    -- Halo translúcido e núcleo fino: evita a coluna sólida/neon.
                    boltStrip(wa,wc,width*taper*.65,r,g,b,math.floor(24*intensity),camera)
                    boltStrip(wa,wc,width*taper*.14,r,g,b,math.floor(190*intensity),camera)
                    boltStrip(wa,wc,width*taper*.04,255,math.min(255,g+195),math.min(255,b+195),math.floor(255*intensity),camera)
                    DrawLine(wa.x,wa.y,wa.z,wc.x,wc.y,wc.z,255,math.min(255,g+195),math.min(255,b+195),math.floor(220*intensity*math.min(1,scale*1.5)))
                end
            end
            if intensity>.004 then drawPath(points,1) end
            if elapsed>=180 then
                if not impact then
                    impact=true;ForceLightningFlash()
                    SendNUIMessage({action='thunder',volume=math.max(.15,math.min(1,(style.thunderVolume or .95)*(1-distance/Config.EffectsDistance)))})
                    if distance<80 then ShakeGameplayCam('LARGE_EXPLOSION_SHAKE',.30*(1-distance/80)) end
                end
                if intensity>.004 then
                    for index,branch in ipairs(branches) do drawPath(branch,index%3==0 and .20 or .35) end
                    DrawLightWithRange(head.x,head.y,head.z,r,g,b,25.0,8.0*intensity)
                end
            end
            if intensity<=.004 then Wait(20) end
        end
    end)
end
RegisterNetEvent('apex_pd:sentence',function(target,coords,bucket,settings)
    local player=GetPlayerFromServerId(target)
    if player~=-1 then APEX.lightning(function() return GetPlayerPed(player) end,coords,settings,target*29) end
    if target==cache.serverId then
        SendNUIMessage({action='sentence',message=Config.Message})
        ShakeGameplayCam('LARGE_EXPLOSION_SHAKE',0.25)
    end
end)
CreateThread(function()
    local rainy=false
    local priorWeather=nil
    while true do
        Wait(500)
        local settings=GlobalState.apexPdSettings or Config.Defaults
        local active={}
        local hidden={}
        for _,player in ipairs(GetActivePlayers()) do
            local id=GetPlayerServerId(player)
            local state=Player(id).state.apexPdSuspended
            local ped=GetPlayerPed(player)
            if Player(id).state.apexPdDying and DoesEntityExist(ped) then SetEntityAlpha(ped,0,false); hidden[ped]=true; APEX.hiddenVictims[ped]=true end
            if state and settings.fire and DoesEntityExist(ped) and #(GetEntityCoords(cache.ped)-GetEntityCoords(ped))<Config.EffectsDistance then
                active[id]=true; APEX.flame(id,ped,settings)
            end
        end
        for id in pairs(APEX.flames) do if type(id)=='number' and not active[id] then APEX.stopFlame(id) end end
        for ped in pairs(APEX.hiddenVictims) do if not hidden[ped] then if DoesEntityExist(ped) then ResetEntityAlpha(ped) end; APEX.hiddenVictims[ped]=nil end end
        local rainUntil=GlobalState.apexPdRainUntil or 0
        -- Um statebag global ativa clima em todos, inclusive clientes que chegam depois.
        if rainUntil>0 then
            if not rainy then priorWeather=GetPrevWeatherTypeHashName(); rainy=true end
            SetOverrideWeather('THUNDER'); SetRainLevel(settings.rainIntensity)
        elseif rainy then
            rainy=false; ClearOverrideWeather(); SetRainLevel(-1.0)
            if GetResourceState('Renewed-Weathersync')~='started' and GetResourceState(Config.WeatherResource)~='started' and priorWeather then
                for _,name in ipairs({'EXTRASUNNY','CLEAR','CLOUDS','OVERCAST','RAIN','THUNDER','CLEARING','SMOG','FOGGY','SNOW','SNOWLIGHT','BLIZZARD','XMAS','NEUTRAL'}) do if joaat(name)==priorWeather then SetWeatherTypeNowPersist(name); break end end
            end
        end
    end
end)
AddEventHandler('onResourceStop',function(name)
    if name~=GetCurrentResourceName() then return end
    for id in pairs(APEX.flames) do APEX.stopFlame(id) end
    for ped in pairs(APEX.hiddenVictims) do if DoesEntityExist(ped) then ResetEntityAlpha(ped) end end
    ClearOverrideWeather(); SetRainLevel(-1.0)
end)
