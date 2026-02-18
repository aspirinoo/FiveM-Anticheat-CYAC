local ESX = nil
local QBCore = nil
local UseESX = false
local UseQBCore = false
local playerHistory = {}
local announcements = {}


-- On resource start, attempt to detect which framework is running
CreateThread(function()
    Wait(1000) -- give time for frameworks to start

    if GetResourceState("qb-core") == "started" then
        UseQBCore = true
        QBCore = exports["qb-core"]:GetCoreObject()
        print("^2[CyberAnticheat-Client] Using QBCore^0")

    elseif GetResourceState("es_extended") == "started" then
        UseESX = true
        local function compareVersions(v1, v2)
            local v1Parts = {}
            local v2Parts = {}
        
            -- Split the version strings into parts
            for part in string.gmatch(v1, "[^%.]+") do
                table.insert(v1Parts, tonumber(part))
            end
            for part in string.gmatch(v2, "[^%.]+") do
                table.insert(v2Parts, tonumber(part))
            end
        
            -- Compare each part numerically
            for i = 1, math.max(#v1Parts, #v2Parts) do
                local v1Part = v1Parts[i] or 0
                local v2Part = v2Parts[i] or 0
                if v1Part > v2Part then
                    return true
                elseif v1Part < v2Part then
                    return false
                end
            end
        
            return false -- Versions are equal
        end
        
        if compareVersions(GetResourceMetadata("es_extended", "version"), "1.9.0") then
            print(compareVersions(GetResourceMetadata("es_extended", "version"), "1.9.0"))
            ESX = exports["es_extended"]:getSharedObject()
        else
            print(compareVersions(GetResourceMetadata("es_extended", "version"), "1.9.0"))
            TriggerEvent("esx:getSharedObject", function(obj) ESX = obj end)
            print("leckeier")
        end
        print("^2[CyberAnticheat-Client] Using ESX^0")

    else
        print("^1[CyberAnticheat-Client] WARNING: No QBCore or ESX detected.^0")
    end
end)

lib.callback.register('CyberAnticheat:getBans', function(source)
    return LoadBans() -- Schrijf eventueel LoadBans() zelf of haal uit DB
end)


--------------------------------------------------------------
-- HELPER: WRAPPED SERVER CALLBACK (ESX.TriggerServerCallback 
--         OR QBCore.Functions.TriggerCallback)
--------------------------------------------------------------
local function FrameworkTriggerServerCallback(name, cb, ...)

    while not (UseESX or UseQBCore) do
        Citizen.Wait(1000)
    end
    
    if UseESX and ESX then
        ESX.TriggerServerCallback(name, cb, ...)
    elseif UseQBCore and QBCore then
        QBCore.Functions.TriggerCallback(name, cb, ...)
    else
        print("^1[CyberAnticheat-Client] No framework to handle callback: " .. tostring(name))
    end
end

--------------------------------------------------------------
-- HELPER: GET PLAYER'S 'GROUP' CROSS-FRAMEWORK
--         (In QBCore, there's no default 'group'. 
--         We'll just guess it might be in qbData.job.name.)
--------------------------------------------------------------
local function GetFrameworkPlayerGroup()
    while not (UseESX or UseQBCore) do
        Citizen.Wait(1000)
    end
    if UseESX and ESX then
        local xData = ESX.GetPlayerData()
        return xData and xData.group or "user"

    elseif UseQBCore and QBCore then
        local qbData = QBCore.Functions.GetPlayerData()
        if qbData and qbData.job then
            -- You might have a custom approach, but let's just return the job name
            return qbData.job.name
        end
        return "user"
    end
    return "unknown"
end

--------------------------------------------------------------
-- The rest of your code, updated to remove direct ESX calls --
--------------------------------------------------------------
local Shared = {}
local configLoaded = false

-- Toggle state for freecam
local freeCamActive = false
-- Reference to our active camera
local freeCamHandle = nil
-- Store the camera’s rotation so we don’t rely on ped heading
local freeCamRot = vector3(0.0, 0.0, 0.0)

-- Load config via cross-framework callback
local function loadConfig()
    FrameworkTriggerServerCallback('CyberAnticheat:get:config', function(config)
        Shared = config
        configLoaded = true
    end)
end

loadConfig()

---------------------------------------
-- FREECAM FUNCTIONS
---------------------------------------
local function StartFreecam()
    if freeCamActive then return end
    freeCamActive = true

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    freeCamRot = GetEntityRotation(playerPed, 2)

    freeCamHandle = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(freeCamHandle, coords.x, coords.y, coords.z + 2.0)
    SetCamRot(freeCamHandle, freeCamRot.x, freeCamRot.y, freeCamRot.z, 2)

    SetCamActive(freeCamHandle, true)
    RenderScriptCams(true, false, 0, true, true)

    FreezeEntityPosition(playerPed, true)
    SetEntityVisible(playerPed, false, false)
    SetEntityCollision(playerPed, false, false)
end

local function StopFreecam()
    if not freeCamActive then return end
    freeCamActive = false

    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(freeCamHandle, false)
    freeCamHandle = nil

    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, false)
    SetEntityVisible(playerPed, true, false)
    SetEntityCollision(playerPed, true, true)
end

---------------------------------------
-- FREECAM RENDERING THREAD
---------------------------------------
Citizen.CreateThread(function()
    local speedNormal = 0.5
    local speedFast   = 3.0

    while true do
        Citizen.Wait(0)
        if freeCamActive and freeCamHandle then
            local camCoords = GetCamCoord(freeCamHandle)
            local camRot    = GetCamRot(freeCamHandle, 2)
            local moveSpeed = IsControlPressed(0, 21) and speedFast or speedNormal 

            if IsControlPressed(0, 32) then 
                camCoords = camCoords + RotationToDirection(camRot) * moveSpeed
            end
            if IsControlPressed(0, 33) then 
                camCoords = camCoords - RotationToDirection(camRot) * moveSpeed
            end
            if IsControlPressed(0, 34) then 
                local heading = (camRot.z - 90.0) % 360.0
                local dir = vector3(math.cos(math.rad(heading)), math.sin(math.rad(heading)), 0.0)
                camCoords = camCoords + (dir * moveSpeed)
            end
            if IsControlPressed(0, 35) then 
                local heading = (camRot.z + 90.0) % 360.0
                local dir = vector3(math.cos(math.rad(heading)), math.sin(math.rad(heading)), 0.0)
                camCoords = camCoords + (dir * moveSpeed)
            end
            if IsControlPressed(0, 85) then 
                camCoords = vector3(camCoords.x, camCoords.y, camCoords.z + moveSpeed)
            end
            if IsControlPressed(0, 48) then 
                camCoords = vector3(camCoords.x, camCoords.y, camCoords.z - moveSpeed)
            end

            local xAxis = (GetDisabledControlNormal(0, 1) * 8.0)
            local yAxis = (GetDisabledControlNormal(0, 2) * 8.0)
            camRot = vector3(camRot.x - yAxis, 0.0, camRot.z - xAxis)

            local playerPed = PlayerPedId()
            for _, player in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(player)
                if ped ~= playerPed then
                    local pedCoords = GetEntityCoords(ped)
                    if #(camCoords - pedCoords) < 50.0 then 
                        DrawText3D(pedCoords.x, pedCoords.y, pedCoords.z + 1.0, "ID: " .. GetPlayerServerId(player))
                    end
                end
            end

            SetCamCoord(freeCamHandle, camCoords.x, camCoords.y, camCoords.z)
            SetCamRot(freeCamHandle, camRot.x, camRot.y, camRot.z, 2)
        end
    end
end)

function DrawText3D(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

function RotationToDirection(rotation)
    local adjustedRotation = {
        x = math.rad(rotation.x),
        y = math.rad(rotation.y),
        z = math.rad(rotation.z)
    }
    local direction = vector3(
        -math.sin(adjustedRotation.z) * math.cos(adjustedRotation.x),
         math.cos(adjustedRotation.z) * math.cos(adjustedRotation.x),
         math.sin(adjustedRotation.x)
    )
    return direction
end

---------------------------------------
-- NUI CALLBACKS / COMMANDS
---------------------------------------

-- Toggling FreeCam from NUI
RegisterNUICallback("FreeCamToggle", function(data, cb)
    if freeCamActive then
        StopFreecam()
    else
        StartFreecam()
    end
    cb('ok')
end)

-- This command triggers the NUI menu:
RegisterCommand("cybermenu", function()
    -- Cross-framework callback to check the group
    FrameworkTriggerServerCallback('CyberAnticheat:get:group', function(group)
        if Shared.ADMIN_GROUPS and Shared.ADMIN_GROUPS[group] then
            OpenAdminPanel()
        end
    end)
end, false)

RegisterNUICallback("closeUI", function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    local playerGroup = GetFrameworkPlayerGroup() 
    if not (Shared.ADMIN_GROUPS and Shared.ADMIN_GROUPS[playerGroup]) then
        cb({ success = false, message = "No permission" })
        return
    end

    local vehicleName = data.vehicleName
    if vehicleName and vehicleName ~= "" then
        spawnVehicle(vehicleName)
        cb({ success = true })
    else
        cb({ success = false, message = "Invalid vehicle name." })
    end
end)

RegisterNUICallback('banPlayer', function(data, cb)
    local playerGroup = GetFrameworkPlayerGroup()
    if not (Shared.ADMIN_GROUPS and Shared.ADMIN_GROUPS[playerGroup]) then
        cb({ success = false, message = "No permission" })
        return
    end

    local playerID = data.playerID 
    local reason = data.reason or 'Not provided'

    TriggerServerEvent('CyberAnticheat:banHandler:Admin', playerID, reason)
    cb({ success = true })
end)

RegisterNUICallback('unbanPlayer', function(data, cb)
    local playerGroup = GetFrameworkPlayerGroup()
    if not (Shared.ADMIN_GROUPS and Shared.ADMIN_GROUPS[playerGroup]) then
        cb({ success = false, message = "No permission" })
        return
    end

    local banID = data.banID 
    TriggerServerEvent('CyberAnticheat:unbanHandler:Admin', banID)
    cb({ success = true })
end)

function spawnVehicle(vehicleName)
    local playerGroup = GetFrameworkPlayerGroup()
    if not (Shared.ADMIN_GROUPS and Shared.ADMIN_GROUPS[playerGroup]) then
        return
    end
    
    local playerPed = PlayerPedId()
    local pos = GetEntityCoords(playerPed)

    RequestModel(vehicleName)
    while not HasModelLoaded(vehicleName) do
        Citizen.Wait(500)
    end

    local vehicle = CreateVehicle(vehicleName, pos.x, pos.y, pos.z, GetEntityHeading(playerPed), true, true)
    TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
    SetVehicleOnGroundProperly(vehicle)
end

function OpenAdminPanel()
    display = true
    SetNuiFocus(true, true)
    
    local dashboardData = GetDashboardData()
    local playersData = GetPlayersData()
    local resourcesData = GetResourcesData()
    local vehiclesData = GetVehiclesData()
    
    SendNUIMessage({
        type = "openPanel",
    })
    
    SendNUIMessage({
        type = "updateData",
        dashboardData = dashboardData,
        playersData = playersData,
        resourcesData = resourcesData,
        vehiclesData = vehiclesData,
        announcementsData = announcements
    })
end

function CloseAdminPanel()
    display = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = "closePanel"
    })
