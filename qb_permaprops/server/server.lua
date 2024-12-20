local QBCore = exports['qb-core']:GetCoreObject()

lib.addCommand('addObject', {
    help = 'Añade un objeto permanente en el servidor',
    restricted = false
}, function(source, args, raw)
    local Player = QBCore.Functions.GetPlayer(source)
    local job = Player.PlayerData.job

    if job.name == "police" and job.grade >= 2 or IsPlayerAceAllowed(source, 'group.admin') then
        TriggerClientEvent('permaprops:addObject', source)
    else
        TriggerClientEvent('chat:addMessage', source, { args = { 'Sistema', 'No tienes permiso para usar este comando.' } })
    end
end)

lib.addCommand('editObject', {
    help = 'Editar objetos',
    restricted = 'group.admin'
}, function(source, args, raw)
    if not IsPlayerAceAllowed(source, 'command') then return end
    TriggerClientEvent('permaprops:editObject', source)
end)

lib.callback.register('permaprops:check', function(source)
    if not IsPlayerAceAllowed(source, 'command') then return false end
    return true
end)

RegisterServerEvent('permaprops:placeObject', function(coord, head, model, type, id, name)
    local src = source
    if not IsPlayerAceAllowed(src, 'command') then return false end

    if not name or name == '' then
        name = 'Unnamed'
    end

    if type == 'delete' then
        MySQL.query.await('DELETE FROM permaprops WHERE id = ?', {id})
        local updatedObjects = MySQL.query.await('SELECT * FROM permaprops', {})
        TriggerClientEvent('permaprops:updateObjects', -1, updatedObjects)
        return
    end

    if type == 'editcoord' then
        local loc = {x = coord.x, y = coord.y, z = coord.z, w = head}
        MySQL.query.await('UPDATE permaprops SET loc = ? WHERE id = ?', {json.encode(loc), id})
        local updatedObjects = MySQL.query.await('SELECT * FROM permaprops', {})
        TriggerClientEvent('permaprops:updateObjects', -1, updatedObjects)
        return
    end

    if type == 'editObject' then
        MySQL.query.await('UPDATE permaprops SET model = ? WHERE id = ?', {model, id})
        local updatedObjects = MySQL.query.await('SELECT * FROM permaprops', {})
        TriggerClientEvent('permaprops:updateObjects', -1, updatedObjects)
        return
    end

    local coords = {x = coord.x, y = coord.y, z = coord.z, w = head}
    MySQL.query.await('INSERT INTO permaprops SET model = ?, loc = ?, name = ?', {model, json.encode(coords), name})
    local updatedObjects = MySQL.query.await('SELECT * FROM permaprops', {})
    TriggerClientEvent('permaprops:updateObjects', -1, updatedObjects)
end)

lib.callback.register('permaprops:getObjects', function(source)
    local data = MySQL.query.await('SELECT * FROM permaprops', {})
    if data[1] == nil then return 'No Objects' end
    return data
end)

RegisterServerEvent('permaprops:deleteAllObjects')
AddEventHandler('permaprops:deleteAllObjects', function()
    local src = source
    if not IsPlayerAceAllowed(src, 'command') then return end
    MySQL.query.await('DELETE FROM permaprops WHERE 1', {})
    local updatedObjects = MySQL.query.await('SELECT * FROM permaprops', {})
    TriggerClientEvent('permaprops:updateObjects', -1, updatedObjects)
    TriggerClientEvent('chat:addMessage', src, { args = { 'Sistema', 'Todos los objetos han sido eliminados.' } })
end)
