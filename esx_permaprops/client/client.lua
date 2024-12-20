local validModels = {
    "hei_prop_cc_metalcover_01",
    "prop_fncconstruc_ld",
    "prop_fnclink_02i",
}

local objects = {}
local currentMarker = nil
local isBuilding = false
local isConstructing = false  -- Estado de construcción

local function StartRay(obj)
    local heading = 180.0
    local created = false
    local coord = GetEntityCoords(PlayerPedId())
    lib.requestModel(obj, 30000)
    local entity = CreateObject(obj, coord.x, coord.y, coord.z, false, false)
    local z = math.floor(coord.z * 100) / 100
    local run = true
    repeat
        local hit, entityHit, endCoords, surfaceNormal, matHash = lib.raycast.cam(511, 4, 30)
        if not created then
            created = true
            lib.showTextUI('[E] Para Colocar\n[DEL] Para Cancelar\n[←] Para Mover Izquierda\n[→] Para Mover Derecha')
        else
            SetEntityCoords(entity, endCoords.x, endCoords.y, z)
            SetEntityHeading(entity, heading)
            SetEntityCollision(entity, false, false)
        end
        if IsControlPressed(0, 174) then heading = heading - 1 end
        if IsControlPressed(0, 175) then heading = heading + 1 end
        if IsControlPressed(0, 172) then z = z + 0.1 end
        if IsControlPressed(0, 173) then z = z - 0.1 end
        if IsControlPressed(0, 38) then
            lib.hideTextUI()
            run = false
            DeleteEntity(entity)
            local loc = {x = math.floor(endCoords.x * 100) / 100, y = math.floor(endCoords.y * 100) / 100, z = math.floor(endCoords.z * 100) / 100}
            return loc, heading, obj
        end
        if IsControlPressed(0, 178) then
            lib.hideTextUI()
            run = false
            DeleteEntity(entity)
            return nil
        end
        Wait(0)
    until not run
end

local function spawn()
    for k, v in pairs(objects) do
        DeleteEntity(v.object)
    end
    objects = {}

    local list = lib.callback.await('permaprops:getObjects', false)
    if list == 'No Objects' then
        print('No hay Objetos')
        return
    end

    for k, v in pairs(list) do
        local coords = json.decode(v.loc)
        lib.requestModel(v.model, 30000)
        local obj = CreateObject(v.model, coords.x, coords.y, coords.z, false, true, true)
        SetEntityHeading(obj, coords.w)
        FreezeEntityPosition(obj, true)
        table.insert(objects, {object = obj, coords = coords, model = v.model, id = v.id, name = v.name})
    end
end

local function addObject()
    -- Crear opciones para el menú desplegable de modelos
    local modelOptions = {}
    for _, model in ipairs(validModels) do
        table.insert(modelOptions, {label = model, value = model})
    end

    -- Mostrar el diálogo de entrada con el menú desplegable
    local inputs = lib.inputDialog('Añadir Objeto', {
        {description = 'Selecciona el modelo', type = 'select', options = modelOptions},
        {description = 'Nombre del objeto (deja en blanco para usar "Unnamed")', type = 'input'}
    })

    if not inputs then return end
    local model = inputs[1]
    local name = inputs[2] and inputs[2] ~= '' and inputs[2] or 'Unnamed'

    -- Validar si el modelo seleccionado es válido
    local isValidModel = false
    for _, validModel in ipairs(validModels) do
        if model == validModel then
            isValidModel = true
            break
        end
    end

    if isValidModel then
        local hash = GetHashKey(model)
        if IsModelValid(hash) then
            local coord, head = StartRay(model)
            if coord then
                -- Mostrar el marcador
                currentMarker = {
                    coords = vector3(coord.x, coord.y, coord.z + 0.5),
                    type = 30,
                    color = {r = 255, g = 0, b = 0, a = 255},
                    width = 1.0,
                    height = 1.0
                }

                -- Función para dibujar el marcador
                local function drawMarker()
                    if currentMarker then
                        DrawMarker(currentMarker.type, currentMarker.coords.x, currentMarker.coords.y, currentMarker.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, currentMarker.width, currentMarker.height, currentMarker.height, currentMarker.color.r, currentMarker.color.g, currentMarker.color.b, currentMarker.color.a, false, true, 2, false, nil, nil, false)
                    end
                end

                -- Función para controlar la UI del texto
                local function updateTextUI()
                    -- Comprobar la distancia
                    local playerCoords = GetEntityCoords(PlayerPedId())
                    local distance = #(currentMarker.coords - playerCoords)

                    -- Mostrar el texto si está cerca, de lo contrario, ocultarlo
                    if distance < 1.5 then
                        if not lib.isTextUIOpen() then
                            lib.showTextUI('[E] para colocar el objeto aquí')
                        end
                    else
                        lib.hideTextUI()
                    end
                end

                -- Bloqueo para evitar más interacciones durante el proceso de construcción
                isConstructing = true

                -- Loop principal para verificar la proximidad
                Citizen.CreateThread(function()
                    while isConstructing do
                        -- Dibujar el marcador
                        drawMarker()

                        -- Actualizar el texto UI dependiendo de la distancia
                        updateTextUI()

                        -- Comprobar si se presiona 'E' para colocar el objeto
                        local playerCoords = GetEntityCoords(PlayerPedId())
                        local distance = #(currentMarker.coords - playerCoords)

                        if distance < 1.5 then
                            if IsControlJustPressed(0, 51) then  -- Si se presiona 'E'
                                -- Preparar el martillo y la animación
                                local hammerModel = "prop_tool_hammer"
                                lib.requestModel(hammerModel, 30000)
                                local playerPed = PlayerPedId()

                                -- Crear el martillo
                                local hammer = CreateObject(GetHashKey(hammerModel), 0, 0, 0, true, true, false)
                                AttachEntityToEntity(hammer, playerPed, GetPedBoneIndex(playerPed, 57005), 0.1, 0.0, 0.0, 90.0, 0.0, 180.0, true, true, false, true, 1, true)

                                -- Cargar y reproducir la animación de martilleo
                                local animDict = "amb@world_human_hammering@male@base"
                                local animName = "base"
                                lib.requestAnimDict(animDict, 30000)
                                TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)

                                -- Barra de progreso para colocar el objeto
                                local success = lib.progressBar({
                                    duration = 5000,
                                    label = 'Colocando objeto...',
                                    useWhileDead = false,
                                    canCancel = true,
                                    disable = {
                                        move = true,
                                        car = true,
                                        combat = true,
                                        mouse = false,
                                        sprint = true,
                                    }
                                })

                                if success then
                                    -- Coloca el objeto
                                    TriggerServerEvent('permaprops:placeObject', coord, head, model, 'add', nil, name)

                                    -- Limpia el martillo y detiene la animación
                                    DeleteObject(hammer)
                                    ClearPedTasks(playerPed)

                                    -- Elimina el marcador de construcción
                                    currentMarker = nil  -- El marcador ya no es válido
                                    isConstructing = false  -- Desactivar la construcción

                                    -- Actualiza la UI
                                    lib.hideTextUI()  -- Asegura que el mensaje se oculte después de la colocación
                                    
                                    -- Desactiva las teclas de interacción de construcción
                                    DisableControlAction(0, 51, true) -- 'E' para interactuar
                                    DisableControlAction(0, 172, true) -- Flecha izquierda
                                    DisableControlAction(0, 173, true) -- Flecha derecha
                                    DisableControlAction(0, 174, true) -- Flecha arriba
                                    DisableControlAction(0, 175, true) -- Flecha abajo

                                    -- Reiniciar las variables de interacción
                                    isConstructing = false
                                    isBuilding = false
                                end
                            end
                        end

                        Citizen.Wait(0)
                    end
                end)
            end
        end
    else
        lib.notify({title = "Error", description = "Modelo no válido.", type = "error"})
    end
