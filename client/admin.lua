local open=false
RegisterNetEvent('apex_pd:openAdmin',function()
    local result=lib.callback.await('apex_pd:adminSnapshot',false)
    if not result or not result.ok then return end
    open=true; SetNuiFocus(true,true); SendNUIMessage({action='open',data=result.data})
end)
RegisterNUICallback('close',function(_,cb) open=false; SetNuiFocus(false,false); SendNUIMessage({action='close'}); cb({ok=true}) end)
RegisterNUICallback('refresh',function(_,cb) cb(lib.callback.await('apex_pd:adminSnapshot',false) or {ok=false,error='Servidor indisponível'}) end)
RegisterNUICallback('action',function(data,cb)
    local ok,result=pcall(function() return lib.callback.await('apex_pd:adminAction',false,data.action,data.data or {}) end)
    cb(ok and result or {ok=false,error='Falha de comunicação'})
end)
RegisterNetEvent('apex_pd:waypoint',function(c) SetNewWaypoint(c.x,c.y); lib.notify({title='Auren Death',description='Localização marcada',type='success'}) end)
AddEventHandler('onResourceStop',function(resource) if resource==GetCurrentResourceName() and open then SetNuiFocus(false,false) end end)
