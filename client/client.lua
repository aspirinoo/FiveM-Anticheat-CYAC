-------------------------------------
-- DETECT ESX OR QBCORE AT RUNTIME --
-------------------------------------
local ESX = nil
local QBCore = nil
local UseESX = false
local UseQBCore = false

local serverCallbacksReady = false
local checkingCallbacks = false

CreateThread(function()
    Wait(1000)
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
        print("^1[CyberAnticheat-Client] No QBCore or ESX found. Some features may not work^0")
    end
end)

CreateThread(function()
    checkingCallbacks = true
    while not serverCallbacksReady do
        TriggerServerEvent("CyberAnticheat:AreCallbacksReady")

        local p = promise.new()
        local function onReady()
            p:resolve(true)
        end
        local function onNotReady()
            p:resolve(false)
        end

        -- We'll attach these events once here:
        RegisterNetEvent("CyberAnticheat:CallbacksReady", onReady)
        RegisterNetEvent("CyberAnticheat:CallbacksNotReady", onNotReady)

        local success = Citizen.Await(p)
        
        if success then
            serverCallbacksReady = true
            print("^2[CyberAnticheat-Client] Server callbacks are now registered, we can safely call them!^0")
        else
            -- not ready yet
            Wait(1000)
        end
    end
    checkingCallbacks = false
end)

-- print("here clientjajaj1")

CreateThread(function()
    Wait(2000) -- wacht even tot speler volledig geladen is
    TriggerServerEvent("CyberAnticheat:MarkPlayerJoined")
end)

RegisterNetEvent("CyberAnticheat:ForceSoloSession", function()
    -- Routing bucket methode (zet speler in aparte 'dimensie')
    local playerId = PlayerId()
    local ped = PlayerPedId()

    -- Optioneel effect of melding
    SetEntityVisible(ped, false, false)
    SetTimeout(2000, function()
        SetEntityVisible(ped, true, false)
    end)
end)

-------------------------------------------
-- WAIT FOR FRAMEWORK IN SERVER CALLBACK --
-------------------------------------------
local function FrameworkTriggerServerCallback(name, cb, ...)
    -- Wacht tot een framework is geladen
    while (not UseESX and not UseQBCore) do
        -- print("^1[CyberAnticheat-Client] Waiting for framework to load...^0")
        Wait(500)
    end

    -- Wacht totdat server callbacks klaar zijn
    while (not serverCallbacksReady) do
        -- print("^1[CyberAnticheat-Client] Waiting for server callbacks to be ready...^0")
        Wait(100)
    end

    -- Roep de juiste callback aan
    if UseESX and ESX then
        ESX.TriggerServerCallback(name, cb, ...)
    elseif UseQBCore and QBCore then
        QBCore.Functions.TriggerCallback(name, cb, ...)
    else
        print("^1[CyberAnticheat-Client] No framework to call callback: "..tostring(name))
    end
end
----------------------------------
-- SIMPLE NOTIFICATION WRAPPER  --
----------------------------------
local function ShowNotification(msg)
    if UseESX then
        TriggerEvent("esx:showNotification", msg)
    elseif UseQBCore then
        QBCore.Functions.Notify(msg, "inform", 5000)
    else
        print("Notification: "..msg)
    end
end

--------------------------------
-- LOAD CONFIG LOGIC
--------------------------------
local Shared = {}
local configLoaded = false

function loadConfig()
    FrameworkTriggerServerCallback('CyberAnticheat:get:config', function(config)
        Shared = config
        configLoaded = true
    end)
end

CreateThread(function()
    while not serverCallbacksReady do
        Wait(100)
    end
    loadConfig()
end)

-- print("here clientjajaj2")

-------------------------------------------
-- EXAMPLE: Some non-protection thread
-------------------------------------------
local clientUUID = tostring(GetPlayerServerId(PlayerId())) .. "-" .. tostring(math.random(100000, 999999))
local resourceName = GetCurrentResourceName()
local secretKey = math.random(100000, 999999)
local lastHeartbeat = 0
local lastStealthCheck = 0

local function WaitForPlayerToLoad()
    while not NetworkIsSessionStarted() or not NetworkIsPlayerActive(PlayerId()) or not DoesEntityExist(PlayerPedId()) do
        Citizen.Wait(100)
    end
end

-- Registreer volledig zodra speler is geladen
Citizen.CreateThread(function()
    WaitForPlayerToLoad()
    Citizen.Wait(2000)
    TriggerServerEvent('CyberAnticheat:registerUUID', clientUUID, secretKey, false)
end)

-- Heartbeat loop
Citizen.CreateThread(function()
    WaitForPlayerToLoad()
    while true do
        Citizen.Wait(math.random(4500, 6000))
        if GetCurrentResourceName() ~= resourceName then
            TriggerServerEvent('CyberAnticheat:kickPlayer', 'Anticheat gemanipuleerd of gestopt!')
            return
        end
        local token = math.random(100000, 999999)
        lastHeartbeat = GetGameTimer()
        TriggerServerEvent('CyberAnticheat:heartbeat', resourceName, clientUUID, secretKey, token)
    end
end)

-- Stealth check loop
Citizen.CreateThread(function()
    WaitForPlayerToLoad()
    while true do
        Citizen.Wait(math.random(8500, 12500))
        if GetGameTimer() - lastStealthCheck < 7000 then return end
        lastStealthCheck = GetGameTimer()
        local token = math.random(100000, 999999)
        TriggerServerEvent('CyberAnticheat:stealthCheck', clientUUID, secretKey, token)
    end
end)

AddEventHandler('onClientResourceStop', function(stoppedResource)
    if stoppedResource == GetCurrentResourceName() then
        if clientUUID then
            TriggerServerEvent('CyberAnticheat:kickPlayer', 'You tried to stop the Anticheat!', clientUUID)
        end
        ExecuteCommand("ensure " .. GetCurrentResourceName())
    end
end)

AddEventHandler("onClientResourceStart", function(startedResource)
    if startedResource == resourceName and not clientUUID then
        TriggerServerEvent('CyberAnticheat:kickPlayer', 'Anticheat herstartte zonder registratie!')
    end
end)

-- print("CLIENT CHECK 1")


---------------------------------------------------------------------------------
-- TELEPORT DETECTION
---------------------------------------------------------------------------------
local teleportDetectionTime = 5000
local maxTeleportSpeed = 400
local lastPosition = vector3(0, 0, 0)
local lastCheckTime = 0
local isTeleportingByScript = false
local teleportCooldown = 1000

function getPlayerPosition()
    return GetEntityCoords(PlayerPedId())
end

function checkForTeleportation()
    local currentTime = GetGameTimer()
    if lastPosition == vector3(0, 0, 0) then
        lastPosition = getPlayerPosition()
        return 
    end

    if currentTime - lastCheckTime >= teleportDetectionTime then
        local currentPosition = getPlayerPosition()
        local distance = #(currentPosition - lastPosition)
        -- Make sure we check if Shared.Client['Max Distance Telelporting'] exists
        local maxDist = (Shared.Client and Shared.Client['Max Distance Telelporting']) or 200.0

        if distance > maxDist and not isTeleportingByScript then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped) then return end
            TriggerServerEvent('CyberAnticheat:banHandler', 'Teleport Detected')
        end
        lastPosition = currentPosition
        lastCheckTime = currentTime
    end
end

function setEntityCoordsSafely(entity, x, y, z)
    isTeleportingByScript = true
    Wait(101)
    SetEntityCoords(entity, x, y, z, false, false, false, false)
    Wait(teleportCooldown)
    isTeleportingByScript = false
    lastPosition = vector3(x, y, z)
end

Citizen.CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    while true do
        Citizen.Wait(1000)
        if not Shared.Protections or not Shared.Protections['Anti Teleport'] then
            break
        end
        checkForTeleportation()
    end
end)

-- print("CLIENT CHECK 2")
---------------------------------------------------------------------------------
-- ANTI EXPLOSION2
---------------------------------------------------------------------------------
Citizen.CreateThread(function()
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    while true do
        Citizen.Wait(1000)
        if not Shared.Protections or not Shared.Protections['Anti Explosion'] then
            break
        end

        local playerCoords = GetEntityCoords(PlayerPedId())
        local explosionDetected = false
        local explosionTypeDetected = nil

        for _, explosionType in pairs({2, 4, 7, 8, 9, 12, 21, 39, 82}) do
            if IsExplosionInArea(
                explosionType,
                playerCoords.x - 50.0, playerCoords.y - 50.0, playerCoords.z - 50.0,
                playerCoords.x + 50.0, playerCoords.y + 50.0, playerCoords.z + 50.0
            ) then
                explosionDetected = true
                explosionTypeDetected = explosionType
                break
            end
        end

        if explosionDetected then
            if explosionTypeDetected and Shared.Client['Explosion Whitelist'][explosionTypeDetected] == true then
                return -- Gewhitelist, dus geen ban
            end
            TriggerServerEvent('CyberAnticheat:banHandler', 'Explosion Detected', explosionTypeDetected)
        end
    end
end)

-- print("here clientjajaj3")

--------------------------------------
-- OVERRIDE AddExplosion
--------------------------------------
local originalAddExplosion = AddExplosion

AddExplosion = function(x, y, z, explosionType, damage, isAudible, isInvisible, cameraShake)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = Vdist(playerCoords.x, playerCoords.y, playerCoords.z, x, y, z)

    if distance <= 50.0 then
        TriggerServerEvent('CyberAnticheat:banHandler', 'Explosion Detected (Native)', explosionType)
    end

    originalAddExplosion(x, y, z, explosionType, damage, isAudible, isInvisible, cameraShake)
end

---------------------------------------------------------------------------------
-- ANTI INVISIBLE EXPLOSION
---------------------------------------------------------------------------------
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if not Shared.Protections or not Shared.Protections['Anti Invisible Explosion'] then
            break
        end

        local playerCoords = GetEntityCoords(PlayerPedId())
        local explosionDetected = false
        local explosionTypeDetected = nil

        for _, explosionType in pairs({2, 4, 7, 8, 9, 12, 21}) do
            if IsExplosionInArea(
                explosionType,
                playerCoords.x - 50.0, playerCoords.y - 50.0, playerCoords.z - 50.0,
                playerCoords.x + 50.0, playerCoords.y + 50.0, playerCoords.z + 50.0
            ) then
                if isInvisible then
                    explosionDetected = true
                    explosionTypeDetected = explosionType
                    break
                end
            end
        end

        -- Check whitelist before banning
        local playerId = GetPlayerServerId(PlayerId())
        if explosionDetected and not isPlayerInWhitelist(playerId) then
            TriggerServerEvent('CyberAnticheat:banHandler', 'Invisible Explosion Detected', explosionTypeDetected)
        end
    end
end)

-- print("CLIENT CHECK 3")

-- print("here clientjajaj4")

---------------------------------------------------------------------------------
-- ANTI PHONE EXPLOSION
---------------------------------------------------------------------------------
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if not Shared.Protections or not Shared.Protections['Anti Phone Explosion'] then
            break
        end

        local playerCoords = GetEntityCoords(PlayerPedId())
        local explosionDetected = false
        local explosionTypeDetected = nil

        for _, explosionType in pairs({2, 4, 7, 8, 9, 12, 21}) do
            if IsExplosionInArea(
                explosionType,
                playerCoords.x - 50.0, playerCoords.y - 50.0, playerCoords.z - 50.0,
                playerCoords.x + 50.0, playerCoords.y + 50.0, playerCoords.z + 50.0
            ) then
                -- Detect if it’s from a phone
                if explosionType == 2 then -- assuming 2 corresponds to phone explosions
                    explosionDetected = true
                    explosionTypeDetected = explosionType
                    break
                end
            end
        end

        -- Check whitelist before banning
        local playerId = GetPlayerServerId(PlayerId())
        if explosionDetected and not isPlayerInWhitelist(playerId) then
            TriggerServerEvent('CyberAnticheat:banHandler', 'Phone Explosion Detected', explosionTypeDetected)
        end
    end
end)

-- print("here clientjajaj5")

---------------------------------------------------------------------------------
-- ANTI SILENT EXPLOSION
---------------------------------------------------------------------------------
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if not Shared.Protections or not Shared.Protections['Anti Silent Explosion'] then
            break
        end

        local playerCoords = GetEntityCoords(PlayerPedId())
        local explosionDetected = false
        local explosionTypeDetected = nil

        for _, explosionType in pairs({2, 4, 7, 8, 9, 12, 21}) do
            if IsExplosionInArea(
                explosionType,
                playerCoords.x - 50.0, playerCoords.y - 50.0, playerCoords.z - 50.0,
                playerCoords.x + 50.0, playerCoords.y + 50.0, playerCoords.z + 50.0
            ) then
                if not isAudible then
                    explosionDetected = true
                    explosionTypeDetected = explosionType
                    break
                end
            end
        end

        -- Check whitelist before banning
        local playerId = GetPlayerServerId(PlayerId())
        if explosionDetected and not isPlayerInWhitelist(playerId) then
            TriggerServerEvent('CyberAnticheat:banHandler', 'Silent Explosion Detected', explosionTypeDetected)
        end
    end
end)

---------------------------------------------------------------------------------
-- ANTI PLATE CHANGER
---------------------------------------------------------------------------------
function IsPlayerInWhitelistedAreePlateChanging()
    local playerCoords = GetEntityCoords(PlayerPedId())
    if not (Shared.Client and Shared.Client['Plate Changing']) then
        return false
    end
    for _, area in ipairs(Shared.Client['Plate Changing']['Whitelisted Areas']) do
        if #(playerCoords - area.coords) <= area.radius then 
            return true
        end
    end
    return false
end

Citizen.CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    local VEH = nil
    local PLATE = nil

    while true do
        Citizen.Wait(1000)
        if not Shared.Protections or not Shared.Protections['Anti Plate Changer'] then
            break
        end

        if IsPedInAnyVehicle(PlayerPedId(), false) then
            local vehicle = GetVehiclePedIsIn(PlayerPedId())
            local plate = GetVehicleNumberPlateText(vehicle)

            if VEH and PLATE and plate ~= PLATE then
                if not IsPlayerInWhitelistedAreePlateChanging() then
                    -- Wacht even om te controleren of het geen false-positive is (zoals texture reload of spawn verandering)
                    Wait(2000)

                    -- Controleer opnieuw voor zekerheid
                    local newPlate = GetVehicleNumberPlateText(vehicle)
                    if newPlate ~= PLATE then
                        DeleteVehicle(VEH)
                        Wait(500) -- kleine delay om DeleteVehicle zijn werk te laten doen
                        -- print("ban doeie")
                        TriggerServerEvent('CyberAnticheat:banHandler', 'Plate Changer Detected')
                    end
                end
            end

            VEH = vehicle
            PLATE = plate
        else
            VEH = nil
            PLATE = nil
        end
    end
end)


-- print("here clientjajaj6")

---------------------------------------------------------------------------------
-- ARMOUR DETECTION
---------------------------------------------------------------------------------
Citizen.CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    while true do
        Citizen.Wait(1000)
        if not Shared.Protections or not Shared.Protections['Armour Detection'] then
            break
        end

        Wait(1000)
        local maxArmour = (Shared.Client and Shared.Client['MAX ARMOUR']) or 100
        if GetPedArmour(PlayerPedId()) > maxArmour then 
            TriggerServerEvent('CyberAnticheat:banHandler', 'Armour Detection - '..GetPedArmour(PlayerPedId())..'')
        end
    end
end)

-- print("CLIENT CHECK 4")


---------------------------------------------------------------------------------
-- ANTI MODEL CHANGER
---------------------------------------------------------------------------------
local function validateModel()
    local hash = tostring(GetEntityModel(PlayerPedId()))
    local allowedHash = tostring(GetHashKey("mp_m_freemode_01"))
    local allowedHash2 = tostring(GetHashKey("mp_f_freemode_01"))
    if hash ~= allowedHash or hash ~= allowedHash2 then
        print('CyberAnticheat:banHandler', 'Model changed' .. hash)
        TriggerServerEvent('CyberAnticheat:banHandler', 'Model changed')
    end
end

Citizen.CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    while true do
        Citizen.Wait(1000)
        if not Shared.Protections or not Shared.Protections['Anti Model Changer'] then
            break
        end
        local myModel = GetEntityModel(PlayerPedId())
        if Shared.Client and Shared.Client['Whitelisted Models'] then
            if not Shared.Client['Whitelisted Models'][tostring(myModel)] then
                print('CyberAnticheat:banHandler', 'Model changed' .. myModel)
                TriggerServerEvent('CyberAnticheat:banHandler', 'Model changed')
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        TriggerServerEvent('CyberAnticheat:flagPlayer', 'Tried to stop the anticheat script')
    end
end)

---------------------------------------------------------------------------------
-- ANTI INVISIBLE2
---------------------------------------------------------------------------------
local isExempt = false
local playerLoaded = false
local playerInvisible = false
local lastWarningTime = 0

AddEventHandler("playerSpawned", function()
    playerLoaded = true
    TriggerServerEvent('CyberAnticheat:isExempt')
end)

Citizen.CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

   while not playerLoaded or isExempt == nil do
        Citizen.Wait(500)
   end

    while true do
        Citizen.Wait(300)
        if not Shared.Protections or not Shared.Protections['Anti invisible2'] then
            break
        end

        local playerPed = PlayerPedId()
        if not DoesEntityExist(playerPed) or IsEntityDead(playerPed) then
            Citizen.Wait(1100)
        else
            local entityAlpha = GetEntityAlpha(playerPed)
            local isVisible = IsEntityVisible(playerPed)
            local hasCollision = not IsEntityOccluded(playerPed)

            if not isExempt and ((not isVisible) or entityAlpha <= 150 or not hasCollision) then
                SetEntityVisible(playerPed, true, false)
                SetEntityAlpha(playerPed, 255, false)
                Citizen.Wait(1100)

                if GetEntityAlpha(playerPed) < 255 or not IsEntityVisible(playerPed) then
                    local currentTime = GetGameTimer()
                    if playerInvisible then
                        if currentTime - lastWarningTime > 1200 then
                            TriggerServerEvent('CyberAnticheat:banHandler', 'Invisible Detection #2')
                            -- TriggerServerEvent('CyberAnticheat:Log', "^1[Anti Invisible] Player was invisible again")
                            lastWarningTime = currentTime
                        end
                    else
                        playerInvisible = true
                        -- TriggerServerEvent('CyberAnticheat:Log', "^1[Anti Invisible] Player was invisible and is now visible.")
                        lastWarningTime = currentTime
                    end
                end
            else
                if playerInvisible and isVisible and entityAlpha == 255 and hasCollision then
                    playerInvisible = false
                end
            end
        end
    end
end)

RegisterNetEvent('CyberAnticheat:returnExemptStatus', function(status)
    isExempt = status
end)

-- print("CLIENT CHECK 5")