end

function GetDashboardData()
    local players = GetActivePlayers()
    local playerCount = #players
    
    local resourceCount = GetNumResources()
    
    local vehicleCount = 0
    local vehicles = GetGamePool('CVehicle')
    vehicleCount = #vehicles
    
    local hours = GetClockHours()
    local minutes = GetClockMinutes()
    local currentTime = string.format("%02d:%02d", hours, minutes)
    table.insert(playerHistory, {time = currentTime, count = playerCount})
    
    if #playerHistory > 24 then
        table.remove(playerHistory, 1)
    end
    
    return {
        playerCount = playerCount,
        resourceCount = resourceCount,
        vehicleCount = vehicleCount,
        playerHistory = playerHistory
    }
end

function GetPlayersData()
    local players = {}

    for _, playerId in ipairs(GetActivePlayers()) do
        local playerName = GetPlayerName(playerId) or "Unknown"
        local playerServerId = GetPlayerServerId(playerId) or -1
        local steamId = "Unknown"

        local ping = lib.callback.await('CyberAnticheat:server:get:ping', false)

        table.insert(players, {
            id = playerServerId,
            name = lib.callback.await('CyberAnticheat:server:get:name', false, playerServerId),
            steamId = lib.callback.await('CyberAnticheat:server:get:steamname', false, playerServerId),
            status = "online",
            ping = ping
        })
    end

    return players
