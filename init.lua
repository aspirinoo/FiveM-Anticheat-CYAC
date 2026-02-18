local isServer = IsDuplicityVersion() == 1

if isServer then
    local _RegisterNetEvent, _RegisterServerEvent = RegisterNetEvent, RegisterServerEvent

    function RegisterNetEvent(eventName, eventFunc)
        if eventName ~= "playerJoining" then
            exports['CyberAnticheat']:EventRegistered(eventName, eventFunc)            
        end

        return _RegisterNetEvent(eventName, eventFunc)
    end

    function RegisterServerEvent(eventName, eventFunc)
        if eventName ~= "playerJoining" then
            exports['CyberAnticheat']:EventRegistered(eventName, eventFunc)            
        end

        return _RegisterServerEvent(eventName, eventFunc)
    end

else
    local _TriggerServerEvent = TriggerServerEvent

    function TriggerServerEvent(eventName, ...)
        if eventName ~= "playerJoining" then
            return exports["CyberAnticheat"]:EventFired(eventName, ...)
        end

        return _TriggerServerEvent(eventName, ...);
    end
end