---------------------------------------------------------------------------------
-- ANTI SPAWN VEHICLE2
---------------------------------------------------------------------------------
local entityEnumerator = {
    __gc = function(enum)
        if enum.destructor and enum.handle then
            enum.destructor(enum.handle)
        end
        enum.destructor = nil
        enum.handle = nil
    end
}
function EnumerateEntities(initFunc, moveFunc, disposeFunc)
    return coroutine.wrap(function()
        local iter, id = initFunc()
        if not id or id == 0 then
            disposeFunc(iter)
            return
        end
        local enum = {handle = iter, destructor = disposeFunc}
        setmetatable(enum, entityEnumerator)

        local next = true
        repeat
            coroutine.yield(id)
            next, id = moveFunc(iter)
        until not next

        enum.destructor, enum.handle = nil, nil
        disposeFunc(iter)
    end)
end
function EnumerateVehicles()
    return EnumerateEntities(FindFirstVehicle, FindNextVehicle, EndFindVehicle)
end

Citizen.CreateThread(function()
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    DisableIdleCamera(true)
    Wait(16000)

    while true do
        Wait(1000)
        if not Shared.Protections or not Shared.Protections['Anti Spawn Vehicle2'] then break end

        for vehicle in EnumerateVehicles() do
            local script = GetEntityScript(vehicle)
            if script and (script == "scr_2" or script == "startup" or script == "screenshot-basic" or script == "scr_3") then
                local popType = GetEntityPopulationType(vehicle)
                if not (popType >= 4 and popType <= 7) then
                    TriggerServerEvent('CyberAnticheat:banHandler', 'Vehicle Spawn Detected #2')
                    DeleteEntity(vehicle)
                end
            end
        end
    end
end)

local function generateValidToken()
    -- Dit is een voorbeeld van "szykEg" = 123 122 121 107 101 103 (moet eindigen op kkEg)
    return "123 122 121 107 101 103"
end

-- Voorbeeld: spawn voertuig met beveiligde trigger
function requestEntitySpawn(type)
    local token = generateValidToken()
    local resource = GetCurrentResourceName()
    TriggerServerEvent("cfx:getdataforserver", type, token, resource)
end


---------------------------------------------------------------------------------
-- ANTI SPAWN VEHICLE
---------------------------------------------------------------------------------

local entityEnumerator = {
    __gc = function(enum)
        if enum.destructor and enum.handle then
            enum.destructor(enum.handle)
        end
        enum.destructor = nil
        enum.handle = nil
    end
}
function EnumerateEntities(initFunc, moveFunc, disposeFunc)
    return coroutine.wrap(function()
        local iter, id = initFunc()
        if not id or id == 0 then
            disposeFunc(iter)
            return
        end
        local enum = {handle = iter, destructor = disposeFunc}
        setmetatable(enum, entityEnumerator)

        local next = true
        repeat
            coroutine.yield(id)
            next, id = moveFunc(iter)
        until not next

        enum.destructor, enum.handle = nil, nil
        disposeFunc(iter)
    end)
end
function EnumerateVehicles()
    return EnumerateEntities(FindFirstVehicle, FindNextVehicle, EndFindVehicle)
end

Citizen.CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    DisableIdleCamera(true)
    Citizen.Wait(16000)

    while true do
        Citizen.Wait(1000)
        if not Shared.Protections or not Shared.Protections['Anti Spawn Vehicle'] then
            break
        end

        for vehicle in EnumerateVehicles() do
            if GetEntityScript(vehicle) == "scr_2" or GetEntityScript(vehicle) == "startup"
               or GetEntityScript(vehicle) == "screenshot-basic" or GetEntityScript(vehicle) == "scr_3" then
                local popType = GetEntityPopulationType(vehicle)
                if popType ~= 4 or popType ~= 7 or popType ~= 5 or popType ~= 6 then
                    TriggerServerEvent('CyberAnticheat:banHandler', 'Vehicle Spawn Detected')
                end
            end
        end
    end
end)

---------------------------------------------------------------------------------
-- ANTI SPAWN VEHICLE #3
---------------------------------------------------------------------------------

AddEventHandler('entityCreating', function(entity)
    -- Check of de bescherming is ingeschakeld
    if not Shared.Protections or not Shared.Protections['Anti Spawn Vehicle3'] then 
        return
    end

    if not DoesEntityExist(entity) then return end

    local entityType = GetEntityType(entity)
    if entityType ~= 2 then return end -- Alleen voertuigen

    -- Haal informatie op
    local model = GetEntityModel(entity)
    local popType = GetEntityPopulationType(entity) -- 0-7, zie uitleg onder
    local netId = NetworkGetNetworkIdFromEntity(entity)
    local owner = NetworkGetEntityOwner(entity)
    local coords = GetEntityCoords(entity)
    local resName = GetInvokingResource()

    -- Populatie types:
    -- 0 = onbekend / script
    -- 1 = Permanent
    -- 2 = Random voertuig (parked)
    -- 6 = NPC (driving)
    -- 7 = Scenario (politie, taxi's, etc)

    -- print("[Vehicle Debug]")
    -- print(("→ Model: %s"):format(model))
    -- print(("→ NetworkID: %s"):format(netId))
    -- print(("→ Entity ID: %s"):format(entity))
    -- print(("→ Coords: %s, %s, %s"):format(coords.x, coords.y, coords.z))
    -- print(("→ PopType: %s"):format(popType))
    -- print(("→ Owner (Player ID): %s"):format(owner))
    -- print(("→ Triggered by Resource: %s"):format(resName or "unknown"))

    -- Optioneel: notify speler in-game als hij een voertuig heeft gespawned
    if owner and owner > 0 then
        local name = GetPlayerName(owner)
        -- print(("[ALERT] %s (%s) heeft waarschijnlijk een voertuig gespawned."):format(name, owner))
        TriggerServerEvent('CyberAnticheat:banHandler', 'Vehicle Spawn Detected #3')
    end
end)



-- print("CLIENT CHECK 6")



-- print("here clientjajaj7")

-- print("here clientjajaj8")

-- local camdisthres = 7.26
-- local raydisthres = 10.0
-- local collcheckintv = 3000
-- local maxdetect = 3

-- local dectcount = 0
-- local lastcolcheck = 0
-- local spawnTime = 0
-- local waitAfterSpawn = 70000 -- 30 seconden wachttijd na spawn

-- AddEventHandler('playerSpawned', function()
--     spawnTime = GetGameTimer()
-- end)

-- local function CheckCameraDistance(pedCoords)
--     local camCoordsFinal = GetFinalRenderedCamCoord()
--     local distFinal = #(camCoordsFinal - pedCoords)
--     local camCoordsGame = GetGameplayCamCoord()
--     local distGameplay = #(camCoordsGame - pedCoords)
--     return math.max(distFinal, distGameplay)
-- end

-- local function CheckRaycast(pedCoords, camCoords)
--     local rayHandle = StartShapeTestRay(
--         camCoords.x, camCoords.y, camCoords.z,
--         pedCoords.x, pedCoords.y, pedCoords.z,
--         -1,
--         PlayerPedId(),
--         0
--     )
--     local _, didHit = GetShapeTestResult(rayHandle)
--     local dist = #(camCoords - pedCoords)
--     if dist > raydisthres and not didHit then
--         return true
--     end
--     return false
-- end

-- Citizen.CreateThread(function()
--     while not (UseESX or UseQBCore) do Wait(250) end
--     while not configLoaded do Wait(250) end

--     while true do
--         Citizen.Wait(1000)
--         if not Shared.Protections or not Shared.Protections['Anti Freecam'] then
--             break
--         end

--         if (GetGameTimer() - spawnTime) < waitAfterSpawn then
--             goto continue
--         end

--         local playerPed = PlayerPedId()
--         if DoesEntityExist(playerPed) then
--             local pedCoords = GetEntityCoords(playerPed, false)
--             local maxDistance = CheckCameraDistance(pedCoords)
--             if maxDistance > camdisthres then
--                 dectcount = dectcount + 1
--             else
--                 if dectcount > 0 then
--                     dectcount = dectcount - 1
--                 end
--             end

--             local pedInterior = GetInteriorFromEntity(playerPed)
--             local camCoordsFinal = GetFinalRenderedCamCoord()
--             local camInterior = GetInteriorAtCoords(camCoordsFinal.x, camCoordsFinal.y, camCoordsFinal.z)

--             if pedInterior ~= camInterior then
--                 dectcount = dectcount + 1
--             end

--             local suspiciousRay = CheckRaycast(pedCoords, camCoordsFinal)
--             if suspiciousRay then
--                 dectcount = dectcount + 1
--             end

--             if (GetGameTimer() - lastcolcheck) > collcheckintv then
--                 lastcolcheck = GetGameTimer()
--                 if not IsEntityVisible(playerPed) then
--                     dectcount = dectcount + 2
--                 end
--             end

--             if dectcount >= maxdetect then
--                 if GetVehiclePedIsIn(playerPed, false) == 0 then
--                     TriggerServerEvent('CyberAnticheat:banHandler', 'FreeCam Detected')
--                 end
--                 dectcount = 0
--             end
--         end
--         ::continue::
--     end
-- end)

-- print("here clientjajaj9")
---------------------------------------------------------------------------------
-- ANTI NIGHT / THERMAL VISION
---------------------------------------------------------------------------------
CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    while true do
        Wait(1000)
        if not Shared.Protections or not Shared.Protections['Anti Night/ThermalVision'] then
            break
        end

        if IsNightvisionActive() and not IsPedInAnyHeli(PlayerPedId()) then
            SetNightvision(false)
            TriggerServerEvent('CyberAnticheat:banHandler', 'Night Vision Detected')
        end

        if IsSeethroughActive() and not IsPedInAnyHeli(PlayerPedId()) then
            SetSeethrough(false)
            TriggerServerEvent('CyberAnticheat:banHandler', 'Thermal Vision Detected')
        end
    end
end)

---------------------------------------------------------------------------------
-- ANTI SPECTATE
---------------------------------------------------------------------------------
Citizen.CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    while true do
        Citizen.Wait(math.random(500, 1500))
        if not Shared.Protections or not Shared.Protections['Anti Spectate'] then
            break
        end

        if NetworkIsInSpectatorMode() then
            TriggerServerEvent('CyberAnticheat:checkSpectateStatus', true)
        end

        local playerPed = PlayerPedId()
        local health = GetEntityHealth(playerPed)
        if health < 0 then
            TriggerServerEvent('CyberAnticheat:banHandler', 'Spectate detected')
        end
    end
end)

---------------------------------------------------------------------------------
-- ANTI GODMODE
---------------------------------------------------------------------------------
-- Citizen.CreateThread(function()
--     -- Wacht op framework en configuratie
--     while not (UseESX or UseQBCore) do Wait(250) end
--     while not configLoaded do Wait(250) end

--     local lastHealth = GetEntityHealth(PlayerPedId())
--     local healthChanges = {}

--     while true do 
--         Citizen.Wait(1000)
--         if not Shared.Protections or not Shared.Protections['Anti Godmode'] then break end

--         local playerPed = PlayerPedId()
--         local playerId = PlayerId()
--         local vehicle = GetVehiclePedIsIn(playerPed, false)

--         if Shared.Client and Shared.Client['God Mode Protections'] then
--             -- 1: Controleer of entity kan worden beschadigd
--             if Shared.Client['God Mode Protections']['1'] and GetPlayerInvincible(playerId) and not IsEntityPositionFrozen(playerPed) then
--                 TriggerServerEvent('CyberAnticheat:banHandler', 'Godmode Detection (1)')
--                 return
--             end

--             -- 3: Controleer snelle gezondheidsstijgingen
--             if Shared.Client['God Mode Protections']['2'] then
--                 local currentHealth = GetEntityHealth(playerPed)
--                 table.insert(healthChanges, currentHealth)
--                 if #healthChanges > 5 then table.remove(healthChanges, 1) end
--                 if math.max(table.unpack(healthChanges)) - math.min(table.unpack(healthChanges)) > 100 then
--                     TriggerServerEvent('CyberAnticheat:banHandler', 'Godmode Detection (2 - Rapid Health Increase)')
--                     return
--                 end
--             end

--             -- 4: Controleer of speler geen schade ontvangt
--             if Shared.Client['God Mode Protections']['3'] then
--                 local currentHealth = GetEntityHealth(playerPed)
--                 if lastHealth == currentHealth and lastHealth < 200 then
--                     TriggerServerEvent('CyberAnticheat:banHandler', 'Godmode Detection (3 - No Damage Received)')
--                     return
--                 end
--                 lastHealth = currentHealth
--             end     

--             -- 7: Controleer of speler meer armor heeft dan toegestaan
--             if Shared.Client['God Mode Protections']['4'] then
--                 local retval, bulletProof, fireProof, explosionProof, collisionProof, meleeProof, steamProof, p7, drownProof = GetEntityProofs(playerPed)
--                 if GetPlayerInvincible(playerPed) or GetPlayerInvincible_2(playerPed) then
--                     TriggerServerEvent('CyberAnticheat:banHandler', playerId, 'Godmode Detection (4 - Invincible)')
--                     return
--                 end
--                 if retval == 1 and bulletProof == 1 and fireProof == 1 and explosionProof == 1 and collisionProof == 1 and steamProof == 1 and p7 == 1 and drownProof == 1 then
--                     TriggerServerEvent('CyberAnticheat:banHandler', 'Godmode Detection (4 - All Proofs)')
--                     return
--                 end
--             end
--         end
--     end
-- end)

local godmodeStrikes = {}
local strikeThreshold = 2

function getEntityHitByBullet()
    local playerPed = PlayerPedId()
    local camRot = GetGameplayCamRot(2)
    local camCoords = GetGameplayCamCoord()
    local direction = RotationToDirection(camRot)
    local endCoords = vec3(
        camCoords.x + direction.x * 1000.0,
        camCoords.y + direction.y * 1000.0,
        camCoords.z + direction.z * 1000.0
    )
    local rayHandle = StartShapeTestRay(
        camCoords.x, camCoords.y, camCoords.z,
        endCoords.x, endCoords.y, endCoords.z,
        8, playerPed, 0
    )
    local _, hit, _, _, entity = GetShapeTestResult(rayHandle)
    return hit == 1 and entity or nil
end

function RotationToDirection(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vec3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

Citizen.CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti Godmode'] then return end

    while true do
        Citizen.Wait(0)
        if IsPedArmed(PlayerPedId(), 6) and IsControlJustPressed(0, 24) then
            local entity = getEntityHitByBullet()
            if entity and IsPedAPlayer(entity) then
                local healthBefore = GetEntityHealth(entity)
                Wait(200)
                local healthAfter = GetEntityHealth(entity)

                if healthBefore == healthAfter then
                    -- Strike geven aan de speler ZELF
                    local myServerId = GetPlayerServerId(PlayerId())
                    godmodeStrikes[myServerId] = (godmodeStrikes[myServerId] or 0) + 1

                    if godmodeStrikes[myServerId] >= strikeThreshold then
                        TriggerServerEvent("cybergodmode:detected") -- zonder target
                        godmodeStrikes[myServerId] = 0
                    end
                else
                    -- Reset strikes bij geldige hit
                    local myServerId = GetPlayerServerId(PlayerId())
                    godmodeStrikes[myServerId] = 0
                end
            end
        end
    end
end)

-- print("CLIENT CHECK 6")

--------------------------------------------------------
-- ANTI Godemode 2 and 3
--------------------------------------------------------

Citizen.CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti Godmode2'] then return end
    while true do
        Citizen.Wait(500) -- Wartezeit erhöht, um Performance zu verbessern

        local playerId = PlayerId()
        local playerPed = PlayerPedId()
        local currentHealth = GetEntityHealth(playerPed)

        -- Überprüfen, ob der Spieler aktiv und das Ped valide ist
        if currentHealth > 0 and NetworkIsPlayerActive(playerId) and DoesEntityExist(playerPed) then
            local simulatedDamage = 20
            local testHealth = math.max(currentHealth - simulatedDamage, 0) -- Sicherstellen, dass die Gesundheit nicht negativ wird

            SetEntityHealth(playerPed, testHealth) -- Simuliertes Senken der Gesundheit
            Citizen.Wait(200) -- Warten, um Änderungen zu überprüfen
            local newHealth = GetEntityHealth(playerPed)

            -- Logik für God-Mode-Check
            if newHealth >= currentHealth then
                -- Zusätzliche Sicherheitsüberprüfung, um False Positives zu minimieren
                Citizen.Wait(200) -- Doppelte Validierung nach einer kurzen Pause
                newHealth = GetEntityHealth(playerPed)
                if newHealth >= currentHealth then
                    -- God Mode festgestellt, Server benachrichtigen
                    TriggerServerEvent('CyberAnticheat:banHandler', 'Godmode Detected #2')
                end
            end

            -- Gesundheit wiederherstellen
            SetEntityHealth(playerPed, currentHealth)
        end
    end
end)

            -- Anti-GodMode check
    local SPAWN = false
    local checkEnabled = false

    AddEventHandler("playerSpawned", function()
        Citizen.Wait(2000)  -- Warte 20 Sekunden nach dem ersten Spawn
        SPAWN = true
        checkEnabled = true
    end)

    Citizen.CreateThread(function()
        if not Shared.Protections or not Shared.Protections['Anti Godmode3'] then return end
        while true do
            Citizen.Wait(3000)
            if SPAWN and checkEnabled then 
                if NetworkIsPlayerActive(PlayerId()) then
                    if not IsNuiFocused() and IsScreenFadedIn() then
                        local retval, bulletProof, fireProof, explosionProof, collisionProof, meleeProof, steamProof, p7, drownProof = GetEntityProofs(PlayerPedId())
                        local isInvincible = GetPlayerInvincible(PlayerId()) or GetPlayerInvincible_2(PlayerId())
                        local canBeDamaged = GetEntityCanBeDamaged(PlayerPedId())

                        -- Debugging-Meldungen für die Überprüfung (falls notwendig)
                        -- print("Invincible Status:", isInvincible)
                        -- print("Entity Proofs:", retval, bulletProof, fireProof, explosionProof, collisionProof, steamProof, p7, drownProof)
                        -- print("Can Be Damaged:", canBeDamaged)

                        -- Godmode-Prüfungen
                        if isInvincible and canBeDamaged then
                            Citizen.Wait(500)  -- zusätzliche Wartezeit zur Absicherung
                            if GetPlayerInvincible(PlayerId()) or GetPlayerInvincible_2(PlayerId()) then
                                TriggerServerEvent('CyberAnticheat:banHandler', 'Godmode Detected #3')
                            end
                        elseif retval == 1 and bulletProof == 1 and fireProof == 1 and explosionProof == 1 and collisionProof == 1 and steamProof == 1 and p7 == 1 and drownProof == 1 then
                            Citizen.Wait(500)  -- zusätzliche Wartezeit zur Absicherung
                            local retValCheck, bulletProofCheck, fireProofCheck, explosionProofCheck, collisionProofCheck, meleeProofCheck, steamProofCheck, p7Check, drownProofCheck = GetEntityProofs(PlayerPedId())
                            if retValCheck == 1 and bulletProofCheck == 1 and fireProofCheck == 1 and explosionProofCheck == 1 and collisionProofCheck == 1 and steamProofCheck == 1 and p7Check == 1 and drownProofCheck == 1 then
                                TriggerServerEvent('CyberAnticheat:banHandler', 'Godmode Detected #3')
                            end
                        elseif not canBeDamaged then
                            Citizen.Wait(500)  -- zusätzliche Wartezeit zur Absicherung
                            if not GetEntityCanBeDamaged(PlayerPedId()) then
                                TriggerServerEvent('CyberAnticheat:banHandler', 'Godmode Detected #3')
                            end
                        end
                    end
                end
            end
        end
    end)

    -- print("CLIENT CHECK 7")