end

function GetResourcesData()
    local resources = {}
    
    for i = 0, GetNumResources() - 1 do
        local resourceName = GetResourceByFindIndex(i)
        
        local version = GetResourceMetadata(resourceName, "version", 0) or "1.0"
        local author = GetResourceMetadata(resourceName, "author", 0) or "Unknown"
        local status = GetResourceState(resourceName)
        
        table.insert(resources, {
            name = resourceName,
            status = status,
            version = version,
            author = author
        })
    end
    
    return resources
end

function GetVehiclesData()
    local vehicles = {}
    local vehiclePool = GetGamePool('CVehicle')

    for i = 1, #vehiclePool do
        local vehicle = vehiclePool[i]

        -- Sla voertuigen over die geen netwerkentiteit zijn (anders krijg je warnings)
        if not NetworkGetEntityIsNetworked(vehicle) then
            goto continue
        end

        local model = GetEntityModel(vehicle)
        local modelName = GetDisplayNameFromVehicleModel(model)

        local owner = "No Driver"
        local playerPed = PlayerPedId()
        if GetPedInVehicleSeat(vehicle, -1) == playerPed then
            owner = "You"
        end

        local coords = GetEntityCoords(vehicle)
        local streetName, crossingRoad = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local location = GetStreetNameFromHashKey(streetName)

        local plate = GetVehicleNumberPlateText(vehicle)

        if crossingRoad ~= 0 then
            location = location .. " / " .. GetStreetNameFromHashKey(crossingRoad)
        end

        table.insert(vehicles, {
            id = NetworkGetNetworkIdFromEntity(vehicle),
            model = modelName,
            owner = owner,
            plate = plate,
            location = location
        })

        ::continue::
    end

    return vehicles
end


RegisterNUICallback('closePanel', function(data, cb)
    CloseAdminPanel()
    cb('ok')
end)

RegisterNUICallback('sendMessageToPlayer', function(data, cb)
    local playerId = tonumber(data.playerId)
    local message = data.message
    
    if playerId and message then
        TriggerServerEvent('CyberAnticheat:send:message', playerId, message)
    end
    
    cb('ok')
end)

RegisterNUICallback('addAnnouncement', function(data, cb)
    local title = data.title
    local content = data.content
    
    if title and content then
        local time = "Just now"
        table.insert(announcements, 1, {
            title = title,
            content = content,
            time = time
        })
        
        TriggerServerEvent('CyberAnticheat:announce', title, content)
    end
    
    cb('ok')
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    local model = data.model
    
    if model then
        local hash = GetHashKey(model)
        
        if IsModelInCdimage(hash) and IsModelAVehicle(hash) then
            RequestModel(hash)
            
            while not HasModelLoaded(hash) do
                Citizen.Wait(0)
            end
            
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            
            local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, GetEntityHeading(playerPed), true, false)
            
            SetPedIntoVehicle(playerPed, vehicle, -1)
            SetVehicleEngineOn(vehicle, true, true, false)
            SetModelAsNoLongerNeeded(hash)
            
            local dashboardData = GetDashboardData()
            local vehiclesData = GetVehiclesData()
            
            SendNUIMessage({
                type = "updateData",
                dashboardData = dashboardData,
                vehiclesData = vehiclesData
            })
        else
            TriggerEvent('chat:addMessage', {
                color = {255, 0, 0},
                multiline = true,
                args = {"System", "Invalid vehicle model."}
            })
        end
    end
    
    cb('ok')
end)

RegisterNUICallback('deleteClosestVehicle', function(data, cb)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local closestVehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
    
    if DoesEntityExist(closestVehicle) then
        DeleteEntity(closestVehicle)
        
        local dashboardData = GetDashboardData()
        local vehiclesData = GetVehiclesData()
        
        SendNUIMessage({
            type = "updateData",
            dashboardData = dashboardData,
            vehiclesData = vehiclesData
        })
    else
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "No vehicle found nearby."}
        })
    end
    
    cb('ok')
end)