end

local function editObjectMenu()
    local options = {}

    -- Opción para eliminar todos los objetos
    table.insert(options, {
        title = 'Eliminar Todos los Objetos',
        onSelect = function()
            TriggerServerEvent('permaprops:deleteAllObjects')  -- Llamar al evento para eliminar todos los objetos
        end
    })

    -- Opciones de objetos existentes
    for k, v in pairs(objects) do
        local coord = v.coords
        options[#options + 1] = {
            title = 'Objeto: ' .. v.name,
            description = string.format('Modelo: %s | Coordenadas: %s', v.model, string.format('vector4(%s, %s, %s, %s)', coord.x, coord.y, coord.z, coord.w)),
            onSelect = function()
                lib.registerContext({
                    id = 'edit_Object_' .. k,
                    title = 'Editar Objeto: ' .. v.name,
                    options = {
                        {
                            title = 'Eliminar Objeto',
                            onSelect = function()
                                TriggerServerEvent('permaprops:placeObject', coord, coord.w, v.model, 'delete', v.id)
                            end
                        },
                        {
                            title = 'Editar Coordenadas',
                            onSelect = function()
                                local coords, head = StartRay(v.model)
                                if coords then
                                    TriggerServerEvent('permaprops:placeObject', coords, head, v.model, 'editcoord', v.id)
                                end
                            end
                        },
                        {
                            title = 'Editar Objeto',
                            onSelect = function()
                                local model = lib.inputDialog('Introduce la ID del modelo', {
                                    {description = 'Introduce la ID del Modelo', type = 'input'}
                                })
                                if not model or not model[1] then return end
                                local hash = GetHashKey(model[1])
                                if IsModelValid(hash) then
                                    TriggerServerEvent('permaprops:placeObject', coord, coord.w, model[1], 'editObject', v.id)
                                else
                                    lib.notify({
                                        title = 'Modelo inválido',
                                        description = 'El modelo proporcionado no es válido.',
                                        type = 'error'
                                    })
                                end
                            end
                        },
                    }
                })
                lib.showContext('edit_Object_' .. k)
            end
        }
    end

    lib.registerContext({
        id = 'edit_object_menu',
        title = 'Editar Objetos',
        options = options
    })

    lib.showContext('edit_object_menu')
end

RegisterCommand('editobjects', function()
    editObjectMenu()
end, false)

RegisterNetEvent('permaprops:updateObjects')
AddEventHandler('permaprops:updateObjects', function(objectsData)
    for k, v in pairs(objects) do
        DeleteEntity(v.object)
    end
    objects = {}

    for k, v in pairs(objectsData) do
        local coords = json.decode(v.loc)
        lib.requestModel(v.model, 30000)
        local obj = CreateObject(v.model, coords.x, coords.y, coords.z, false, true, true)
        SetEntityHeading(obj, coords.w)
        FreezeEntityPosition(obj, true)
        table.insert(objects, {object = obj, coords = coords, model = v.model, id = v.id, name = v.name})
    end
end)

local function mainMenu()
    lib.registerContext({
        id = 'main_menu',
        title = 'Permanent Props Menu',
        options = {
            {title = 'Añadir Objeto', onSelect = addObject},
            {title = 'Editar Objetos', onSelect = editObjectMenu},
            {title = 'Reiniciar Objetos', onSelect = spawn}
        }
    })
    lib.showContext('main_menu')
end

RegisterCommand('permaprops', function()
    mainMenu()
end, false)

CreateThread(function()
    spawn()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for i = 1, #objects do
            DeleteEntity(objects[i].object)
        end
        objects = {}
    end
end)