-- print("here clientjajaj10")
---------------------------------------------------------------------------------
-- ANTI SPEEDHACK
---------------------------------------------------------------------------------
local fallStartTime = nil
local lastCoords = nil
local distanceThreshold = 5
local vehicleExitTime = nil
local wasInVehicle = false
local WHITELIST_DURATION = 7000 -- 7 seconden whitelist

Citizen.CreateThread(function()
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    while true do
        Citizen.Wait(500)

        if not Shared.Protections or not Shared.Protections['Anti Speedhack'] then
            break
        end

        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local heightAboveGround = GetEntityHeightAboveGround(playerPed)
        local isOnFoot = IsPedOnFoot(playerPed)
        local isFalling = IsPedFalling(playerPed)
        local onGround = isOnFoot and not isFalling and heightAboveGround < 1.5
        local inVehicle = IsPedInAnyVehicle(playerPed, false)

        -- Detectie: speler was net in voertuig maar nu niet meer → start whitelist timer
        if not inVehicle and wasInVehicle and not vehicleExitTime then
            vehicleExitTime = GetGameTimer()
        elseif inVehicle then
            vehicleExitTime = nil
        end
        wasInVehicle = inVehicle

        -- Valdetectie
        if isFalling and not fallStartTime then
            fallStartTime = GetGameTimer()
        end

        if onGround and fallStartTime then
            local fallTime = GetGameTimer() - fallStartTime
            fallStartTime = nil
            if fallTime > 2000 then
                inVehicle = false
            end
        end

        -- Afstand controleren
        if lastCoords then
            local distance = #(coords - lastCoords)
            if distance < distanceThreshold then
                lastCoords = coords
                goto continue
            end
        end
        lastCoords = coords

        -- Speler is binnen whitelist-tijd → skip check
        local now = GetGameTimer()
        if vehicleExitTime and (now - vehicleExitTime) <= WHITELIST_DURATION then
            goto continue
        end

        -- Normale snelheid check
        TriggerServerEvent('CyberAnticheat:checkSpeed', { x = coords.x, y = coords.y, z = coords.z }, inVehicle, onGround)

        ::continue::
    end
end)


---------------------------------------------------------------------------------
-- HELPER FOR WHITELISTED AREAS
---------------------------------------------------------------------------------
function IsPlayerInWhitelistedAreaInvisible()
    local playerCoords = GetEntityCoords(PlayerPedId())
    if not (Shared.Client and Shared.Client['Anti invisible']) then
        return false
    end
    for _, area in ipairs(Shared.Client['Anti invisible']['Whitelisted Areas']) do
        if #(playerCoords - area.coords) <= area.radius then 
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------------
-- EXPORTED FUNCTION
---------------------------------------------------------------------------------
exports('tpsafely', function(entity, coords)
    setEntityCoordsSafely(entity, coords.x, coords.y, coords.z)
end)

-- print("here client11")


-- print("here client12")
---------------------------------------------------------------------------------
-- ANTI SPOOF/ SPAWN WEAPON2
---------------------------------------------------------------------------------
CreateThread(function()
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    while true do
        Wait(3000)

        if not Shared.Protections or not Shared.Protections['Anti Spawn Weapon2'] then
            break
        end

        local PlayerPed = PlayerPedId()

        local isArmed1 = IsPedArmed(PlayerPed, 1)
        local isArmed2 = IsPedArmed(PlayerPed, 2)
        local isArmed3 = IsPedArmed(PlayerPed, 4)

        if not isArmed1 and not isArmed2 and not isArmed3 then
            goto skip
        end

        local weaponHoldStatus, weaponHash = GetCurrentPedWeapon(PlayerPed)

        -- ox_inventory
        if Shared.Inventory['ox'] then
            local oxWeaponData = exports.ox_inventory:getCurrentWeapon()
            if oxWeaponData and oxWeaponData.hash == weaponHash then
                goto skip
            else
                TriggerServerEvent('CyberAnticheat:banHandler', 'Anti Spawn/Spoof Weapon #2')
                goto skip
            end
        end

        -- ESX Inventory
        if Shared.Inventory['esx'] then
            local esxWeaponData = exports.esx_addoninventory:getCurrentWeapon()
            if esxWeaponData and esxWeaponData.hash == weaponHash then
                goto skip
            else
                TriggerServerEvent('CyberAnticheat:banHandler', 'Anti Spawn/Spoof Weapon #2')
                goto skip
            end
        end

        -- QB Inventory
        if Shared.Inventory['qb'] then
            local qbWeaponData = exports.qb_inventory:getCurrentWeapon()
            if qbWeaponData and qbWeaponData.hash == weaponHash then
                goto skip
            else
                TriggerServerEvent('CyberAnticheat:banHandler', 'Anti Spawn/Spoof Weapon #2')
                goto skip
            end
        end

        -- PS Inventory
        if Shared.Inventory['ps'] then
            local psWeaponData = exports.ps_inventory:getCurrentWeapon()
            if psWeaponData and psWeaponData.hash == weaponHash then
                goto skip
            else
                TriggerServerEvent('CyberAnticheat:banHandler', 'Anti Spawn/Spoof Weapon #2')
                goto skip
            end
        end

        -- Quasar Inventory
        if Shared.Inventory['quasar'] then
            local quasarWeaponData = exports.quasar_inventory:getCurrentWeapon()
            if quasarWeaponData and quasarWeaponData.hash == weaponHash then
                goto skip
            else
                TriggerServerEvent('CyberAnticheat:banHandler', 'Anti Spawn/Spoof Weapon #2')
                goto skip
            end
        end

        -- Custom Inventory
        if Shared.Inventory['custom'] then
            local customWeaponData = Shared.CustomInventory.getWeapon()
            if customWeaponData and customWeaponData.hash == weaponHash then
                goto skip
            else
                TriggerServerEvent('CyberAnticheat:banHandler', 'Anti Spawn/Spoof Weapon #2')
                goto skip
            end
        end

        -- Als geen enkel inventory systeem actief is maar speler wel wapen heeft
        if weaponHoldStatus then
            TriggerServerEvent('CyberAnticheat:banHandler', 'Anti Spawn/Spoof Weapon #2')
        end

        ::skip::
    end
end)

-- print("CLIENT CHECK 8")
---------------------------------------------------------------------------------
-- ANTI SPOOF/ SPAWN WEAPON3
---------------------------------------------------------------------------------

local warningCount = 0

Citizen.CreateThread(function()
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    while true do
        Wait(500)

        if not Shared.Protections or not Shared.Protections['Anti Spawn Weapon3'] then
            break
        end

        local playerPed = PlayerPedId()
        local weapon = nil
        local isInVehicle = IsPedInAnyVehicle(playerPed, false)
        local warningLimit = isInVehicle and 9 or 6

        -- Controleer welk inventory systeem in de configuratie is ingeschakeld
        if Shared.Inventory['ox'] then
            weapon = exports.ox_inventory:getCurrentWeapon()
        elseif Shared.Inventory['ps'] then
            weapon = exports.ps_inventory:getCurrentWeapon()
        elseif Shared.Inventory['quasar'] then
            weapon = exports.quasar_inventory:getCurrentWeapon()
        elseif Shared.Inventory['custom'] then
            weapon = Shared.CustomInventory.getWeapon()
        elseif Shared.Inventory['esx'] then
            local xPlayer = ESX.GetPlayerData()
            if xPlayer and xPlayer.inventory then
                for _, item in pairs(xPlayer.inventory) do
                    if item.count > 0 and string.find(item.name, 'WEAPON_') then
                        weapon = { name = item.name }
                        break
                    end
                end
            end
        elseif Shared.Inventory['qb'] then
            local playerData = QBCore.Functions.GetPlayerData()
            if playerData and playerData.items then
                for _, item in pairs(playerData.items) do
                    if item and item.name and string.find(item.name, 'weapon_') then
                        weapon = { name = string.upper(item.name) } -- om te matchen met native hash
                        break
                    end
                end
            end
        end

        local nativeWeapon = GetSelectedPedWeapon(playerPed)

        if nativeWeapon ~= -1569615261 then 
            if weapon and weapon.name then
                local weaponHash = GetHashKey(weapon.name)

                if weaponHash ~= nativeWeapon then
                    warningCount = warningCount + 1

                    if warningCount > warningLimit then
                        TriggerServerEvent('CyberAnticheat:banHandler', '(Anti Spawn Weapon) #3')
                        warningCount = 0
                    end
                end
            else
                warningCount = warningCount + 1

                if warningCount > warningLimit then
                    TriggerServerEvent('CyberAnticheat:banHandler', '(Anti Spawn Weapon) #3')
                    warningCount = 0
                end
            end
        end
    end
end)

-- Nieuwe thread om warningCount na 9.5 seconden te resetten
Citizen.CreateThread(function()
    while true do
        Wait(9500)
        warningCount = 0
    end
end)

-- print("here clientjajaj12")

-- print("CLIENT CHECK 9")
---------------------------------------------------------------------------------
-- ANTI NOCLIP
---------------------------------------------------------------------------------
local function isInFreecamNoclipWhitelist()
    local pedCoords = GetEntityCoords(PlayerPedId())
    local whitelist = Shared.Client['Noclip/Freecam Whitelist'] and Shared.Client['Noclip/Freecam Whitelist']['Whitelisted Areas'] or {}
    
    for _, area in pairs(whitelist) do
        if #(pedCoords - area.coords) <= area.radius then
            return true
        end
    end

    return false
end


local wasDead = false
local noclipProtectionActive = false

Citizen.CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    while true do
        Citizen.Wait(200)

        if not Shared.Protections or not Shared.Protections['Anti Noclip'] then
            break
        end

        local playerPed = PlayerPedId()

        if not DoesEntityExist(playerPed) then
            goto continue
        end

        local isDead = IsPlayerDead(playerPed)

        -- Check of speler zojuist levend is geworden
        if wasDead and not isDead then
            noclipProtectionActive = true
            CreateThread(function()
                Wait(25000) -- 25 seconden bescherming
                noclipProtectionActive = false
            end)
        end

        wasDead = isDead -- Update vorige status

        -- Skip detectie tijdens bescherming
        if noclipProtectionActive then
            goto continue
        end

        local isInAirVehicle = IsPedInAnyPlane(playerPed) or IsPedInAnyHeli(playerPed)
        local isInGroundVehicle = IsPedInAnyVehicle(playerPed, false)
        local isPlayingValidAnim = IsEntityPlayingAnim(playerPed, 'missfinale_c2mcs_1', 'fin_c2_mcs_1_camman', 3)
        local height = GetEntityHeightAboveGround(playerPed)
        local vx, vy, vz = table.unpack(GetEntityVelocity(playerPed))

        local isFalling = IsPedFalling(playerPed)
        local isJumping = IsPedJumping(playerPed)
        local isSwimming = IsPedSwimming(playerPed) or IsPedSwimmingUnderWater(playerPed)
        local isClimbing = IsPedClimbing(playerPed)
        local isAttached = IsEntityAttached(playerPed)

        local minHeight = 1.0
        local suspiciousMovement = false

        if not isSwimming and not isClimbing and not isDead and not isAttached then
            if (isFalling or isJumping) and height < minHeight and vz < -0.5 then
                suspiciousMovement = true
            elseif not isFalling and not isJumping and height > 2.5 and (math.abs(vx) + math.abs(vy)) < 0.1 and math.abs(vz) < 0.1 then
                suspiciousMovement = true
            end

            if suspiciousMovement and not isInFreecamNoclipWhitelist() then
                TriggerServerEvent('CyberAnticheat:checkNoclip', {
                    planeorheli = isInAirVehicle,
                    invehicle = isInGroundVehicle,
                    animcheck = isPlayingValidAnim,
                    height = height,
                    velocity = {vx, vy, vz},
                    isFalling = isFalling,
                    isJumping = isJumping,
                    isSwimming = isSwimming,
                    isClimbing = isClimbing,
                    isDead = isDead,
                    isAttached = isAttached,
                    isSuspicious = suspiciousMovement
                })
            end
        end

        ::continue::
    end
end)

-- print("CLIENT CHECK 10")

---------------------------------------------------------------------------------
-- ANTI BeBetter NOCLIP
---------------------------------------------------------------------------------

Citizen.CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    local suspiciousTime = 0
    local banThreshold = 3000 -- 4 seconden in milliseconden

    while true do
        Citizen.Wait(200)
        if not Shared.Protections or not Shared.Protections['Anti Bebetter Noclip'] then
            break
        end

        if isInFreecamNoclipWhitelist() then
            suspiciousTime = 0 -- ook resetten als speler in whitelist zit
            goto continue
        end

        local ped = PlayerPedId()
        if not DoesEntityExist(ped) then 
            suspiciousTime = 0
            goto continue
        end

        local isInVehicle = IsPedInAnyVehicle(ped, false)
        local isInHeli = IsPedInAnyHeli(ped)
        local isInPlane = IsPedInAnyPlane(ped)

        local vx, vy, vz = table.unpack(GetEntityVelocity(ped))
        local speed = math.sqrt(vx*vx + vy*vy + vz*vz)
        local height = GetEntityHeightAboveGround(ped)

        local isFalling = IsPedFalling(ped)
        local isParachuting = GetPedParachuteState(ped) >= 0 and GetPedParachuteState(ped) <= 2
        local isFreefall = IsPedInParachuteFreeFall(ped)

        local legitMovement = (
            isInVehicle or isInHeli or isInPlane or
            isFalling or isParachuting or isFreefall
        )

        if not legitMovement and height > 3.0 and speed < 0.5 then
            suspiciousTime = suspiciousTime + 200
            if suspiciousTime >= banThreshold then
                TriggerServerEvent('CyberAnticheat:banHandler', 'BEBETTER Noclip Detected')
                break
            end
        else
            suspiciousTime = 0
        end

        ::continue::
    end
end)


-- Citizen.CreateThread(function()
--     while true do
--         Citizen.Wait(1000) -- elke seconde

--         local ped = PlayerPedId()
--         if not DoesEntityExist(ped) then return end

--         local inPlaneOrHeli = IsPedInAnyPlane(ped) or IsPedInAnyHeli(ped)
--         local inVehicle = IsPedInAnyVehicle(ped, false)
--         local isFalling = IsPedFalling(ped)
--         local isJumping = IsPedJumping(ped)
--         local isSwimming = IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped)
--         local isClimbing = IsPedClimbing(ped)
--         local isRagdoll = IsPedRagdoll(ped)
--         local isParachuting = GetPedParachuteState(ped) >= 0 and GetPedParachuteState(ped) <= 2
--         local isFreefall = IsPedInParachuteFreeFall(ped)
--         local isDead = IsEntityDead(ped)
--         local isAttached = IsEntityAttached(ped)
--         local alpha = GetEntityAlpha(ped)

--         local vx, vy, vz = table.unpack(GetEntityVelocity(ped))
--         local speed = math.sqrt(vx*vx + vy*vy + vz*vz)
--         local height = GetEntityHeightAboveGround(ped)
--         local coords = GetEntityCoords(ped)

--         local suspiciousReasons = {}

--         local naturalState = (
--             inPlaneOrHeli or inVehicle or isFalling or isJumping or isSwimming or
--             isClimbing or isRagdoll or isParachuting or isFreefall or isAttached or isDead
--         )

--         -- Check op verdachte situaties
--         if not naturalState then
--             if height > 3.0 and speed < 1.0 then
--                 table.insert(suspiciousReasons, "zweeft boven grond zonder beweging")
--             end

--             if speed > 15.0 and height > 2.5 then
--                 table.insert(suspiciousReasons, "beweegt te snel op hoogte")
--             end

--             if alpha < 100 then
--                 table.insert(suspiciousReasons, "lage alpha (mogelijk onzichtbaar)")
--             end
--         end

--         -- Debug output
--         print("^5[CyberAnticheat DEBUG]^7")
--         print("  Hoogte:", string.format("%.2f", height))
--         print("  Snelheid:", string.format("%.2f", speed))
--         print("  Alpha:", alpha)
--         print("  In voertuig:", inVehicle)
--         print("  In vliegtuig/heli:", inPlaneOrHeli)
--         print("  Vallen:", isFalling)
--         print("  Zwemmen:", isSwimming)
--         print("  Klimmen:", isClimbing)
--         print("  Parachute:", isParachuting)
--         print("  Attached:", isAttached)
--         print("  Dood:", isDead)

--         if #suspiciousReasons > 0 then
--             print("^1[VERDACHT GEDRAG GEDETECTEERD]^7 Redenen:")
--             for _, reason in ipairs(suspiciousReasons) do
--                 print("  -", reason)
--             end
--             print("-----------------------------------------")
--         end
--     end
-- end)

CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    local detectionTime = 0
    local requiredTime = 2500 -- 3 seconden

    while true do
        Citizen.Wait(200)
        if not Shared.Protections or not Shared.Protections['Anti Noclip2'] then
            break
        end

        local ped = PlayerPedId()

        if IsPedFalling(ped) then
            local coords = GetEntityCoords(ped)
            local speed = GetEntitySpeed(ped)

            if coords.z > 35 and speed < 0.1 then
                detectionTime = detectionTime + 200
                if detectionTime >= requiredTime then
                    TriggerServerEvent('CyberAnticheat:banHandler', 'Noclip Detected #2')
                    break
                end
            else
                detectionTime = 0
            end
        else
            detectionTime = 0
        end
    end
end)



---------------------------------------------------------------------------------
-- ANTI NOCLIP3
---------------------------------------------------------------------------------

local wasFalling = false
local lastHeight = 0.0
local zeroSpeedStart = 0