RegisterNUICallback('deleteAllVehicles', function(data, cb)
    local vehicles = GetGamePool('CVehicle')
    
    for i = 1, #vehicles do
        DeleteEntity(vehicles[i])
    end

    local dashboardData = GetDashboardData()
    local vehiclesData = GetVehiclesData()
    
    SendNUIMessage({
        type = "updateData",
        dashboardData = dashboardData,
        vehiclesData = vehiclesData
    })
    
    cb('ok')
end)

local isNoclipActive = false

local function ToggleNoclip()
    local ped = PlayerPedId()

    if isNoclipActive then
        SetEntityInvincible(ped, false)
        SetEntityVisible(ped, true, false)
        FreezeEntityPosition(ped, false)
        SetEntityCollision(ped, true, true)
        isNoclipActive = false
    else
        SetEntityInvincible(ped, true)
        SetEntityVisible(ped, false, false)
        FreezeEntityPosition(ped, true)
        SetEntityCollision(ped, false, false)
        isNoclipActive = true
    end
end

-- Tick loop
CreateThread(function()
    while true do
        Wait(0)
        if isNoclipActive then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local camRot = GetGameplayCamRot(2)
            local direction = RotationToDirection(camRot)
            local rightDir = RotationToDirection(vector3(0.0, 0.0, camRot.z + 90.0))

            local speed = IsControlPressed(0, 21) and 2.5 or 1.0 -- SHIFT = sneller

            -- Vooruit / achteruit
            if IsControlPressed(0, 32) then -- W
                coords = coords + direction * speed
            end
            if IsControlPressed(0, 33) then -- S
                coords = coords - direction * speed
            end
            -- Links / rechts
            if IsControlPressed(0, 34) then -- A
                coords = coords - rightDir * speed
            end
            if IsControlPressed(0, 35) then -- D
                coords = coords + rightDir * speed
            end
            -- Omhoog / omlaag
            if IsControlPressed(0, 44) then -- Q
                coords = coords + vector3(0.0, 0.0, speed)
            end
            if IsControlPressed(0, 20) then -- Z
                coords = coords - vector3(0.0, 0.0, speed)
            end

            SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, true, true, true)
        end
    end
end)


-- NUI callback
RegisterNUICallback('toggleNoclip', function(data, cb)
    ToggleNoclip()
    cb('ok')
end)


RegisterNUICallback('kickPlayer', function(data, cb)
    local playerId = tonumber(data.playerId)
    local reason = data.reason
    
    if playerId and reason then
        TriggerServerEvent('CyberAnticheat:kickPlayer:Admin', playerId, reason)
    end
    
    cb('ok')
end)

RegisterNUICallback('banPlayer', function(data, cb)
    local playerId = tonumber(data.playerId)
    local reason = data.reason
    local duration = tonumber(data.duration) or 0
    
    if playerId and reason then
        TriggerServerEvent('CyberAnticheat:banHandler', playerId, reason)
    end
    
    cb('ok')
end)

RegisterNUICallback('unbanPlayer', function(data, cb)
    local banId = data.banId
    
    if banId then
        TriggerServerEvent('CyberAnticheat:unbanHandler:Admin', banId)
    end
    
    cb('ok')
end)

RegisterNUICallback('restartResource', function(data, cb)
    local resourceName = data.resourceName
    
    if resourceName then
        TriggerServerEvent('CyberAnticheat:restartResource', resourceName)
    end
    
    cb('ok')
end)

RegisterNUICallback('stopResource', function(data, cb)
    local resourceName = data.resourceName
    
    if resourceName then
        TriggerServerEvent('CyberAnticheat:stopResource', resourceName)
    end
    
    cb('ok')
end)

RegisterNUICallback('startResource', function(data, cb)
    local resourceName = data.resourceName
    
    if resourceName then
        TriggerServerEvent('CyberAnticheat:startResource', resourceName)
    end
    
    cb('ok')
end)

RegisterNUICallback('teleportToVehicle', function(data, cb)
    local vehicleId = tonumber(data.vehicleId)
    
    if vehicleId then
        local vehicle = NetworkGetEntityFromNetworkId(vehicleId)
if vehicle == 0 or not DoesEntityExist(vehicle) then
    print("[CyberAnticheat] Ongeldige vehicleId of voertuig bestaat niet:", vehicleId)
    cb({ success = false })
    return
end
        
        if DoesEntityExist(vehicle) then
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(vehicle)
            
            SetEntityCoords(playerPed, coords.x, coords.y, coords.z)
        end
    end
    
    cb('ok')
end)

RegisterNUICallback('deleteVehicle', function(data, cb)
    local vehicleId = tonumber(data.vehicleId)
    
    if vehicleId then
        local vehicle = NetworkGetEntityFromNetworkId(vehicleId)
if vehicle == 0 or not DoesEntityExist(vehicle) then
    print("[CyberAnticheat] Ongeldige vehicleId of voertuig bestaat niet:", vehicleId)
    cb({ success = false })
    return
end
        
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
            
            local dashboardData = GetDashboardData()
            local vehiclesData = GetVehiclesData()
            
            SendNUIMessage({
                type = "updateData",
                dashboardData = dashboardData,
                vehiclesData = vehiclesData
            })
        end
    end
    
    cb('ok')
end)

RegisterNUICallback('teleportPlayerToMe', function(data, cb)
    local playerId = tonumber(data.playerId)
    
    if playerId then
        TriggerServerEvent('CyberAnticheat:teleportPlayerToMe', playerId)
    end
    
    cb('ok')
end)

RegisterNUICallback('teleportToPlayer', function(data, cb)
    local playerId = tonumber(data.playerId)
    
    if playerId then
        TriggerServerEvent('CyberAnticheat:teleportToPlayer', playerId)
    end
    
    cb('ok')
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(30000) 
        
        if display then
            local dashboardData = GetDashboardData()
            local playersData = GetPlayersData()
            local resourcesData = GetResourcesData()
            local vehiclesData = GetVehiclesData()
            
            SendNUIMessage({
                type = "updateData",
                dashboardData = dashboardData,
                playersData = playersData,
                resourcesData = resourcesData,
                vehiclesData = vehiclesData,
                announcementsData = announcements
            })
        end
    end
end)

local ESX = nil
local QBCore = nil
local UseESX = false
local UseQBCore = false
local playerHistory = {}


-- On resource start, attempt to detect which framework is running
CreateThread(function()
    Wait(1000) -- give time for frameworks to start

    if GetResourceState("qb-core") == "started" then
        UseQBCore = true
        QBCore = exports["qb-core"]:GetCoreObject()
        print("^2[CyberAnticheat-Client] Using QBCore^0")

    elseif GetResourceState("es_extended") == "started" then
        UseESX = true
        local function compareVersions(v1, v2)
            local v1Parts = {}
            local v2Parts = {}
        
            -- Split the version strings into parts
            for part in string.gmatch(v1, "[^%.]+") do
                table.insert(v1Parts, tonumber(part))
            end
            for part in string.gmatch(v2, "[^%.]+") do
                table.insert(v2Parts, tonumber(part))
            end
        
            -- Compare each part numerically
            for i = 1, math.max(#v1Parts, #v2Parts) do
                local v1Part = v1Parts[i] or 0
                local v2Part = v2Parts[i] or 0
                if v1Part > v2Part then
                    return true
                elseif v1Part < v2Part then
                    return false
                end
            end
        
            return false -- Versions are equal
        end
        
        if compareVersions(GetResourceMetadata("es_extended", "version"), "1.9.0") then
            print(compareVersions(GetResourceMetadata("es_extended", "version"), "1.9.0"))
            ESX = exports["es_extended"]:getSharedObject()
        else
            print(compareVersions(GetResourceMetadata("es_extended", "version"), "1.9.0"))
            TriggerEvent("esx:getSharedObject", function(obj) ESX = obj end)
            print("leckeier")
        end
        print("^2[CyberAnticheat-Client] Using ESX^0")

    else
        print("^1[CyberAnticheat-Client] WARNING: No QBCore or ESX detected.^0")
    end
end)

lib.callback.register('CyberAnticheat:getBans', function(source)
    return LoadBans() -- Schrijf eventueel LoadBans() zelf of haal uit DB
end)


--------------------------------------------------------------
-- HELPER: WRAPPED SERVER CALLBACK (ESX.TriggerServerCallback 
--         OR QBCore.Functions.TriggerCallback)
--------------------------------------------------------------
local function FrameworkTriggerServerCallback(name, cb, ...)

    while not (UseESX or UseQBCore) do
        Citizen.Wait(1000)
    end
    
    if UseESX and ESX then
        ESX.TriggerServerCallback(name, cb, ...)
    elseif UseQBCore and QBCore then
        QBCore.Functions.TriggerCallback(name, cb, ...)
    else
        print("^1[CyberAnticheat-Client] No framework to handle callback: " .. tostring(name))
    end
end

--------------------------------------------------------------
-- HELPER: GET PLAYER'S 'GROUP' CROSS-FRAMEWORK
--         (In QBCore, there's no default 'group'. 
--         We'll just guess it might be in qbData.job.name.)
--------------------------------------------------------------
local function GetFrameworkPlayerGroup()
    while not (UseESX or UseQBCore) do
        Citizen.Wait(1000)
    end
    if UseESX and ESX then
        local xData = ESX.GetPlayerData()
        return xData and xData.group or "user"

    elseif UseQBCore and QBCore then
        local qbData = QBCore.Functions.GetPlayerData()
        if qbData and qbData.job then
            -- You might have a custom approach, but let's just return the job name
            return qbData.job.name
        end
        return "user"
    end
    return "unknown"
end

--------------------------------------------------------------
-- The rest of your code, updated to remove direct ESX calls --
--------------------------------------------------------------
local Shared = {}
local configLoaded = false

-- Toggle state for freecam
local freeCamActive = false
-- Reference to our active camera
local freeCamHandle = nil
-- Store the camera’s rotation so we don’t rely on ped heading
local freeCamRot = vector3(0.0, 0.0, 0.0)

-- Load config via cross-framework callback
local function loadConfig()
    FrameworkTriggerServerCallback('CyberAnticheat:get:config', function(config)
        Shared = config
        configLoaded = true
    end)
end

loadConfig()

---------------------------------------
-- FREECAM FUNCTIONS
---------------------------------------
local function StartFreecam()
    if freeCamActive then return end
    freeCamActive = true

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    freeCamRot = GetEntityRotation(playerPed, 2)

    freeCamHandle = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(freeCamHandle, coords.x, coords.y, coords.z + 2.0)
    SetCamRot(freeCamHandle, freeCamRot.x, freeCamRot.y, freeCamRot.z, 2)

    SetCamActive(freeCamHandle, true)
    RenderScriptCams(true, false, 0, true, true)

    FreezeEntityPosition(playerPed, true)
    SetEntityVisible(playerPed, false, false)
    SetEntityCollision(playerPed, false, false)
end

local function StopFreecam()
    if not freeCamActive then return end
    freeCamActive = false

    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(freeCamHandle, false)
    freeCamHandle = nil

    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, false)
    SetEntityVisible(playerPed, true, false)
    SetEntityCollision(playerPed, true, true)
end

---------------------------------------
-- FREECAM RENDERING THREAD
---------------------------------------
Citizen.CreateThread(function()
    local speedNormal = 0.5
    local speedFast   = 3.0

    while true do
        Citizen.Wait(0)
        if freeCamActive and freeCamHandle then
            local camCoords = GetCamCoord(freeCamHandle)
            local camRot    = GetCamRot(freeCamHandle, 2)
            local moveSpeed = IsControlPressed(0, 21) and speedFast or speedNormal 

            if IsControlPressed(0, 32) then 
                camCoords = camCoords + RotationToDirection(camRot) * moveSpeed
            end
            if IsControlPressed(0, 33) then 
                camCoords = camCoords - RotationToDirection(camRot) * moveSpeed
            end
            if IsControlPressed(0, 34) then 
                local heading = (camRot.z - 90.0) % 360.0
                local dir = vector3(math.cos(math.rad(heading)), math.sin(math.rad(heading)), 0.0)
                camCoords = camCoords + (dir * moveSpeed)
            end
            if IsControlPressed(0, 35) then 
                local heading = (camRot.z + 90.0) % 360.0
                local dir = vector3(math.cos(math.rad(heading)), math.sin(math.rad(heading)), 0.0)
                camCoords = camCoords + (dir * moveSpeed)
            end
            if IsControlPressed(0, 85) then 
                camCoords = vector3(camCoords.x, camCoords.y, camCoords.z + moveSpeed)
            end
            if IsControlPressed(0, 48) then 
                camCoords = vector3(camCoords.x, camCoords.y, camCoords.z - moveSpeed)
            end

            local xAxis = (GetDisabledControlNormal(0, 1) * 8.0)
            local yAxis = (GetDisabledControlNormal(0, 2) * 8.0)
            camRot = vector3(camRot.x - yAxis, 0.0, camRot.z - xAxis)

            local playerPed = PlayerPedId()
            for _, player in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(player)
                if ped ~= playerPed then
                    local pedCoords = GetEntityCoords(ped)
                    if #(camCoords - pedCoords) < 50.0 then 
                        DrawText3D(pedCoords.x, pedCoords.y, pedCoords.z + 1.0, "ID: " .. GetPlayerServerId(player))
                    end
                end
            end

            SetCamCoord(freeCamHandle, camCoords.x, camCoords.y, camCoords.z)
            SetCamRot(freeCamHandle, camRot.x, camRot.y, camRot.z, 2)
        end
    end
end)

function DrawText3D(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

function RotationToDirection(rotation)
    local adjustedRotation = {
        x = math.rad(rotation.x),
        y = math.rad(rotation.y),
        z = math.rad(rotation.z)
    }
    local direction = vector3(
        -math.sin(adjustedRotation.z) * math.cos(adjustedRotation.x),
         math.cos(adjustedRotation.z) * math.cos(adjustedRotation.x),
         math.sin(adjustedRotation.x)
    )
    return direction
end

---------------------------------------
-- NUI CALLBACKS / COMMANDS
---------------------------------------

-- Toggling FreeCam from NUI
RegisterNUICallback("FreeCamToggle", function(data, cb)
    if freeCamActive then
        StopFreecam()
    else
        StartFreecam()
    end
    cb('ok')
end)

-- This command triggers the NUI menu:
RegisterCommand("cybermenu", function()
    -- Cross-framework callback to check the group
    FrameworkTriggerServerCallback('CyberAnticheat:get:group', function(group)
        if Shared.ADMIN_GROUPS and Shared.ADMIN_GROUPS[group] then
            OpenAdminPanel()
        end
    end)
end, false)

RegisterNUICallback("closeUI", function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    local playerGroup = GetFrameworkPlayerGroup() 
    if not (Shared.ADMIN_GROUPS and Shared.ADMIN_GROUPS[playerGroup]) then
        cb({ success = false, message = "No permission" })
        return
    end

    local vehicleName = data.vehicleName
    if vehicleName and vehicleName ~= "" then
        spawnVehicle(vehicleName)
        cb({ success = true })
    else
        cb({ success = false, message = "Invalid vehicle name." })
    end
end)

RegisterNUICallback('banPlayer', function(data, cb)
    local playerGroup = GetFrameworkPlayerGroup()
    if not (Shared.ADMIN_GROUPS and Shared.ADMIN_GROUPS[playerGroup]) then
        cb({ success = false, message = "No permission" })
        return
    end

    local playerID = tonumber(data.playerID)
    if not playerID then
        cb({ success = false, message = "Invalid player ID" })
        return
    end

    local reason = data.reason or 'Not provided'
    TriggerServerEvent('CyberAnticheat:banHandler:Admin', playerID, reason)
    cb({ success = true })
end)


RegisterNUICallback('unbanPlayer', function(data, cb)
    local playerGroup = GetFrameworkPlayerGroup()
    if not (Shared.ADMIN_GROUPS and Shared.ADMIN_GROUPS[playerGroup]) then
        cb({ success = false, message = "No permission" })
        return
    end

    local banID = data.banID 
    TriggerServerEvent('CyberAnticheat:unbanHandler:Admin', banID)
    cb({ success = true })
end)

function spawnVehicle(vehicleName)
    local playerGroup = GetFrameworkPlayerGroup()
    if not (Shared.ADMIN_GROUPS and Shared.ADMIN_GROUPS[playerGroup]) then
        return
    end
    
    local playerPed = PlayerPedId()
    local pos = GetEntityCoords(playerPed)

    local hash = GetHashKey(vehicleName)
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(0)
    end

    -- ✅ Spawn met netMission=true (2e true), zodat hij genetworked is
    local vehicle = CreateVehicle(hash, pos.x, pos.y, pos.z, GetEntityHeading(playerPed), true, true)

    -- ✅ Zorg dat hij een mission entity is
    SetEntityAsMissionEntity(vehicle, true, true)

    -- ✅ Veilig controleren of hij een geldig netwerk ID heeft
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then
        -- print("^1[CyberAnticheat] WARNING: Voertuig is niet genetworked!^0")
        return
    end

    -- ✅ Zet speler in voertuig en voltooi spawn
    TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
    SetVehicleOnGroundProperly(vehicle)
    SetModelAsNoLongerNeeded(hash)
end

function OpenAdminPanel()
    display = true
    SetNuiFocus(true, true)
    
    local dashboardData = GetDashboardData()
    local playersData = GetPlayersData()
    local resourcesData = GetResourcesData()
    local vehiclesData = GetVehiclesData()
    
    SendNUIMessage({
        type = "openPanel",
    })
    
    SendNUIMessage({
        type = "updateData",
        dashboardData = dashboardData,
        playersData = playersData,
        resourcesData = resourcesData,
        vehiclesData = vehiclesData,
        announcementsData = announcements
    })
end

function CloseAdminPanel()
    display = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = "closePanel"
    })