CreateThread(function()
    while true do
        Wait(200)

        if not Shared.Protections or not Shared.Protections['Anti Noclip3'] then 
            goto continue
        end

        local ped = PlayerPedId()
        local isFalling = IsPedFalling(ped)
        local z = GetEntityCoords(ped).z
        local speed = GetEntitySpeed(ped)

        -- Bereken tijd zonder snelheid
        local timeNoSpeed = zeroSpeedStart ~= 0 and (GetGameTimer() - zeroSpeedStart) or 0
        local heightDiff = lastHeight ~= 0.0 and (z - lastHeight) or 0.0

        -- Debug
        -- print("^5[CyberAnticheat DEBUG]^7")
        -- print("  Hoogte:\t" .. string.format("%.2f", z))
        -- print("  Snelheid:\t" .. string.format("%.2f", speed))
        -- print("  Vallen:\t" .. tostring(isFalling))
        -- print("  Tijd zonder speed:\t" .. timeNoSpeed)
        -- print("  Hoogteverschil:\t" .. string.format("%.2f", heightDiff))

        if isFalling then
            -- 🔺 Plotselinge stijging
            if lastHeight ~= 0.0 and z - lastHeight > 26.0 then
                TriggerServerEvent('CyberAnticheat:banHandler', 'Noclip Detected #3')
                -- print("^1[CyberAnticheat]^7 Speler gebanned: Noclip (Falling omhoog)")
                return
            end

            -- 🟥 Valt met 0 snelheid
            if speed < 0.05 then
                if zeroSpeedStart == 0 then
                    zeroSpeedStart = GetGameTimer()
                elseif GetGameTimer() - zeroSpeedStart > 5500 then
                    TriggerServerEvent('CyberAnticheat:banHandler', 'Noclip Detected #3')
                    -- print("^1[CyberAnticheat]^7 Speler gebanned: Noclip (Falling met 0 speed)")
                    return
                end
            else
                zeroSpeedStart = 0
            end

            -- 🧨 Nieuw: hoogte exact 0.00 tijdens val
            if z <= 0.01 then
                TriggerServerEvent('CyberAnticheat:banHandler', 'Noclip Detected #3')
                -- print("^1[CyberAnticheat]^7 Speler gebanned: Noclip (Falling met hoogte 0.00)")
                return
            end

            lastHeight = z
            wasFalling = true
        else
            wasFalling = false
            zeroSpeedStart = 0
            lastHeight = 0.0
        end

        ::continue::
    end
end)


---------------------------------------------------------------------------------
-- ANTI PARACHUTE NOCLIP
---------------------------------------------------------------------------------
local ncfix = false
local lastTimeChecked = GetGameTimer()

AddEventHandler('playerSpawned', function()
    if not ncfix then
        ncfix = true
        Wait(2500)
        ncfix = false
    end
end)

Citizen.CreateThread(function()
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    local prevCoords = GetEntityCoords(PlayerPedId())  -- Houd de vorige coördinaten bij

    while true do
        Wait(500)  -- Iets langer om spam te voorkomen

        if not Shared.Protections or not Shared.Protections['Anti Parachute Noclip'] then break end

        local ped = PlayerPedId()
        if not DoesEntityExist(ped) or IsEntityDead(ped) then goto continue end

        local coords = GetEntityCoords(ped)
        local height = GetEntityHeightAboveGround(ped)
        local vx, vy, vz = table.unpack(GetEntityVelocity(ped))

        local isParachuting = false
        local isMovingTooFast = false
        local isMovingUpwards = false

        -- Uitsluiten van legitieme situaties
        local allow = 
            IsPedInAnyVehicle(ped, false) or 
            IsPedInAnyPlane(ped) or 
            IsPedInAnyHeli(ped) or
            IsPedJumping(ped) or 
            IsPedFalling(ped) or 
            IsPedSwimming(ped) or 
            IsPedClimbing(ped) or 
            IsEntityAttached(ped) or 
            IsPauseMenuActive() or
            IsPlayerDead(PlayerId()) or
            not HasPedGotWeapon(ped, GetHashKey("GADGET_PARACHUTE"), false)  -- Controleer of de speler geen parachute heeft

        -- Controleer of de speler omhoog gaat met de parachute
        if not allow and height > 1.5 then
            if vz > 0.1 then  -- Positieve verticale snelheid betekent omhoog gaan
                isMovingUpwards = true
            end

            -- Controleer of de speler te snel naar links of rechts beweegt (abnormaal snel)
            local speedLimit = 10.0  -- Stel een limiet in voor horizontale snelheid, bijvoorbeeld 10 m/s
            if math.abs(vx) > speedLimit or math.abs(vy) > speedLimit then
                isMovingTooFast = true
            end
        end

        -- Als er verdacht omhoog bewegen of te snel bewegen naar links/rechts met parachute wordt gedetecteerd
        if isMovingUpwards or isMovingTooFast then
            TriggerServerEvent('CyberAnticheat:checkParachuteMovement', {
                coords = coords,
                height = height,
                velocity = {vx, vy, vz},
                isMovingTooFast = isMovingTooFast,
                isMovingUpwards = isMovingUpwards
            })
        end

        -- Update de vorige coördinaten voor de volgende check
        prevCoords = coords
        lastTimeChecked = GetGameTimer()

        ::continue::
    end
end)

-- print("CLIENT CHECK 10.1")


---------------------------------------------------------------------------------
-- CHECK NOCLIP2
---------------------------------------------------------------------------------
-- Citizen.CreateThread(function()
--     -- WAIT FOR FRAMEWORK & CONFIG
--     while not (UseESX or UseQBCore) do Wait(250) end
--     while not configLoaded do Wait(250) end

--     while not NetworkIsPlayerActive(PlayerId()) or not PlayerPedId() do
--         Citizen.Wait(860)
--     end

--     while true do
--         Citizen.Wait(math.random(5000, 6500))
--         if not Shared or not Shared.Protections or not Shared.Protections['Anti Noclip2'] then
--             return
--         end

--         local ped = PlayerPedId()
--         local playerCoords = GetEntityCoords(ped)
--         local speed = GetEntitySpeed(ped)
--         local vehicle = GetVehiclePedIsIn(ped, false)
--         local inVehicle = (vehicle ~= 0)
--         local isFalling = IsPedInParachuteFreeFall(ped)
--         local isRagdoll = IsPedRagdoll(ped)
--         local _, groundZ = GetGroundZFor_3dCoord(playerCoords.x, playerCoords.y, playerCoords.z, 0)
--         local groundCheck = playerCoords.z - groundZ

--         TriggerServerEvent('CyberAnticheat:CheckNoclip2', playerCoords, speed, inVehicle, isFalling, isRagdoll, groundCheck)
--     end
-- end)

-- function notifyAdmins(message)
--     print("[NotifyAdmins] " .. message)
-- end

-- Citizen.CreateThread(function()
--     while true do
--         Wait(20000)
--         -- If you want to reset warnings every X seconds, do it here
--     end
-- end)

-- Citizen.CreateThread(function()
--     while true do
--         Citizen.Wait(5000)
--         -- Possibly watch for event-blocking if you want
--     end
-- end)

RegisterNetEvent('CyberAnticheat:checkSpectateStatus')
AddEventHandler('CyberAnticheat:checkSpectateStatus', function(isSpectating)
    local playerId = source
    if isSpectating then
        local playerPed = GetPlayerPed(playerId)
        if IsPedInAnyVehicle(playerPed, false) then
            TriggerServerEvent('CyberAnticheat:banHandler', 'Spectate mode manipulation detected')
        end
    end
end)

RegisterNetEvent('CyberAnticheat:checkExplosion')
AddEventHandler('CyberAnticheat:checkExplosion', function(playerId, playerCoords, reason)
    print("Received explosion info from player " .. playerId .. " reason: " .. tostring(reason))
    if reason == "Suspicious Frequency" then
        print("Suspicious explosion frequency, banning player " .. playerId)
        TriggerServerEvent('CyberAnticheat:banHandler', 'Suspicious Explosion Activity')
    end
end)

-- print("here clientjajaj13")
---------------------------------------------------------------------------------
-- ANTI SUPER PUNCH
---------------------------------------------------------------------------------
local health = {}
CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    while true do
        Wait(3000)
        if not Shared.Protections or not Shared.Protections['Anti Super Punch'] then
            break
        end

        AddEventHandler('gameEventTriggered', function(eventName, eventData)
            if eventName == "CEventNetworkEntityDamage" then
                local ped2 = eventData[1]
                local attacker = eventData[2]
                local playerPed = PlayerPedId()
                if attacker == playerPed then
                    if ped2 and IsEntityAPed(playerPed) then
                        local ped2health = GetEntityHealth(ped2)
                        local maxHealth = GetEntityMaxHealth(ped2)
                        local previousHealth = health[ped2] or maxHealth
                        local damage = previousHealth - ped2health
                        local invehicle = IsPedInAnyVehicle(attacker, false)
                        health[ped2] = ped2health

                        local healthcheck = (previousHealth / maxHealth) * 100

                        if IsPedShooting(attacker) then
                            return
                        end

                        if healthcheck > 50 and ped2health <= 0 
                           and GetSelectedPedWeapon(attacker) == GetHashKey("WEAPON_UNARMED") 
                           and not invehicle then
                            TriggerServerEvent('CyberAnticheat:banHandler', 'Super Punch Detected')
                        end
                    end
                end
            end
        end)
    end
end)

local function IsPlayerHoldingHandsUp()
    return IsControlPressed(0, 323) -- Standaard "handen omhoog" control
end

CreateThread(function()
    while true do
        Wait(500)
        if IsPlayerHoldingHandsUp() then
            -- print("[DEBUG] Speler heeft handen omhoog!")
        end
    end
end)

-- print("CLIENT CHECK 10.2")
-- print("here clientjajaj13.5")

---------------------------------------------------------------------------------
-- ANTI CARRY VEHICLE
---------------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(1500)

        if not Shared.Protections or not Shared.Protections['Anti Carry Vehicle'] then
            break
        end

        local playerPed = PlayerPedId()

        if not IsPedInAnyVehicle(playerPed, false) and GetVehiclePedIsTryingToEnter(playerPed) == 0 then
            local playerCoords = GetEntityCoords(playerPed)
            local nearbyVehicles = GetNearbyEntities(playerCoords, 6.0)

            for _, vehicle in ipairs(nearbyVehicles) do
                if DoesEntityExist(vehicle) and IsEntityAVehicle(vehicle) then

                    local vehicleCoords = GetEntityCoords(vehicle)
                    local heightDiff = vehicleCoords.z - playerCoords.z

                    local isAttachedToPed = IsEntityAttachedToEntity(vehicle, playerPed)
                    local isAttachedToAnything = IsEntityAttached(vehicle)
                    local parentEntity = GetEntityAttachedTo(vehicle)

                    local vehicleSpeed = GetEntitySpeed(vehicle)

                    if (isAttachedToPed or (isAttachedToAnything and parentEntity == playerPed)) and
                       (heightDiff > 1.5 and heightDiff < 10.0) and
                       vehicleSpeed < 1.0 then

                        TriggerServerEvent('CyberAnticheat:banHandler', 'Carry Vehicle Detected')
                        DeleteEntity(vehicle)
                    end
                end
            end
        end
    end
end)

function GetNearbyEntities(coords, radius)
    local vehicles = {}
    local handle, vehicle = FindFirstVehicle()
    local success
    repeat
        if DoesEntityExist(vehicle) then
            local vehicleCoords = GetEntityCoords(vehicle)
            if #(vehicleCoords - coords) <= radius then
                table.insert(vehicles, vehicle)
            end
        end
        success, vehicle = FindNextVehicle(handle)
    until not success
    EndFindVehicle(handle)
    return vehicles
end

-- print("here clientjajaj13.6")

---------------------------------------------------------------------------------
-- ANTI REDENGINE
---------------------------------------------------------------------------------
Citizen.CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    while true do
        Citizen.Wait(0)
        if not Shared.Protections or not Shared.Protections['Anti RedEngine'] then
            break
        end

        if IsControlJustPressed(0, 24) then
            local ped = PlayerPedId()
            local isStill = IsPedStill(ped)
            local x, y = GetNuiCursorPosition()

            -- Debug: (optional) 
            -- print("[Anti-Cheat Client] Left-click. IsPedStill="..tostring(isStill).." Coords=("..x..","..y..")")

            if isStill then
                TriggerServerEvent("reportCursorPosition", x, y)
            end
        end
    end
end)

RegisterNetEvent("cybersecure:notify")
AddEventHandler("cybersecure:notify", function(message, type)
    SendNUIMessage({
        action = "notify",
        message = message,
        type = type or "info"
    })
end)

function GetNearbyEntities(coords, radius)
    local entities = {}
    local handle, vehicle = FindFirstVehicle()
    local success

    repeat
        local vehicleCoords = GetEntityCoords(vehicle)
        if #(vehicleCoords - coords) <= radius then
            table.insert(entities, vehicle)
        end
        success, vehicle = FindNextVehicle(handle)
    until not success
    EndFindVehicle(handle)

    local handle2, object = FindFirstObject()
    repeat
        local objectCoords = GetEntityCoords(object)
        if #(objectCoords - coords) <= radius then
            table.insert(entities, object)
        end
        success, object = FindNextObject(handle2)
    until not success
    EndFindObject(handle2)

    return entities
end

-- print("CLIENT CHECK 10.3")
-- print("here clientjajaj13.7")

---------------------------------------------------------------------------------
-- ANTI SPOOFED DAMAGE/WEAPON
---------------------------------------------------------------------------------
Citizen.CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    local lastBanTime = 0

    while true do
        Wait(250)

        if not Shared.Protections or not Shared.Protections['Anti Spoofed Damage/Weapon'] then
            return
        end

        local playerPed = PlayerPedId()

        -- Skip als speler in voertuig zit
        if IsPedInAnyVehicle(playerPed, false) then goto continue end

        -- Controleer of speler "unarmed" is
        local weapon = GetSelectedPedWeapon(playerPed)
        local isUnarmed = (weapon == GetHashKey('WEAPON_UNARMED'))

        -- Extra check: wordt speler als gewapend gezien?
        local isTrulyUnarmed = not IsPedArmed(playerPed, 6)

        -- Controleer of speler aan het schieten is terwijl unarmed
        if isUnarmed and isTrulyUnarmed and IsPedShooting(playerPed) then
            -- Cooldown van 10 sec om spam te voorkomen
            local currentTime = GetGameTimer()
            if currentTime - lastBanTime > 10000 then
                lastBanTime = currentTime
                TriggerServerEvent('CyberAnticheat:banHandler', 'Spoofed Damage/Weapon Detected')
                break
            end
        end

        ::continue::
    end
end)


-- print("here clientjajaj13.7.1")

---------------------------------------------------------------------------------
-- ANTI INJECTION
---------------------------------------------------------------------------------
-- local checkInterval = 60
-- Citizen.CreateThread(function()
--     -- WAIT FOR FRAMEWORK & CONFIG
--     while not (UseESX or UseQBCore) do Wait(250) end
--     while not configLoaded do Wait(250) end

--     while true do
--         Citizen.Wait(checkInterval * 1000)
--         if not Shared.Protections or not Shared.Protections['Anti Injection'] then
--             break
--         end
--         TakeScreenshot()
--     end
-- end)

-- function TakeScreenshot()
--     exports["screenshot-basic"]:requestScreenshotUpload("files://", "files[]", function(data)
--         local imageData = json.decode(data)
--         if imageData and imageData.files and imageData.files[1] then
--             local filePath = imageData.files[1].file
--             TriggerServerEvent("screenshot:save", filePath)
--         end
--     end)
-- end

-- function IsAltTabbed()
--     local screenWidth, screenHeight = GetActiveScreenResolution()
--     local x = GetDisabledControlNormal(2, 239)
--     local y = GetDisabledControlNormal(2, 240)
--     local mouseX, mouseY = screenWidth * x, screenHeight * y
--     return mouseX == screenWidth / 2 and mouseY == screenHeight / 2
-- end

---------------------------------------------------------------------------------
-- ANTI INJECTION SKRIPT
---------------------------------------------------------------------------------
-- local cheating = false
-- local menu = false
-- local valid = false
-- local enabled = {}
-- local menuOptions = {
--     "YOINK", "VOID", "FLING", "TP MARKER", "STEAL PLATE",
--     "BREAK ENGINE", "REPAIR", "HIGH SUSPENSION", "LOCK INSIDE",
--     "DELETE", "SILENT EXPLODE"
-- }
-- local strikes = 0
-- local maxStrikes = 5

-- CreateThread(function()
--     -- WAIT FOR FRAMEWORK & CONFIG
--     while not (UseESX or UseQBCore) do Wait(250) end
--     while not configLoaded do Wait(250) end

--     while true do
--         Wait(100)
--         if not Shared.Protections or not Shared.Protections['Anti Skript'] then
--             break
--         end

--         local nuiX, nuiY = GetNuiCursorPosition()
--         local screenWidth, screenHeight = GetActiveScreenResolution()
--         local startPos = ((screenHeight - (64 * 11)) / 2) - 64

--         for k, v in pairs(menuOptions) do
--             if nuiX >= 0 and nuiX <= 64 and nuiY >= startPos + (k * 64)
--                and nuiY <= (startPos + 64) + (k * 64) then
--                 enabled[v] = true
--             else
--                 enabled[v] = false
--             end
--         end

--         local x = GetDisabledControlNormal(2, 239)
--         local y = GetDisabledControlNormal(2, 240)
--         local mouseX, mouseY = screenWidth * x, screenHeight * y

--         cheating = false
--         menu = false

--         -- Check of speler stil staat
--         if IsPedStill(PlayerPedId()) then
--             if mouseX == 0 and mouseY == 0 then
--                 if nuiX >= 1 and nuiY >= 1 then
--                     menu = true
--                 end
--                 for k, v in pairs(enabled) do
--                     if v then
--                         if not IsAltTabbed() then
--                             cheating = true
--                         end
--                     end
--                 end
--             end
--         end

--         if cheating or menu then
--             SetCursorLocation(0.7, 0.7)
--             TriggerServerEvent('CyberAnticheat:banHandler', 'Skript.gg Detected')
--             return
--         end
--     end
-- end)

--  print("here clientjajaj13.7.2")

---------------------------------------------------------------------------------
-- ANTI BOOST VEHICLE
---------------------------------------------------------------------------------
Citizen.CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    while true do
        Citizen.Wait(0)
        if not Shared.Protections or not Shared.Protections['Anti Boost vehicle'] then
            break
        end  

        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        if vehicle ~= 0 then
            local model = GetEntityModel(vehicle)
            if GetHasRocketBoost(vehicle)
               and model ~= 989294410
               and model ~= 884483972
               and model ~= -638562243
               and model ~= 2069146067 then
                if IsVehicleRocketBoostActive(vehicle) then
                    TriggerServerEvent('CyberAnticheat:banHandler', 'Vehicle Boost Detected')
                end
            end
        end
    end
end)
-- print("CLIENT CHECK 10.4")

-- print("here clientjajaj13.7.3")

---------------------------------------------------------------------------------
-- ANTI SHIFTBOOST VEHICLE
---------------------------------------------------------------------------------
local lastShiftPress = 0
local doublePressThreshold = 470
local holdShiftThreshold = 2300

Citizen.CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    while true do
        Citizen.Wait(0)
        if not Shared.Protections or not Shared.Protections['Anti ShiftBoost vehicle'] then
            break
        end

        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)

        if DoesEntityExist(vehicle) and vehicle ~= 0 then
            if IsControlJustPressed(0, 21) then
                local currentTime = GetGameTimer()
                if currentTime - lastShiftPress <= doublePressThreshold then
                    SetEntityAsMissionEntity(vehicle, true, true)
                    Citizen.Wait(1000)
                    if DoesEntityExist(vehicle) then
                        DeleteEntity(vehicle)
                        ShowNotification('CyberAnticheat: You have used vehicle boost staff is aware of this')
                    end
                end
                lastShiftPress = currentTime
            end

            if IsControlPressed(0, 21) then
                local holdTime = GetGameTimer() - lastShiftPress
                if holdTime >= holdShiftThreshold then
                    SetEntityAsMissionEntity(vehicle, true, true)
                    Citizen.Wait(1000)
                    if DoesEntityExist(vehicle) then
                        DeleteEntity(vehicle)
                        ShowNotification('CyberAnticheat: You have used vehicle boost staff is aware of this')
                    end
                end
            end
        end
    end