end

function GetDashboardData()
    local players = GetActivePlayers()
    local playerCount = #players
    
    local resourceCount = GetNumResources()
    
    local vehicleCount = 0
    local vehicles = GetGamePool('CVehicle')
    vehicleCount = #vehicles
    
    local hours = GetClockHours()
    local minutes = GetClockMinutes()
    local currentTime = string.format("%02d:%02d", hours, minutes)
    table.insert(playerHistory, {time = currentTime, count = playerCount})
    
    if #playerHistory > 24 then
        table.remove(playerHistory, 1)
    end
    
    return {
        playerCount = playerCount,
        resourceCount = resourceCount,
        vehicleCount = vehicleCount,
        playerHistory = playerHistory
    }
end

function GetPlayersData()
    local players = {}

    for _, playerId in ipairs(GetActivePlayers()) do
        local playerName = GetPlayerName(playerId) or "Unknown"
        local playerServerId = GetPlayerServerId(playerId) or -1
        local steamId = "Unknown"

        local ping = lib.callback.await('CyberAnticheat:server:get:ping', false)

        table.insert(players, {
            id = playerServerId,
name = lib.callback.await('CyberAnticheat:server:get:name', false, playerServerId),
steamId = lib.callback.await('CyberAnticheat:server:get:steamname', false, playerServerId),
            status = "online",
            ping = ping
        })
    end

    return players