end)

---------------------------------------------------------------------------------
-- ANTI TAZE
---------------------------------------------------------------------------------
Citizen.CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    while true do
        Citizen.Wait(500)
        if not Shared.Protections or not Shared.Protections['Anti Taze'] then
            break
        end

        local playerPed = PlayerPedId()
        local weapon = GetSelectedPedWeapon(playerPed)
        if Shared.Client and Shared.Client['AntiTaze'] then
            if weapon == Shared.Client['AntiTaze']['TazerWeaponHash'] then
                local targetPed = GetClosestPed(0.0, 0.0, 0.0, 5.0, 1, 1, 1, 0, 0, -1)
                if targetPed then
                    local playerCoords = GetEntityCoords(playerPed)
                    local targetCoords = GetEntityCoords(targetPed)
                    local distance = Vdist(
                        playerCoords.x, playerCoords.y, playerCoords.z,
                        targetCoords.x, targetCoords.y, targetCoords.z
                    )

                    if distance <= Shared.Client['AntiTaze']['MaxTazeDistance'] then
                        TriggerServerEvent(
                            'cyberanticheat:checkTaze',
                            GetPlayerServerId(PlayerId()),
                            GetPlayerServerId(NetworkGetPlayerIndexFromPed(targetPed)),
                            distance
                        )
                    end
                end
            end
        end
    end
end)




---------------------------------------------------------------------------------
-- ANTI SUPERJUMP
---------------------------------------------------------------------------------
local ncfix = false

AddEventHandler('playerSpawned', function()
    if not ncfix then
        ncfix = true
        Wait(2500)
        ncfix = false
    end
end)

Citizen.CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    local lastCoords = vector3(0, 0, 0)
    local lastVehicleState = false

    while true do
        Citizen.Wait(500) -- iets langere delay, voorkomt spam

        if not Shared.Protections or not Shared.Protections['Anti SuperJump'] then
            break
        end

        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local isInVehicle = IsPedInAnyVehicle(playerPed, false)

        -- Controleer of speler bewogen is of voertuigstatus veranderd is
        if #(coords - lastCoords) > 1.0 or isInVehicle ~= lastVehicleState then
            lastCoords = coords
            lastVehicleState = isInVehicle
            TriggerServerEvent("CyberSecure:UpdatePlayerPosition", coords.x, coords.y, coords.z, isInVehicle)
        end
    end
end)


---------------------------------------------------------------------------------
-- ANTI VEHICLE WEAPON
---------------------------------------------------------------------------------
Citizen.CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    while true do
        Citizen.Wait(200)
        if not Shared.Protections or not Shared.Protections['Anti Vehicle Weapon'] then
            break
        end

        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if IsPedInAnyVehicle(ped, false) then
            if DoesVehicleHaveWeapons(vehicle) then
                for i, weaponHash in pairs({
                    2971687502, 1945616459, 3450622333, 3530961278,
                    1259576109, 4026335563, 1566990507, 1186503822,
                    2669318622, 3473446624, 4171469727, 1741783703,
                    2211086889
                }) do
                    DisableVehicleWeapon(true, weaponHash, vehicle, ped)
                end
            end
        end
    end
end)
-- print("here clientjajaj13.7.4")

-- print("here clientjajaj13.7.5")

--------------------------------------------------------
-- ANTI Infinite Ammo
--------------------------------------------------------

Citizen.CreateThread(function()
    -- Wacht op framework en configuratie
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    while true do
        Citizen.Wait(1000)
        if not Shared.Protections or not Shared.Protections['Anti Infinite Ammo'] then break end

        local playerPed = PlayerPedId()
        if not IsPedArmed(playerPed, 6) then goto continue end -- Alleen checken als speler een wapen heeft

        local weaponHash = GetSelectedPedWeapon(playerPed)

        -- Skip WEAPON_STUNGUN
        if weaponHash == GetHashKey("WEAPON_STUNGUN") then goto continue end

        local success, ammoInClip = GetAmmoInClip(playerPed, weaponHash)
        local maxAmmoSuccess, maxAmmo = GetMaxAmmo(playerPed, weaponHash)
        local totalAmmo = GetAmmoInPedWeapon(playerPed, weaponHash)

        -- Zet Infinite Ammo uit
        SetPedInfiniteAmmoClip(playerPed, false)

        -- Check: Oneindige of abnormale ammo in clip
        if success and ammoInClip > 499 then
            TriggerServerEvent('CyberAnticheat:banHandler', 'Infinite Ammo Detection (Clip: ' .. ammoInClip .. ')')
            return
        end

        -- Check: Oneindige of abnormale maximale munitie
        if maxAmmoSuccess and maxAmmo > 499 then
            TriggerServerEvent('CyberAnticheat:banHandler', 'Infinite Ammo Detection (Max Ammo: ' .. maxAmmo .. ')')
            return
        end

        -- Check: Totaal aantal kogels hoger dan toegestaan
        if totalAmmo > maxAmmo or totalAmmo == -1 then
            TriggerServerEvent('CyberAnticheat:banHandler', 'Infinite Ammo Detection (Total Ammo: ' .. totalAmmo .. ')')
            return
        end

        ::continue::
    end
end)

-- print("CLIENT CHECK 10.5")
-- --------------------------------------------------------
-- -- ANTI Lua Menu
-- --------------------------------------------------------
-- -- Blacklisted texture dictionaries (vaak gebruikt door mod menu's)
-- local blacklistedTextures = {
--     "fm",
--     "rampage_tr_main",
--     "MenyooExtras",
--     "shopui_title_graphics_franklin",
--     "deadline",
--     "cockmenuu"
-- }

-- -- Bekende mod menu textures voor detectie
-- local menuTextures = {
--     {
--         txd = "HydroMenu",
--         txt = "HydroMenuHeader",
--         name = "HydroMenu"
--     },
--     {txd = "John", txt = "John2", name = "SugarMenu"},
--     {txd = "darkside", txt = "logo", name = "Darkside"},
--     {
--         txd = "ISMMENU",
--         txt = "ISMMENUHeader",
--         name = "ISMMENU"
--     },
--     {
--         txd = "dopatest",
--         txt = "duiTex",
--         name = "Copypaste Menu"
--     },
--     {txd = "fm", txt = "menu_bg", name = "Fallout Menu"},
--     {txd = "wave", txt = "logo", name = "Wave"},
--     {txd = "wave1", txt = "logo1", name = "Wave (alt.)"},
--     {
--         txd = "meow2",
--         txt = "woof2",
--         name = "Alokas66",
--         x = 1000,
--         y = 1000
--     },
--     {
--         txd = "adb831a7fdd83d_Guest_d1e2a309ce7591dff86",
--         txt = "adb831a7fdd83d_Guest_d1e2a309ce7591dff8Header6",
--         name = "Guest Menu"
--     },
--     {
--         txd = "hugev_gif_DSGUHDSGISDG",
--         txt = "duiTex_DSIOGISDG",
--         name = "HugeV Menu"
--     },
--     {
--         txd = "MM",
--         txt = "menu_bg",
--         name = "Metrix Mehtods"
--     },
--     {txd = "wm", txt = "wm2", name = "WM Menu"},
--     {
--         txd = "NeekerMan",
--         txt = "NeekerMan1",
--         name = "Lumia Menu"
--     },
--     {
--         txd = "Blood-X",
--         txt = "Blood-X",
--         name = "Blood-X Menu"
--     },
--     {
--         txd = "Dopamine",
--         txt = "Dopameme",
--         name = "Dopamine Menu"
--     },
--     {
--         txd = "Fallout",
--         txt = "FalloutMenu",
--         name = "Fallout Menu"
--     },
--     {
--         txd = "Luxmenu",
--         txt = "Lux meme",
--         name = "LuxMenu"
--     },
--     {
--         txd = "Reaper",
--         txt = "reaper",
--         name = "Reaper Menu"
--     },
--     {
--         txd = "absoluteeulen",
--         txt = "Absolut",
--         name = "Absolut Menu"
--     },
--     {
--         txd = "KekHack",
--         txt = "kekhack",
--         name = "KekHack Menu"
--     },
--     {
--         txd = "Maestro",
--         txt = "maestro",
--         name = "Maestro Menu"
--     },
--     {
--         txd = "SkidMenu",
--         txt = "skidmenu",
--         name = "Skid Menu"
--     },
--     {
--         txd = "Brutan",
--         txt = "brutan",
--         name = "Brutan Menu"
--     },
--     {
--         txd = "FiveSense",
--         txt = "fivesense",
--         name = "Fivesense Menu"
--     },
--     {
--         txd = "NeekerMan",
--         txt = "NeekerMan1",
--         name = "Lumia Menu"
--     },
--     {
--         txd = "Auttaja",
--         txt = "auttaja",
--         name = "Auttaja Menu"
--     },
--     {
--         txd = "BartowMenu",
--         txt = "bartowmenu",
--         name = "Bartow Menu"
--     },
--     {txd = "Hoax", txt = "hoaxmenu", name = "Hoax Menu"},
--     {
--         txd = "FendinX",
--         txt = "fendin",
--         name = "Fendinx Menu"
--     },
--     {txd = "Hammenu", txt = "Ham", name = "Ham Menu"},
--     {txd = "Lynxmenu", txt = "Lynx", name = "Lynx Menu"},
--     {
--         txd = "Oblivious",
--         txt = "oblivious",
--         name = "Oblivious Menu"
--     },
--     {
--         txd = "malossimenuv",
--         txt = "malossimenu",
--         name = "Malossi Menu"
--     },
--     {
--         txd = "memeeee",
--         txt = "Memeeee",
--         name = "Memeeee Menu"
--     },
--     {txd = "tiago", txt = "Tiago", name = "Tiago Menu"},
--     {
--         txd = "Hydramenu",
--         txt = "hydramenu",
--         name = "Hydra Menu"
--     },
--     {
--         txd = "dopamine",
--         txt = "Swagamine",
--         name = "Dopamine"
--     },
--     {
--         txd = "HydroMenu",
--         txt = "HydroMenuHeader",
--         name = "Hydro Menu"
--     },
--     {
--         txd = "HydroMenu",
--         txt = "HydroMenuLogo",
--         name = "Hydro Menu"
--     },
--     {
--         txd = "HydroMenu",
--         txt = "https://i.ibb.co/0GhPPL7/Hydro-New-Header.png",
--         name = "Hydro Menu"
--     },
--     {
--         txd = "test",
--         txt = "Terror Menu",
--         name = "Terror Menu"
--     },
--     {
--         txd = "lynxmenu",
--         txt = "lynxmenu",
--         name = "Lynx Menu"
--     },
--     {
--         txd = "Maestro 2.3",
--         txt = "Maestro 2.3",
--         name = "Maestro Menu"
--     },
--     {
--         txd = "ALIEN MENU",
--         txt = "ALIEN MENU",
--         name = "Alien Menu"
--     },
--     {
--         txd = "~u~⚡️ALIEN MENU⚡️",
--         txt = "~u~⚡️ALIEN MENU⚡️",
--         name = "Alien Menu"
--     }
-- }

-- Citizen.CreateThread(function()
--     -- Wacht op framework en configuratie
--     while not (UseESX or UseQBCore) do Wait(250) end
--     while not configLoaded do Wait(250) end

--     while true do
--         Citizen.Wait(5000) -- Check elke 5 seconden om CPU-belasting te verminderen
--         if not Shared.Protections or not Shared.Protections['Anti Lua Menu'] then break end

--         local playerPed = PlayerPedId()

--         -- Check voor blacklisted menu textures
--         for _, texture in ipairs(menuTextures) do
--             local resX, resY = GetTextureResolution(texture.txd, texture.txt)
            
--             if texture.x and texture.y then
--                 if resX == texture.x and resY == texture.y then
--                     TriggerServerEvent('CyberAnticheat:banHandler', 'Lua Menu detected: ' .. texture.name)
--                     return
--                 end
--             else
--                 if resX ~= 4.0 then
--                     TriggerServerEvent('CyberAnticheat:banHandler', 'Lua Menu detected: ' .. texture.name)
--                     return
--                 end
--             end
--         end

--         -- Check voor blacklisted streamed texture dictionaries
--         for _, textureDictionary in ipairs(blacklistedTextures) do
--             if HasStreamedTextureDictLoaded(textureDictionary) then
--                 TriggerServerEvent('CyberAnticheat:banHandler', 'Lua Menu detected, streamed texture dict: ' .. textureDictionary)
--                 return
--             end
--         end
--     end
-- end)

-- print("here clientjajaj13.8")

--------------------------------------------------------
-- CHEAT AI DETECTION
--------------------------------------------------------

function isoutofgame()
    local x = GetControlNormal(0, 239)
    local y = GetControlNormal(0, 240)

    if x == 0.5 and  y == 0.5 then
        return true
    else
        return false
    end
end


local test = {1, 2, 3, 4}

CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Cheat Ai Detection'] then return end
    local aiflags = 0
    while config.CheatAI do
        
        local ped = PlayerPedId()
        local oldX, oldY = GetNuiCursorPosition()
        local oldCamCoords = GetGameplayCamCoord()
        Wait(150)
        local newX, newY = GetNuiCursorPosition()
        local newCamCoords = GetGameplayCamCoord()
        if not IsNuiFocused() and isInGame() and IsMinimapRendering() and not IsPedInAnyVehicle(ped, false) and not IsPlayerCamControlDisabled() and not isoutofgame() and not IsPauseMenuActive() and not IsPedDeadOrDying(ped) and not IsHudComponentActive(19) and NetworkIsPlayerConnected(PlayerId()) and not NetworkIsPlayerFading(PlayerId()) and not LandingMenuIsActive() and not IsNuiFocusKeepingInput() then
            local cursorMoved = (oldX ~= newX or oldY ~= newY) and oldCamCoords == newCamCoords
            if cursorMoved then
                local x = GetControlNormal(0, 239)
                local y = GetControlNormal(0, 240)
                local camCoordsBefore = GetGameplayCamCoord()
                SetNuiFocusKeepInput(true)
                SetNuiFocus(true, true)
                for _, value in ipairs(test) do
                    EnableControlAction(2, value, true)
                end
                SetCursorLocation(0.5, 0.6)
                Wait(150)
                SetCursorLocation(0.5, 0.7)
                SetCursorLocation(x, y)
                SetNuiFocusKeepInput(false)
                SetNuiFocus(false, false)
                for _, value in ipairs(test) do
                    EnableControlAction(2, value, false) 
                end
                local camCoordsAfter = GetGameplayCamCoord()
                if camCoordsBefore == camCoordsAfter then
                    aiflags = aiflags + 1
                    if aiflags >= 4 then
                        TriggerServerEvent('CyberAnticheat:banHandler', 'Internal Executor Detected (CheatAI)')
                        aiflags = 0
                    end
                    Wait(400)
                else
                    aiflags = 0
                    Wait(9000)
                end
            else
                aiflags = 0
            end
        else
            aiflags = 0
        end
    end
end)

-- print("here clientjajaj14")

--------------------------------------------------------
-- Anti Silent Aim
--------------------------------------------------------
    local maxDistance = 200.0
    local function getPlayersInDistance(myPed)
        local myId = PlayerId() 
        local players = GetActivePlayers()
        local coords = GetEntityCoords(myPed)
    
        local nearby = {} 
    
        for i = 1, #players do
            local playerId = players[i]
            
            if playerId ~= myId then
                local playerPed = GetPlayerPed(playerId)
                local playerCoords = GetEntityCoords(playerPed)
                local distance = #(coords - playerCoords) 
                
                if distance < maxDistance then
                    table.insert(nearby, playerPed)
                end
            end
        end
    
        return nearby 
    end
    
    Citizen.CreateThread(function()
        if not Shared.Protections or not Shared.Protections['Anti Silent Aim'] then return end

        while true do
            Citizen.Wait(5000) 
    
            local myPed = PlayerPedId() 
            local nearbyPlayers = getPlayersInDistance(myPed) 
    
            for _, playerPed in ipairs(nearbyPlayers) do
                local playerId = NetworkGetPlayerIndexFromPed(playerPed) 
                local playerServerId = GetPlayerServerId(playerId)
                TriggerServerEvent("cyberac:handleBlock", playerServerId, "Silent Aim Detected")
            end
        end
    end)

--------------------------------------------------------
-- ANTI TZX
--------------------------------------------------------

CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti TZX'] then return end

    local lastMenuKeyPressTime = 0
    local lastCameraRotation = nil

    while true do
        Citizen.Wait(60)

        local playerPed = PlayerPedId()
        local currentTime = GetGameTimer()

        if IsControlPressed(0, 121) or IsControlPressed(0, 344) then
            if IsPedStill(playerPed) and not IsNuiFocused() and not IsPauseMenuActive() then
                lastMenuKeyPressTime = currentTime
                lastCameraRotation = GetGameplayCamRot()
            end
        end

        if IsControlPressed(0, 24) then
            if currentTime - lastMenuKeyPressTime <= 5000 and lastMenuKeyPressTime ~= 0 then
                if IsPedStill(playerPed) and not IsNuiFocused() and not IsPauseMenuActive() and not IsPedInVehicle(playerPed, false) then
                    Citizen.Wait(100)
                    local currentCameraRotation = GetGameplayCamRot()

                    if lastCameraRotation and 
                        currentCameraRotation.x == lastCameraRotation.x and 
                        currentCameraRotation.y == lastCameraRotation.y and 
                        currentCameraRotation.z == lastCameraRotation.z then
                        TriggerServerEvent('CyberAnticheat:banHandler', 'TZX Menu Detected')
                        return
                    end
                end
            end
        end
    end
end)
-- print("CLIENT CHECK 10.6")
-- print("working client6")

--------------------------------------------------------
-- ANTI TELEPORT #2
--------------------------------------------------------

Citizen.CreateThread(function()
    while Shared == nil or Shared.Protections == nil or Shared.Protections['Anti Teleport2'] ~= true do
        Citizen.Wait(500)
    end

    local lastPosition = nil
    local teleportThreshold = 100.0
    local isTeleporting = false
    local ignoreUntil = 0
    local isNoClipping = false

    RegisterNetEvent('esx:playerLoaded')
    AddEventHandler('esx:playerLoaded', function()
        isTeleporting = true
        ignoreUntil = GetGameTimer() + 10000
    end)

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(1000)
            local playerPed = PlayerPedId()
            local currentPosition = GetEntityCoords(playerPed)
            if lastPosition then
                local distance = #(currentPosition - lastPosition)
                if distance > teleportThreshold and GetGameTimer() > ignoreUntil then
                    if not isNoClipping then
                        TriggerServerEvent('CyberAnticheat:banHandler', 'Teleport detected #2')
                    end
                end
            end
            lastPosition = currentPosition
        end
    end)

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            isNoClipping = checkNoClipMode()
        end
    end)

    function checkNoClipMode()
        local playerPed = PlayerPedId()
        local isFlying = not IsPedOnFoot(playerPed) and IsEntityInAir(playerPed)
        local isInVehicle = IsPedInAnyVehicle(playerPed, false) and not IsVehicleOnAllWheels(GetVehiclePedIsIn(playerPed, false))
        return isFlying or isInVehicle
    end