end

function GetResourcesData()
    local resources = {}
    
    for i = 0, GetNumResources() - 1 do
        local resourceName = GetResourceByFindIndex(i)
        
        local version = GetResourceMetadata(resourceName, "version", 0) or "1.0"
        local author = GetResourceMetadata(resourceName, "author", 0) or "Unknown"
        local status = GetResourceState(resourceName)
        
        table.insert(resources, {
            name = resourceName,
            status = status,
            version = version,
            author = author
        })
    end
    
    return resources
end

function GetVehiclesData()
    local vehicles = {}
    local vehiclePool = GetGamePool('CVehicle')
    
    for i = 1, #vehiclePool do
        local vehicle = vehiclePool[i]
        local model = GetEntityModel(vehicle)
        local modelName = GetDisplayNameFromVehicleModel(model)
        
        local owner = "No Driver"
        local playerPed = PlayerPedId()
        if GetPedInVehicleSeat(vehicle, -1) == playerPed then
            owner = "You"
        end

        local coords = GetEntityCoords(vehicle)
        local streetName, crossingRoad = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local location = GetStreetNameFromHashKey(streetName)

        local plate = GetVehicleNumberPlateText(vehicle)
        
        if crossingRoad ~= 0 then
            location = location .. " / " .. GetStreetNameFromHashKey(crossingRoad)
        end

        local netId = 0
if NetworkGetEntityIsNetworked(vehicle) then
    netId = NetworkGetNetworkIdFromEntity(vehicle)
end

        
table.insert(vehicles, {
    id = netId,
    model = modelName,
    owner = owner,
    plate = plate,
    location = location
})

    end
    
    return vehicles
end

RegisterNUICallback('closePanel', function(data, cb)
    CloseAdminPanel()
    cb('ok')
end)

RegisterNUICallback('sendMessageToPlayer', function(data, cb)
    local playerId = tonumber(data.playerId)
    local message = data.message
    
    if playerId and message then
        TriggerServerEvent('CyberAnticheat:send:message', playerId, message)
    end
    
    cb('ok')
end)

RegisterNUICallback('addAnnouncement', function(data, cb)
    local title = data.title
    local content = data.content
    
    if title and content then
        local time = "Just now"
        table.insert(announcements, 1, {
            title = title,
            content = content,
            time = time
        })
        
        TriggerServerEvent('CyberAnticheat:announce', title, content)
    end
    
    cb('ok')
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    local model = data.model
    
    if model then
        local hash = GetHashKey(model)
        
        if IsModelInCdimage(hash) and IsModelAVehicle(hash) then
            RequestModel(hash)
            
            while not HasModelLoaded(hash) do
                Citizen.Wait(0)
            end
            
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            
            local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, GetEntityHeading(playerPed), true, false)
            
            SetPedIntoVehicle(playerPed, vehicle, -1)
            SetVehicleEngineOn(vehicle, true, true, false)
            SetModelAsNoLongerNeeded(hash)
            
            local dashboardData = GetDashboardData()
            local vehiclesData = GetVehiclesData()
            
            SendNUIMessage({
                type = "updateData",
                dashboardData = dashboardData,
                vehiclesData = vehiclesData
            })
        else
            TriggerEvent('chat:addMessage', {
                color = {255, 0, 0},
                multiline = true,
                args = {"System", "Invalid vehicle model."}
            })
        end
    end
    
    cb('ok')