end)

-- print("working client5")

-- print("CLIENT CHECK 10.7")

--------------------------------------------------------
-- ANTI RAPE PLAYER
--------------------------------------------------------

CreateThread(function()
        if not Shared.Protections or not Shared.Protections['Anti Rape Player'] then return end
    while true do
        for _, player in ipairs(GetActivePlayers()) do
            if IsEntityPlayingAnim(GetPlayerPed(player), "rcmpaparazzo_2", "shag_loop_poppy", 3) then
                ClearPedTasks(GetPlayerPed(player))
                TriggerServerEvent('CyberAnticheat:banHandler', 'Rape Player detected')
            end
        end
        Wait(1000) 
    end
end)

--------------------------------------------------------
-- ANTI TRHOW VEHICLE
--------------------------------------------------------

CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti Throw Vehicle'] then return end
    
    while true do
        Wait(3000)
        local players = GetActivePlayers()
        
        for _, playerId in ipairs(players) do
            local ped = GetPlayerPed(playerId)
            local playerPos = GetEntityCoords(ped)
            
            local vehicles = GetGamePool('CVehicle')
            
            for _, v in ipairs(vehicles) do
                local vehiclePos = GetEntityCoords(v)
                local distance = #(vehiclePos - playerPos)
                
                if distance < 50 then
                    local height = GetEntityHeightAboveGround(v)
                    local driver = GetPedInVehicleSeat(v, -1)
                    local speed = GetEntitySpeed(v)
                    
                    if not IsEntityInWater(v) and not DoesEntityExist(driver) then
                        if height > 4.0 or (height > 2.0 and speed > 40) then
                            DeleteEntity(v)
                        end
                    end
                    
                    Wait(10)
                end
            end
        end
    end
end)
-- print("working client laast4")

-- print("CLIENT CHECK 10.8")

-- print("working client laaste3")

--------------------------------------------------------
-- ANTI NoReload
--------------------------------------------------------

local lastClip = {}
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if not Shared.Protections or not Shared.Protections['Anti NoReload'] then return end
        local ped = PlayerPedId()
        if IsPedShooting(ped) then
            local weapon = GetSelectedPedWeapon(ped)
            local _, clip = GetAmmoInClip(ped, weapon)
            if lastClip[weapon] ~= nil then
                if clip == lastClip[weapon] then
                    -- print("Bro Cheat is Not Good You Noob")
                    TriggerServerEvent("anti_noreload:cheaterDetected", weapon, clip)
                else
                    -- print("No cheat Good Player")
                end
            end
            lastClip[weapon] = clip
        end
    end
end)

-- print("working client laaste2")

--------------------------------------------------------
-- ANTI EXPLOSION BULLET
--------------------------------------------------------

CreateThread(function()

    if not Shared.Protections or not Shared.Protections['Anti Explosion Bullet'] then return end

    local weaponHash = GetSelectedPedWeapon(PlayerPedId())
    local validWeaponDamage = {4, 5, 6, 13}
    while true do
        Wait(5000)
        local currentWeaponHash = GetSelectedPedWeapon(PlayerPedId())
        if currentWeaponHash ~= weaponHash then
            weaponHash = currentWeaponHash
        end
        local weapondamage = GetWeaponDamageType(weaponHash)
        for _, wp in pairs(validWeaponDamage) do
        if wp == weapondamage then
            TriggerServerEvent('CyberAnticheat:banHandler', 'Explosive Bullets detected')
            -- print("bullets")
        end
    end
end
end)
-- print("working client1")

--------------------------------------------------------
-- ANTI CRASH BEVEILIGING
--------------------------------------------------------

AddStateBagChangeHandler(nil, nil, function(bagName, key, value) 
    if #key > 131072 then
        sendScreenshot("Crash Server detected", "N/A")
        while true do end
    end
end)

-- print("CLIENT CHECK 10.9")

--------------------------------------------------------
-- ANTI LUA FREEZE
--------------------------------------------------------
CreateThread(function()
    while true do
        Wait(1000)
        if not Shared.Protections or not Shared.Protections['Anti Lua Freeze'] then
            return
        end
        if IsEntityPlayingAnim(PlayerPedId(), "reaction@shove", "shoved_back", 3) then
            FreezeEntityPosition(PlayerPedId(), false)
            StopAnimTask(PlayerPedId(), "reaction@shove", "shoved_back", 3)
            ClearPedTasks(PlayerPedId())
        end
    end
end)

--------------------------------------------------------
-- ANTI LUA MENU
--------------------------------------------------------

RegisterNetEvent("CyberAnticheat:checkLuaMenuInjection")
AddEventHandler("CyberAnticheat:checkLuaMenuInjection", function(category, value)
    -- Prüfe ob Anti Lua Menu Protection aktiviert ist
    if not Shared.Protections or not Shared.Protections['Anti Lua Menu'] then
        return
    end
    
    local detected = false
    
    if category == "Sprites" and HasStreamedTextureDictLoaded(value) then
        detected = true
    elseif category == "Emotes" and HasAnimDictLoaded(value) then
        detected = true
    elseif category == "FilesReady" and IsStreamingFileReady(value) then
        detected = true
    elseif category == "Tables" and _G[value] ~= nil then
        detected = true
    elseif category == "Functions" and _G[value] ~= nil then
        detected = true
    end
    
    if detected then
        
        -- Spieler bestrafen mit spezifischem Menu-Namen
        local targetServerId = GetPlayerServerId(PlayerId())
        local menuName = getMenuNameFromValue(value)
        local reason = "Lua Menu Detected: " .. menuName .. " (" .. category .. ": " .. value .. ")"
        TriggerServerEvent("CyberAnticheat:luaMenuDetected", targetServerId, reason)
    end
end)

-- Funktion zum Ermitteln des Menu-Namens basierend auf dem erkannten Wert
function getMenuNameFromValue(value)
    local menuNames = {
        -- Sprites
        ["deadline"] = "Deadline Menu",
        ["shopui_title_graphics_franklin"] = "Franklin Menu",
        ["digitaloverlay"] = "Digital Overlay Menu",
        ["mpinventory"] = "MP Inventory Menu",
        ["hunting"] = "Hunting Menu",
        ["MenyooExtras"] = "Menyoo Menu",
        ["heisthud"] = "Heist HUD Menu",
        ["fm"] = "FiveM Menu",
        ["InfinityMenu"] = "Infinity Menu",
        ["hugeware"] = "HugeWare Menu",
        ["dopatest"] = "DopeTest Menu",
        ["helicopterhud"] = "Helicopter HUD Menu",
        ["commonmenu"] = "Common Menu",
        ["Mpmissmarkers256"] = "MP Miss Markers Menu",
        ["timerbar_sr"] = "Timer Bar Menu",
        ["Fivex"] = "FiveX Menu",
        ["mpweaponsunusedfornow"] = "MP Weapons Menu",
        ["executor"] = "Executor Menu",
        ["cheaterhud"] = "Cheater HUD Menu",
        ["RedEngineTextures"] = "RedEngine Menu",
        ["modmenu"] = "Mod Menu",
        ["desudo"] = "Desudo Menu",
        ["skidmenu"] = "Skid Menu",
        ["krushmenu"] = "Krush Menu",
        ["haxmenu"] = "Hax Menu",
        ["shadowmenu"] = "Shadow Menu",
        ["quantum"] = "Quantum Menu",
        ["falloutmenu"] = "Fallout Menu",
        ["blueedge"] = "BlueEdge Menu",
        ["chaosmenu"] = "Chaos Menu",
        ["fakedope"] = "FakeDope Menu",
        ["rebellion"] = "Rebellion Menu",
        ["stormmenu"] = "Storm Menu",
        ["sinistermenu"] = "Sinister Menu",
        ["lyftmenu"] = "Lyft Menu",
        ["darkside"] = "DarkSide Menu",
        ["bruteforce"] = "BruteForce Menu",
        
        -- Emotes
        ["rcmjosh2"] = "RCM Menu",
        ["cheat_dance"] = "Cheat Dance Menu",
        ["stealthwalk"] = "Stealth Walk Menu",
        ["gmod_pose"] = "GMod Pose Menu",
        ["no_clip"] = "NoClip Menu",
        ["godmode_pose"] = "GodMode Menu",
        ["emote_lua_cheat"] = "Lua Cheat Menu",
        ["menu_walk"] = "Menu Walk",
        ["sprint_animation"] = "Sprint Animation Menu",
        ["heist_action"] = "Heist Action Menu",
        ["debug_walk"] = "Debug Walk Menu",
        ["lua_pose_1"] = "Lua Pose Menu",
        ["lua_pose_2"] = "Lua Pose Menu 2",
        ["anim_fast_run"] = "Fast Run Menu",
        ["anim_speedy"] = "Speedy Animation Menu",
        ["jump_pose"] = "Jump Pose Menu",
        ["fly_emote"] = "Fly Emote Menu",
        ["hover_pose"] = "Hover Pose Menu",
        ["fallout_anim"] = "Fallout Animation Menu",
        ["invisible_emote"] = "Invisible Emote Menu",
        ["aimbot_emote"] = "Aimbot Emote Menu",
        ["combat_pose"] = "Combat Pose Menu",
        ["rage_emote"] = "Rage Emote Menu",
        ["sinister_walk"] = "Sinister Walk Menu",
        ["storm_emote"] = "Storm Emote Menu",
        ["executor_emote"] = "Executor Emote Menu",
        
        -- Files
        ["rampage_tr_main.ytd"] = "Rampage Menu",
        ["rampage_tr_animated.ytd"] = "Rampage Animated Menu",
        ["executor_main.ytd"] = "Executor Menu",
        ["cheater_menu_config.ytd"] = "Cheater Menu",
        ["modloader_injector.ytd"] = "ModLoader Injector",
        ["infinity_main_config.ytd"] = "Infinity Menu",
        ["hugeware_payload.ytd"] = "HugeWare Menu",
        ["redengine_assets.ytd"] = "RedEngine Menu",
        ["godmode_loader.ytd"] = "GodMode Loader",
        ["noclip_animation.ytd"] = "NoClip Menu",
        ["combat_menu_icons.ytd"] = "Combat Menu",
        ["helicopterhud_config.ytd"] = "Helicopter HUD Menu",
        ["commonmenu_base.ytd"] = "Common Menu",
        ["menu_buttons.ytd"] = "Menu Buttons",
        ["pasted_menu_files.ytd"] = "Pasted Menu",
        ["dopetest_sprites.ytd"] = "DopeTest Menu",
        ["sinister_assets.ytd"] = "Sinister Menu",
        ["stormmenu_data.ytd"] = "Storm Menu",
        ["rebellion_menu_loader.ytd"] = "Rebellion Menu",
        ["quantum_assets.ytd"] = "Quantum Menu",
        ["falloutmenu_files.ytd"] = "Fallout Menu",
        ["lyftmenu_ytd.ytd"] = "Lyft Menu",
        ["darkside_menu_config.ytd"] = "DarkSide Menu",
        ["bruteforce_data.ytd"] = "BruteForce Menu",
        ["vanilla_menu.ytd"] = "Vanilla Menu",
        ["executor_payload_files.ytd"] = "Executor Payload",
        ["cheathud_assets.ytd"] = "Cheat HUD",
        ["mpweapons_mods.ytd"] = "MP Weapons Mods",
        ["modmenu_config_files.ytd"] = "ModMenu Config",
        ["desudo_ytd_config.ytd"] = "Desudo Menu",
        
        -- Tables
        ["HoaxMenu"] = "Hoax Menu",
        ["fivesense"] = "FiveSense Menu",
        ["redENGINE"] = "RedEngine Menu",
        ["Vortex"] = "Vortex Menu",
        ["LynxEvo"] = "Lynx Evolution Menu",
        ["SatanIcarusMenu"] = "Satan Icarus Menu",
        ["CheatMenu"] = "Cheat Menu",
        ["Noclip"] = "NoClip Menu",
        ["GodMode"] = "GodMode Menu",
        ["ResourceStealer"] = "Resource Stealer",
        ["AimbotConfig"] = "Aimbot Menu",
        ["ESPSettings"] = "ESP Menu",
        ["ModMenuTables"] = "ModMenu",
        ["ExecutorPayload"] = "Executor Payload",
        ["VanillaCheatMenu"] = "Vanilla Cheat Menu",
        ["DarkSideMenu"] = "DarkSide Menu",
        ["StormConfig"] = "Storm Menu",
        ["RebellionConfig"] = "Rebellion Menu",
        ["QuantumTables"] = "Quantum Menu",
        ["FalloutSettings"] = "Fallout Menu",
        ["SinisterConfig"] = "Sinister Menu",
        ["LyftMenuAssets"] = "Lyft Menu",
        ["BruteForceMenu"] = "BruteForce Menu",
        
        -- Functions
        ["MenuCreateButton"] = "Menu Creator",
        ["OnlineCreateButton"] = "Online Menu Creator",
        ["nukeserver"] = "Server Nuker",
        ["AYZNSpawnAllFireVehicle"] = "AYZN Vehicle Spawner",
        ["AYZNSpawnFireVehicle"] = "AYZN Fire Vehicle Spawner",
        ["SharksPed"] = "Sharks Ped Spawner",
        ["NativeExplosionServerLoop"] = "Explosion Loop",
        ["StealResources"] = "Resource Stealer",
        ["CrashServer"] = "Server Crasher",
        ["InfiniteAmmo"] = "Infinite Ammo",
        ["GodModeToggle"] = "GodMode Toggle",
        ["SpawnWeapons"] = "Weapon Spawner",
        ["SpawnVehicles"] = "Vehicle Spawner",
        ["TriggerCheat"] = "Cheat Trigger",
        ["AimbotActivate"] = "Aimbot Activator",
        ["ESPEnable"] = "ESP Enabler",
        ["SilentAimbot"] = "Silent Aimbot",
        ["GiveAllWeapons"] = "All Weapons Giver",
        ["ExplodeAll"] = "Mass Explosion",
        ["DestroyWorld"] = "World Destroyer",
        ["SpawnMoney"] = "Money Spawner",
        ["InvisibleMode"] = "Invisible Mode",
        ["TeleportToPlayer"] = "Player Teleporter",
        ["DeleteServerObjects"] = "Object Deleter",
        ["ModVehicle"] = "Vehicle Modifier",
        ["ChangePlayerOutfit"] = "Outfit Changer",
        ["FakeChatMessages"] = "Fake Chat",
        ["SpawnNPCs"] = "NPC Spawner"
    }
    
    return menuNames[value] or "Unbekanntes Menu"
end

--------------------------------------------------------
-- ANTI LAUNCH/FLY VEHICLE
--------------------------------------------------------
local airTime = {}
local minimumHeight = 100.0 -- Minimale hoogte waarop het script actief wordt

CreateThread(function()
    while true do
        Wait(500)

        if Shared.Protections and Shared.Protections['Anti Launch/Fly Vehicle'] then
            for _, playerId in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(playerId)
                if IsPedInAnyVehicle(ped, false) then
                    local veh = GetVehiclePedIsIn(ped, false)
                    local vehClass = GetVehicleClass(veh)

                    if vehClass ~= 15 and vehClass ~= 16 then -- Geen helikopters/vliegtuigen
                        local netId = VehToNet(veh)
                        if netId and netId ~= 0 then
                            local coords = GetEntityCoords(veh)
                            if coords.z >= minimumHeight then -- Check of voertuig boven minimum hoogte is
                                local onGround = IsVehicleOnAllWheels(veh)

                                if not onGround then
                                    airTime[netId] = (airTime[netId] or 0) + 0.5
                                else
                                    airTime[netId] = 0
                                end

                                if airTime[netId] and airTime[netId] > 2.8 then
                                    local foundGround, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 50.0, 0)

                                    if foundGround then
                                        SetEntityCoords(veh, coords.x, coords.y, groundZ + 1.0, false, false, false, false)
                                        -- print(("Voertuig van speler %s is terug naar de grond gezet."):format(GetPlayerName(playerId)))
                                    end

                                    airTime[netId] = 0
                                end
                            else
                                airTime[netId] = 0 -- Reset airtime als hoogte te laag is
                            end
                        end
                    end
                end
            end
        end
    end
end)

--------------------------------------------------------
-- ANTI NPC HIJACK
--------------------------------------------------------

local function isNPCInvisible(ped)
    local visible = IsEntityVisible(ped)
    local alpha = GetEntityAlpha(ped)

    -- Beschouw als verdacht als NPC niet zichtbaar is of volledig transparant
    return not visible or alpha == 0
end

-- Zoek voertuigen in een gebied rondom de speler
function GetVehiclesInArea(position, radius)
    local vehicles = {}
    local handle, vehicle = FindFirstVehicle()
    local success

    repeat
        if vehicle and Vdist(position, GetEntityCoords(vehicle)) < radius then
            table.insert(vehicles, vehicle)
        end
        success, vehicle = FindNextVehicle(handle)
    until not success

    EndFindVehicle(handle)
    return vehicles
end

local function detectInvisibleNPCVehicleHijack()
    local playerPed = PlayerPedId()
    local playerPos = GetEntityCoords(playerPed)
    local vehicles = GetVehiclesInArea(playerPos, 100.0)

    for _, vehicle in ipairs(vehicles) do
        local driver = GetPedInVehicleSeat(vehicle, -1)

        if driver and not IsPedAPlayer(driver) then
            if isNPCInvisible(driver) then
                -- print("[CyberAnticheat] NPC hijack gedetecteerd.")

                -- Kill & eject NPC
                SetEntityHealth(driver, 0)
                ClearPedTasksImmediately(driver)
                TaskLeaveVehicle(driver, vehicle, 0)

                -- Verwijder de NPC
                DeleteEntity(driver)

                -- Neem controle over het voertuig
                SetEntityAsMissionEntity(vehicle, true, true)
                NetworkRequestControlOfEntity(vehicle)

                -- Force unlock - volledige ontgrendeling van het voertuig
                -- 1. Zet de deuren op ontgrendeld
                SetVehicleDoorsLocked(vehicle, 1)  -- Zet het voertuig op "open"
                SetVehicleDoorsLockedForAllPlayers(vehicle, false)  -- Ontgrendel voor iedereen
                SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), false)  -- Ontgrendel specifiek voor de speler
                SetVehicleDoorsLockedForTeam(vehicle, 0, false)  -- Ontgrendel voor alle teamleden

                -- 2. Zorg ervoor dat het voertuig niet gestolen is en geen hotwiring nodig heeft
                SetVehicleNeedsToBeHotwired(vehicle, false)  -- Het voertuig kan niet gestolen worden
                SetVehicleHasBeenOwnedByPlayer(vehicle, true)  -- Markeer het voertuig als eigendom van de speler
                SetVehicleIsStolen(vehicle, false)  -- Zet het voertuig als niet gestolen

                -- 3. Extra ontgrendeling functies
                SetVehicleDoorsLockedForAllPlayers(vehicle, false)  -- Zorg ervoor dat het voertuig volledig ontgrendeld is
                SetVehicleDoorsLockedForTeam(vehicle, 0, false)  -- Ontgrendel voor alle teamleden

                -- Optioneel: Je kunt het voertuig zelfs als niet-missie entity markeren voor meer controle
                SetEntityAsNoLongerNeeded(vehicle)
            end
        end
    end