end)

RegisterNUICallback('deleteClosestVehicle', function(data, cb)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local closestVehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
    
    if DoesEntityExist(closestVehicle) then
        DeleteEntity(closestVehicle)
        
        local dashboardData = GetDashboardData()
        local vehiclesData = GetVehiclesData()
        
        SendNUIMessage({
            type = "updateData",
            dashboardData = dashboardData,
            vehiclesData = vehiclesData
        })
    else
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "No vehicle found nearby."}
        })
    end
    
    cb('ok')
end)

RegisterNUICallback('deleteAllVehicles', function(data, cb)
    local vehicles = GetGamePool('CVehicle')
    
    for i = 1, #vehicles do
        DeleteEntity(vehicles[i])
    end

    local dashboardData = GetDashboardData()
    local vehiclesData = GetVehiclesData()
    
    SendNUIMessage({
        type = "updateData",
        dashboardData = dashboardData,
        vehiclesData = vehiclesData
    })
    
    cb('ok')
end)

RegisterNUICallback('toggleNoclip', function(data, cb)
    -- Alleen deze function moet nog gemaakt worden!
    
    cb('ok')
end)

-- RegisterNUICallback('kickPlayer', function(data, cb)
--     local playerId = tonumber(data.playerId)
--     local reason = data.reason
    
--     if playerId and reason then
--         TriggerServerEvent('CyberAnticheat:kickPlayer:Admin', playerId, reason)
--     end
    
--     cb('ok')
-- end)

-- RegisterNUICallback('banPlayer', function(data, cb)
--     local playerId = tonumber(data.playerId)
--     local reason = data.reason
--     local duration = tonumber(data.duration) or 0
    
--     if playerId and reason then
--         TriggerServerEvent('CyberAnticheat:banHandler:Admin', playerId, reason)
--     end
    
--     cb('ok')
-- end)

-- RegisterNUICallback('unbanPlayer', function(data, cb)
--     local banId = data.banId
    
--     if banId then
--         TriggerServerEvent('CyberAnticheat:unbanHandler:Admin', banId)
--     end
    
--     cb('ok')
-- end)

RegisterNUICallback('restartResource', function(data, cb)
    local resourceName = data.resourceName
    
    if resourceName then
        TriggerServerEvent('CyberAnticheat:restartResource', resourceName)
    end
    
    cb('ok')
end)

RegisterNUICallback('stopResource', function(data, cb)
    local resourceName = data.resourceName
    
    if resourceName then
        TriggerServerEvent('CyberAnticheat:stopResource', resourceName)
    end
    
    cb('ok')
end)

RegisterNUICallback('startResource', function(data, cb)
    local resourceName = data.resourceName
    
    if resourceName then
        TriggerServerEvent('CyberAnticheat:startResource', resourceName)
    end
    
    cb('ok')
end)

RegisterNUICallback('teleportToVehicle', function(data, cb)
    local vehicleId = tonumber(data.vehicleId)
    
    if vehicleId then
        local vehicle = NetworkGetEntityFromNetworkId(vehicleId)
if vehicle == 0 or not DoesEntityExist(vehicle) then
    print("[CyberAnticheat] Ongeldige vehicleId of voertuig bestaat niet:", vehicleId)
    cb({ success = false })
    return
end
        
        if DoesEntityExist(vehicle) then
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(vehicle)
            
            SetEntityCoords(playerPed, coords.x, coords.y, coords.z)
        end
    end
    
    cb('ok')
end)

RegisterNUICallback('deleteVehicle', function(data, cb)
    local vehicleId = tonumber(data.vehicleId)
    
    if vehicleId then
        local vehicle = NetworkGetEntityFromNetworkId(vehicleId)
if vehicle == 0 or not DoesEntityExist(vehicle) then
    print("[CyberAnticheat] Ongeldige vehicleId of voertuig bestaat niet:", vehicleId)
    cb({ success = false })
    return
end
        
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
            
            local dashboardData = GetDashboardData()
            local vehiclesData = GetVehiclesData()
            
            SendNUIMessage({
                type = "updateData",
                dashboardData = dashboardData,
                vehiclesData = vehiclesData
            })
        end
    end
    
    cb('ok')
end)

RegisterNUICallback('teleportPlayerToMe', function(data, cb)
    local playerId = tonumber(data.playerId)
    
    if playerId then
        TriggerServerEvent('CyberAnticheat:teleportPlayerToMe', playerId)
    end
    
    cb('ok')
end)

RegisterNUICallback('teleportToPlayer', function(data, cb)
    local playerId = tonumber(data.playerId)
    
    if playerId then
        TriggerServerEvent('CyberAnticheat:teleportToPlayer', playerId)
    end
    
    cb('ok')
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(30000) 
        
        if display then
            local dashboardData = GetDashboardData()
            local playersData = GetPlayersData()
            local resourcesData = GetResourcesData()
            local vehiclesData = GetVehiclesData()
            
            SendNUIMessage({
                type = "updateData",
                dashboardData = dashboardData,
                playersData = playersData,
                resourcesData = resourcesData,
                vehiclesData = vehiclesData,
                announcementsData = announcements
            })
        end
    end
end)

RegisterNUICallback("client/getBans", function(data, cb)
    FrameworkTriggerServerCallback('CyberAnticheat:get:banlist', function(bans)
        cb(bans or {})
    end)
end)

RegisterNUICallback("getBans", function(_, cb)
    TriggerServerEvent("CyberAnticheat:RequestBans")
    RegisterNetEvent("CyberAnticheat:SendBans")
    AddEventHandler("CyberAnticheat:SendBans", function(bans)
        cb(bans)
    end)
end)