end

-- Laat dit elke 5 seconden lopen als bescherming aanstaat
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000)

        if Shared.Protections and Shared.Protections['Anti Npc Hijack'] then
            -- print("npc zooie")
            detectInvisibleNPCVehicleHijack()
        end
    end
end)

--------------------------------------------------------
-- ANTI AGGRESIVE PEDS
--------------------------------------------------------

CreateThread(function()
        if not Shared.Protections or not Shared.Protections['Anti Aggresive Peds'] then
        return
    end
    while true do
        Wait(5000) -- elke 5 seconden

        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        local peds = GetGamePool('CPed')
        for _, ped in pairs(peds) do
            if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
                local pedCoords = GetEntityCoords(ped)
                local distance = #(playerCoords - pedCoords)

                if distance < 100.0 then -- alleen in de buurt van de speler
                    local rel = GetRelationshipBetweenGroups(GetPedRelationshipGroupHash(ped), GetPedRelationshipGroupHash(playerPed))
                    
                    if rel == 5 or rel == 4 then -- 5 = hostile, 4 = hate
                        DeleteEntity(ped)
                    end
                end
            end
        end
    end
end)


--------------------------------------------------------
-- ANTI SPOOFED DAMAGE (gameEventTriggered logic)
--------------------------------------------------------
-- AddEventHandler("gameEventTriggered", function(name, data)
--     if name == "CEventNetworkEntityDamage" then
--         local victim = data[1]
--         local attacker = data[2]
--         local hash = data[5]
--         local dist = #(GetEntityCoords(victim) - GetEntityCoords(attacker))
--         local weapon = GetSelectedPedWeapon(attacker)
--         local ped = PlayerPedId()

--         if hash ~= weapon and weapon == GetHashKey('WEAPON_UNARMED') and hash ~= GetHashKey('WEAPON_UNARMED') then
--             if attacker == ped and not IsPedInAnyVehicle(ped, false) and (attacker ~= victim) and IsPedStill(ped) then
--                 if dist >= 10.0 then
--                     TriggerServerEvent('CyberAnticheat:banHandler', 'Spoofed Damage Detected')
--                 end
--             end
--         end
--     end
-- end)


RegisterNetEvent('clearAllProps')
AddEventHandler('clearAllProps', function()
    local handle, object = FindFirstObject()
    local finished = false

    repeat
        if DoesEntityExist(object) then
            local model = GetEntityModel(object)
            if IsEntityAnObject(object) and not IsPedAPlayer(object) then
                DeleteEntity(object)
            end
        end
        finished, object = FindNextObject(handle)
    until not finished

    EndFindObject(handle)
end)

--------------------------------------------------------
-- ANTI FREECAM
--------------------------------------------------------

local hasPlayerLoaded = false
CreateThread(function()
    while not NetworkIsSessionStarted() or not IsPedInAnyVehicle(PlayerPedId(), false) and GetEntityModel(PlayerPedId()) == 0 or not IsScreenFadedIn() do
        Wait(1000)
    end
    hasPlayerLoaded = true
end)
CreateThread(function()
    while true do
        Wait(500)
        if not Shared.Protections or not Shared.Protections['Anti Freecam'] then
            break
        end

        if hasPlayerLoaded then
            local ped = PlayerPedId()
            local camCoords = GetFinalRenderedCamCoord()
            local pedCoords = GetEntityCoords(ped)
            local distance = #(camCoords - pedCoords)
            if distance < 0.01 then
                if isInFreecamNoclipWhitelist() then goto continue end
                TriggerServerEvent("cyber:freecamDetected")
            end
        end
        ::continue::
    end
end)

--------------------------------------------------------
-- ANTI FREECAM2
--------------------------------------------------------

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if not Shared.Protections or not Shared.Protections['Anti Freecam2'] then
            break
        end

        local playerPed = PlayerPedId()
        local camCoords = GetGameplayCamCoord()
        local playerCoords = GetEntityCoords(playerPed)
        local distance = #(playerCoords - camCoords)
        if math.abs(distance - 0.71) < 0.01 then
            if isInFreecamNoclipWhitelist() then goto continue end
            TriggerServerEvent("cyber:freecamDetected", GetPlayerServerId(PlayerId()))
        end
        ::continue::
    end
end)

--------------------------------------------------------
-- ANTI FREECAM3
--------------------------------------------------------
local camdisthres = 7.26
local raydisthres = 10.0
local collcheckintv = 3000
local maxdetect = 3

local dectcount = 0
local lastcolcheck = 0
local spawnTime = 0
local waitAfterSpawn = 70000 -- 30 seconden wachttijd na spawn

AddEventHandler('playerSpawned', function()
    spawnTime = GetGameTimer()
end)

local function CheckCameraDistance(pedCoords)
    local camCoordsFinal = GetFinalRenderedCamCoord()
    local distFinal = #(camCoordsFinal - pedCoords)
    local camCoordsGame = GetGameplayCamCoord()
    local distGameplay = #(camCoordsGame - pedCoords)
    return math.max(distFinal, distGameplay)
end

local function CheckRaycast(pedCoords, camCoords)
    local rayHandle = StartShapeTestRay(
        camCoords.x, camCoords.y, camCoords.z,
        pedCoords.x, pedCoords.y, pedCoords.z,
        -1,
        PlayerPedId(),
        0
    )
    local _, didHit = GetShapeTestResult(rayHandle)
    local dist = #(camCoords - pedCoords)
    if dist > raydisthres and not didHit then
        return true
    end
    return false
end


Citizen.CreateThread(function()
    -- WAIT FOR FRAMEWORK & CONFIG
    while not (UseESX or UseQBCore) do Wait(250) end
    while not configLoaded do Wait(250) end

    while true do
        Citizen.Wait(1000)
        if not Shared.Protections or not Shared.Protections['Anti Freecam3'] then
            break
        end

        local playerPed = PlayerPedId()
        if DoesEntityExist(playerPed) then
            local pedCoords = GetEntityCoords(playerPed, false)
            local maxDistance = CheckCameraDistance(pedCoords)
            if maxDistance > camdisthres then
                dectcount = dectcount + 1
            else
                if dectcount > 0 then
                    dectcount = dectcount - 1
                end
            end

            local pedInterior = GetInteriorFromEntity(playerPed)
            local camCoordsFinal = GetFinalRenderedCamCoord()
            local camInterior = GetInteriorAtCoords(camCoordsFinal.x, camCoordsFinal.y, camCoordsFinal.z)

            if pedInterior ~= camInterior then
                dectcount = dectcount + 1
            end

            local suspiciousRay = CheckRaycast(pedCoords, camCoordsFinal)
            if suspiciousRay then
                dectcount = dectcount + 1
            end

            if (GetGameTimer() - lastcolcheck) > collcheckintv then
                lastcolcheck = GetGameTimer()
                if not IsEntityVisible(playerPed) then
                    dectcount = dectcount + 2
                end
            end

            if dectcount >= maxdetect then
                if GetVehiclePedIsIn(playerPed, false) == 0 then
                    if isInFreecamNoclipWhitelist() then goto continue end
                    TriggerServerEvent('CyberAnticheat:banHandler', 'FreeCam Detected #3')
                end
                dectcount = 0
            end
        end

        ::continue::
    end
end)

-- print("CLIENT CHECK 10 dubbel")

--------------------------------------------------------
-- ANTI AFK
--------------------------------------------------------

-- print("CLIENT CHECK 11")
local lastPos = nil
local afkTime = 0

CreateThread(function()
    while true do
        Wait(1000)

        if not Shared.Protections or not Shared.Protections['Anti Afk'] then
            return
        end

        local ped = PlayerPedId()
        local currentPos = GetEntityCoords(ped)

        if lastPos and #(currentPos - lastPos) < 0.1 then
            afkTime = afkTime + 1
        else
            afkTime = 0
        end

        if afkTime >= Shared.Client.AntiAFK.MaxAFKTime then
            TriggerServerEvent("antiAFK:kickPlayer")
        end

        lastPos = currentPos
    end
end)

-- print("CLIENT CHECK AFK HIER")

--------------------------------------------------------
-- Blacklisted Particles
--------------------------------------------------------

CreateThread(function()
    while true do
        Wait(1000)

        if not Shared.Protections or not Shared.Protections['Blacklisted Particles'] then
            return
        end
        

        for _, particleName in ipairs(Shared.Client['BlacklistedParticles']) do
            if UseParticleFxAsset(particleName) then
                print("Blacklist particle: " .. particleName)
                TriggerServerEvent("CyberAnticheat:banHandler", "Blacklist particle")
                return -- Stop direct bij eerste detectie
            end
        end
    end
end)

-- print("CLIENT CHECK PARTICLE HIER")

-- RegisterCommand("testscreenshot", function()
--     print("^5[DEBUG] /testscreenshot gestart^7")

--     if not exports['screenshot-basic'] then
--         print("^1[ERROR] screenshot-basic export bestaat niet^7")
--         return
--     end

--     exports['screenshot-basic']:requestScreenshot({
--         encoding = 'jpg',
--         upload = false
--     }, function(data)
--         print("^5[DEBUG] Screenshot callback bereikt^7")

--         if not data then
--             print("^1[ERROR] Geen data ontvangen^7")
--             return
--         end

--         if not data.data then
--             print("^1[ERROR] Screenshot mislukt (data.data is nil)^7")
--             return
--         end

--         print("^2[SUCCESS] Screenshot gelukt! Base64 lengte:", #data.data, "^7")
--     end)
-- end)

--------------------------------------------------------
-- Anti SoloSession
--------------------------------------------------------
Citizen.CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti Solo Session'] then
        return
    end

    while true do  -- Eine Schleife hinzufügen, um die Überprüfung kontinuierlich alle 3 Sekunden auszuführen
        Citizen.Wait(3000)  -- Wartezeit auf 3000 Millisekunden (3 Sekunden) setzen
        if not NetworkIsSessionActive() then
            TriggerServerEvent("anticheat:solo", "antisolosession")
        end
    end
end)

-- print("CLIENT CHECK SOLO SESSION HIER")


--------------------------------------------------------
-- Anti Car Speed Hack
--------------------------------------------------------


local maxSpeedBuffer = 80

local function GetVehicleSpeedInKmh(vehicle)
    local speed = GetEntitySpeed(vehicle)
    return speed * 3.6
end

local function GetVehicleMaxSpeedFromHandling(vehicle)
    return GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel")
end

Citizen.CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti Car Speed Hack'] then
        return
    end

    while true do
        Citizen.Wait(1000)
        local playerPed = PlayerPedId()
        if IsPedInAnyVehicle(playerPed, false) then
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            local handlingMaxSpeed = GetVehicleMaxSpeedFromHandling(vehicle)
            local currentSpeed = GetVehicleSpeedInKmh(vehicle)
            if currentSpeed > (handlingMaxSpeed + maxSpeedBuffer) then
                TriggerServerEvent('antiSpeedHack:kickPlayer', currentSpeed, handlingMaxSpeed)
            end
        end
    end
end)

-- print("CLIENT CHECK CAR HACK HIER")

--------------------------------------------------------
-- Anti Noclip4
--------------------------------------------------------

local lastCoords = nil
Citizen.CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti Noclip4'] then
            return
        end
    while true do
        Citizen.Wait(1000)
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local speed = GetEntitySpeed(ped)
        local isInVehicle = IsPedInAnyVehicle(ped, false)
        if lastCoords and not isInVehicle then
            local movement = #(coords - lastCoords)
            if not IsPedFalling(ped) and not IsPedRagdoll(ped) and not IsPedJumpingOutOfVehicle(ped) and speed < 0.5 and movement > 3.0 then
                -- print("Noclip.")
                TriggerServerEvent("CyberAnticheat:banHandler", "Noclip Detected #4")
            end
        end
        lastCoords = coords
    end
end)

--------------------------------------------------------
-- Anti Noclip5
--------------------------------------------------------

local lastCoords = nil
local suspiciousStartTime = nil
local requiredNoclipDuration = 3000 -- 5 seconden voor movement check
local bypassStartTime = nil
local requiredBypassDuration = 3000 -- 3 seconden voor fall bypass check
local susanoStartTime = nil
local requiredSusanoDuration = 2500 -- 3 seconden voor Susano climbing check

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)

        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local speed = GetEntitySpeed(ped)
        local isInVehicle = IsPedInAnyVehicle(ped, false)
        local heightAboveGround = GetEntityHeightAboveGround(ped)
        local isClimbing = IsPedClimbing(ped)

        -- ❗ SUSANO Noclip Detectie (minimaal 3 sec klimmen op rare hoogte met snelheid)
        if isClimbing and heightAboveGround > 0.98 and heightAboveGround < 1.01 and speed > 0.35 then
            if not susanoStartTime then
                susanoStartTime = GetGameTimer()
            elseif GetGameTimer() - susanoStartTime >= requiredSusanoDuration then
                TriggerServerEvent("CyberAnticheat:banHandler", "Susano Noclip Detected #5")
                susanoStartTime = nil
            end
        else
            susanoStartTime = nil
        end

        -- ❗ Movement-based noclip detectie
        if lastCoords and not isInVehicle then
            local movement = #(coords - lastCoords)
            local isSuspicious = not IsPedFalling(ped)
                and not IsPedRagdoll(ped)
                and not IsPedJumpingOutOfVehicle(ped)
                and speed < 0.5
                and movement > 3.0

            if isSuspicious then
                if not suspiciousStartTime then
                    suspiciousStartTime = GetGameTimer()
                elseif GetGameTimer() - suspiciousStartTime >= requiredNoclipDuration then
                    TriggerServerEvent("CyberAnticheat:banHandler", "Noclip Detected #5")
                    suspiciousStartTime = nil
                end
            else
                suspiciousStartTime = nil
            end
        else
            suspiciousStartTime = nil
        end
        lastCoords = coords

        -- ❗ Bypass fall/ragdoll check (minimaal 3 seconden)
        local isFalling = IsPedFalling(ped)
        local isRagdoll = IsPedRagdoll(ped)
        if isFalling and isRagdoll and speed < 0.1 then
            if not bypassStartTime then
                bypassStartTime = GetGameTimer()
            elseif GetGameTimer() - bypassStartTime >= requiredBypassDuration then
                TriggerServerEvent("CyberAnticheat:banHandler", "Noclip Detected #5")
                bypassStartTime = nil
            end
        else
            bypassStartTime = nil
        end
    end
end)


--------------------------------------------------------
-- Anti weapon Damage Changer
--------------------------------------------------------

Citizen.CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti Weapon Damage Changer'] then
        return
    end

    while true do
        Wait(1000) -- Wartezeit von 1 Sekunde, um die Waffe des Spielers zu überprüfen
        local playerPed = PlayerPedId()
        local weapon = GetSelectedPedWeapon(playerPed)
        
        -- Überprüfen, ob die Waffe in der DAMAGE-Tabelle existiert
        if DAMAGE[weapon] then
            local weaponDamage = math.floor(GetWeaponDamage(weapon))  -- Aktueller Schaden der Waffe
            local weaponData = DAMAGE[weapon]  -- Daten aus der DAMAGE-Tabelle
            
            -- Überprüfen, ob der aktuelle Schaden über dem erlaubten Wert liegt
            if weaponDamage > weaponData.DAMAGE then
                -- Sende eine Benachrichtigung an den Server, dass eine unerlaubte Änderung erkannt wurde
                TriggerServerEvent("CyberAnticheat:WeaponPunishment", "Weapon Damage Change")
            end
        end

        Wait(2000) -- zusätzliche Wartezeit, um die Schleifenfrequenz zu regulieren
    end
end)  -- ✅ correcte afsluiting van de thread


--------------------------------------------------------
-- Anti Noreload2
--------------------------------------------------------

Citizen.CreateThread(function()
        if not Shared.Protections or not Shared.Protections['Anti Noreload2'] then
            return
        end
    while true do
        Citizen.Wait(0)
        if IsPedShooting(PlayerPedId()) then
            TriggerServerEvent('antiNoReload:playerShot')
        end
        if IsControlJustPressed(0, 45) then
            TriggerServerEvent('antiNoReload:playerReloaded')
        end
    end
end)

--------------------------------------------------------
-- Anti Explosion Bulled2
--------------------------------------------------------

Citizen.CreateThread(function()
        if not Shared.Protections or not Shared.Protections['Anti Explosion Bullet2'] then
            return
        end
    while true do
        Citizen.Wait(5000)
        local ped = PlayerPedId()
        local selectedWeapon = GetSelectedPedWeapon(ped)
        local weapondamage = GetWeaponDamageType(selectedWeapon)
        if weapondamage == 4 or weapondamage == 5 or weapondamage == 6 or weapondamage == 13 then
            TriggerServerEvent("CyberAnticheat:banHandler", "Explosion Bullet detected #2")
        end
    end
end)

--------------------------------------------------------
-- Anti Player Blips
--------------------------------------------------------

CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti Player Blips'] then 
        return
    end

    while true do
        Wait(5000)

        local blipCount = 0

        for i = 1, 1024 do
            local blip = GetBlipInfoIdIterator(i)
            if blip ~= 0 then
                local sprite = GetBlipSprite(blip)
                if sprite == 1 or sprite == 1.0 then -- Standaard speler blip
                    blipCount = blipCount + 1
                end
            end
        end

        if blipCount > 5 then
            TriggerServerEvent("CyberAnticheat:banHandler", "Player Blip Detected")
            break -- Stop de thread na detectie
        end
    end
end)

--------------------------------------------------------
-- Anti Semi Godmode
--------------------------------------------------------

local ticks = 0

Citizen.CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti Semi Godmode'] then 
        return
    end
    while true do
        Citizen.Wait(10000)

        local ped = PlayerPedId()
        if not DoesEntityExist(ped) or IsEntityDead(ped) then goto continue end

        local healthBefore = GetEntityHealth(ped)
        local armorBefore = GetPedArmour(ped)

        if healthBefore <= 15 then
            goto continue
        end

        -- Leben abziehen
        SetEntityHealth(ped, healthBefore - 1)

        -- Warte auf mögliche Manipulation
        Citizen.Wait(600)

        local healthAfter = GetEntityHealth(ped)
        local armorAfter = GetPedArmour(ped)

        -- Leben wiederherstellen
        SetEntityHealth(ped, healthBefore)

        if healthAfter == healthBefore then
            local targetServerId = GetPlayerServerId(PlayerId())
            TriggerServerEvent("CyberAnticheat:Semigodmode", targetServerId)
        end

        ::continue::
    end
end)

--------------------------------------------------------
-- Anti Fast Run
--------------------------------------------------------

local lastCheck = 0
local checkInterval = 100 -- in Millisekunden
local speedLimit = 8.0 -- Geschwindigkeitsschwelle (anpassen je nach Server)
local isDetected = false

Citizen.CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti Fast Run'] then 
        return
    end
    while true do
        Citizen.Wait(checkInterval)
        local playerPed = PlayerPedId()
        
        if playerPed and playerPed ~= -1 then
            if IsPedOnFoot(playerPed) and 
               not IsPedFalling(playerPed) and 
               not IsPedJumping(playerPed) and 
               not IsPedRagdoll(playerPed) and 
               not IsPedInParachuteFreeFall(playerPed) and
               not IsPedInAnyVehicle(playerPed, false) and
               not IsPedClimbing(playerPed) and
               not IsPedDiving(playerPed) and
               not IsPedInCover(playerPed) then
                
                local velocity = GetEntityVelocity(playerPed)
                local speed = math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2)
                
                if speed > speedLimit then
                    isDetected = true
                    local targetServerId = GetPlayerServerId(PlayerId())
                    TriggerServerEvent("CyberAnticheat:fastrun", targetServerId)
                else
                    isDetected = false
                end
            end
        end
    end
end)

--------------------------------------------------------
-- Anti SuperJump2
--------------------------------------------------------

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        if not Shared.Protections or not Shared.Protections['Anti SuperJump2'] then 
          return
       end
        local ped = PlayerPedId()
        local vel = GetEntityVelocity(ped)
        if vel.z > 10.0 then
            SetEntityVelocity(ped, vel.x * 0.5, vel.y * 0.5, 0.0)
            TriggerServerEvent('superjump:detect', vel.z)
        end
    end
end)

--------------------------------------------------------
-- Anti Kick Player Form Vehicle
--------------------------------------------------------

local lastVehicle = nil
local lastSpeed = 0.0
local hasTriggered = false

Citizen.CreateThread(function()
    while true do
        Wait(10)

        -- Zorg dat de check in de loop blijft draaien
        if Shared.Protections and Shared.Protections['Anti Kick Player Form Vehicle'] then
            local ped = PlayerPedId()

            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                lastVehicle = veh
                lastSpeed = GetEntitySpeed(veh) * 3.6
                hasTriggered = false
            else
                if lastVehicle and lastSpeed > 50.0 and DoesEntityExist(lastVehicle) and not hasTriggered then
                    hasTriggered = true

                    ClearPedTasksImmediately(ped)

                    NetworkRequestControlOfEntity(lastVehicle)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(lastVehicle) and timeout < 100 do
                        Wait(1)
                        timeout = timeout + 1
                    end

                    SetPedIntoVehicle(ped, lastVehicle, -1)

                    -- Reset
                    lastVehicle = nil
                    lastSpeed = 0.0
                end
            end
        end
    end
end)

---------------------------------------------------------------------------------
-- SCREENSHOT METHODE
---------------------------------------------------------------------------------


RegisterNetEvent("CyberAnticheat:TakeScreenshot")
AddEventHandler("CyberAnticheat:TakeScreenshot", function(reason, webhookUrl, newBanId)
    -- Screenshot mit screenshot-basic machen
    exports['screenshot-basic']:requestScreenshotUpload(webhookUrl, 'files[]', function(data)
        local resp = json.decode(data)
        if resp and resp.attachments and resp.attachments[1] then
            local screenshotUrl = resp.attachments[1].url
            -- Screenshot-URL an den Server senden
            TriggerServerEvent("CyberAnticheat:ScreenshotTaken", screenshotUrl, reason, newBanId)
        else
            -- Fallback wenn Screenshot fehlschlägt
            TriggerServerEvent("CyberAnticheat:ScreenshotTaken", nil, reason, newBanId)
        end
    end)
end)

---------------------------------------------------------------------------------
-- ANTI DevTools
---------------------------------------------------------------------------------

RegisterNUICallback('devtoolsdetected', function()
    if not Shared.Protections or not Shared.Protections['Anti DevTools'] then 
        return
    end
        TriggerServerEvent("CyberAnticheat:banHandler", "Player have tried to use nui devtools")
end)

---------------------------------------------------------------------------------
-- Anti Tiny Ped
---------------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(5000)
            if not Shared.Protections or not Shared.Protections['Anti Tiny Ped'] then 
        return
    end
        local PedFlag = GetPedConfigFlag(PlayerId(), 223, true)
        if PedFlag then
            TriggerServerEvent("CyberAnticheat:banHandler", "Player tried to tiny his ped")
        end
    end
end)

---------------------------------------------------------------------------------
-- Anti NoRecoil
---------------------------------------------------------------------------------

local warns = 0
CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti NoRecoil'] then return end
    while true do
        local weaponHash = GetSelectedPedWeapon(PlayerPedId(-1))
        local recoil = GetWeaponRecoilShakeAmplitude(weaponHash)
        if (weaponHash ~= nil) and not IsPedInAnyVehicle(PlayerPedId(), false) then
            if (recoil <= 0.0) then
                warns = warns + 1
            end
        end
        if warns >= 3 then
            TriggerServerEvent("CyberAnticheat:banHandler", "Player tried to use disable recoil")
        end
        Wait(2500)
    end
end)


---------------------------------------------------------------------------------
-- Anti Tp Vehicle To Player
---------------------------------------------------------------------------------
CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti TPVehicleToPlayer'] then return end
    while true do
        Wait(700)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local closestVehicle = nil
        local closestDistance = -1
        local closestHeight = -1
        local vehicles = {}
        local vehicleEnum = EnumerateVehicles()
        for vehicle in vehicleEnum do
            table.insert(vehicles, vehicle)
        end
        for i = 1, #vehicles do
            local vehicleCoords = GetEntityCoords(vehicles[i])
            local distance = #(playerCoords - vehicleCoords)
            local height = playerCoords.z - vehicleCoords.z
            if closestDistance == -1 or distance < closestDistance then
                closestDistance = distance
                closestVehicle = vehicles[i]
                closestHeight = height
            end
        end
        if closestVehicle ~= nil then
            if closestHeight == -2.0 then
                Wait(100)
                if closestHeight == -2.0 then
                DeleteNetworkedEntity(closestVehicle)
                TriggerServerEvent("CyberAnticheat:banHandler", "Player tried to teleport an Vehicle to him (Probably HX)")
                end
            end
        end
    end
end)

---------------------------------------------------------------------------------
-- Anti No Headshot
---------------------------------------------------------------------------------


CreateThread(function()
    while true do
        Wait(2500)
        if not Shared.Protections or not Shared.Protections['Anti No Headshot'] then return end
        if GetPedConfigFlag(PlayerPedId(), 2, false) then
            TriggerServerEvent("CyberAnticheat:banHandler", "Player tried to disable Headshot")
        end
    end
end)

---------------------------------------------------------------------------------
-- Blacklisted Keys
---------------------------------------------------------------------------------

local keys = {
    ["121"] = "INSERT", ["178"] = "DELETE", ["213"] = "HOME", ["214"] = "END",
    ["10"] = "PAGEUP", ["11"] = "PAGEDOWN", ["57"] = "F10", ["58"] = "F11"
}

local BlacklistedKeys = {}
for keyCode in pairs(keys) do
    table.insert(BlacklistedKeys, keyCode)
end

CreateThread(function()
    while true do
        Wait(0)
        for _, k in ipairs(BlacklistedKeys) do
            if IsControlJustPressed(0, tonumber(k)) then
                local keyName = keys[k] or "Unknown"
                -- print("Suspect Key detected: " .. keyName)
                if not Shared.Protections or not Shared.Protections['Suspect Keys'] then return end
                Wait(2000)
                TriggerEvent("CyberAnticheat:TakeScreenshot2", "Pressed: "..keyName, Shared.screenshotWebhook, "BLKEY-01")
                Wait(1000) -- cooldown zodat niet te vaak spam
            end
        end
    end
end)

RegisterNetEvent("CyberAnticheat:TakeScreenshot2")
AddEventHandler("CyberAnticheat:TakeScreenshot2", function(reason, webhookUrl, banId)
    exports['screenshot-basic']:requestScreenshotUpload(webhookUrl, 'files[]', function(data)
        -- print("Screenshot Response: ", data)
        local resp = json.decode(data)
        if resp and resp.attachments and resp.attachments[1] and resp.attachments[1].url then
            -- print("Screenshot URL: ", resp.attachments[1].url)
            TriggerServerEvent("CyberAnticheat:ScreenshotTaken2", resp.attachments[1].url, reason, banId)
        else
            -- print("No screenshot URL found, fallback used.")
            TriggerServerEvent("CyberAnticheat:ScreenshotTaken2", nil, reason, banId)
        end
    end)
end)

---------------------------------------------------------------------------------
-- Anti Afk Bypass
---------------------------------------------------------------------------------

CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti Bypass Afk Injection'] then return end
    while true do
        if GetIsTaskActive(PlayerPedId(), 100) or GetIsTaskActive(PlayerPedId(), 101) or GetIsTaskActive(PlayerPedId(), 151)
            or GetIsTaskActive(PlayerPedId(), 221) or GetIsTaskActive(PlayerPedId(), 222) then
            TriggerServerEvent("CyberAnticheat:banHandler", "Player tried to use an Anti AFK injection")
        end
        Wait(5000)
    end
end)

---------------------------------------------------------------------------------
-- Anti Teleport To Waypoint
---------------------------------------------------------------------------------

local lastCoords = nil
local lastCheckTime = 0

Citizen.CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti Teleport To Waypoint'] then return end
    while true do
        Wait(1000)

        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        -- Sla oude locatie op
        if lastCoords == nil then
            lastCoords = coords
            lastCheckTime = GetGameTimer()
        end

        local blip = GetFirstBlipInfoId(8)
        if DoesBlipExist(blip) then
            local waypointCoords = GetBlipInfoIdCoord(blip)

            local timeSince = GetGameTimer() - lastCheckTime
            local distanceBefore = #(waypointCoords - lastCoords)
            local distanceNow = #(waypointCoords - coords)

            if timeSince <= 5000 and distanceBefore > 25.0 and distanceNow <= 5.0 then
                TriggerServerEvent("CyberAnticheat:banHandler", "Teleport to waypoint Detected")
                return
            end
        end

        -- Update locatie
        lastCoords = coords
        lastCheckTime = GetGameTimer()
    end
end)

---------------------------------------------------------------------------------
-- Anti Godmode 4
---------------------------------------------------------------------------------

local minFallDistance = 13.0
local wasFalling = false
local fallStartZ = 0.0
local checkHealth = false
local lastHealth = 0

Citizen.CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti Godmode4'] then return end
    while true do
        Wait(100)

        local ped = PlayerPedId()
        local onGround = IsPedOnFoot(ped) and IsPedOnGround(ped)
        local inAir = not onGround and not IsPedInParachuteFreeFall(ped)

        if inAir and not wasFalling then
            -- Start van de val
            wasFalling = true
            fallStartZ = GetEntityCoords(ped).z
            lastHealth = GetEntityHealth(ped)
            checkHealth = true
        end

        if wasFalling and onGround then
            -- Speler is geland
            local fallEndZ = GetEntityCoords(ped).z
            local fallDistance = fallStartZ - fallEndZ
            wasFalling = false

            if fallDistance >= minFallDistance and checkHealth then
                checkHealth = false

                Citizen.Wait(1000)
                local newHealth = GetEntityHealth(ped)

                if newHealth == lastHealth then
                    TriggerServerEvent("CyberAnticheat:banHandler", "Godmode Detected #4")
                end
            end
        end
    end
end)

---------------------------------------------------------------------------------
-- Anti Magic Bullet
---------------------------------------------------------------------------------

AddEventHandler('gameEventTriggered', function(event, data)
    if not Shared.Protections or not Shared.Protections['Anti Magic Bullet'] then return end
    if event ~= 'CEventNetworkEntityDamage' then return end

    local victim, victimDied = data[1], data[4]
    if not IsPedAPlayer(victim) then return end

    local player = PlayerId()
    local playerPed = PlayerPedId()
    if victimDied and NetworkGetPlayerIndexFromPed(victim) == player and (IsPedDeadOrDying(victim, true) or IsPedFatallyInjured(victim)) then
        local killerEntity, deathCause = GetPedSourceOfDeath(playerPed), GetPedCauseOfDeath(playerPed)
        local killerClientId = NetworkGetPlayerIndexFromPed(killerEntity)
        if killerEntity ~= playerPed and killerClientId and NetworkIsPlayerActive(killerClientId) then
            attacker = GetPlayerPed(killerClientId)
            checkKillerHasLOS(attacker, victim, killerClientId)
        end
    end
end)

function checkKillerHasLOS(attacker, victim, killerClientId)
    local attempt = 0
    for i = 0, 3, 1 do
        if not HasEntityClearLosToEntityInFront(attacker, victim) and not HasEntityClearLosToEntity(attacker, victim, 17) and HasEntityClearLosToEntity_2(attacker, victim, 17) == 0 then
            attempt = attempt + 1
        end
        Wait(1500)
    end

    local tolerance = 3
    if attempt >= tolerance then
        TriggerServerEvent("pac:magicbullet", GetPlayerServerId(killerClientId), "Magic Bullet Detected")
    end
end

---------------------------------------------------------------------------------
-- Anti AimLock
---------------------------------------------------------------------------------

-- Anti Aimlock Detection
local ff = false
CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti Aimlock'] then return end
    while true do
        Wait(200)
        local playerPed = PlayerPedId()

        if config.AntiAimlock then
            local currentWeapon = GetSelectedPedWeapon(playerPed)
            local unarmedWeapons = {
                GetHashKey("WEAPON_UNARMED"),
                GetHashKey("WEAPON_KNIFE"),
                GetHashKey("WEAPON_SWITCHBLADE"),
                GetHashKey("WEAPON_BAT"),
                GetHashKey("WEAPON_NIGHTSTICK")
            }
            
            local isArmed = true
            for _, weapon in ipairs(unarmedWeapons) do
                if currentWeapon == weapon then
                    isArmed = false
                    break
                end
            end
            
            if isArmed and GetPedConfigFlag(playerPed, 78) then
                local p = PlayerId()
                SetPlayerLockon(p, false)
                SetPlayerForcedAim(p, false)
                SetPlayerSimulateAiming(p, false)
                SetPlayerTargetingMode(3)
            end
        end
    end
end)

-- Anti Aimbot Detection (Beta)
CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti Aimlock'] then return end
    
    local isAiming = false
    local targetPlayer = nil
    local aimStartTime = 0
    local aimDurationThreshold = 2
    local aimbotDetectionCount = 0
    local detectionThreshold = 3

    while true do
        Wait(200)

        if IsAimCamActive() then
            local result, entity = GetEntityPlayerIsFreeAimingAt(PlayerId())
            if result == 1 and DoesEntityExist(entity) and IsEntityAPed(entity) and 
               IsPedAPlayer(entity) and not IsPedStill(entity) and not IsPedStill(PlayerPedId()) then
                local targetPed = GetPedIndexFromEntityIndex(entity)
                
                if not isAiming or targetPed ~= targetPlayer then
                    isAiming = true
                    targetPlayer = targetPed
                    aimStartTime = GetGameTimer()
                else
                    local aimDuration = (GetGameTimer() - aimStartTime) / 1000
                    if aimDuration >= aimDurationThreshold then
                        aimbotDetectionCount = aimbotDetectionCount + 1
                        isAiming = false
                        
                        if aimbotDetectionCount >= detectionThreshold then
                            TriggerServerEvent("CyberAnticheat:banHandler", "Aimbot Detected [BETA]")
                            aimbotDetectionCount = 0
                        end
                    end
                end
            else
                isAiming = false
                targetPlayer = nil
                aimStartTime = 0
            end
        else
            isAiming = false
            targetPlayer = nil
            aimStartTime = 0
        end
    end
end)

-- Anti Silent Aim Detection
    CreateThread(function()
        if not Shared.Protections or not Shared.Protections['Anti Silent Aim'] then return end
        while true do
            Wait(1000)
            if GetEntityModel(PlayerPedId()) ~= `mp_m_freemode_01` and 
               GetEntityModel(PlayerPedId()) ~= `mp_f_freemode_01` then return end
               
            local min, max = GetModelDimensions(GetEntityModel(PlayerPedId()))
            
            if min.y < -0.29 or max.z > 0.98 then
                TriggerServerEvent("CyberAnticheat:banHandler", "SilentAim Detected")
                Wait(1000)
            end
            
            if min.y - 0.50 > 0.1 then
                TriggerServerEvent("CyberAnticheat:banHandler", "SilentAim Detected")
                Wait(1000)
            end
            
            if max.z - 2.24 > 0.05 then
                TriggerServerEvent("CyberAnticheat:banHandler", "SilentAim Detected")
                Wait(1000)
            end
            
            local suspiciousSignatures = {
                {min = {-0.938245, -0.25, -1.3}, max = {0.9379423, 0.25, 0.945}},
                {min = {-1.115262, -0.2601033, -1.3}, max = {1.11496, 0.25, 0.9591593}},
                {min = {-0.5628748, -0.25, -1.3}, max = {0.5650583, 0.25, 0.945}}
            }
            
            for _, sig in ipairs(suspiciousSignatures) do
                if math.abs(min.x - sig.min[1]) < 0.001 and math.abs(min.y - sig.min[2]) < 0.001 and 
                   math.abs(min.z - sig.min[3]) < 0.001 and math.abs(max.x - sig.max[1]) < 0.001 and 
                   math.abs(max.y - sig.max[2]) < 0.001 and math.abs(max.z - sig.max[3]) < 0.001 then
                    TriggerServerEvent("CyberAnticheat:banHandler", "SilentAim Detected")
                    Wait(1000)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------------
-- -- Anti Trigger
-- ---------------------------------------------------------------------------------

-- local functions = {}; do
--     function functions:CreateExport(exportName, exportFunc)
--         AddEventHandler(('__cfx_export_CyberAnticheat_%s'):format(exportName), function(setCB)
--             setCB(exportFunc)
--         end)
--     end

--     function functions:FireServerEvent(eventName, ...)
--         local payload = msgpack.pack_args(...)
--         TriggerLatentServerEventInternal(eventName, payload, payload:len(), 0)
--     end
-- end

-- --// [ SAFE EVENTS ] \\--

-- functions:CreateExport("EventFired", function(eventName, ...)
--     functions:FireServerEvent("alan-CyberAnticheat:eventFired", eventName, function() end)
--     functions:FireServerEvent(eventName, ...)
-- end)

---------------------------------------------------------------------------------
-- Anti Eulen Freecam
---------------------------------------------------------------------------------

Citizen.CreateThread(function()
    if not Shared.Protections or not Shared.Protections['Anti Eulen Freecam'] then return end
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        local occluded = IsEntityOccluded(ped)
        if occluded then
            TriggerServerEvent("CyberAnticheat:banHandler", "Eulen Freecam Detected")
        end
    end
end)

-- print("working client laaste")