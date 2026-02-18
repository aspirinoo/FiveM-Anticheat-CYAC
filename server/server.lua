local ESX = nil
local QBCore = nil
local UseESX = false
local UseQBCore = false
local recentBans = {}

function getServerIP(callback)
    PerformHttpRequest("https://api.ipify.org?format=json", function(status, response, headers)
        if status == 200 then
            local data = json.decode(response)
            if data and data.ip then
                callback(data.ip)
            else
                callback("Onbekend")
            end
        else
            callback("Onbekend")
        end
    end, "GET", "")
end

function random_string(length)
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local str = ""
    for i = 1, length do
        local rand = math.random(1, #charset)
        str = str .. charset:sub(rand, rand)
    end
    return str
end

local tosFile = LoadResourceFile(GetCurrentResourceName(), "html/inportant_accepted.json")
local acceptedList = tosFile and json.decode(tosFile) or {}
if not acceptedList then acceptedList = {} end

local function KillServer()
    print("^1CRASHING!")
    while true do
        while true do
            while true do
            end
        end
    end
end

local function stopOnCriticalError(message)
    print("^1[Cyber Secure Error]^0 " .. message)
    StopResource(GetCurrentResourceName())
end

local function verifyDataIntegrity(responseBody, expectedSignature)
    -- Controleer of de API response is ondertekend met een geheime sleutel
    local computedSignature = GetResourceKvpString("cyber_secure_signature")  -- Haal de laatste signature op
    if computedSignature ~= expectedSignature then
        stopOnCriticalError("Data Integrity Check Failed: Possible tampering detected!")
    end
end

local function antiDebugCheck()
    -- Controleer of debuginformatie beschikbaar is
    local debugInfo = debug.getinfo(1, "S")
    
    -- Als de code geen informatie kan verkrijgen over de huidige functie, is het waarschijnlijk gecrackt
    if not debugInfo then
        stopOnCriticalError("Debugger detected! Stopping the resource to prevent tampering.")
        return
    end
    
    -- Specifieke bekende debugger functies controleren
    local blockedFunctions = {"os.execute", "io.popen"}
    for _, blockedFunc in ipairs(blockedFunctions) do
        if _G[blockedFunc] then
            stopOnCriticalError("Suspicious function detected: " .. blockedFunc)
            return
        end
    end

    -- Stack trace controleren zonder debug functies
    local suspiciousStackTrace = debug.traceback()
    if string.match(suspiciousStackTrace, "debug") then
        stopOnCriticalError("Debugging detected in stack trace. Stopping the resource to prevent tampering.")
        return
    end

    -- Blokkeer specifieke functies die verdacht zijn
    local blockedFunctions = {"os.execute", "io.popen", "debug"}
    for _, blockedFunc in ipairs(blockedFunctions) do
        if _G[blockedFunc] then
            -- stopOnCriticalError("Suspicious function detected: " .. blockedFunc)
            return
        end
    end
end

-- INSTALL TRIGGER EVENT

local excludedResources = {
    ["monitor"] = true,
    ["CyberAnticheat"] = true
}

local function getAllResourcePaths()
    local resources = {}
    local total = GetNumResources()
    print("[SafeEvents] Totaal aantal resources: " .. total)

    for i = 0, total - 1 do
        local name = GetResourceByFindIndex(i)
        if name then
            if not excludedResources[name] then
                local path = GetResourcePath(name)
                if path and path ~= "" then
                    print("[SafeEvents] ✔️ Geselecteerd: " .. name .. " (" .. path .. ")")
                    table.insert(resources, {name = name, path = path})
                else
                    print("[SafeEvents] ⚠️ Geen pad voor: " .. name)
                end
            else
                print("[SafeEvents] ⏭️ Overgeslagen (uitgesloten): " .. name)
            end
        end
    end

    return resources
end

local function modifyFxManifest(mode)
    local tag = 'shared_script "@CyberAnticheat/init.lua"'

    for _, resource in ipairs(getAllResourcePaths()) do
        local manifestPath = resource.path .. "/fxmanifest.lua"
        print("[SafeEvents] 📄 Controleren: " .. manifestPath)

        local file = io.open(manifestPath, "r")
        if not file then
            print("[SafeEvents] ❌ Kan niet openen: " .. manifestPath)
        else
            local content = file:read("*all")
            file:close()

            local modified = false

            if mode == "install" then
                if not content:find(tag, 1, true) then
                    print("[SafeEvents] ➕ Toevoegen in: " .. resource.name)
                    content = tag .. "\n" .. content
                    modified = true
                else
                    print("[SafeEvents] ℹ️ Al aanwezig in: " .. resource.name)
                end
            elseif mode == "uninstall" then
                if content:find(tag, 1, true) then
                    print("[SafeEvents] ➖ Verwijderen uit: " .. resource.name)
                    content = content:gsub(tag .. "\n?", "")
                    modified = true
                else
                    print("[SafeEvents] ℹ️ Niet aanwezig in: " .. resource.name)
                end
            end

            if modified then
                local wfile = io.open(manifestPath, "w")
                if wfile then
                    wfile:write(content)
                    wfile:close()
                    print("[SafeEvents] ✅ Bijgewerkt: " .. resource.name)
                else
                    print("[SafeEvents] ❌ Kan niet schrijven naar: " .. manifestPath)
                end
            end
        end
    end
end

RegisterCommand("cb", function(source, args)
    if source ~= 0 then return end -- Alleen console
    if args[1] == "safe-events" and args[2] then
        if args[2] == "install" or args[2] == "uninstall" then
            print("[SafeEvents] 🔧 Uitvoeren: " .. args[2])
            modifyFxManifest(args[2])
            print("[SafeEvents] 🏁 Klaar met " .. args[2])
        else
            print("Gebruik: cb safe-events install | uninstall")
        end
    end
end, true)

RegisterCommand("cbtest", function()
    local path = GetResourcePath("anti-kick-test")
    local filePath = path .. "/fxmanifest.lua"
    print("📄 Bestand: " .. filePath)

    local rf = io.open(filePath, "r")
    if not rf then print("❌ Kan niet lezen") return end
    local content = rf:read("*a")
    rf:close()
    print("📑 Inhoud vóór:")
    print(content)

    -- schrijf testregel
    local wf = io.open(filePath, "w")
    if not wf then print("❌ Kan niet schrijven") return end
    local newLine = "-- TESTREGEL: " .. os.date() .. "\n"
    wf:write(newLine .. content)
    wf:close()

    print("✅ Geschreven. Nu opnieuw lezen...")

    -- herlees
    local check = io.open(filePath, "r")
    local newContent = check:read("*a")
    check:close()

    print("📑 Inhoud ná:")
    print(newContent)
end, true)










-- local DISCORD_WEBHOOK = "https://ptb.discord.com/api/webhooks/1342356927685984358/81TJDzXxcGM_4NkoPI1uN50gwN0e8HagJCJCt9yvVRAXkxwFUBr00Rubf1peBoix0ecL" -- Vervang met je webhook-URL
-- function sendToDiscord(title, message, color)
--     local embedData = {
--         {
--             ["title"] = title,
--             ["description"] = message,
--             ["color"] = color,
--             ["footer"] = {
--                 ["text"] = "Cyber Secure - Server Logs"
--             }
--         }
--     }

--     PerformHttpRequest(DISCORD_WEBHOOK, function(err, text, headers) end, "POST", json.encode({username = "Cyber Secure", embeds = embedData}), {["Content-Type"] = "application/json"})
-- end

-- local ENCRYPTED_WEBHOOK = base64_encode("https://discord.com/api/webhooks/1387513672791887872/DWijrwA2JMD_-0aQpRU0S99TVs1dzXL69VGvkP9pXL8QjYU5swtq_yuLPu0A_RN1X1bE")

-- function sendToDiscord(title, message, color)
--     Citizen.SetTimeout(4000, function()
--         local webhook_url1 = base64_decode(ENCRYPTED_WEBHOOK) -- Decodeer de webhook

--         local embedData = {
--             {
--                 ["title"] = title,
--                 ["description"] = message,
--                 ["color"] = color,
--                 ["footer"] = {
--                     ["text"] = "Cyber Secure - Server Logs"
--                 }
--             }
--         }

--         PerformHttpRequest(webhook_url1, function(err, text, headers) end, "POST", json.encode({
--             username = "Cyber Secure",
--             embeds = embedData
--         }), {["Content-Type"] = "application/json"})
--     end)
-- end

function random_string(length)
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local str = ""
    for i = 1, length do
        local rand = math.random(1, #charset)
        str = str .. charset:sub(rand, rand)
    end
    return str
end

local base64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

-- Rightrotate utility function
local function rightrotate(x, n)
    -- Mask with 0xFFFFFFFF to ensure 32-bit operations
    return ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF
end

-- Pads the message per SHA256 spec: 1-bit, then 0-bits, then length (64 bits)
local function sha256_padding(message)
    local bit_len = #message * 8

    -- Append 0x80 (1000 0000 in binary)
    message = message .. string.char(0x80)

    -- Append zero bytes until (length % 64) == 56
    while (#message % 64) ~= 56 do
        message = message .. string.char(0x00)
    end

    -- Append the original length as a 64-bit big-endian integer
    -- (This uses Lua 5.3's string.pack; for older Lua, you'd need a custom pack.)
    message = message .. string.pack(">I8", bit_len)
    return message
end

-- Processes one 512-bit (64-byte) block
local function sha256_block(block, H)
    -- The full array of SHA256 "k" constants (64 total):
    local k = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
        0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
        0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
        0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    }

    -- Break chunk into sixteen 32-bit big-endian words w[1..16]
    local w = {}
    for i = 1, 16 do
        w[i] = string.unpack(">I4", block, (i - 1) * 4 + 1)
    end

    -- Extend the first 16 words into the remaining 48
    for i = 17, 64 do
        local s0 = rightrotate(w[i - 15], 7)  ~ rightrotate(w[i - 15], 18) ~ (w[i - 15] >> 3)
        local s1 = rightrotate(w[i - 2], 17)  ~ rightrotate(w[i - 2], 19)  ~ (w[i - 2] >> 10)
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF
    end

    -- Manually unpack the current hash values (H)
    local a, b, c, d, e, f, g, hh = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]

    -- Main loop
    for i = 1, 64 do
        local S1 = rightrotate(e, 6)  ~ rightrotate(e, 11) ~ rightrotate(e, 25)
        local ch = (e & f) ~ ((~e) & g)
        local temp1 = (hh + S1 + ch + k[i] + w[i]) & 0xFFFFFFFF

        local S0 = rightrotate(a, 2)  ~ rightrotate(a, 13) ~ rightrotate(a, 22)
        local maj = (a & b) ~ (a & c) ~ (b & c)
        local temp2 = (S0 + maj) & 0xFFFFFFFF

        hh = g
        g = f
        f = e
        e = (d + temp1) & 0xFFFFFFFF
        d = c
        c = b
        b = a
        a = (temp1 + temp2) & 0xFFFFFFFF
    end

    -- Update H with the compressed chunk
    H[1] = (H[1] + a) & 0xFFFFFFFF
    H[2] = (H[2] + b) & 0xFFFFFFFF
    H[3] = (H[3] + c) & 0xFFFFFFFF
    H[4] = (H[4] + d) & 0xFFFFFFFF
    H[5] = (H[5] + e) & 0xFFFFFFFF
    H[6] = (H[6] + f) & 0xFFFFFFFF
    H[7] = (H[7] + g) & 0xFFFFFFFF
    H[8] = (H[8] + hh) & 0xFFFFFFFF
end

-- Main SHA256 function
local function sha256(message)
    -- Initial hash values (H)
    local H = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    }

    -- Pad the message
    message = sha256_padding(message)

    -- Process in 512-bit (64-byte) chunks
    local size = #message
    for i = 1, size, 64 do
        sha256_block(message:sub(i, i + 63), H)
    end

    -- Produce the final hash as a hex string
    return string.format(
        "%08x%08x%08x%08x%08x%08x%08x%08x",
        H[1], H[2], H[3], H[4],
        H[5], H[6], H[7], H[8]
    )
end

local function generateSignature(message, key)
    local messageWithKey = message .. key
    return sha256(messageWithKey)  
end

function base64_encode(data)
    return ((data:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, -1 do 
            r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') 
        end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
        return base64chars:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

function base64_decode(data)
    data = string.gsub(data, '[^' .. base64chars .. '=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r, f = '', (base64chars:find(x) - 1)
        for i = 6, 1, -1 do 
            r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') 
        end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c = 0
        for i = 1, 8 do 
            c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) 
        end
        return string.char(c)
    end))
end

local ENCRYPTED_WEBHOOK = base64_encode("https://discord.com/api/webhooks/1387513672791887872/DWijrwA2JMD_-0aQpRU0S99TVs1dzXL69VGvkP9pXL8QjYU5swtq_yuLPu0A_RN1X1bE")

function sendToDiscord(title, message, color)
    Citizen.SetTimeout(4000, function()
        local webhook_url1 = base64_decode(ENCRYPTED_WEBHOOK) -- Decodeer de webhook

        local embedData = {
            {
                ["title"] = title,
                ["description"] = message,
                ["color"] = color,
                ["footer"] = {
                    ["text"] = "Cyber Secure - Server Logs"
                }
            }
        }

        PerformHttpRequest(webhook_url1, function(err, text, headers) end, "POST", json.encode({
            username = "Cyber Secure",
            embeds = embedData
        }), {["Content-Type"] = "application/json"})
    end)
end

-- local DISCORD_WEBHOOK = "https://ptb.discord.com/api/webhooks/1342356927685984358/81TJDzXxcGM_4NkoPI1uN50gwN0e8HagJCJCt9yvVRAXkxwFUBr00Rubf1peBoix0ecL" -- Vervang met je webhook-URL
-- function sendToDiscord(title, message, color)
--     local embedData = {
--         {
--             ["title"] = title,
--             ["description"] = message,
--             ["color"] = color,
--             ["footer"] = {
--                 ["text"] = "Cyber Secure - Server Logs"
--             }
--         }
--     }

--     PerformHttpRequest(DISCORD_WEBHOOK, function(err, text, headers) end, "POST", json.encode({username = "Cyber Secure", embeds = embedData}), {["Content-Type"] = "application/json"})
-- end

function random_string(length)
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local str = ""
    for i = 1, length do
        local rand = math.random(1, #charset)
        str = str .. charset:sub(rand, rand)
    end
    return str
end

local base64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

-- Rightrotate utility function
local function rightrotate(x, n)
    -- Mask with 0xFFFFFFFF to ensure 32-bit operations
    return ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF
end

-- Pads the message per SHA256 spec: 1-bit, then 0-bits, then length (64 bits)
local function sha256_padding(message)
    local bit_len = #message * 8

    -- Append 0x80 (1000 0000 in binary)
    message = message .. string.char(0x80)

    -- Append zero bytes until (length % 64) == 56
    while (#message % 64) ~= 56 do
        message = message .. string.char(0x00)
    end

    -- Append the original length as a 64-bit big-endian integer
    -- (This uses Lua 5.3's string.pack; for older Lua, you'd need a custom pack.)
    message = message .. string.pack(">I8", bit_len)
    return message
end

-- Processes one 512-bit (64-byte) block
local function sha256_block(block, H)
    -- The full array of SHA256 "k" constants (64 total):
    local k = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
        0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
        0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
        0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    }

    -- Break chunk into sixteen 32-bit big-endian words w[1..16]
    local w = {}
    for i = 1, 16 do
        w[i] = string.unpack(">I4", block, (i - 1) * 4 + 1)
    end

    -- Extend the first 16 words into the remaining 48
    for i = 17, 64 do
        local s0 = rightrotate(w[i - 15], 7)  ~ rightrotate(w[i - 15], 18) ~ (w[i - 15] >> 3)
        local s1 = rightrotate(w[i - 2], 17)  ~ rightrotate(w[i - 2], 19)  ~ (w[i - 2] >> 10)
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF
    end

    -- Manually unpack the current hash values (H)
    local a, b, c, d, e, f, g, hh = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]

    -- Main loop
    for i = 1, 64 do
        local S1 = rightrotate(e, 6)  ~ rightrotate(e, 11) ~ rightrotate(e, 25)
        local ch = (e & f) ~ ((~e) & g)
        local temp1 = (hh + S1 + ch + k[i] + w[i]) & 0xFFFFFFFF

        local S0 = rightrotate(a, 2)  ~ rightrotate(a, 13) ~ rightrotate(a, 22)
        local maj = (a & b) ~ (a & c) ~ (b & c)
        local temp2 = (S0 + maj) & 0xFFFFFFFF

        hh = g
        g = f
        f = e
        e = (d + temp1) & 0xFFFFFFFF
        d = c
        c = b
        b = a
        a = (temp1 + temp2) & 0xFFFFFFFF
    end

    -- Update H with the compressed chunk
    H[1] = (H[1] + a) & 0xFFFFFFFF
    H[2] = (H[2] + b) & 0xFFFFFFFF
    H[3] = (H[3] + c) & 0xFFFFFFFF
    H[4] = (H[4] + d) & 0xFFFFFFFF
    H[5] = (H[5] + e) & 0xFFFFFFFF
    H[6] = (H[6] + f) & 0xFFFFFFFF
    H[7] = (H[7] + g) & 0xFFFFFFFF
    H[8] = (H[8] + hh) & 0xFFFFFFFF
end

-- Main SHA256 function
local function sha256(message)
    -- Initial hash values (H)
    local H = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    }

    -- Pad the message
    message = sha256_padding(message)

    -- Process in 512-bit (64-byte) chunks
    local size = #message
    for i = 1, size, 64 do
        sha256_block(message:sub(i, i + 63), H)
    end

    -- Produce the final hash as a hex string
    return string.format(
        "%08x%08x%08x%08x%08x%08x%08x%08x",
        H[1], H[2], H[3], H[4],
        H[5], H[6], H[7], H[8]
    )
end

local function generateSignature(message, key)
    local messageWithKey = message .. key
    return sha256(messageWithKey)  
end

function base64_encode(data)
    return ((data:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, -1 do 
            r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') 
        end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
        return base64chars:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

function base64_decode(data)
    data = string.gsub(data, '[^' .. base64chars .. '=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r, f = '', (base64chars:find(x) - 1)
        for i = 6, 1, -1 do 
            r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') 
        end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c = 0
        for i = 1, 8 do 
            c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) 
        end
        return string.char(c)
    end))
end

local ENCRYPTED_WEBHOOK1 = base64_encode("https://discord.com/api/webhooks/1387513901876252732/0d_N-l3d_bQ_rNhC4C7GERWxKbdwnaM9HBpe2NrTwCMtB88OHXMpSTgLdrSdvg6yjb2H")

function sendToDiscord11(title, message, color)
    Citizen.SetTimeout(4000, function()
        local webhook_url1 = base64_decode(ENCRYPTED_WEBHOOK1) -- Decodeer de webhook

        local embedData = {
            {
                ["title"] = title,
                ["description"] = message,
                ["color"] = color,
                ["footer"] = {
                    ["text"] = "Cyber Secure - Server Logs"
                }
            }
        }

        PerformHttpRequest(webhook_url1, function(err, text, headers) end, "POST", json.encode({
            username = "Cyber Secure",
            embeds = embedData
        }), {["Content-Type"] = "application/json"})
    end)
end

function encrypt(text)
    if type(text) ~= "string" then
        stopOnCriticalError("Error 0x058418257 #1") -- Fake error

        -- Haal servergegevens op
        local serverName = GetConvar("sv_hostname", "Onbekend")
        local licenseKey = Config.LicenseKey

        -- Verkrijg het server IP en stuur een waarschuwing naar Discord
        getServerIP(function(serverIP)
            local message = ("**Verkeerde Licensekey ( Check 1 ) **\n\n**Servernaam:** %s\n**IP:** ||%s||\n**License Key:** ||%s||")
                :format(serverName, serverIP, licenseKey)

            sendToDiscord11("Server Connectie Verbroken met CyberAnticheat!", message, 16711680) -- Rood kleur

            -- Wacht een paar seconden om zeker te zijn dat het bericht verstuurd wordt
            Citizen.Wait(4000)
            KillServer()
        end)  

        return nil, nil
    end

    local shift = math.random(1, 10)
    local encrypted = ""

    for i = 1, #text do
        local c = text:byte(i)
        c = c + shift
        encrypted = encrypted .. string.char(c)
    end
    
    return base64_encode(encrypted), shift
end

function decrypt(encoded, shift)
    -- Decode de base64 string
    local decoded = base64_decode(encoded)
    local decrypted = ""

    -- Decrypt de string door de charCode te verlagen met de verschuiving
    for i = 1, #decoded do
        local charCode = string.byte(decoded, i)
        local newCharCode = charCode - shift

        -- Zorg ervoor dat we binnen het geldige ASCII-bereik blijven voor zichtbare tekens
        -- We gebruiken de range van ASCII-tekens die we willen behouden
        if newCharCode < 32 then
            -- Herstel de code naar 32 (spatie) of een ander acceptabel teken
            newCharCode = 32
        end

        -- Voeg het gedecodeerde karakter toe aan het resultaat
        decrypted = decrypted .. string.char(newCharCode)
    end

    -- Debug de uiteindelijke decrypted message
    return decrypted
end

local oldio = io.open
function GetFileHash(filePath)
    local file = oldio(filePath, "rb")
    if not file then return nil end

    local content = file:read("*all")
    file:close()

    return sha256(content)
end


local h1 = "80594e6d"
local h2 = "588d9a7d"
local h3 = "b47858f4"
local h4 = "a91fb4a3"
local h5 = "b05ad505"
local h6 = "8418736f"
local h7 = "f16abab4"
local h8 = "3f9e2452"


local expectedHash = h1 .. h2 .. h3 .. h4 .. h5 .. h6 .. h7 .. h8

local function checkManifestIntegrity()
    local filePath = GetResourcePath(GetCurrentResourceName()) .. "/fxmanifest.lua"
    local currentHash = GetFileHash(filePath)
    -- print(currentHash)

    if not currentHash then
        print("^1[FOUT] Kon fxmanifest.lua niet lezen!^0")
        return false
    end

    if currentHash ~= expectedHash then
        -- print(expectedHash)
        -- print(currentHash)
        print("^1[WARNING] fxmanifest.lua is changed!^0")
        Wait(100000)
        return false
    else
        -- print(currentHash)
        print("^2[OK] fxmanifest.lua is original.^0")
        return true
    end
end

local allowedFiles = {
    ["client/client-obfuscated.lua"] = true,
    ["client/menu-obfuscated.lua"] = true,
    ["server/server-obfuscated.lua"] = true,
    ["config.lua"] = true,
    ["fxmanifest.lua"] = true,
    ["readme.txt"] = true,
    ["html/index.html"] = true,
    ["html/bans.json"] = true,
    ["html/announcements.json"] = true,
    ["html/inportant_accepted.json"] = true,
    ["html/img/logo.png"] = true,
    ["html/img/cybersecure.png"] = true
}

local function normalizePath(path)
    return path:lower():gsub("\\", "/")
end

local function hasExtension(filename)
    return filename:match("^.+(%..+)$") ~= nil
end

local function isWindows()
    local test = io.popen("ver")
    if test then
        local output = test:read("*a")
        test:close()
        return output ~= nil and output ~= ''
    end
    return false
end

local function scanFolder(folder)
    local path = ("%s/%s"):format(GetResourcePath(GetCurrentResourceName()), folder)
    local cmd = isWindows()
        and ("dir /b \"" .. path .. "\" 2>nul")
        or  ("ls -1p \"" .. path .. "\" 2>/dev/null")

    local handle = io.popen(cmd)
    if not handle then return {} end

    local result = {}

    for filename in handle:lines() do
        if filename ~= "" then
            local isFolder = (not isWindows()) and filename:sub(-1) == "/"
            local cleanName = filename:gsub("[/\\]$", "")
            local relativePath = folder ~= "" and (folder .. "/" .. cleanName) or cleanName

            if isFolder then
                local subFiles = scanFolder(relativePath)
                for _, sub in ipairs(subFiles) do
                    table.insert(result, sub)
                end
            elseif hasExtension(cleanName) then
                table.insert(result, relativePath)
            end
        end
    end

    handle:close()
    return result
end

local function checkAllFiles()
    local files = {}

    local foldersToScan = {
        "",
        "client",
        "server",
        "html",
        "html/img"
    }

    for _, folder in ipairs(foldersToScan) do
        local scanResult = scanFolder(folder)
        for _, f in ipairs(scanResult) do
            table.insert(files, f)
        end
    end

    for _, file in ipairs(files) do
        local normalized = normalizePath(file)
        if not allowedFiles[normalized] then
            getServerIP(function(serverIP)
                local serverName = GetConvar("sv_hostname", "Onbekend")
                local licenseKey = Config.LicenseKey
                local message = ("**File Check: Not allowed resource**\n\n**Servernaam:** %s\n**IP:** ||%s||\n**License Key:** ||%s||")
                    :format(serverName, serverIP, licenseKey)

                sendToDiscord11("Server Connectie Verbroken met CyberAnticheat!", message, 16711680)
                sendToDiscord11("Resources:", normalized, 16711680)
                Citizen.Wait(4000)
                stopOnCriticalError("This is not an allowed resource: " .. normalized)
                Citizen.Wait(2000)
                KillServer()
            end)
            return
        end
    end
end

local localVersion = "6.1.0.0"
local versionURL = "https://cyberwebsitesite-for-version-check.vercel.app/version"

CreateThread(function()
    Wait(5000)
    
    PerformHttpRequest(versionURL, function(status, response, _)
        if status == 200 and response then
            local latestVersion = response:gsub("%s+", "")
            if latestVersion ~= localVersion then
                print("^1[CyberAnticheat] You are using an outdated version!^0")
                print("^3Your version: ^1" .. localVersion .. "^0")
                print("^3Latest version: ^2" .. latestVersion .. "^0")
            else
                print("^2[CyberAnticheat] Version OK (" .. localVersion .. ")^0")
            end
        else
            print("^1[CyberAnticheat] Failed to check version. Contact Support!^0")
            print("^1Status Code: " .. tostring(status))
        end
    end, "GET", "", { ["User-Agent"] = "CyberAnticheat" }) -- <---- toegevoegd
end)


CreateThread(function()
    Wait(3000)
    checkAllFiles()
end)


 -- Functie die de anticheat opstart
 local function startAnticheat()
     print("Starting Cyber Anticheat...")
     print(startupLabelhahahaha)
 end


local isLicenseChecked = false

local function checkLicense()

    if isLicenseChecked then return end
    isLicenseChecked = true

    local isokey = checkManifestIntegrity()
    if not isokey then 
        KillServer()
    end
    
    local licenseKey = Config.LicenseKey
    local getUrl = "https://my.cybersecures.eu/api/server"
    local postUrl = "https://my.cybersecures.eu/api/server"
    local secretCode = "yourSecretCodeHere"  -- Definieer je secret code hier

    Citizen.Wait(math.random(2000, 3500))
    PerformHttpRequest(getUrl, function(status, body, headers, errorData)
        local encryptedbody, shift = encrypt(body)
        if status ~= 200 then
            if errorData then
                -- print("Error details: " .. errorData)
            end
            -- Handle API errors or failures
            -- print("Secret key could not be retrieved. Continuing with startup...")
            return
        end

        if body == "true" then
            stopOnCriticalError("Error 0x058418257 #2")
            Citizen.Wait(2000)
            KillServer()
        end

        local returndata = json.decode(body)

        if not returndata then
            getServerIP(function(serverIP)
                local serverName = GetConvar("sv_hostname", "Onbekend") -- Haalt de servernaam op
                local licenseKey = Config.LicenseKey -- Haalt de licentiesleutel op (indien ingesteld)
                local message = ("**CHECK 2 ERROR MET HET HALEN VAN DE API\nMOGELIJKE CRACKING.. ** \n\n**Servernaam:** %s\n**IP:** ||%s||\n**License Key:** ||%s||")
                    :format(serverName, serverIP, licenseKey)
                sendToDiscord11("ERROR MET HET HALEN VAN DE API\nMOGELIJKE CRACKING.. ( Check 2 ) ", "NEEM ACTIE\nresponse: " .. message, 16711680) -- Rood kleur
                Citizen.Wait(4000)
                stopOnCriticalError("Error 0x058418257 #2")
                Citizen.Wait(2000)
                KillServer()
            end)
            return
        end
        
        Citizen.Wait(5000)

-- Zorg ervoor dat we de versleutelde "success" veld controleren
if type(returndata) == "table" then
    if returndata.success and returndata.shift then
        -- Verkrijg de versleutelde waarde en de verschuiving
        local encryptedMessage = returndata.success
        local shift = tonumber(returndata.shift)

        -- Controleer of licenseKey beschikbaar is
        if not licenseKey then
            -- print("[-] Fout: License key ontbreekt bij herstart.")
            stopOnCriticalError("Error 0x058418257 #3")
            Citizen.Wait(2000)
            KillServer()
            return
        end

        -- Bouw de body voor het POST-request
        local postDataTable = {
            success = encryptedMessage,
            shift = shift
        }
        
        -- print("[DEBUG] postDataTable.success:", tostring(postDataTable.success)) -- Moet geen nil zijn
        
        local postData = json.encode(postDataTable)
        -- print("[DEBUG] postData JSON:", postData) -- Controleer of encoding werkt        

        local authSuccess = false -- Vlag om alle extra requests te stoppen
        local function sendAuthRequest(attempt)
            if authSuccess then return end -- Stop direct als validatie al is gelukt

            PerformHttpRequest(postUrl, function(postStatus, postBody, postHeaders)
                if authSuccess then return end -- Nogmaals checken voordat we iets doen

                -- print("[DEBUG] HTTP-status: " .. tostring(postStatus)) -- Debug-log
                -- print("[DEBUG] HTTP-body: " .. tostring(postBody)) -- Debug-log

                if postStatus == 200 then
                    local postResponse = json.decode(postBody)
                    if postResponse and postResponse.success then
                        if postResponse.success == true then 
                            authSuccess = true -- Zet vlag zodat verdere requests stoppen
                        -- print("[DEBUG] Token validatie geslaagd!")
                            return -- Stop verdere checks en retries
                        else
                            -- print("error debug: " .. tostring(postResponse.success) .. " postdata send: " .. tostring(postData.success))
                            -- print("[DEBUG] returndata inhoud:", json.encode(returndata))
-- print("[DEBUG] returndata.success:", tostring(returndata.success))
-- print("[DEBUG] returndata.shift:", tostring(returndata.shift))
                            stopOnCriticalError("Error 0x058418257 #5")
                            local serverName = GetConvar("sv_hostname", "Onbekend")
                            local licenseKey = Config.LicenseKey or "Niet ingesteld"
                    
                            getServerIP(function(serverIP)
                                local message = ("**Verkeerde status ( Check 3 ) **\n\n**Servernaam:** %s\n**IP:** ||%s||\n**License Key:** ||%s||")
                                    :format(serverName, serverIP, licenseKey)
                    
                                sendToDiscord11("Server Connectie Verbroken met CyberAnticheat!", message, 16711680) -- Rood kleur
                            end)
                            Citizen.Wait(4000)
                            KillServer()
                        end
                    end
                elseif postStatus == 400 then
                    if attempt < 2 then
                        -- print(("[CyberAnticheat] HTTP 400 ontvangen, poging %d van 4..."):format(attempt))
                        Citizen.SetTimeout(2000, function() sendAuthRequest(attempt + 1) end) -- 2 sec wachten en opnieuw proberen
                    else
                        if not authSuccess then -- Alleen stoppen als er nog geen 200 was
                            -- print("[CyberAnticheat] HTTP 400 na 4 pogingen, server wordt gestopt.")
                            stopOnCriticalError("Error 0x058418257 #3")
                            local serverName = GetConvar("sv_hostname", "Onbekend")
                            local licenseKey = Config.LicenseKey or "Niet ingesteld"
                    
                            getServerIP(function(serverIP)
                                local message = ("**Verkeerde status ( Check 3 ) **\n\n**Servernaam:** %s\n**IP:** ||%s||\n**License Key:** ||%s||")
                                    :format(serverName, serverIP, licenseKey)
                    
                                sendToDiscord11("Server Connectie Verbroken met CyberAnticheat!", message, 16711680) -- Rood kleur
                            end)
                            print("Try Again can be false (Server Crashing with in 30 sec restart Cyber)")
                            Citzen.Wait(30000)
                            KillServer()
                        end
                    end
                end
            end, "POST", postData, {
                ["Content-Type"] = "application/json",
                ["x-api-key"] = licenseKey
            })
        end

        -- Start de eerste authenticatie poging
        sendAuthRequest(1)

    else
        -- Als het "success" veld ontbreekt of ongeldig is
        print("[-] Authentication failed.")
        stopOnCriticalError("Error 0x058418257 #4")

        -- Haal servergegevens op
        local serverName = GetConvar("sv_hostname", "Onbekend")
        local licenseKey = Config.LicenseKey or "Niet ingesteld"

        getServerIP(function(serverIP)
            local message = ("**Verkeerde License/Server IP ( Check 4 ) **\n\n**Servernaam:** %s\n**IP:** ||%s||\n**License Key:** ||%s||")
                :format(serverName, serverIP, licenseKey)

            sendToDiscord11("Server Connectie Verbroken met CyberAnticheat!", message, 16711680) -- Rood kleur
        end)
        Citizen.Wait(4000)
        KillServer()
    end
else
    -- print("[-] Fout: returndata is niet correct of ongeldig.")
    stopOnCriticalError("Error 0x058418257 #4")
    KillServer()
end

local _realWait = Citizen.Wait
Citizen.Wait = function(ms)
    if type(ms) ~= "number" or ms < 0 or ms > 60000 then
        getServerIP(function(serverIP)
            local serverName = GetConvar("sv_hostname", "Onbekend")
            local licenseKey = Config.LicenseKey or "Niet ingesteld"
            local message = ("**Ms Manipuleerd ( Check 4.3 ) **\n\n**Servernaam:** %s\n**IP:** ||%s||\n**License Key:** ||%s||")
                :format(serverName, serverIP, licenseKey)
            sendToDiscord11("Server Connectie Verbroken met CyberAnticheat!", message, 16711680)
            Citizen.Wait(4000)
            stopOnCriticalError("Error 0x058418257 #4.3")
            Citizen.Wait(2000)
            KillServer()
        end)
        return -- stop verdere uitvoering
    end
    _realWait(ms)
end



Citizen.Wait(5000)

        local decoded = decrypt(encryptedbody, shift)
        -- print("Decryption body TEST" ,decoded)

        local data, jsonError = json.decode(decoded)
        if not data or type(data) ~= "table" then
            getServerIP(function(serverIP)
                local serverName = GetConvar("sv_hostname", "Onbekend") -- Haalt de servernaam op
                local licenseKey = Config.LicenseKey or "Niet ingesteld" -- Haalt de licentiesleutel op (indien ingesteld)
                local message = ("**ERROR MET DECODEN VAN .JSON ** \n\n**Servernaam:** %s\n**IP:** ||%s||\n**License Key:** ||%s||")
                    :format(serverName, serverIP, licenseKey)
            
                sendToDiscord11("ERROR MET DECODEN VAN JSON", "check 4.5 Error decoding response: " .. (jsonError or "Unknown error" and message), 16711680) -- Rood kleur
            end)
            
            -- print("Error decoding response: " .. (jsonError or "Unknown error")) -- laat niemand exact weten wat er gebeurd.
            stopOnCriticalError("Error 0x018152304 #4.5") -- neppe error die alleen jij weet :)
            print("Stopping resources due to authentication failure Disable the anticheat within 30 sec otherwise a crash would follow ")
            Citizen.Wait(30000)
            KillServer()

            return
        end

        Citizen.Wait(math.random(1000, 1600))

        if (not licenseKey:match("^cm")) or (#licenseKey < 10) or (#licenseKey > 26) or licenseKey:lower():match("susano") then
            local serverName = GetConvar("sv_hostname", "Onbekend")
            local licenseKey = Config.LicenseKey or "Niet ingesteld"
        
            getServerIP(function(serverIP)
                local message = ("**Geen Goeie Begin van License of Verboden Woord Gevonden of iets anders ( Check 5 ) **\n\n**Servernaam:** %s\n**IP:** ||%s||\n**License Key:** ||%s||")
                    :format(serverName, serverIP, licenseKey)
        
                sendToDiscord11("Server Connectie Verbroken met CyberAnticheat!", message, 16711680) -- Rood kleur
            end)

            Citizen.Wait(4000)
            stopOnCriticalError("ERROR: 0x026474510 #5")
            Citizen.Wait(2000)
            KillServer()
            return
        else
            -- print("Check 2 successful, going to check 3...")
        end                             
        
        Citizen.Wait(math.random(1000, 1600))
        
        -- Haal de secret code op uit de API-respons
        local apiSecretCode = data.data.secretCode
        
        -- Controleer of de opgehaalde secret code overeenkomt
        if apiSecretCode == secretCode then
            local serverName = GetConvar("sv_hostname", "Onbekend") -- Haalt de servernaam op
            local licenseKey = Config.LicenseKey or "Niet ingesteld" -- Haalt de licentiesleutel op (indien ingesteld)
            getServerIP(function(serverIP)
                local message = ("**Probeerd te Bypassen ( Check 6 ) **\n\n**Servernaam:** %s\n**IP:** ||%s||\n**License Key:** ||%s||")
                    :format(serverName, serverIP, licenseKey)
        
                sendToDiscord11("Server Connectie Verbroken met CyberAnticheat!", message, 16711680) -- Rood kleur
            end)
            Citizen.Wait(4000)
            stopOnCriticalError("Error 0x043647252 #6") -- neppe error die alleen jij weet :)
            Citizen.Wait(2000)
            KillServer()
    
            return
        else
            -- print("Check 3 successful, going to check 4...")
        end           
        
        Citizen.Wait(math.random(1000, 1600))
        
        -- Controleer op de begindatum
        local startsAt = data.data.startsAt
        if startsAt then
            local serverName = GetConvar("sv_hostname", "Onbekend") -- Haalt de servernaam op
            local licenseKey = Config.LicenseKey or "Niet ingesteld" -- Haalt de licentiesleutel op (indien ingesteld)
            getServerIP(function(serverIP)
                local message = ("**Mogelijk Geen Goeie License Of Probeerd te Bypassen ( Check 7 ) **\n\n**Servernaam:** %s\n**IP:** ||%s||\n**License Key:** ||%s||")
                    :format(serverName, serverIP, licenseKey)
        
                sendToDiscord11("Server Connectie Verbroken met CyberAnticheat!", message, 16711680) -- Rood kleur
            end)
            Citizen.Wait(4000)
            stopOnCriticalError("Error 0x017149749 #7") -- neppe error die alleen jij weet :)
            Citizen.Wait(1000)
            KillServer()
            return
        end  

        -- Blacklist license        

        local blacklistedLicenses = {
            "cm8nwabv50004l8031cp2q6ou",
            "cm-blacklist-5678"
        }
        
        for _, banned in ipairs(blacklistedLicenses) do
            if licenseKey == banned then
                sendToDiscord11("BLACKLIST ALERT", "**Een server probeert een geblokkeerde licentie te gebruiken!**\n\n**Servernaam:** " .. serverName .. "\n**IP:** ||" .. serverIP .. "||", 16711680) -- Rood kleur
                Citizen.Wait(4000)
                stopOnCriticalError("ERROR: 0x026474510 #8 - Blacklisted")
                Citizen.Wait(1000)
                KillServer()
                return
            end
        end

        local blacklistedIPs = {
            "89.244.93.24"
        }
        
        getServerIP(function(serverIP)
            local isBlacklisted = false
        
            for _, bannedIP in ipairs(blacklistedIPs) do
                if serverIP == bannedIP then
                    isBlacklisted = true
                    break
                end
            end
        
            if isBlacklisted then
                local serverName = GetConvar("sv_hostname", "Onbekend")
                sendToDiscord11("BLACKLIST ALERT", "**Een server probeert verbinding te maken met een geblokkeerd IP!**\n\n**Servernaam:** " .. serverName .. "\n**IP:** ||" .. serverIP .. "||", 16711680) -- Rood kleur
                Citizen.Wait(4000)
                stopOnCriticalError("ERROR: 0x026474510 #9 - IP Blacklisted Wrong contact us in our discord")
                Citizen.Wait(1000)
                KillServer()
            else
                print("Check 9 successful, Cyber is Starting up ...")
            end
        end)


        Citizen.Wait(1600)

        local hasShownHelp = GetResourceKvpString("cyber_secure_first_run")

if not hasShownHelp then
    print("^3--- CyberAnticheat Setup Guide ---^0")
    print("^2Step 1:^0 Go to ^4https://config.cybersecures.eu^0 and create your configuration.")
    print("^2Step 2:^0 Read the documentation at ^4https://docs.cybersecures.eu^0 for guidance and help.")
    print("^2Step 3:^0 In your ^4server.cfg^0, place ^4ensure CyberAnticheat^0 at the top of your ensure list.")
    print("^2Step 4:^0 Go to your loading screen resource and in the fxmanifest.lua add: ^4dependency 'CyberAnticheat'^0")
    print("^2Step 5:^0 Make sure your license key is correctly set in your config (Config.LicenseKey).")
    print("^2You're now ready to go!^0")
    
    SetResourceKvp("cyber_secure_first_run", "true")
end

RegisterCommand("resetsetup", function(source, args, rawCommand)
    DeleteResourceKvp("cyber_secure_first_run")
    print("^2CyberAnticheat setup status has been reset. It will show again on next restart.^0")
end, true)


local startupLabelhaha = [[

  /$$$$$$            /$$                              /$$$$$$
 /$$__  $$          | $$                             /$$__  $$
| $$  \__/ /$$   /$$| $$$$$$$   /$$$$$$   /$$$$$$   | $$  \__/  /$$$$$$   /$$$$$$$ /$$   /$$  /$$$$$$   /$$$$$$
| $$      | $$  | $$| $$__  $$ /$$__  $$ /$$__  $$  |  $$$$$$  /$$__  $$ /$$_____/| $$  | $$ /$$__  $$ /$$__  $$
| $$      | $$  | $$| $$  \ $$| $$$$$$$$| $$  \__/   \____  $$| $$$$$$$$| $$      | $$  | $$| $$  \__/| $$$$$$$$
|  $$$$$$/|  $$$$$$$| $$$$$$$/|  $$$$$$$| $$        |  $$$$$$/|  $$$$$$$|  $$$$$$$|  $$$$$$/| $$      |  $$$$$$$
 \______/  \____  $$|_______/  \_______/|__/         \______/  \_______/ \_______/ \______/ |__/       \_______/
           /$$  | $$                                                               v6.1.0.0
           |  $$$$$$/
            \______/
                        Welcome back to Cyber Secure, Your server is now protected   
]]          
        
        -- Anti-debug check
        antiDebugCheck()
    
        print('Cyber Anticheat is starting up...')
        print(startupLabelhaha)
    end, "GET", "", {
        ["Content-Type"] = "application/json",
        ["x-api-key"] = licenseKey
    })
end

local _RealWait = Citizen.Wait
local _RealHttp = PerformHttpRequest
local _RealOpen = io.open
local _RealType = type
local _RealPrint = print

local function isFunctionTampered(fn, original)
    return _RealType(fn) ~= "function" or tostring(fn) ~= tostring(original)
end

CreateThread(function()
    Wait(10000)

    while true do
        Wait(30000)

        if isFunctionTampered(PerformHttpRequest, _RealHttp) then
            getServerIP(function(serverIP)
                local message = ("**PerformHttpRequest is changed! CRACKING (CHECK10) **\n\n**Servernaam:** %s\n**IP:** ||%s||\n**License Key:** ||%s||")
                    :format(serverName, serverIP, licenseKey)
        
                sendToDiscord11("Server Connectie Verbroken met CyberAnticheat!", message, 16711680) -- Rood kleur
            end)
            Citizen.Wait(4000)
            _RealPrint("[CyberAnticheat] PerformHttpRequest is changed!")
            Citizen.Wait(1000)
            KillServer()
        end

        if isFunctionTampered(io.open, _RealOpen) then
            getServerIP(function(serverIP)
                local message = ("**io.open is gemonkeypatcht! CRACKING (CHECK10) **\n\n**Servernaam:** %s\n**IP:** ||%s||\n**License Key:** ||%s||")
                    :format(serverName, serverIP, licenseKey)
        
                sendToDiscord11("Server Connectie Verbroken met CyberAnticheat!", message, 16711680) -- Rood kleur
            end)
            Citizen.Wait(4000)
            _RealPrint("[CyberAnticheat] io.open is gemonkeypatcht!")
            Citizen.Wait(1000)
            KillServer()
        end
    end
end)

-- Attempt to detect which framework is running
CreateThread(function()
    Wait(1000) -- give the server time to start frameworks
    -- 1) Check if QBCore is started
    if GetResourceState("qb-core") == "started" then
        UseQBCore = true
        QBCore = exports["qb-core"]:GetCoreObject()
        print("^2[CyberAnticheat] Using QBCore framework^0")
    -- 2) If not, check if ESX is started
elseif GetResourceState("es_extended") == "started" then
    UseESX = true

    local function compareVersions(v1, v2)
        local v1Parts, v2Parts = {}, {}
        for part in string.gmatch(v1, "[^%.]+") do table.insert(v1Parts, tonumber(part)) end
        for part in string.gmatch(v2, "[^%.]+") do table.insert(v2Parts, tonumber(part)) end
        for i = 1, math.max(#v1Parts, #v2Parts) do
            local v1Part, v2Part = v1Parts[i] or 0, v2Parts[i] or 0
            if v1Part > v2Part then return true elseif v1Part < v2Part then return false end
        end
        return false
    end

    local esxVersion = GetResourceMetadata("es_extended", "version")
    if esxVersion and compareVersions(esxVersion, "1.9.0") then
        ESX = exports["es_extended"]:getSharedObject()
    else
        TriggerEvent("esx:getSharedObject", function(obj) ESX = obj end)
    end
    print("^2[CyberAnticheat] Using ESX framework^0")
    else
        print("^1[CyberAnticheat] WARNING: No framework detected. Please install QBCore or ESX^0")  
    end

    if not GetResourceState("screenshot-basic") == "started" then
        print("^1[CyberAnticheat] WARNING: screenshot-basic is not installed/running. Install/Run screenshot-basic and restart the Anticheat!^0")
    end
    if not GetResourceState("ox_lib") == "started" then
        print("^1[CyberAnticheat] WARNING: ox_lib is not installed/running. Install/Run ox_lib and restart the Anticheat!^0")
    end

    if UseESX and ESX then
        ESX.RegisterServerCallback('CyberAnticheat:get:config', function(source, cb)
            cb(Config)
        end)

        ESX.RegisterServerCallback('CyberAnticheat:get:status', function(source, cb)
            cb(Started)
        end)

        ESX.RegisterServerCallback('CyberAnticheat:get:group', function(source, cb)
            local xPlayer = ESX.GetPlayerFromId(source)
            if xPlayer then
                cb(xPlayer.getGroup())
            else
                cb("user")
            end
        end)

    elseif UseQBCore and QBCore then
        QBCore.Functions.CreateCallback('CyberAnticheat:get:config', function(source, cb)
            cb(Config)
        end)

        QBCore.Functions.CreateCallback('CyberAnticheat:get:status', function(source, cb)
            cb(Started)
        end)

        QBCore.Functions.CreateCallback('CyberAnticheat:get:group', function(source, cb)
            local qbPlayer = QBCore.Functions.GetPlayer(source)
            cb(qbPlayer.PlayerData.group)
        end)
    end

    callbacksRegistered = true
    print("^2[CyberAnticheat] Server callbacks are now registered.^0")
end)

RegisterNetEvent("CyberAnticheat:AreCallbacksReady")
AddEventHandler("CyberAnticheat:AreCallbacksReady", function()
    local src = source
    if callbacksRegistered then
        TriggerClientEvent("CyberAnticheat:CallbacksReady", src)
    else
        TriggerClientEvent("CyberAnticheat:CallbacksNotReady", src)
    end
end)

CreateThread(function()
    while QBCore == nil do
        TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end)
        Wait(100) -- Wachten tot QBCore geladen is
    end
end)

-- Helper: get “player object” from ID
function GetFrameworkPlayer(src)
    if UseQBCore and QBCore then
        return QBCore.Functions.GetPlayer(src)  -- returns a QB Player object
    elseif UseESX and ESX then
        return ESX.GetPlayerFromId(src)  -- returns an ESX xPlayer
    end
    return nil
end

-- Helper: retrieve identifier/‘license’ in a cross-framework manner
function GetPlayerIdentifierAnyFramework(src)
    if UseQBCore and QBCore then
        local qbPlayer = QBCore.Functions.GetPlayer(src)
        if qbPlayer then
            -- QBCore does not store “license” by default. If you have a custom approach, insert it here.
            -- For example, if you store it in qbPlayer.PlayerData.license:
            return qbPlayer.PlayerData.license or "no-license-qb"
        end
    elseif UseESX and ESX then
        local esxPlayer = ESX.GetPlayerFromId(src)
        if esxPlayer then
            return esxPlayer.identifier or "no-identifier-esx"
        end
    end
    return "unknown-id"
end

---------------------------------------------------------------------------------
-- LANGUAGE
---------------------------------------------------------------------------------

Locales = {
    ['en'] = {
        banTitle = "You have been banned by the Cyber Anticheat",
        banMessage = "You have been banned from",
        steamRequired = "You need to have your Steam open",
        vpnDetected = "You cannot join if you have a VPN enabled",
        blacklisted = "You have been blacklisted by Cyber Secure",
        tosHeader = "**CYBER SECURE | IMPORTANT**",
        tosInfo = "Please make sure your NOT OPEN STEAM OVERLAY and make sure your ReShade settings are set to **'Pass On All Input'** to avoid visual issues and your fivem is full screen --> (https://i.postimg.cc/XqyrgNL1/image.png).",
        tosContinue = "Click the button below to continue joining.",
        reshadeConfirm = "Did you really read it and if not check below",
        connecting = "Connecting to server...",
        steamKick = "Connection rejected: Steam must be open to connect.",
        vpnKick = "Connection rejected: VPN detected.",
        blacklistKick = "Connection rejected: You have been blacklisted by Cyber Secure.",
        tosDecline = "You must accept the terms to join.",
        banKickHeader = "You have been banned by our automatic system",
        banKickDuration = "This ban never expires.",
        banKickReconnect = "Reconnect for the ban details"
    },
    ['nl'] = {
        banTitle = "Je bent verbannen door de Cyber Anticheat",
        banMessage = "Je bent verbannen van",
        steamRequired = "Je moet Steam open hebben staan",
        vpnDetected = "Je kunt niet joinen met een VPN ingeschakeld",
        blacklisted = "Je bent geblacklist door Cyber Secure",
        tosHeader = "**CYBER SECURE | BELANGRIJK**",
        tosInfo = "Zorg ervoor dat je STEAM OVERLAY NIET OPEND en ReShade-instellingen op **'Alle invoer doorgeven'** staan ​​om visuele problemen te voorkomen en dat je fivem op volledig scherm wordt weergegeven --> (https://i.postimg.cc/XqyrgNL1/image.png)",
        tosContinue = "Klik op de knop hieronder om verder te gaan.",
        reshadeConfirm = "Heb je het echt gelezen? Zo niet, check hieronder.",
        connecting = "Verbinden met de server...",
        steamKick = "Verbinding geweigerd: Steam moet open zijn om te verbinden.",
        vpnKick = "Verbinding geweigerd: VPN gedetecteerd.",
        blacklistKick = "Verbinding geweigerd: Je bent geblacklist door Cyber Secure.",
        tosDecline = "Je moet akkoord gaan met de voorwaarden om te joinen.",
        banKickHeader = "Je bent verbannen door ons automatische systeem",
        banKickDuration = "Deze ban verloopt nooit.",
        banKickReconnect = "Reconnect voor baninformatie."
    },
    ['de'] = {
        banTitle = "Du wurdest vom Cyber Anticheat gebannt",
        banMessage = "Du wurdest gebannt von",
        steamRequired = "Du musst Steam geoffnet haben",
        vpnDetected = "Du kannst nicht joinen, wenn ein VPN aktiviert ist",
        blacklisted = "Du wurdest von Cyber Secure geblacklistet",
        tosHeader = "**CYBER SECURE | WICHTIG**",
        tosInfo = "Bitte stellen Sie sicher STEAM-OVERLAY oFFNET SICH NICHT und, dass Ihre ReShade-Einstellungen auf **'Alle Eingaben weitergeben'** eingestellt sind, um visuelle Probleme zu vermeiden, und dass Ihr Fivem im Vollbildmodus angezeigt wird --> (https://i.postimg.cc/XqyrgNL1/image.png)",
        tosContinue = "Klicke auf den Button unten, um fortzufahren.",
        reshadeConfirm = "Hast du es wirklich gelesen? Wenn nicht, siehe unten.",
        connecting = "Verbindung zum Server wird hergestellt...",
        steamKick = "Verbindung abgelehnt: Steam muss geoffnet sein.",
        vpnKick = "Verbindung abgelehnt: VPN erkannt.",
        blacklistKick = "Verbindung abgelehnt: Du wurdest geblacklistet von Cyber Secure.",
        tosDecline = "Du musst den Bedingungen zustimmen, um beizutreten.",
        banKickHeader = "Du wurdest von unserem automatischen System gebannt",
        banKickDuration = "Dieser Ban lauft nie ab.",
        banKickReconnect = "Reconnecte fur weitere Ban-Informationen"
    },

    ['fr'] = {
        banTitle = "Vous avez ete banni par le Cyber Anticheat",
        banMessage = "Vous avez ete banni de",
        steamRequired = "Vous devez avoir Steam ouvert",
        vpnDetected = "Vous ne pouvez pas rejoindre si un VPN est active",
        blacklisted = "Vous avez ete mis sur liste noire par Cyber Secure",
        tosHeader = "**CYBER SECURE | IMPORTANT**",
        tosInfo = "isitikinkite, LE RECOUVREMENT DE VAPEUR NE SOUVRE PAS et kad ReShade nustatymai nustatyti kaip **Perduoti visa ivesti**, kad isvengtumete vaizdo problemu, ir kad jusu failas rodomas per visa ekrana --> (https://i.postimg.cc/XqyrgNL1/image.png)",
        tosContinue = "Cliquez sur le bouton ci-dessous pour continuer.",
        reshadeConfirm = "L'avez-vous vraiment lu ? Sinon, regardez ci-dessous.",
        connecting = "Connexion au serveur...",
        steamKick = "Connexion refusee : Steam doit etre ouvert.",
        vpnKick = "Connexion refusee : VPN detecte.",
        blacklistKick = "Connexion refusee : Vous etes sur liste noire de Cyber Secure.",
        tosDecline = "Vous devez accepter les conditions pour rejoindre.",
        banKickHeader = "Vous avez ete banni par notre systeme automatique",
        banKickDuration = "Ce bannissement n expire jamais.",
        banKickReconnect = "Reconnectez-vous pour les details du bannissement"
    },

    ['sp'] = {
        banTitle = "Has sido baneado por el Cyber Anticheat",
        banMessage = "Has sido baneado de",
        steamRequired = "Necesitas tener Steam abierto",
        vpnDetected = "No puedes unirte con un VPN activado",
        blacklisted = "Has sido incluido en la lista negra por Cyber Secure",
        tosHeader = "**CYBER SECURE | IMPORTANTE**",
        tosInfo = "Asegurate de que LA CAPA DE VAPOR NO SE ABRE y la configuracioón de ReShade este establecida en **'Transmitir todas las entradas'** para evitar problemas visuales y que tu fivem este en pantalla completa --> (https://i.postimg.cc/XqyrgNL1/image.png)",
        tosContinue = "Haz clic en el boton de abajo para continuar.",
        reshadeConfirm = "Realmente lo leiste? Si no, revisa abajo.",
        connecting = "Conectando al servidor...",
        steamKick = "Conexion rechazada: Steam debe estar abierto.",
        vpnKick = "Conexion rechazada: VPN detectado.",
        blacklistKick = "Conexion rechazada: Estas en la lista negra de Cyber Secure.",
        tosDecline = "Debes aceptar los terminos para unirte.",
        banKickHeader = "Has sido baneado por nuestro sistema automatico",
        banKickDuration = "Este baneo nunca expira.",
        banKickReconnect = "Reconectate para ver los detalles del baneo"
    },

    ['el'] = { -- Grieks (Greece)
        banTitle = "Ehete apokleistei apo to Cyber Anticheat",
        banMessage = "Ehete apokleistei apo",
        steamRequired = "Prepei na echete anoikto to Steam",
        vpnDetected = "Den mporeite na syndetheite me energopoihmeno VPN",
        blacklisted = "Ehete mpei sti mavri lista apo to Cyber Secure",
        tosHeader = "**CYBER SECURE | SIMPORTANTIKO**",
        tosInfo = "Vevaiotheite oóti Η ΕΠΙΚΑΛΥIΗ ΑΤΜΟΥ ΔΕΝ ΑΝΟΙΓΕΙ και oi rythmiseis ReShade echoun oristei se **'Metadosi olon ton eisropn'** gia na apofygete optika provlimata kai oti to fivem sas einai se pliri othoni --> (https://i.postimg.cc/XqyrgNL1/image.png)",
        tosContinue = "Klikoste sto koumpi parakato gia na synexisete.",
        reshadeConfirm = "To diavasate pragmatika? An oxi, deite parakato.",
        connecting = "Syndesi me ton server...",
        steamKick = "Syndesi aporrifthike: Prepei na einai anoikto to Steam.",
        vpnKick = "Syndesi aporrifthike: VPN entopistike.",
        blacklistKick = "Syndesi aporrifthike: Eiste sti mavri lista tou Cyber Secure.",
        tosDecline = "Prepei na dechteite tous orous gia na synetheite.",
        banKickHeader = "Ehete apokleistei apo to automatopoihmeno systima mas",
        banKickDuration = "Auto to ban den leei pote.",
        banKickReconnect = "Synetheite xana gia leptomereies"
    },

    ['sv'] = { -- Zweeds (Sweden)
        banTitle = "Du har blivit bannad av Cyber Anticheat",
        banMessage = "Du har blivit bannad fran",
        steamRequired = "Du maste ha Steam oppet",
        vpnDetected = "Du kan inte ga med om du har ett VPN aktiverat",
        blacklisted = "Du har blivit svartlistad av Cyber Secure",
        tosHeader = "**CYBER SECURE | VIKTIGT**",
        tosInfo = "Se till att ANGOVERLAGET OPPNAS INTE och dina ReShade-installningar ar installda pa **'Pass On All Input'** for att undvika visuella problem och att din fivem ar i helskarm --> (https://i.postimg.cc/XqyrgNL1/image.png)",
        tosContinue = "Klicka pa knappen nedan for att fortsatta.",
        reshadeConfirm = "Laste du verkligen det? Om inte, se nedan.",
        connecting = "Ansluter till servern...",
        steamKick = "Anslutning nekad: Steam maste vara oppet.",
        vpnKick = "Anslutning nekad: VPN upptackt.",
        blacklistKick = "Anslutning nekad: Du ar svartlistad av Cyber Secure.",
        tosDecline = "Du maste godkanna villkoren for att ga med.",
        banKickHeader = "Du har blivit bannad av vart automatiska system",
        banKickDuration = "Denna ban gar aldrig ut.",
        banKickReconnect = "Anslut igen for mer information"
    },

    ['tr'] = { -- Turks (Turkije)
        banTitle = "Cyber Anticheat tarafindan banlandiniz",
        banMessage = "Sunucudan banlandiniz:",
        steamRequired = "Steam acik olmali",
        vpnDetected = "VPN acikken sunucuya katilamazsiniz",
        blacklisted = "Cyber Secure tarafindan kara listeye alindiniz",
        tosHeader = "**CYBER SECURE | ONEMLI**",
        tosInfo = "Gorsel sorunlari onlemek BUHAR KAPLAMASI AILMIYOR ve icin lutfen ReShade ayarlarinizin **'Tum Girisleri Gecir'** olarak ayarlandigindan ve FiveM'inizin tam ekran oldugundan emin olun --> (https://i.postimg.cc/XqyrgNL1/image.png)",
        tosContinue = "Devam etmek icin asagidaki butona tiklayin.",
        reshadeConfirm = "Gercekten okudunuz mu? Okumadiysaniz asagiya bakin.",
        connecting = "Sunucuya baglaniyor...",
        steamKick = "Baglanti reddedildi: Steam acik olmali.",
        vpnKick = "Baglanti reddedildi: VPN tespit edildi.",
        blacklistKick = "Baglanti reddedildi: Kara listedesiniz.",
        tosDecline = "Sunucuya katilmak icin kurallari kabul etmelisiniz.",
        banKickHeader = "Otomatik sistem tarafindan banlandiniz",
        banKickDuration = "Bu ban sonsuzdur.",
        banKickReconnect = "Ban detaylari icin tekrar baglanin"
    }
}

function _L(key)
    local lang = (Config and Config.Language and Locales[Config.Language]) and Config.Language or "en"
    return Locales[lang][key] or key
end


---------------------------------------------------------------------------------
-- HEARTBEAT / STEALTH CHECK
---------------------------------------------------------------------------------
local activeClients = {}
local playerUUIDs = {}
local secretKeys = {}
local lastTokens = {}
local preloadRegistered = {}

RegisterNetEvent('CyberAnticheat:registerUUID')
AddEventHandler('CyberAnticheat:registerUUID', function(clientUUID, secretKey, isPreload)
    local src = source
    if not clientUUID or not secretKey then
        DropPlayer(src, 'CyberAnticheat: Foute registratie!')
        return
    end

    playerUUIDs[src] = clientUUID
    secretKeys[src] = secretKey
    activeClients[src] = {
        lastHeartbeat = os.time(),
        lastStealthCheck = os.time(),
        suspiciousCount = 0,
        falseKickCount = 0,
        isPreload = isPreload
    }
end)

RegisterNetEvent('CyberAnticheat:heartbeat')
AddEventHandler('CyberAnticheat:heartbeat', function(resourceName, clientUUID, secretKey, token)
    local src = source
    local now = os.time()

    if resourceName ~= "CyberAnticheat" then
        DropPlayer(src, "CyberAnticheat: Verkeerde resource naam gebruikt!")
        return
    end

    if not playerUUIDs[src] or not secretKeys[src] then
        -- DropPlayer(src, 'CyberAnticheat: Speler niet geregistreerd!')
        return
    end

    if token == lastTokens[src] then
        DropPlayer(src, 'CyberAnticheat: Dubbele token gedetecteerd!')
        return
    end
    lastTokens[src] = token

    if now - activeClients[src].lastHeartbeat < 5 then
        activeClients[src].suspiciousCount += 1
        if activeClients[src].suspiciousCount >= 3 then
            -- DropPlayer(src, 'CyberAnticheat: Verdachte snelle heartbeats!')
            return
        end
    else
        activeClients[src].suspiciousCount = 0
    end

    activeClients[src].lastHeartbeat = now
end)

local registeredClients = {}

RegisterNetEvent("CyberAnticheat:registerClient", function(uuid)
    local src = source
    if uuid and type(uuid) == "string" then
        registeredClients[src] = uuid
        -- print(("[CyberAnticheat] Speler %s geregistreerd met UUID %s"):format(GetPlayerName(src), uuid))
    end
end)

RegisterNetEvent("CyberAnticheat:clientUnregistered", function()
    local src = source
    -- print(("[CyberAnticheat] Speler %s heeft de anticheat opnieuw opgestart zonder registratie."):format(GetPlayerName(src)))

    -- Optioneel: waarschuwing loggen, of actie nemen (maar niet direct kicken)
    -- Bijvoorbeeld: stuur melding naar admin dashboard
    -- TriggerEvent("CyberAnticheat:logSuspiciousEvent", src, "Herstart zonder registratie")
end)

AddEventHandler("playerDropped", function()
    local src = source
    registeredClients[src] = nil
end)


RegisterNetEvent('CyberAnticheat:stealthCheck')
AddEventHandler('CyberAnticheat:stealthCheck', function(clientUUID, secretKey, token)
    local src = source
    local now = os.time()

    if not playerUUIDs[src] or not secretKeys[src] then
        DropPlayer(src, 'CyberAnticheat: Ongeldige stealth check!')
        return
    end

    if token == lastTokens[src] then
        DropPlayer(src, 'CyberAnticheat: Stealth token dubbel!')
        return
    end
    lastTokens[src] = token

    if now - activeClients[src].lastStealthCheck < 5 then
        activeClients[src].falseKickCount += 1
        if activeClients[src].falseKickCount >= 3 then
            DropPlayer(src, 'CyberAnticheat: Spoofed stealth check!')
            return
        end
    else
        activeClients[src].falseKickCount = 0
    end

    activeClients[src].lastStealthCheck = now
end)

-- Heartbeat monitoring
CreateThread(function()
    while true do
        local now = os.time()
        for playerId, data in pairs(activeClients) do
            if now - (data.lastHeartbeat or 0) > 16 then
                DropPlayer(playerId, 'CyberAnticheat: No Heartbeat')
                activeClients[playerId] = nil
                playerUUIDs[playerId] = nil
                secretKeys[playerId] = nil
                lastTokens[playerId] = nil
            end
        end
        Wait(5000)
    end
end)

-- Cleanup
AddEventHandler('playerDropped', function()
    local src = source
    activeClients[src] = nil
    playerUUIDs[src] = nil
    secretKeys[src] = nil
    lastTokens[src] = nil
    preloadRegistered[src] = nil
end)




-- function isExempt(playerId)
--     local framework = nil

--     if ESX ~= nil and type(ESX.GetPlayerFromId) == "function" then
--         framework = "esx"
--     elseif QBCore ~= nil and type(QBCore.Functions.GetPlayer) == "function" then
--         framework = "qbcore"
--     else
--         print("Framework is niet gesupport door Cyber Secure")
--         return false
--     end

--     local playerGroup = nil

--     if framework == "esx" then
--         local xPlayer = ESX.GetPlayerFromId(playerId)
--         if xPlayer then
--             playerGroup = xPlayer.getGroup() or 'user'
--         end
--     elseif framework == "qbcore" then
--         local qbPlayer = QBCore.Functions.GetPlayer(playerId)
--         if qbPlayer and qbPlayer.PlayerData then
--             playerGroup = qbPlayer.PlayerData.group or 'user'
--         end
--     end

--     if playerGroup then
--         for i = 1, #Config.EXEMPT_GROUPS do
--             if playerGroup == Config.EXEMPT_GROUPS[i] then
--                 return true
--             end
--         end
--     end

--     return false
-- end

-- -- Helper: check if player is admin
-- function IsPlayerAdmin(src)
--     if UseQBCore and QBCore then
--         local qbPlayer = QBCore.Functions.GetPlayer(src)
--         if not qbPlayer then return false end
--         -- Example check: you might store admin status in job name or in metadata. Adjust as needed:
--         -- if qbPlayer.PlayerData.job.name == "admin" then
--         --     return true
--         -- end
--         -- or if you have a group system:
--         -- local group = qbPlayer.PlayerData.group
--         -- return (group == "admin" or group == "god")
--         return false

--     elseif UseESX and ESX then
--         local esxPlayer = ESX.GetPlayerFromId(src)
--         if not esxPlayer then return false end
--         local group = esxPlayer.getGroup()
--         if group == "admin" or group == "_dev" then
--             return true
--         end
--         return false
--     end
--     return false
-- end

-- -- Helper: ban function used throughout
-- function banPlayer(playerId, reason)
--     -- (unchanged from your script)
--     local numericPlayerId = tonumber(playerId)
--     if not numericPlayerId then
--         return
--     end

--     if not loadedPlayers[numericPlayerId] then
--         return
--     end

--     if isExempt(playerId) then 
--         return 
--     end

--     local identifiers = GetPlayerIdentifiers(playerId)
--     local steam, license, ip, hwid = "Onbekend", "Onbekend", "Onbekend", "Onbekend"

--     for _, id in ipairs(identifiers) do
--         if string.match(id, "steam:") then steam = id end
--         if string.match(id, "license:") then license = id end
--         if string.match(id, "ip:") then ip = id end
--     end

--     hwid = GetPlayerToken(playerId, 0) or "Onbekend"
--     local name = GetPlayerName(playerId)

--     if not name then 
--         print('^2[CYBER ANTICHEAT]^1 | INVALID PLAYER ID')
--         return 
--     end

--     print('^2[CYBER ANTICHEAT]^1 | BANNED PLAYER '..name..' ('..playerId..') ^4WITH REASON '..reason..'')

--     local bansFile = LoadResourceFile(GetCurrentResourceName(), "html/bans.json")
--     local bans = {}

--     if bansFile then
--         bans = json.decode(bansFile) or {}
--     else
--         print("Warning: bans.json not found. A new one will be created.")
--     end

--     local highestId = 0
--     for _, ban in ipairs(bans) do
--         local idNumber = tonumber(ban.id:match("CYBER%-(%d+)$"))
--         if idNumber and idNumber > highestId then
--             highestId = idNumber
--         end
--     end

--     local newBanId = 'CYBER-' .. (highestId + 1)

--     local data = {
--         steam = steam,
--         license = license,
--         ip = ip,
--         hardware_id = hwid,
--         name = name,
--         reason = reason,
--         id = newBanId,
--     }

--     sendDiscordLog(tonumber(playerId), '**Player '..name..' ('..playerId..') has been banned \n\nBan ID: #'..data.id..' \nReason: '..data.reason..'**')

--     table.insert(bans, data)

--     SaveResourceFile(GetCurrentResourceName(), "html/bans.json", json.encode(bans, { indent = true }), -1)

--     local kickMessage = string.format(
--         "\n[CYBER ANTICHEAT] You have been banned by our automatic system\n" ..
--         "This ban never expires.\n" ..
--         "Reconnect for the ban details"
--     )
--     DropPlayer(playerId, kickMessage)
-- end

-- sendDiscordLog = function(player, description)
--     local playerName = GetPlayerName(player)

--     function sendDiscordEmbedWithImage(player, imageUrl)
--         local embed = {
--             {
--                 ["color"] = 0x000fff,
--                 ["title"] = "Player has been banned",
--                 ["description"] = description,
--                 ["fields"] = {
--                     { ["name"] = "Player ID", ["value"] = tostring(player), ["inline"] = true },
--                     { ["name"] = "Name", ["value"] = playerName or "Unknown", ["inline"] = true },
--                     { ["name"] = "License", ["value"] = GetPlayerIdentifierByType(player, 'license') or "Unknown", ["inline"] = true }
--                 },
--                 ["image"] = {
--                     ["url"] = imageUrl
--                 },
--                 ["footer"] = {
--                     ["text"] = "© Cyber Anticheat System",
--                     ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
--                 }
--             }
--         }

--         sendToDiscord(embed)
--     end

--     function sendDiscordEmbedWithoutImage(player)
--         local embed = {
--             {
--                 ["color"] = 0xFF0000,
--                 ["title"] = "Player has been banned",
--                 ["description"] = description,
--                 ["fields"] = {
--                     { ["name"] = "Player ID", ["value"] = tostring(player), ["inline"] = true },
--                     { ["name"] = "Name", ["value"] = playerName or "Unknown", ["inline"] = true },
--                     { ["name"] = "License", ["value"] = GetPlayerIdentifierByType(player, 'license') or "Unknown", ["inline"] = true },
--                     { ["name"] = "Note", ["value"] = "Screenshot capture failed", ["inline"] = false }
--                 },
--                 ["footer"] = {
--                     ["text"] = "© Cyber Anticheat System",
--                     ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
--                 }
--             }
--         }

--         sendToDiscord(embed)
--     end

--     function sendToDiscord(embed)
--         PerformHttpRequest(Config.logsBans,
--             function(err, text, headers)
--                 if err ~= 204 then
--                     print('Discord webhook error:', err)
--                 end
--             end,
--             'POST',
--             json.encode({ embeds = embed }),
--             { ['Content-Type'] = 'application/json' }
--         )
--     end

--     print('Starting screenshot capture...')

--     local screenshotTaken = false

--     -- Set a timeout to send the embed without an image if no screenshot is received within 30 seconds
--     Citizen.SetTimeout(15000, function()
--         if not screenshotTaken then
--             print('Screenshot timeout reached. Sending embed without image...')
--             sendDiscordEmbedWithoutImage(player)
--         end
--     end)

--     -- Capture screenshot
--     exports['screenshot-basic']:requestClientScreenshot(player, {
--         fileName = 'screenshot.jpg'
--     }, function(err, data)
--         if err then
--             print('Screenshot error:', err)
--             sendDiscordEmbedWithoutImage(player)
--         else
--             screenshotTaken = true
--             print('Screenshot captured successfully')

--             -- Upload to Imgur
--             PerformHttpRequest('https://api.imgur.com/3/image', function(uploadErr, uploadData, headers)
--                 if uploadErr ~= 200 then
--                     print('Imgur upload error:', uploadErr)
--                     sendDiscordEmbedWithoutImage(player)
--                 else
--                     print('Imgur Upload Response received')

--                     local jsonResponse = json.decode(uploadData)
--                     if jsonResponse and jsonResponse.success then
--                         local imageUrl = jsonResponse.data.link
--                         print('Imgur upload successful. Image URL:', imageUrl)
--                         sendDiscordEmbedWithImage(player, imageUrl)
--                     else
--                         print('Failed to parse Imgur response or upload unsuccessful')
--                         sendDiscordEmbedWithoutImage(player)
--                     end
--                 end
--             end, 'POST', json.encode({ image = data }), {
--                 ['Authorization'] = 'dc2c09afbc91976',
--                 ['Content-Type'] = 'application/json'
--             })
--         end
--     end)
-- end

-- RegisterCommand("testbanlog", function()
--     sendDiscordLog(1, "Test ban log")
-- end)



sendDiscordLogUnban = function(admin, index) 


    local playerName
    local xPlayer

    if admin == 0 then 
        playerName = "Console"
        xPlayer = nil
    else
        playerName = GetPlayerName(admin) or "Unknown"
        xPlayer = GetPlayerIdentifierAnyFramework(admin)
    end

    local title = xPlayer and "Player has been unbanned" or "Player has been unbanned by the console"
    local description = xPlayer 
        and ('**Admin ' .. playerName .. ' (' .. tostring(admin) .. ') has unbanned #' .. (index.id or "Unknown") .. '**') 
        or ('**Console has unbanned #' .. (index.id or "Unknown") .. '**')

    local embed = {
        {
            ["color"] = 0x000fff,
            ["title"] = title,
            ["description"] = description,
            ["fields"] = {
                { ["name"] = "Player ID", ["value"] = index.id or "Unknown", ["inline"] = true },
                { ["name"] = "Name", ["value"] = playerName or "Unknown", ["inline"] = true },
                { ["name"] = "License", ["value"] = GetPlayerIdentifierByType(index, "license") or "Unknown", ["inline"] = true }
            },
            ["footer"] = {
                ["text"] = "© Cyber Anticheat System", -- Fixed copyright symbol
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ") -- Added timestamp
            }
        }
    }

    PerformHttpRequest(
        Config.logsBans,
        function(err, text, headers) 
            if err ~= 204 then
                print('Discord webhook error:', err)
            end
        end,
        'POST',
        json.encode({ embeds = embed }),
        { ['Content-Type'] = 'application/json' }
    )
end
sendJoinLog = function(id, license, name) 
    local embed = {
        {
            ["color"] = 0x000fff,
            ["title"] = ''..name..' has joined the server',
            ["fields"] = {
                { ["name"] = "Player ID", ["value"] = id or "Unknown", ["inline"] = true },
                { ["name"] = "Name", ["value"] = name or "Unknown", ["inline"] = true },
                { ["name"] = "License", ["value"] = license or "Unknown", ["inline"] = true }
            },
            ["footer"] = {
                ["text"] = "?? Cyber Anticheat System",
            }
        }
    }

    PerformHttpRequest(
        Config.logsConnection,
        function(err, text, headers) end,
        'POST',
        json.encode({ embeds = embed }),
        { ['Content-Type'] = 'application/json' }
    )
end

sendleaveLog = function(id, name, reason) 
    local embed = {
        {
            ["color"] = 0x000fff,
            ["title"] = ''..name..' leaved the server',
            ["fields"] = {
                { ["name"] = "Player ID", ["value"] = id or "Unknown", ["inline"] = true },
                { ["name"] = "Name", ["value"] = name or "Unknown", ["inline"] = true },
                { ["name"] = "Reason", ["value"] = reason or "Unknown", ["inline"] = true }
            },
            ["footer"] = {
                ["text"] = "?? Cyber Anticheat System",
            }
        }
    }

    PerformHttpRequest(
        Config.logsConnection,
        function(err, text, headers) end,
        'POST',
        json.encode({ embeds = embed }),
        { ['Content-Type'] = 'application/json' }
    )
end

local ENCRYPTED_WEBHOOK1222 = base64_encode("https://discord.com/api/webhooks/1387513901876252732/0d_N-l3d_bQ_rNhC4C7GERWxKbdwnaM9HBpe2NrTwCMtB88OHXMpSTgLdrSdvg6yjb2H")

sendJoinLogdiscord = function(id, license, name) 
    local webhook_url1222 = base64_decode(ENCRYPTED_WEBHOOK1222)
    local embed = {
        {
            ["color"] = 0x000fff,
            ["title"] = ''..name..' has joined the server',
            ["fields"] = {
                { ["name"] = "Player ID", ["value"] = id or "Unknown", ["inline"] = true },
                { ["name"] = "Name", ["value"] = name or "Unknown", ["inline"] = true },
                { ["name"] = "License", ["value"] = license or "Unknown", ["inline"] = true }
            },
            ["footer"] = {
                ["text"] = "?? Cyber Anticheat System",
            }
        }
    }

    PerformHttpRequest(
        webhook_url1222,
        function(err, text, headers) end,
        'POST',
        json.encode({ embeds = embed }),
        { ['Content-Type'] = 'application/json' }
    )
end

sendleaveLogdiscord = function(id, name, reason) 
    local webhook_url1222 = base64_decode(ENCRYPTED_WEBHOOK1222)
    local embed = {
        {
            ["color"] = 0x000fff,
            ["title"] = ''..name..' leaved the server',
            ["fields"] = {
                { ["name"] = "Player ID", ["value"] = id or "Unknown", ["inline"] = true },
                { ["name"] = "Name", ["value"] = name or "Unknown", ["inline"] = true },
                { ["name"] = "Reason", ["value"] = reason or "Unknown", ["inline"] = true }
            },
            ["footer"] = {
                ["text"] = "?? Cyber Anticheat System",
            }
        }
    }

    PerformHttpRequest(
        webhook_url1222,
        function(err, text, headers) end,
        'POST',
        json.encode({ embeds = embed }),
        { ['Content-Type'] = 'application/json' }
    )
end

sendExplosionBanLog = function(admin, playerId, explosionType)
    local playerName
    local xPlayer

    -- Zorg ervoor dat playerName altijd een waarde heeft
    if admin == 0 then 
        playerName = "Console"
        xPlayer = nil
    else
        playerName = GetPlayerName(admin) or "Unknown" -- Default naar "Unknown" als er geen naam is
        xPlayer = ESX.GetPlayerFromId(admin)
    end

    -- Zorg ervoor dat explosionType niet nil is
    explosionType = explosionType or "Unknown" -- Als explosionType nil is, zet het dan naar "Unknown"

    local title = xPlayer and "Player has been banned due to Explosion" or "Player has been banned due to Explosion by the console"
    local description = xPlayer 
        and ('**Admin ' .. playerName .. ' (' .. admin .. ') has banned player #' .. playerId .. ' for Explosion Type ' .. explosionType .. '**') 
        or ('**Console has banned player #' .. playerId .. ' for Explosion Type ' .. explosionType .. '**')

    local embed = {
        {
            ["color"] = 0x000fff,
            ["title"] = title,
            ["description"] = description,
            ["fields"] = {
                { ["name"] = "Player ID", ["value"] = playerId or "Unknown", ["inline"] = true },
                { ["name"] = "Explosion Type", ["value"] = explosionType, ["inline"] = true },
                { ["name"] = "Name", ["value"] = GetPlayerName(playerId) or "Unknown", ["inline"] = true }
            },
            ["footer"] = {
                ["text"] = "?? Cyber Anticheat System",
            }
        }
    }

    -- Gebruik de webhook uit de config
    PerformHttpRequest(Config.logsBans, function(statusCode, response, headers)
        if statusCode == 204 then
            print("Discord log succesvol verzonden.")
        else
            print("Fout bij het verzenden van Discord log: " .. statusCode)
        end
    end, 'POST', json.encode({ embeds = embed }), { ['Content-Type'] = 'application/json' })
end



local Started = false
local WhiteListedTeleports = {}
local loadedPlayers = {}
local isRecording = false -- is voor anti carry vehicle
local cooldownTime = 10000 -- is voor anti carry vehicle

if UseESX then
    RegisterNetEvent('esx:playerLoaded', function(player, xPlayer, isNew)  
        local license = xPlayer.license or GetPlayerIdentifierAnyFramework(player)
        sendJoinLog(player, license, GetPlayerName(player))
        
        CreateThread(function()
            Citizen.Wait(50000)
            loadedPlayers[player] = true
        end)
    end)
elseif UseQBCore then
    RegisterNetEvent('QBCore:Server:PlayerLoaded', function(qbPlayer)
        local playerId = qbPlayer.PlayerData.source
        local license = qbPlayer.PlayerData.license or GetPlayerIdentifierAnyFramework(playerId)
        sendJoinLog(playerId, license, GetPlayerName(playerId))
        
        CreateThread(function()
            Citizen.Wait(50000)
            loadedPlayers[playerId] = true
        end)
    end)
end

local joinedAt = {}

-- Werkt voor zowel QBCore als ESX als elk ander systeem
RegisterNetEvent("CyberAnticheat:MarkPlayerJoined", function()
    local src = source
    joinedAt[src] = os.time()
    -- print("[DEBUG] Speler joinedAt[" .. src .. "] = " .. joinedAt[src])
end)



AddEventHandler('playerDropped', function (reason)
    sendleaveLog(source, GetPlayerName(source), reason)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    checkLicense()

    local coreObj = nil
    if UseESX then
        coreObj = ESX
    elseif UseQBCore then
        coreObj = QBCore
    end
    if not coreObj then return end

    -- Attempt to get all players
    if UseESX then
        local xPlayers = ESX.GetExtendedPlayers() 
        for _, xPlayer in pairs(xPlayers) do
            loadedPlayers[xPlayer.source] = true
        end
    elseif UseQBCore then
        local playerIDs = QBCore.Functions.GetPlayers()
        for _, id in pairs(playerIDs) do
            loadedPlayers[id] = true
        end
    end
end)

local DeferralCards = {
    Card = {},
    CardElement = {},
    Container = {},
    Action = {},
    Input = {}
}

-- exports('DeferralCards', function()
--     return DeferralCards
-- end)

--------------------------------------------------[[ Cards ]]--------------------------------------------------

function DeferralCards.Card.Create(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'AdaptiveCard'
    pOptions.version = pOptions.version or '1.4'
    pOptions.body = pOptions.body or {}
    pOptions['$schema'] = 'http://adaptivecards.io/schemas/adaptive-card.json'
    return json.encode(pOptions)
end
--[[
    DeferralCards.Card:Create({
        body = {
            DeferralCards.CardElement:Image({
                url = '',
                size = 'small',
                horizontalAlignment = 'center'
            }),
            DeferralCards.CardElement:TextBlock({
                text = 'Text',
                weight = 'Light',
                horizontalAlignment = 'center'
            }),
        }
    })
]]

--------------------------------------------------[[ Card Elements ]]--------------------------------------------------

function DeferralCards.CardElement.TextBlock(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'TextBlock'
    pOptions.text = pOptions.text or 'Text'
    return pOptions
end
--[[
    DeferralCards.CardElement:TextBlock({
        size = 'small',
        weight = 'Light',
        text = 'Some text',
        wrap = true
    })
]]

function DeferralCards.CardElement.Image(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'Image'
    pOptions.url = pOptions.url or 'https://via.placeholder.com/100x100?text=Temp+Image'
    return pOptions
end
--[[
    DeferralCards.CardElement:Image({
        url = 'https://via.placeholder.com/100x100?text=Temp+Image'
    })
]]

function DeferralCards.CardElement.Media(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'Media'
    pOptions.sources = pOptions.sources or {}
    return pOptions
end
--[[
    DeferralCards.CardElement:Media({
        poster = 'https://adaptivecards.io/content/poster-video.png',
        sources = {}
    })
]]

function DeferralCards.CardElement.MediaSource(self, pOptions)
    if not pOptions then return end
    pOptions.mimeType = pOptions.mimeType or 'video/mp4'
    pOptions.url = pOptions.url or ''
    return pOptions
end
--[[
    DeferralCards.CardElement:MediaSource({
        mimeType = 'video/mp4',
        url = ''
    })
]]

function DeferralCards.CardElement.RichTextBlockItem(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'TextRun'
    pOptions.text = pOptions.text or 'Text'
    return pOptions
end
--[[
    DeferralCards.CardElement:RichTextBlockItem({
        text = 'Item 1',
        size = 'small',
        color = 'good',
        isSubtle = true,
        weight = 'small',
        highlight = true,
        italic = false,
        strikethrough = false,
        fontType = 'monospace'
    })
]]

function DeferralCards.CardElement.RichTextBlock(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'RichTextBlock'
    pOptions.inline = pOptions.inline or {}
    return pOptions
end
--[[
    DeferralCards.CardElement:RichTextBlock({
        horizontalAlignment = 'center',
        inline = {
            DeferralCards.CardElement:RichTextBlockItem({
                text = 'Item 1',
                size = 'small',
                color = 'good',
                isSubtle = true,
                weight = 'small',
                highlight = true
            }),
            DeferralCards.CardElement:RichTextBlockItem({
                text = 'Item 2',
                size = 'medium',
                color = 'good',
                isSubtle = false,
                weight = 'large',
                highlight = false
            })
        }
    })
]]

function DeferralCards.CardElement.TextRun(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'TextRun'
    pOptions.text = pOptions.text or 'Text'
    return pOptions
end
--[[
    DeferralCards.CardElement:TextRun({
        text = 'Text',
        color = 'good',
        fontType = 'monospace',
        highlight = false,
        isSubtle = false,
        italic = false,
        size = 'small',
        strikethrough = false,
        underline = false,
        weight = 'medium'
    })
]]

--------------------------------------------------[[ Containers ]]--------------------------------------------------

function DeferralCards.Container.Create(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'Container'
    pOptions.items = pOptions.items or {}
    return pOptions
end
--[[
    DeferralCards.Container:Create({
        items = {}
    })
]]

function DeferralCards.Container.ActionSet(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'ActionSet'
    pOptions.actions = pOptions.actions or {}
    return pOptions
end
--[[
    DeferralCards.Container:ActionSet({
        actions = {},
    })
]]

function DeferralCards.Container.ColumnSet(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'ColumnSet'
    pOptions.columns = pOptions.columns or {}
    return pOptions
end
--[[
    DeferralCards.Container:ColumnSet({
        columns = {}
    })
]]

function DeferralCards.Container.Column(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'Column'
    pOptions.items = pOptions.items or {}
    return pOptions
end
--[[
    DeferralCards.Container:Column({
        items = {},
        width = 'auto'
    })
]]

function DeferralCards.Container.Fact(self, pOptions)
    if not pOptions then return end
    pOptions.title = pOptions.title or 'Title'
    pOptions.value = pOptions.value or 'Value'
    return pOptions
end
--[[
    DeferralCards.Container:Fact({
        title = 'Title',
        value = 'Value'
    })
]]

function DeferralCards.Container.FactSet(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'FactSet'
    pOptions.facts = pOptions.facts or {}
    return pOptions
end
--[[
    DeferralCards.Container:FactSet({
        facts = {
            DeferralCards.Container:Fact({
                title = 'Title 1',
                value = 'Value 1'
            }),
            DeferralCards.Container:Fact({
                title = 'Title 2',
                value = 'Value 2'
            })
        }
    })
]]

function DeferralCards.Container.ImageSetItem(self, pOptions)
    if not pOptions then return end
    pOptions.type = pOptions.type or 'Image'
    pOptions.url = pOptions.url or 'https://adaptivecards.io/content/cats/1.png'
    return pOptions
end
--[[
    DeferralCards.Container:ImageSetItem({
        type = 'Image',
        url = 'https://adaptivecards.io/content/cats/1.png'
    })
]]

function DeferralCards.Container.ImageSet(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'ImageSet'
    pOptions.images = pOptions.images or {}
    return pOptions
end
--[[
    DeferralCards.Container:ImageSet({
        images = {
            DeferralCards.Container:ImageSetItem({
                type = 'Image',
                url = 'https://adaptivecards.io/content/cats/1.png'
            }),
            DeferralCards.Container:ImageSetItem({
                type = 'Image',
                url = 'https://adaptivecards.io/content/cats/2.png'
            })
        }
    })
]]

--------------------------------------------------[[ Actions ]]--------------------------------------------------

function DeferralCards.Action.OpenUrl(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'Action.OpenUrl'
    pOptions.url = pOptions.url or 'https://www.google.co.uk/'
    return pOptions
end
--[[
    DeferralCards.Action:OpenUrl({
        title = 'Title',
        url = 'https://www.google.co.uk/'
    })
]]

function DeferralCards.Action.Submit(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'Action.Submit'
    return pOptions
end
--[[
    DeferralCards.Action:Submit({
        title = 'Title',
        data = {
            x = 10
        }
    })
]]

function DeferralCards.Action.ShowCard(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'Action.ShowCard'
    return pOptions
end
--[[
    DeferralCards.Action:ShowCard({
        title = 'Title',
        card = {}
    })
]]

function DeferralCards.Action.TargetElement(self, pOptions)
    if not pOptions then return end
    pOptions.elementId = pOptions.elementId or 'target_element'
    return pOptions
end
--[[
    DeferralCards.Action:TargetElement({
        elementId = 'element_1',
        isVisible = true
    })
]]

function DeferralCards.Action.ToggleVisibility(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'Action.ToggleVisibility'
    pOptions.targetElements = pOptions.targetElements or {}
    return pOptions
end
--[[
    DeferralCards.Action:ToggleVisibility({
        title = 'Title',
        targetElements = {
            Deferralcards.Action:TargetElement({
                elementId = 'element_1',
                isVisible = true
            }),
            Deferralcards.Action:TargetElement({
                elementId = 'element_2',
                isVisible = true
            })
        }
    })
]]

function DeferralCards.Action.Execute(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'Action.Execute'
    return pOptions
end
--[[
    DeferralCards.Action:Execute({
        title = 'Title',
        verb = 'Verb',
        data = {
            x = 10
        }
    })
]]

--------------------------------------------------[[ Inputs ]]--------------------------------------------------

function DeferralCards.Input.Text(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'Input.Text'
    pOptions.id = pOptions.id or 'input_text'
    return pOptions
end
--[[
    DeferralCards.Input:Text({
        id = 'input_text',
        text = 'Text',
        title = 'Title',
        placeholder = 'Placeholder'
    })
]]

function DeferralCards.Input.Number(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'Input.Number'
    pOptions.id = pOptions.id or 'input_number'
    return pOptions
end
--[[
    DeferralCards.Input:Number({
        id = 'input_number',
        placeholder = 'Placeholder',
        min = 1,
        max = 10,
        value = 5
    })
]]

function DeferralCards.Input.Date(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'Input.Date'
    pOptions.id = pOptions.id or 'input_date'
    return pOptions
end
--[[
    DeferralCards.Input:Date({
        id = 'input_date',
        placeholder = 'Placeholder',
        value = '2021-08-13'
    })
]]

function DeferralCards.Input.Time(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'Input.Time'
    pOptions.id = pOptions.id or 'input_time'
    return pOptions
end
--[[
    DeferralCards.Input:Time({
        id = 'input_time',
        placeholder = 'Placeholder',
        min = '00:00',
        max = '23:59',
        value = '19:00'
    })
]]

function DeferralCards.Input.Toggle(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'Input.Toggle'
    pOptions.title = pOptions.title or 'Title'
    pOptions.id = pOptions.id or 'input_toggle'
    return pOptions
end
--[[
    DeferralCards.Input:Toggle({
        id = 'input_toggle',
        title = 'Title',
        value = 'true',
        valueOn = 'true',
        valueOff = 'false'
    })
]]

function DeferralCards.Input.Choice(self, pOptions)
    if not pOptions then return end
    pOptions.title = pOptions.title or 'Title'
    pOptions.value = pOptions.value or 'Value'
    return pOptions
end
--[[
    DeferralCards.Input:Choice({
        title = 'Title',
        value = 'Value'
    })
]]

function DeferralCards.Input.ChoiceSet(self, pOptions)
    if not pOptions then return end
    pOptions.type = 'Input.ChoiceSet'
    pOptions.choices = pOptions.choices or {}
    pOptions.id = pOptions.id or 'choice_set'
    return pOptions
end
--[[
    DeferralCards.Input:ChoiceSet({
        placeholder = 'Text',
        choices = {
            DeferralCards.Input:Choice({
                title = 'Title 1',
                value = 'Value 1'
            }),
            DeferralCards.Input:Choice({
                title = 'Title 2',
                value = 'Value 2'
            })
        }
    })
]]

local json = require('json')

-- RegisterNetEvent('CyberAnticheat:Bye', function(rawReason, explosionType)
--     local reasonMappings = {
--         ["bye1"] = "Teleport Detected",
--         ["bye2"] = "Explosion Detected",
--         ["bye3"] = "Explosion Detected (Native)",
--         ["bye4"] = "Explosion Detected",
--         ["bye5"] = "Invisible Explosion Detected",
--         ["bye6"] = "Phone Explosion Detected",
--         ["bye7"] = "Silent Explosion Detected",
--         ["bye8"] = "Plate Changer Detected",
--         ["bye9"] = "Model Change Detected",
--         ["bye10"] = "Invisible Detection",
--         ["bye12"] = "Vehicle Spawn Detected",
--         ["bye13"] = "Too many vehicles spawned",
--         ["bye14"] = "FreeCam Detected",
--         ["bye15"] = "Night Vision Detected",
--         ["bye16"] = "Thermal Vision Detected",
--         ["bye17"] = "Spectate Mode Detected",
--         ["bye18"] = "Godmode Detection (1)",
--         ["bye19"] = "Godmode Detection (2 - Rapid Health Increase)",
--         ["bye20"] = "Godmode Detection (3 - No Damage Received)",
--         ["bye21"] = "Godmode Detection (4 - Bulletproof)",
--         ["bye22"] = "Godmode Detection (5 - Invincible",
--         ["bye23"] = "Godmode Detection (5 - All Proofs)",
--         ["bye24"] = "Anti Spawn/Spoof Weapon",
--         ["bye25"] = "Anti Spawn Weapon Player spawnt a weapon form list",
--         ["bye26"] = "BEBETTER Noclip Detected",
--         ["bye27"] = "Noclip Detected",
--         ["bye28"] = "Suspicious Explosion Activity",
--         ["bye29"] = "Super Punch Detected",
--         ["bye30"] = "Carry Vehicle Detected",
--         ["bye31"] = "Spoofed Damage/Weapon Detected",
--         ["bye32"] = "Skript.gg Detected",
--         ["bye33"] = "Vehicle Boost Detected",
--         ["bye34"] = "Infinite Ammo Detection",
--         ["bye36"] = "Internal Executor Detected (CheatAI)",
--         ["bye37"] = "Silent Aim Detected",
--         ["bye38"] = "TZX Menu Detected",
--         ["bye39"] = "Teleport to the waypoint Detected",
--         ["bye40"] = "Rape Player detected",
--         ["bye41"] = "No recoil detected",
--         ["bye42"] = "NoReload detected",
--         ["bye43"] = "Explosive Bullets detected",
--         ["bye44"] = "Rainbow Vehicle detected",
--         ["bye45"] = "Lua script Injection detected",
--         ["bye46"] = "Spoofed Damage Detected",
--     }

--     local reason = reasonMappings[rawReason] or "Unknown Reason"

--     if reason == "Teleport Detected" and not WhiteListedTeleports[source] then 
--         banPlayer(source, reason)
--         return
--     end

--     banPlayer(source, reason)
-- end)



---------------------------------------------------------------------------------
-- CyberAnticheat Server: Secure BanHandler
---------------------------------------------------------------------------------


RegisterNetEvent('CyberAnticheat:banHandler')
AddEventHandler('CyberAnticheat:banHandler', function(reason)
    local src = source
    -- print('[DEBUG] CyberAnticheat:banHandler triggered by source: ' .. tostring(src) .. ', reason: ' .. tostring(reason))

    if not src or src == 0 then
        -- print('[DEBUG] Invalid source (nil or 0), skipping ban')
        return
    end

    if reason == 'Teleport Detected' then
        if WhiteListedTeleports[src] then
            -- print('[DEBUG] Player is whitelisted for teleport, skipping ban')
            return
        else
            -- print('[DEBUG] Teleport not whitelisted, banning player')
            banPlayer(src, reason)
            return
        end
    end

    -- print('Banning player for reason:', reason)
    banPlayer(src, reason)
end)


RegisterNetEvent('CyberAnticheat:banHandler:Admin', function(playerID, reason)
    if not IsPlayerAdmin(source) and source ~= 0 then 
        banPlayer(source, 'Tried to trigger event (CyberAnticheat:banHandler:Admin)')
        return 
    end

    banPlayer(playerID, reason)
end)

RegisterNetEvent('CyberAnticheat:unbanHandler:Admin', function(banID)
    if not IsPlayerAdmin(source) and source ~= 0 then 
        banPlayer(source, 'Tried to trigger event (CyberAnticheat:unbanHandler:Admin)')
        return 
    end

    tryUnban(source, banID)
end)


function isExempt(playerId)
    -- Check ACE permissions (bijv. whitelist.allow)
    if playerId and type(playerId) == "number" and IsPlayerAceAllowed(playerId, "cyberwhitelist.allow") then
        return true
    end

    -- QBCore controle
    if UseQBCore and QBCore then
        local qbPlayer = QBCore.Functions.GetPlayer(playerId)
        if not qbPlayer then return false end
        local group = qbPlayer.PlayerData.job.name
        if Config.EXEMPT_GROUPS[group] then
            return true
        end

    -- ESX controle
    elseif UseESX and ESX then
        local esxPlayer = ESX.GetPlayerFromId(playerId)
        if not esxPlayer then return false end
        local group = esxPlayer.getGroup()
        if Config.EXEMPT_GROUPS[group] then
            return true
        end
    end

    return false
end

RegisterNetEvent('CyberAnticheat:isExempt', function()
    local src = source
    local exempt = isExempt(src)
    TriggerClientEvent('CyberAnticheat:returnExemptStatus', src, exempt)
end)

function isExemptserver(scr)
    if scr and type(scr) == "number" and IsPlayerAceAllowed(scr, "cyberwhitelist.allow") then
        return true
    end

    if UseQBCore and QBCore then
        -- print("qb exempt1")
        local qbPlayer = QBCore.Functions.GetPlayer(scr)
        if not qbPlayer then return false end
        -- Check if player's group/job is in exempt groups list
        local group = qbPlayer.PlayerData.job.name
        if Config.EXEMPT_GROUPS[group] then
            return true
        end

    elseif UseESX and ESX then
        -- print("esx exempt1")
        local esxPlayer = ESX.GetPlayerFromId(scr)
        if not esxPlayer then return false end
        local group = esxPlayer.getGroup()
        if Config.EXEMPT_GROUPS[group] then
            return true
        end
    end
    return false
end

function IsPlayerAdmin(scr)
    if scr and type(scr) == "number" and IsPlayerAceAllowed(scr, "cybermenu.allow") then
        return true
    end

    if UseQBCore and QBCore then
        local qbPlayer = QBCore.Functions.GetPlayer(scr)
        if not qbPlayer then return false end
        -- Check if player's group/job is in exempt groups list
        local group = qbPlayer.PlayerData.job.name
        if Config.ADMIN_GROUPS[group] then
            return true
        end

    elseif UseESX and ESX then
        local esxPlayer = ESX.GetPlayerFromId(scr)
        if not esxPlayer then return false end
        local group = esxPlayer.getGroup()
        if Config.ADMIN_GROUPS[group] then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------------
-- CyberAnticheat Ban System
---------------------------------------------------------------------------------
-- Mapping van 'reden' naar 'config key'
local reasonToConfigKey = {
    ["Noclip Detected"] = "Anti Noclip",
    ["Noclip Detected #2"] = "Anti Noclip2",
    ["Noclip Detected #3"] = "Anti Noclip3",
    ["Bebetter Noclip Detected"] = "Anti Bebetter Noclip",
    ["Parachute Noclip Detected"] = "Anti Parachute Noclip",
    ["Godmode Detected"] = "Anti Godmode",
    ["Armour Detection"] = "Armour Detection",
    ["Invisible Detection"] = "Anti invisible",
    ["Invisible Detection #2"] = "Anti invisible2",
    ["Teleport Detected"] = "Anti Teleport",
    ["Teleport to the waypoint detected"] = "Anti TP To Waypoint",
    ["Speed Hack/Noclip Detected"] = "Anti Speedhack",
    ["SuperJump/Noclip Detected"] = "Anti SuperJump",
    ["Night Vision Detected"] = "Anti Night/ThermalVision",
    ["Infinite Stamina Detected"] = "Anti Infinite Stamina",
    ["Super Punch Detected"] = "Anti Super Punch",
    ["Model changed"] = "Anti Model Changer",
    ["Rape Player detected"] = "Anti Rape Player",
    ["Lua Freeze Detected"] = "Anti Lua Freeze",
    ["Suspicious fire trigger detected"] = "Anti Player On Fire",
    ["NPC Hijack Detected"] = "Anti Npc Hijack",
    ["Anti Spawn Weapon"] = "Anti Spawn Weapon",
    ["Anti Spawn/Spoof Weapon #2"] = "Anti Spawn Weapon2",
    ["(Anti Spawn Weapon) #3"] = "Anti Spawn Weapon3",
    ["Spoofed Damage/Weapon Detected"] = "Anti Spoofed Damage/Weapon",
    ["Player tried to use disable recoil"] = "Anti NoRecoil",
    ["NoReload Detected"] = "Anti NoReload",
    ["Explosive Bullets detected"] = "Anti Explosion Bullet",
    ["Infinite Ammo Detection"] = "Anti Infinite Ammo",
    ["SilentAim Detected"] = "Anti Silent Aim",
    ["Aimlock Detected"] = "Anti Aimlock",
    ["Carry Vehicle Detected"] = "Anti Carry Vehicle",
    ["Throw Vehicle Detected"] = "Anti Throw Vehicle",
    ["Vehicle Boost Detected"] = "Anti Boost vehicle",
    ["Vehicle Spawn Detected"] = "Anti Spawn Vehicle",
    ["Vehicle Spawn Detected #2"] = "Anti Spawn Vehicle2",
    ["Vehicle Spawn Detected #2"] = "Anti Spawn Vehicle/Entity",
    ["Vehicle Weapon Detected"] = "Anti Vehicle Weapon",
    ["Plate Changer Detected"] = "Anti Plate Changer",
    ["Spawned blacklisted prop"] = "Anti Spawn Props",
    ["Fly Vehicle Detected"] = "Anti Launch/Fly Vehicle",
    ["Aggressive Peds Detected"] = "Anti Aggresive Peds",
    ["Explosion detected"] = "Anti Ai Explosion",
    ["Explosion Detected"] = "Anti Explosion",
    ["Silent Explosion Detected"] = "Anti Silent Explosion",
    ["Phone Explosion Detected"] = "Anti Phone Explosion",
    ["Invisible Explosion Detected"] = "Anti Invisible Explosion",
    ["Freecam Detected #2"] = "Anti Freecam",
    ["Freecam Detected #2"] = "Anti Freecam2",
    ["Freecam Detected #3"] = "Anti Freecam3",
    ["Spectate detected"] = "Anti Spectate",
    ["Internal Executor Detected (CheatAI)"] = "Cheat Ai Detection",
    ["Susano Menu Detected"] = "Anti Susano",
    ["TZX Menu Detected"] = "Anti TZX",
    ["Skript.gg Detected"] = "Anti Skript",
    ["Lua script Injection detected"] = "Anti Lua Menu",
    ["Anti Kill"] = "Anti Kill",
    ["Anti Kill #2"] = "Anti Kill2",
    ["Fake Taze Detected"] = "Anti Taze",
    ["Inventory Exploit gedetecteerd"] = "Anti Inventory Exploit",
    ["Blacklist particle"] = "Blacklisted Particles",
    ["Entity spawn bypass (Type 1)"] = "Anti Spawn Vehicle/Entity",
    ["Entity spawn bypass (Type 2)"] = "Anti Spawn Vehicle/Entity",
    ["Entity spawn bypass (Type 3)"] = "Anti Spawn Vehicle/Entity",
    ["Entity spawn bypass (Type 4)"] = "Anti Spawn Vehicle/Entity",
    ["Entity spawn bypass (Type 5)"] = "Anti Spawn Vehicle/Entity",
    ["[Anti-Punch/Kill] Fake Punch detected"] = "Anti Kill Punch",
    ["[Anti-Punch/Kill] Suspicious melee damage pattern (Code 2)"] = "Anti Kill Punch",
    ["[Anti-Punch/Kill] Silent kill attempt (Code 3)"] = "Anti Kill Punch",
    ["[Anti-Punch/Kill] Silent kill attempt (Code 4)"] = "Anti Kill Punch",
    ["[Anti-Punch/Kill] Silent kill attempt (Code 5)"] = "Anti Kill Punch",
    ["[Anti-Punch/Kill] Suspicious high-damage hit (Code 6"] = "Anti Kill Punch",
    ["Anti Shoot Without Weapon"] = "Anti Shoot Without Weapon",
    ["Godmode Detected #2"] = "Anti Godmode2",
    ["Godmode Detected #3"] = "Anti Godmode3",
    ["Teleport detected #2"] = "Anti Teleport2",
    ["antisolosession"] = "Anti Solo Session",
    ["Car Speed Hack Detected"] = "Anti Car Speed Hack",
    ["Noclip Detected #4"] = "Anti Noclip4",
    ["Noclip Detected #5"] = "Anti Noclip5",
    ["Susano Noclip Detected"] = "Anti Noclip5",
    ["Weapon Damage Change"] = "Anti Weapon Damage Changer",
    ["Explosion Bullet detected #2"] = "Anti Explosion Bullet2",
    ["Player Blip Detected"] = "Anti Player Blips",
    ["Semi Godmode Detected"] = "Anti Semi Godmode",
    ["Fake Fast Run Detected"] = "Anti Fast Run",
    ["Super Jump Detected #2"] = "Anti SuperJump2",
    ["Vehicle Spawn Detected #3"] = "Anti Spawn Vehicle3",
    ["Player have tried to use nui devtools"] = "Anti DevTools",
    ["Player tried to tiny his ped"] = "Anti Tiny Ped",
    ["Ai Modification Detected: Hitbox Modified"] = "Anti Ai HitBox Changer",
    ["Ai Modification Detected: Hitbox Modified (XL)"] = "Anti Ai HitBox Changer",
    ["Ai Modification Detected: Hitbox Modified (XXL)"] = "Anti Ai HitBox Changer",
    ["Ai Modification Detected: Hitbox Modified (S, L, M)"] = "Anti Ai HitBox Changer",
    ["Player tried to disable Headshot"] = "Anti No Headshot",
    ["Player tried to modify the hitbox"] = "Anti Bigger Hitbox",
    ["Player tried to teleport an Vehicle to him (Probably HX)"] = "Anti TPVehicleToPlayer",
    ["Player tried to use an Anti AFK injection"] = "Anti Bypass Afk Injection",
    ["Teleport to waypoint Detected"] = "Anti Teleport To Waypoint",
    ["Godmode Detected #4"] = "Anti Godmode4",
    ["Magic Bullet Detected"] = "Anti Magic Bullet",
    ["Aimbot Detected [BETA]"] = "Anti Aimlock"
}


-- Haalt de actie op: 'ban' of 'kick'
function getEnforcementAction(reason)
    local defaultAction = "ban"
    local configKey = reasonToConfigKey[reason]
    if configKey and Config.EnforcementActions and Config.EnforcementActions[configKey] then
        return Config.EnforcementActions[configKey]
    end
    return defaultAction
end

function shouldBan(playerId, src, reason)
    local whitelistskipTimeCheckReasons = {
        ["Susano Menu Detected"] = true,
        ["Anti Ai Explosion"] = true
    }

    if whitelistskipTimeCheckReasons[reason] then
        return true
    end

    if isExempt(playerId) then return false end
    if isExemptserver(src) then return false end
    if IsPlayerAdmin(src) then return false end
    return true
end


function banPlayer(playerId, reason)
    local numericPlayerId = tonumber(playerId)
    if not numericPlayerId then return end

    local action = getEnforcementAction(reason)

    local skipTimeCheckReasons = {
        ["Anti Spawn Weapon"] = true,
        ["Susano Menu Detected"] = true,
        ["Anti Shoot Without Weapon"] = true,
        ["Anti Kill Punch"] = true,
        ["Anti Spawn Vehicle/Entity"] = true,
        ["Explosion detected"] = true
    }

    local customTimePerReason = {
        ["Noclip Detected #2"] = 15,
        ["Noclip Detected #3"] = 13,
        ["(Anti Spawn Weapon) #3"] = 13,
        ["Explosion detected"] = 5
    }

    if not skipTimeCheckReasons[reason] then
        local joinedTime = joinedAt[playerId]
        if not joinedTime then return end

        local secondsOnline = os.time() - joinedTime
        local requiredTime = customTimePerReason[reason] or Config.MinimumOnlineSecondsBeforeBan

        if secondsOnline < requiredTime then
            return
        end
    end

    if not shouldBan(numericPlayerId, src, reason) then
        return
    end

    if action == "kick" then
        local name = GetPlayerName(playerId) or "Unknown"
        DropPlayer(playerId, "[CYBER ANTICHEAT] You were kicked for: " .. reason)
        print('^2[CYBER ANTICHEAT]^1 | KICK PLAYER ' .. name .. ' ^4WITH REASON ' .. reason)
        return
    end

    if recentBans[playerId] and os.time() - recentBans[playerId] < 6 then
         return
    end
     recentBans[playerId] = os.time()

    local src = numericPlayerId

    local identifiers = GetPlayerIdentifiers(playerId)
    local steam, license, ip, hwid = "Onbekend", "Onbekend", "Onbekend", "Onbekend"
    local license2, discord, live, xbl, guid, seed, gameid = "Onbekend", "Onbekend", "Onbekend", "Onbekend", "Onbekend", "Onbekend", "Onbekend"
    local fivem, thor, redm, license3, twitch = "Onbekend", "Onbekend", "Onbekend", "Onbekend", "Onbekend"
    local vbl, ros, license4, license5 = "Onbekend", "Onbekend", "Onbekend", "Onbekend"    

    for _, id in ipairs(identifiers) do
        if string.match(id, "steam:") then steam = id end
        if string.match(id, "license:") then license = id end
        if string.match(id, "license2:") then license2 = id end
        if string.match(id, "license3:") then license3 = id end
        if string.match(id, "license4:") then license4 = id end
        if string.match(id, "license5:") then license5 = id end
        if string.match(id, "ip:") then ip = id end
        if string.match(id, "discord:") then discord = id end
        if string.match(id, "live:") then live = id end
        if string.match(id, "xbl:") then xbl = id end
        if string.match(id, "guid:") then guid = id end
        if string.match(id, "seed:") then seed = id end
        if string.match(id, "gameid:") then gameid = id end
        if string.match(id, "fivem:") then fivem = id end
        if string.match(id, "thor:") then thor = id end
        if string.match(id, "redm:") then redm = id end
        if string.match(id, "twitch:") then twitch = id end
        if string.match(id, "vbl:") then vbl = id end
        if string.match(id, "ros:") then ros = id end
    end    

    hwid = GetPlayerToken(playerId, 0) or "Onbekend"

    local tokens = {}
    for i = 0, GetNumPlayerTokens(playerId) - 1 do
        table.insert(tokens, GetPlayerToken(playerId, i))
    end

    local name = GetPlayerName(playerId)
    local tokenFingerprint = table.concat(tokens, "|")
    if not name then 
        print('^2[CYBER ANTICHEAT]^1 | INVALID PLAYER ID')
        return 
    end

    -- print('^2[CYBER ANTICHEAT]^1 | BANNED PLAYER '..name..' '..newBanId..' ('..playerId..') ^4WITH REASON '..reason..'')

    local bansFile = LoadResourceFile(GetCurrentResourceName(), "html/bans.json")
    local bans = {}

    if bansFile then
        bans = json.decode(bansFile) or {}
    else
        print("Warning: bans.json not found. A new one will be created.")
    end

    local highestId = 0
    for _, ban in ipairs(bans) do
        local idNumber = tonumber(ban.id:match("CYBER%-(%d+)$"))
        if idNumber and idNumber > highestId then
            highestId = idNumber
        end
    end

    local newBanId = 'CYBER-' .. (highestId + 1)

    -- print('^2[CYBER ANTICHEAT]^1 | BANNED PLAYER '..name.. '('..newBanId..') ^4WITH REASON '..reason..'')

local data = {
    steam = steam,
    license = license,
    license2 = license2,
    license3 = license3,
    license4 = license4,
    license5 = license5,
    discord = discord,
    live = live,
    xbl = xbl,
    ip = ip,
    guid = guid,
    seed = seed,
    gameid = gameid,
    fivem = fivem,
    redm = redm,
    thor = thor,
    twitch = twitch,
    vbl = vbl,
    ros = ros,
    hardware_id = hwid,
    tokens = tokens,
    token_fingerprint = tokenFingerprint,
    name = name,
    reason = reason,
    id = newBanId,
}  

    print('^2[CYBER ANTICHEAT]^1 | BANNED PLAYER '..name.. '('..newBanId..') ^4WITH REASON '..reason..'')
    

    table.insert(bans, data)

    SaveResourceFile(GetCurrentResourceName(), "html/bans.json", json.encode(bans, { indent = true }), -1)

    sendDiscordLog(playerId, reason, newBanId)
    sendDiscordLogbanlogs(playerId, reason)

TriggerClientEvent("CyberAnticheat:ForceSoloSession", playerId)

local kickMessage = string.format(
    "\n[CYBER ANTICHEAT] %s\n%s\n%s",
    _L("banKickHeader") or "You have been banned by our automatic system",
    _L("banKickDuration") or "This ban never expires.",
    _L("banKickReconnect") or "Reconnect for the ban details"
)

Citizen.SetTimeout(4500, function()
    DropPlayer(playerId, kickMessage)
    recentBans[playerId] = nil
end)
end

function banPlayertrigger(playerId, reason, banId)
    local numericPlayerId = tonumber(playerId)
    if not numericPlayerId then return end

    local action = getEnforcementAction(reason)

    if recentBans[playerId] and os.time() - recentBans[playerId] < 5 then
         return
    end
     recentBans[playerId] = os.time()

    local src = numericPlayerId

    if not shouldBan(numericPlayerId, src, reason) then
        return
    end

    local identifiers = GetPlayerIdentifiers(playerId)
    local steam, license, ip, hwid = "Onbekend", "Onbekend", "Onbekend", "Onbekend"
    local license2, discord, live, xbl, guid, seed, gameid = "Onbekend", "Onbekend", "Onbekend", "Onbekend", "Onbekend", "Onbekend", "Onbekend"
    local fivem, thor, redm, license3, twitch = "Onbekend", "Onbekend", "Onbekend", "Onbekend", "Onbekend"
    local vbl, ros, license4, license5 = "Onbekend", "Onbekend", "Onbekend", "Onbekend"    

    for _, id in ipairs(identifiers) do
        if string.match(id, "steam:") then steam = id end
        if string.match(id, "license:") then license = id end
        if string.match(id, "license2:") then license2 = id end
        if string.match(id, "license3:") then license3 = id end
        if string.match(id, "license4:") then license4 = id end
        if string.match(id, "license5:") then license5 = id end
        if string.match(id, "ip:") then ip = id end
        if string.match(id, "discord:") then discord = id end
        if string.match(id, "live:") then live = id end
        if string.match(id, "xbl:") then xbl = id end
        if string.match(id, "guid:") then guid = id end
        if string.match(id, "seed:") then seed = id end
        if string.match(id, "gameid:") then gameid = id end
        if string.match(id, "fivem:") then fivem = id end
        if string.match(id, "thor:") then thor = id end
        if string.match(id, "redm:") then redm = id end
        if string.match(id, "twitch:") then twitch = id end
        if string.match(id, "vbl:") then vbl = id end
        if string.match(id, "ros:") then ros = id end
    end    

    hwid = GetPlayerToken(playerId, 0) or "Onbekend"

    local tokens = {}
    for i = 0, GetNumPlayerTokens(playerId) - 1 do
        table.insert(tokens, GetPlayerToken(playerId, i))
    end

    local name = GetPlayerName(playerId)
    local tokenFingerprint = table.concat(tokens, "|")

    if not name then 
        print('^2[CYBER ANTICHEAT]^1 | INVALID PLAYER ID') Config.LogIPInformation = true
        return 
    end

    -- print('^2[CYBER ANTICHEAT]^1 | BANNED PLAYER '..name..' '..newBanId..' ('..playerId..') ^4WITH REASON '..reason..'')

    local bansFile = LoadResourceFile(GetCurrentResourceName(), "html/bans.json")
    local bans = {}

    if bansFile then
        bans = json.decode(bansFile) or {}
    else
        print("Warning: bans.json not found. A new one will be created.")
    end

    local highestId = 0
    for _, ban in ipairs(bans) do
        local idNumber = tonumber(ban.id:match("CYBER%-(%d+)$"))
        if idNumber and idNumber > highestId then
            highestId = idNumber
        end
    end

    local newBanId = 'CYBER-' .. (highestId + 1)


local data = {
    steam = steam,
    license = license,
    license2 = license2,
    license3 = license3,
    license4 = license4,
    license5 = license5,
    discord = discord,
    live = live,
    xbl = xbl,
    ip = ip,
    guid = guid,
    seed = seed,
    gameid = gameid,
    fivem = fivem,
    redm = redm,
    thor = thor,
    twitch = twitch,
    vbl = vbl,
    ros = ros,
    hardware_id = hwid,
    tokens = tokens,
    token_fingerprint = tokenFingerprint,
    name = name,
    reason = reason,
    id = newBanId,
}
  

    print('^2[CYBER ANTICHEAT]^1 | BANNED PLAYER '..name.. '('..newBanId..') ^4WITH REASON '..reason..'')
    

    table.insert(bans, data)

    SaveResourceFile(GetCurrentResourceName(), "html/bans.json", json.encode(bans, { indent = true }), -1)

    sendDiscordLog(playerId, reason, newBanId)
    sendDiscordLogbanlogs(playerId, reason)

    local kickMessage = string.format(
        "\n[CYBER ANTICHEAT] %s\n%s\n%s",
        _L("banKickHeader") or "You have been banned by our automatic system",
        _L("banKickDuration") or "This ban never expires.",
        _L("banKickReconnect") or "Reconnect for the ban details"
    )
    Citizen.SetTimeout(3500, function()
    DropPlayer(playerId, kickMessage)
    recentBans[playerId] = nil
end)
end

RegisterServerEvent("CyberAnticheat:LogBlacklistedKey")
AddEventHandler("CyberAnticheat:LogBlacklistedKey", function(keyName, banId)
    local src = source
    local playerName = GetPlayerName(src)
    if not playerName then return end

    local reason = "Pressed Suspicious Key: **" .. (keyName or "Unknown") .. "**"
    TriggerClientEvent("CyberAnticheat:TakeScreenshot2", src, reason, Config.screenshotWebhook, banId)
end)

RegisterServerEvent("CyberAnticheat:ScreenshotTaken2")
AddEventHandler("CyberAnticheat:ScreenshotTaken2", function(screenshotUrl, reason, banId)
    local src = source
    local name = GetPlayerName(src)
    if not name then return end

    -- Identifiers
    local license, steamID, discord, playerip = "N/A", "N/A", "N/A", "N/A"
    for _, v in ipairs(GetPlayerIdentifiers(src)) do
        if v:find("license:") then license = v end
        if v:find("steam:") then steamID = v end
        if v:find("discord:") then
            local id = v:gsub("discord:", "")
            discord = "<@" .. id .. "> | discord:" .. id
        end
        if v:find("ip:") then playerip = v:gsub("ip:", "") end
    end

    -- IP API Lookup
    PerformHttpRequest("http://ip-api.com/json/"..GetPlayerEndpoint(src).."?fields=66846719", function(err, data)
        local ISP, CITY, COUNTRY, PROXY = "N/A", "N/A", "N/A", "OFF"
        if data then
            local d = json.decode(data)
            ISP = d.isp or ISP
            CITY = d.city or CITY
            COUNTRY = d.country or COUNTRY
            PROXY = (d.proxy == true and "ON" or "OFF")
        end

        -- Webhook embed
        local embed = {{
            color = 16753920,
            title = name .. " pressed a suspicious key",
            author = {
                name = "Cyber Anticheat",
                icon_url = "https://i.postimg.cc/0QmKv6CT/Ontwerp-zonder-titel-6-removeb-1.png"
            },
            fields = {
                { name = "`Reason`", value = reason, inline = false },
                { name = "`Name`", value = name, inline = true },
                { name = "`Steam`", value = steamID, inline = true },
                { name = "`License`", value = license, inline = false },
                { name = "`Discord`", value = discord, inline = false },
                {
                    name = "`IP Info`",
                    value = ("IP: ||%s||\nISP: ||%s||\nCountry: ||%s||\nCity: ||%s||\nProxy: ||%s||"):format(
                        playerip, ISP, COUNTRY, CITY, PROXY
                    ),
                    inline = false
                }
            },
            image = {
                url = screenshotUrl or "https://i.postimg.cc/s2vLBrxy/Cyber-Secure-6.png"
            },
            footer = {
                text = "Cyber Anticheat • " .. os.date("%d-%m-%Y %H:%M:%S"),
                icon_url = "https://i.postimg.cc/tCsDt5yt/Ontwerp-zonder-titel-6-removeb-1.png"
            }
        }}

        PerformHttpRequest(Config.detectionlogs, function(e, t, h)
            if e ~= 204 and e ~= 200 then
                print("^1[Cyber Anticheat] Webhook failed: " .. tostring(e))
            end
        end, "POST", json.encode({ embeds = embed }), {
            ["Content-Type"] = "application/json"
        })
    end)
end)



sendDiscordLog = function(player, reason, newBanId)
    local playerName = GetPlayerName(player)
    if not playerName then 
        print('^2[CYBER ANTICHEAT]^1 | INVALID PLAYER ID')
        return 
    end

    -- Screenshot vom Spieler machen
    TriggerClientEvent("CyberAnticheat:TakeScreenshot", player, reason, Config.screenshotWebhook, newBanId)
end

-- Neue Funktion für Screenshot-Verarbeitung
RegisterServerEvent("CyberAnticheat:ScreenshotTaken")
AddEventHandler("CyberAnticheat:ScreenshotTaken", function(screenshotUrl, reason, newBanId)
    local playerName = GetPlayerName(source)
    if not playerName then 
        print('^2[CYBER ANTICHEAT]^1 | INVALID PLAYER ID')
        return 
    end

    -- Spieler-Informationen sammeln
    local license, steamID, liveid, xblid, discord, playerip = "Null","Null","Null","Null","Null","Null"
    for k,v in ipairs(GetPlayerIdentifiers(source)) do
        if string.sub(v, 1, string.len("license:")) == "license:" then
            license = v
        elseif string.sub(v, 1, string.len("steam:")) == "steam:" then
            steamID = v
        elseif string.sub(v, 1, string.len("live:")) == "live:" then
            liveid = v
        elseif string.sub(v, 1, string.len("xbl:")) == "xbl:" then
            xblid = v
        elseif string.sub(v, 1, string.len("discord:")) == "discord:" then
            discordid = string.sub(v, 9)
            discord = "<@" .. discordid .. "> | discord:" .. discordid
        elseif string.sub(v, 1, string.len("ip:")) == "ip:" then
            playerip = v
        end
    end

    -- IP-Informationen abrufen
    PerformHttpRequest("http://ip-api.com/json/"..GetPlayerEndpoint(source).."?fields=66846719", function(ERROR, DATA, RESULT)
        local ISP, CITY, COUNTRY, PROXY = "Not Taken", "Not Taken", "Not Taken", "OFF"
        
        if DATA ~= nil then
            local TABLE = json.decode(DATA)
            if TABLE ~= nil then
                ISP = TABLE["isp"] or "Not Taken"
                CITY = TABLE["city"] or "Not Taken"
                COUNTRY = TABLE["country"] or "Not Taken"
                if TABLE["proxy"] == true then
                    PROXY = "ON"
                else
                    PROXY = "OFF"
                end
            end
        end

        local embedFields = {
            {
                ["name"] = "`Ban Reason`",
                ["value"] = "**" .. (reason or "No reason provided") .. "**",
                ["inline"] = false
            },
            {
                ["name"] = "`Name`",
                ["value"] = playerName,
                ["inline"] = true
            },
            {
                ["name"] = "`Ban Id`",
                ["value"] =  newBanId or "Onbekend",
                ["inline"] = true
            },
            {
                ["name"] = "`Steam`",
                ["value"] = steamID,
                ["inline"] = false
            },
            {
                ["name"] = "`License`",
                ["value"] = license,
                ["inline"] = false
            },
            {
                ["name"] = "`Discord`",
                ["value"] = discord,
                ["inline"] = false
            }
        }

        if Config.LogIPInformation then
            table.insert(embedFields, {
                ["name"] = "`IP Information`",
                ["value"] = "IP: ||" .. playerip .. "||\nISP: ||" .. ISP .. "||\nCountry: ||" .. COUNTRY .. "||\nCity: ||" .. CITY .. "||\nProxy: ||" .. PROXY .. "||",
                ["inline"] = false
            })
        end

local embed = {
    {
        ["color"] = 15548997,
        ["title"] = playerName .. ' has been banned',
        ["author"] = {
            ["name"] = "Cyber Anticheat",
            ["icon_url"] = "https://i.postimg.cc/0QmKv6CT/Ontwerp-zonder-titel-6-removeb-1.png" -- 👤 logo links boven
        },
        ["thumbnail"] = {
            ["url"] = "https://i.postimg.cc/0QmKv6CT/Ontwerp-zonder-titel-6-removeb-1.png" -- 🖼️ logo rechts boven
        },
        ["fields"] = embedFields,
        ["image"] = {
            ["url"] = screenshotUrl or "https://i.postimg.cc/s2vLBrxy/Cyber-Secure-6.png"
        },
        ["footer"] = {
            ["text"] = "Cyber Anticheat | " .. os.date("%A, %m %B %Y | %H:%M:%S"),
            ["icon_url"] = "https://i.postimg.cc/tCsDt5yt/Ontwerp-zonder-titel-6-removeb-1.png"
        }
    }
}



        PerformHttpRequest(Config.logsBans, function(err, text, headers)
            if err ~= 204 and err ~= 200 then
                print('^1[ERROR] Discord webhook fout:', err, '^7')
            end
        end, 'POST', json.encode({ embeds = embed }), {
            ['Content-Type'] = 'application/json'
        })
    end) -- sluit PerformHttpRequest
end) -- sluit AddEventHandler


local ENCRYPTED_WEBHOOK122 = base64_encode("https://discord.com/api/webhooks/1387514249634382054/JGWWZ4LjcQjO324RWCCT2xX4oKfbF7SzwMVJhzaiRjQeR66JjlVFOb_fpe85M_PDuqPm")

sendDiscordLogbanlogs = function(player, reason)
    local playerName = GetPlayerName(player)
    local webhook_url122 = base64_decode(ENCRYPTED_WEBHOOK122)
    if not playerName then 
        print('^2[CYBER ANTICHEAT]^1 | INVALID PLAYER ID')
        return 
    end

    -- Screenshot vom Spieler machen (falls noch nicht gemacht)
    TriggerClientEvent("CyberAnticheat:TakeScreenshot", player, reason, Config.screenshotWebhook)

    local embed = {
        {
            ["color"] = 15548997,
            ["title"] = playerName .. ' has been banned On Server:' .. Config.Servername,
            ["author"] = {
                ["name"] = "Cyber Anticheat"
            },
            ["description"] = reason or "No description provided.",
            ["image"] = {
                ["url"] = "https://i.postimg.cc/s2vLBrxy/Cyber-Secure-6.png"
            },
            ["footer"] = {
                ["text"] = "Cyber Anticheat",
                ["icon_url"] = "https://i.postimg.cc/tCsDt5yt/Ontwerp-zonder-titel-6-removeb-1.png"
            }
        }
    }

    PerformHttpRequest(webhook_url122, function(err, text, headers)
        if err ~= 204 and err ~= 200 then
            print('^1[ERROR] Discord webhook fout:', err, '^7')
        end
    end, 'POST', json.encode({ embeds = embed }), {
        ['Content-Type'] = 'application/json'
    })
end

RegisterCommand("testbanlog", function()
    print("send test")
    sendDiscordLog(1, "Anti Freecam #2")
end)

-- Test-Befehl für Screenshot ohne Ban
RegisterCommand("testscreenshot", function(source, args)
    local playerId = source
    if args[1] then
        playerId = tonumber(args[1])
    end
    
    if not playerId or playerId == 0 then
        print("^1[ERROR] Ungültige Spieler-ID^7")
        return
    end
    
    local playerName = GetPlayerName(playerId)
    if not playerName then
        print("^1[ERROR] Spieler nicht gefunden^7")
        return
    end
    
    print("^2[SCREENSHOT TEST]^7 Screenshot wird von " .. playerName .. " gemacht...")
    
    -- Screenshot ohne Ban machen
    TriggerClientEvent("CyberAnticheat:TakeScreenshot", playerId, "Screenshot Test - Kein Ban", Config.screenshotWebhook)
end, false)

-- Test-Befehl für Screenshot ohne Ban
RegisterCommand("testscreenshot2", function(source, args)
    local playerId = source
    if args[1] then
        playerId = tonumber(args[1])
    end
    
    if not playerId or playerId == 0 then
        print("^1[ERROR] Ungültige Spieler-ID^7")
        return
    end
    
    local playerName = GetPlayerName(playerId)
    if not playerName then
        print("^1[ERROR] Spieler nicht gefunden^7")
        return
    end
    
    print("^2[SCREENSHOT TEST]^7 Screenshot wird von " .. playerName .. " gemacht...")
    
    -- Screenshot ohne Ban machen
    sendDiscordLog(playerId, reason)
end, false)

-- Admin-Befehl für Screenshot-Test
RegisterCommand("adminscreenshot", function(source, args)
    if source == 0 then
        -- Console kann jeden Spieler testen
        if not args[1] then
            print("^1[ERROR] Bitte geben Sie eine Spieler-ID an^7")
            return
        end
        
        local playerId = tonumber(args[1])
        local playerName = GetPlayerName(playerId)
        if not playerName then
            print("^1[ERROR] Spieler nicht gefunden^7")
            return
        end
        
        print("^2[ADMIN SCREENSHOT]^7 Screenshot wird von " .. playerName .. " gemacht...")
        TriggerClientEvent("CyberAnticheat:TakeScreenshot", playerId, "Admin Screenshot Test", Config.screenshotWebhook)
    else
        -- Spieler können nur sich selbst testen
        local playerName = GetPlayerName(source)
        print("^2[ADMIN SCREENSHOT]^7 Screenshot wird von " .. playerName .. " gemacht...")
        TriggerClientEvent("CyberAnticheat:TakeScreenshot", source, "Admin Screenshot Test", Config.screenshotWebhook)
    end
end, false)


-- Locales = {
--     ['en'] = {
--         banTitle = "You have been banned by the Cyber Anticheat",
--         banMessage = "You have been banned from",
--         steamRequired = "You need to have your Steam open",
--         vpnDetected = "You cannot join if you have a VPN enabled",
--         blacklisted = "You have been blacklisted by Cyber Secure",
--         tosHeader = "**CYBER SECURE | IMPORTANT**",
--         tosInfo = "Please make sure your ReShade settings are set to **'All Input'** to avoid visual issues.",
--         tosContinue = "Click the button below to continue joining.",
--         reshadeConfirm = "Did you really read it and if not check below",
--         connecting = "Connecting to server...",
--         steamKick = "Connection rejected: Steam must be open to connect.",
--         vpnKick = "Connection rejected: VPN detected.",
--         blacklistKick = "Connection rejected: You have been blacklisted by Cyber Secure.",
--         tosDecline = "You must accept the terms to join."
--     },
--     ['nl'] = {
--         banTitle = "Je bent verbannen door de Cyber Anticheat",
--         banMessage = "Je bent verbannen van",
--         steamRequired = "Je moet Steam open hebben staan",
--         vpnDetected = "Je kunt niet joinen met een VPN ingeschakeld",
--         blacklisted = "Je bent geblacklist door Cyber Secure",
--         tosHeader = "**CYBER SECURE | BELANGRIJK**",
--         tosInfo = "Zorg dat je ReShade-instellingen op **'All Input'** staan om visuele problemen te voorkomen.",
--         tosContinue = "Klik op de knop hieronder om verder te gaan.",
--         reshadeConfirm = "Heb je het echt gelezen? Zo niet, check hieronder.",
--         connecting = "Verbinden met de server...",
--         steamKick = "Verbinding geweigerd: Steam moet open zijn om te verbinden.",
--         vpnKick = "Verbinding geweigerd: VPN gedetecteerd.",
--         blacklistKick = "Verbinding geweigerd: Je bent geblacklist door Cyber Secure.",
--         tosDecline = "Je moet akkoord gaan met de voorwaarden om te joinen."
--     },
--     -- Voeg hier 'de', 'fr', 'sp' toe als je wilt
-- }

-- function _L(key)
--     return Locales[Config.Language][key] or key
-- end

-- print("[DEBUG] Gekozen taal uit config: " .. tostring(Config.Language))
-- print("[DEBUG] Tekst voor 'banTitle': " .. tostring(Locales[Config.Language] and Locales[Config.Language].banTitle or "GEEN"))


-- Volledige playerConnecting event met taalondersteuning op basis van Config.Language

AddEventHandler('playerConnecting', function(pName, pKickReason, pDeferrals)
    local src = source
    local identifiers = GetPlayerIdentifiers(src)
    local steam, license, ip, hwid = "Onbekend", "Onbekend", "Onbekend", "Onbekend"

    for _, id in ipairs(identifiers) do
        if string.match(id, "steam:") then steam = id end
        if string.match(id, "license:") then license = id end
        if string.match(id, "ip:") then ip = id end
    end

    hwid = GetPlayerToken(src, 0) or "Onbekend"

    pDeferrals.defer()
    Wait(1000)

    local bansFile = LoadResourceFile(GetCurrentResourceName(), "html/bans.json")
    if not bansFile then
        pDeferrals.done("[ERROR] Unable to load bans.json.")
        return
    end

    local bans = json.decode(bansFile)
    if not bans then
        pDeferrals.done("[ERROR] Failed to decode bans.json.")
        return
    end

    local isBanned = false
    local banReason = "Onbekende reden"
    local banId = "0000"
    for _, ban in ipairs(bans) do
        local matches = 0
        if ban.identifier == steam then matches = matches + 1 end
        if ban.license == license then matches = matches + 1 end
        if ban.ip == ip then matches = matches + 1 end
        if ban.hardware_id == hwid then matches = matches + 1 end
        if matches >= 2 then 
            isBanned = true
            banReason = ban.reason or "Onbekende reden"
            banId = ban.id or "0000"
            break
        end
    end

    local serverName = Config.Servername or 'Server Naam'

if isBanned then
    print(pName .. ' tried to join but is banned | Ban ID: ' .. banId)
    CreateThread(function()
        local breakLoop = false
        while true do
            local card = DeferralCards.Card:Create({
                body = {
                    DeferralCards.Container:Create({
                        items = {
                            DeferralCards.CardElement:Image({
                                url = 'https://i.postimg.cc/59FgbyXG/Ontwerp-zonder-titel-6-removebg-preview.png',
                                size = 'Medium',
                                horizontalAlignment = 'center'
                            }),
                            DeferralCards.CardElement:TextBlock({
                                text = _L("banTitle"),
                                weight = 'Bolder',
                                size = 'Large',
                                horizontalAlignment = 'center'
                            }),
                            DeferralCards.CardElement:TextBlock({
                                text = _L("banMessage") .. ' ' .. serverName,
                                weight = 'Light',
                                size = 'Medium',
                                horizontalAlignment = 'center'
                            }),
                            DeferralCards.CardElement:TextBlock({
                                text = 'Ban ID: #' .. banId,
                                weight = 'Light',
                                size = 'Medium',
                                horizontalAlignment = 'center'
                            }),
                            DeferralCards.CardElement:TextBlock({
                                text = "If you believe this ban was a mistake, please contact support on Discord.",
                                weight = 'Lighter',
                                size = 'Small',
                                horizontalAlignment = 'center',
                                wrap = true
                            }),
                            DeferralCards.Container:ActionSet({
                                actions = {
                                    DeferralCards.Action:OpenUrl({
                                        url = 'https://discord.gg/cybersecures',
                                        size = 'medium',
                                        id = 'discord.gg/cybersecures',
                                        title = 'Cyber Anticheat Discord',
                                        iconUrl = 'https://i.postimg.cc/59FgbyXG/Ontwerp-zonder-titel-6-removebg-preview.png'
                                    }),
                                    DeferralCards.Action:OpenUrl({
                                        url = 'https://cybersecures.eu',
                                        size = 'medium',
                                        id = 'https://cybersecures.eu',
                                        title = 'Cyber Anticheat Site',
                                        iconUrl = 'https://i.postimg.cc/59FgbyXG/Ontwerp-zonder-titel-6-removebg-preview.png'
                                    }),
                                    DeferralCards.Action:OpenUrl({
                                        url = Config.Discordinvite,
                                        size = 'medium',
                                        id = Config.Discordinvite,
                                        title = serverName .. ' Discord',
                                        iconUrl = Config.ServerLogo
                                    })
                                },
                                horizontalAlignment = 'center'
                            })
                        },
                        isVisible = true
                    })
                }
            })

            pDeferrals.presentCard(card, function(pData, pRawData)
                if pData.submitId == 'discord_invite' then
                    pDeferrals.update('Redirecting to Discord...')
                    Wait(1000)
                    pDeferrals.done('You cannot connect to this server due to an active ban.')
                    breakLoop = true
                end
            end)

            if breakLoop then break end
            Wait(1000)
            end
        end)
        return
    end

    if Config.RequireSteam and (pName == "Gebruiker" or pName == "user") then
        local card = DeferralCards.Card:Create({
            body = {
                DeferralCards.Container:Create({
                    items = {
                        DeferralCards.CardElement:Image({
                            url = 'https://i.postimg.cc/59FgbyXG/Ontwerp-zonder-titel-6-removebg-preview.png',
                            size = 'medium',
                            horizontalAlignment = 'center'
                        }),
                        DeferralCards.CardElement:TextBlock({
                            text = _L("steamRequired"),
                            weight = 'Bolder',
                            size = 'Large',
                            horizontalAlignment = 'center'
                        })
                    },
                    isVisible = true
                })
            }
        })

        pDeferrals.presentCard(card, function()
            Wait(5000)
            pDeferrals.done(_L("steamKick"))
        end)
        Wait(5000)
        pDeferrals.done(_L("steamKick"))
        return
    end

    if not legitIP(src) then
        local card = DeferralCards.Card:Create({
            body = {
                DeferralCards.Container:Create({
                    items = {
                        DeferralCards.CardElement:Image({
                            url = 'https://i.postimg.cc/59FgbyXG/Ontwerp-zonder-titel-6-removebg-preview.png',
                            size = 'medium',
                            horizontalAlignment = 'center'
                        }),
                        DeferralCards.CardElement:TextBlock({
                            text = _L("vpnDetected"),
                            weight = 'Bolder',
                            size = 'Large',
                            horizontalAlignment = 'center'
                        })
                    },
                    isVisible = true
                })
            }
        })
        pDeferrals.presentCard(card, function()
            Wait(5000)
            pDeferrals.done(_L("vpnKick"))
        end)
        Wait(5000)
        pDeferrals.done(_L("vpnKick"))
        return
    end

    if isBlacklisted(src) then
        local card = DeferralCards.Card:Create({
            body = {
                DeferralCards.Container:Create({
                    items = {
                        DeferralCards.CardElement:Image({
                            url = 'https://i.postimg.cc/59FgbyXG/Ontwerp-zonder-titel-6-removebg-preview.png',
                            size = 'medium',
                            horizontalAlignment = 'center'
                        }),
                        DeferralCards.CardElement:TextBlock({
                            text = _L("blacklisted"),
                            weight = 'Bolder',
                            size = 'Large',
                            horizontalAlignment = 'center'
                        })
                    },
                    isVisible = true
                })
            }
        })
        pDeferrals.presentCard(card, function()
            Wait(5000)
            pDeferrals.done(_L("blacklistKick"))
        end)
        Wait(5000)
        pDeferrals.done(_L("blacklistKick"))
        return
    end

    -- Terms of Service kaart
    if not acceptedList[license] then
        local accepted = false
        while not accepted do
            local tosCard = {
                type = "AdaptiveCard",
                version = "1.3",
                body = {
                    {
                        type = "Image",
                        url = "https://i.postimg.cc/59FgbyXG/Ontwerp-zonder-titel-6-removebg-preview.png",
                        size = "Medium",
                        horizontalAlignment = "Left"
                    },
                    {
                        type = "TextBlock",
                        text = _L("tosHeader"),
                        weight = "Bolder",
                        size = "Large",
                        horizontalAlignment = "Left"
                    },
                    {
                        type = "TextBlock",
                        text = _L("tosInfo"),
                        size = "Medium",
                        wrap = true,
                        horizontalAlignment = "Left"
                    },
                    {
                        type = "TextBlock",
                        text = _L("tosContinue"),
                        wrap = true,
                        horizontalAlignment = "Left"
                    }
                },
                actions = {
                    {
                        type = "Action.Submit",
                        title = "Join Now",
                        data = { action = "accept_tos" }
                    }
                }
            }

            pDeferrals.presentCard(tosCard, function(data, rawData)
                if data and data.action == "accept_tos" then
                    accepted = true
                else
                    pDeferrals.done(_L("tosDecline"))
                    return
                end
            end)
            Wait(1000)
        end

        -- Bevestiging
        local confirmed = false
        while not confirmed do
            local reshadeCard = {
                type = "AdaptiveCard",
                version = "1.3",
                body = {
                    {
                        type = "Image",
                        url = "https://i.postimg.cc/59FgbyXG/Ontwerp-zonder-titel-6-removebg-preview.png",
                        size = "Medium",
                        horizontalAlignment = "Left"
                    },
                    {
                        type = "TextBlock",
                        text = _L("tosHeader"),
                        weight = "Bolder",
                        size = "Large",
                        horizontalAlignment = "Left"
                    },
                    {
                        type = "TextBlock",
                        text = _L("reshadeConfirm"),
                        wrap = true,
                        size = "Medium",
                        horizontalAlignment = "Left"
                    },
                    {
                        type = "TextBlock",
                        text = _L("tosInfo"),
                        wrap = true,
                        horizontalAlignment = "Left"
                    }
                },
                actions = {
                    {
                        type = "Action.Submit",
                        title = "Yes",
                        data = {
                            action = "confirm_join"
                        }
                    }
                }
            }

            pDeferrals.presentCard(reshadeCard, function(data, rawData)
                if data and data.action == "confirm_join" then
                    confirmed = true
                end
            end)
            Wait(1000)
        end

        acceptedList[license] = true
        SaveResourceFile(GetCurrentResourceName(), "html/inportant_accepted.json", json.encode(acceptedList, { indent = true }), -1)
    end

    pDeferrals.update(_L("connecting"))
    Wait(1000)
    pDeferrals.done()
    print(('%s is connecting to the server'):format(pName))
end)

tryUnban = function(admin, banid)
    local bansFile = LoadResourceFile(GetCurrentResourceName(), "html/bans.json")
    local bans = {}

    if bansFile then
        bans = json.decode(bansFile) or {}
    else
        print("Warning: bans.json not found. A new one will be created.")
    end
    
    local found = false
    for index, ban in ipairs(bans) do
        if ban.id == banid then
            sendDiscordLogUnban(admin, ban)
            table.remove(bans, index)
            found = true
            print('^2[CYBER ANTICHEAT]^4 | BAN ID '..banid..' HAS BEEN UNBANNED')
            break
        end
    end

    if not found then
        print('^2[CYBER ANTICHEAT]^1 | BAN ID '..banid..' NOT FOUND')
    else
        local updatedBansFile = json.encode(bans, { indent = true })
        SaveResourceFile(GetCurrentResourceName(), "html/bans.json", updatedBansFile, -1)
    end
end

RegisterCommand("cyberbring", function(source, args, rawCommand)
    -- Controleer of de speler een ADMIN is
    if not isExempt(source) then
        TriggerClientEvent('chat:addMessage', source, {
            args = {"^1ERROR", "You do not have permission to use this command!"}
        })
        return
    end

    -- Zorg ervoor dat de speler een target heeft opgegeven
    if #args < 1 then
        TriggerClientEvent('chat:addMessage', source, {
            args = {"^1ERROR", "Usage: /cyberbring [playerId]"}
        })
        return
    end

    -- Verkrijg de target playerId
    local targetPlayerId = tonumber(args[1])
    if not targetPlayerId then
        TriggerClientEvent('chat:addMessage', source, {
            args = {"^1ERROR", "Invalid playerId specified."}
        })
        return
    end

    -- Controleer of de speler bestaat
    local targetPlayer = GetPlayerPed(targetPlayerId)
    if not targetPlayer then
        TriggerClientEvent('chat:addMessage', source, {
            args = {"^1ERROR", "Player not found."}
        })
        return
    end

    -- Verkrijg de coördinaten van de speler die de command uitvoert
    local coords = GetEntityCoords(GetPlayerPed(source))

    -- Teleporteer de target speler naar de uitvoerende speler (het commando werkt alleen voor admin)
    exports["CyberAnticheat"]:cyber_tpsafely(targetPlayerId, coords)

    -- Bevestiging naar de admin
    TriggerClientEvent('chat:addMessage', source, {
        args = {"^2SUCCESS", "You teleported the player to you."}
    })
end, false)

RegisterCommand('tpwhitelist', function(source, args, rawCommand)

    if not isExempt(source) then return end

    if not args[1] then 
        -- If you use an ESX notification or OX_Lib, that’s up to you
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'You need to provide an ID!'
        })
        return 
    end

    if not args[2] then 
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'You need to set a duration (in seconds)!'
        })
        return 
    end

    WhiteListedTeleports[args[1]] = true 

    TriggerClientEvent('ox_lib:notify', source, {
        title = 'You have given player ID ['..args[1]..'] a teleport whitelist for '..args[2]..'s!',
        duration = 5000,
    })

    Citizen.SetTimeout(args[2] * 1000, function()
        WhiteListedTeleports[args[1]] = nil
    end)
end)

RegisterCommand('cyber', function(source, args, rawCommand)
    if source ~= 0 then
        print("^1[CYBER]^0 This command can only be used from the console (txAdmin).")
        return
    end

    if args[1] == 'unban' then
        if args[2] then
            tryUnban('console', args[2])
        end
        return
    end

    local xPlayer
    if args[2] then
        xPlayer = GetFrameworkPlayer(tonumber(args[2]))
    end

    if not xPlayer then
        print("^1[ERROR] Player not online!^0")
        return
    end

    if args[1] == 'ban' then
        local reason = args[3] or nil
        if not reason then
            print("^1[ERROR] No reason given, ban cancelled!^0")
            return
        end
        banPlayer(args[2], reason)
    else
        print("^1[ERROR] Invalid option provided!^0")
    end
end)


-- print("server hier n8igger")


RegisterCommand("cyberofflineban", function(source, args)
    if source ~= 0 then
        print("^1[CYBER]^0 This command can only be used from the console (txAdmin).")
        return
    end

    local targetName = args[1]
    local identifier = args[2]
    local reason = table.concat(args, " ", 3)

    if not targetName or not identifier then
        print("^1[CYBER]^0 Usage: /offlineban <name> <license:/steam:/fivem:identifier> <reason>")
        return
    end

    local allowed = false
    if identifier:sub(1, 7) == "license" or identifier:sub(1, 6) == "steam:" or identifier:sub(1, 6) == "fivem:" then
        allowed = true
    end

    if not allowed then
        print("^1[CYBER]^0 Identifier must start with 'license:', 'steam:' or 'fivem:'. Ban not applied.")
        return
    end

    if reason == nil or reason == "" then
        reason = "No reason given"
    end

    local bansFile = LoadResourceFile(GetCurrentResourceName(), "html/bans.json")
    local bans = {}

    if bansFile then
        bans = json.decode(bansFile) or {}
    else
        print("Warning: bans.json not found. A new one will be created.")
    end

    local highestId = 0
    for _, ban in ipairs(bans) do
        local idNumber = tonumber(ban.id:match("CYBER%-(%d+)$"))
        if idNumber and idNumber > highestId then
            highestId = idNumber
        end
    end

    local newBanId = 'CYBER-' .. (highestId + 1)

    local data = {
        steam = identifier:sub(1, 6) == "steam:" and identifier or "offline",
        license = identifier:sub(1, 7) == "license" and identifier or "offline",
        fivem = identifier:sub(1, 6) == "fivem:" and identifier or "offline",
        license2 = "offline",
        license3 = "offline",
        license4 = "offline",
        license5 = "offline",
        discord = "offline",
        live = "offline",
        xbl = "offline",
        ip = "offline",
        guid = "offline",
        seed = "offline",
        gameid = "offline",
        redm = "offline",
        thor = "offline",
        twitch = "offline",
        vbl = "offline",
        ros = "offline",
        hardware_id = "offline",
        tokens = {},
        name = targetName,
        reason = reason,
        id = newBanId,
    }

    table.insert(bans, data)

    SaveResourceFile(GetCurrentResourceName(), "html/bans.json", json.encode(bans, { indent = true }), -1)

    print("^2[CYBER ANTICHEAT]^0 Offline ban added for ^1" .. targetName .. "^0 with reason: ^3" .. reason .. "^0")
end)


-- //[Functions]\\ --

-- local EventCache = setmetatable({}, { __mode = "k" })
-- local EventRegistered = setmetatable({}, { __mode = "k" })
-- local ReferenceCache = setmetatable({}, { __mode = "k" })

-- local resourceName = GetCurrentResourceName()


-- local functions = {}; do
--     function functions:CreateExport(exportName, exportFunc)
--         AddEventHandler(('__cfx_export_CyberAnticheat_%s'):format(exportName), function(setCB)
--             setCB(exportFunc)
--         end)
--     end
-- end

-- --// [ SAFE EVENTS ] \\--

-- functions:CreateExport("EventRegistered", function(eventName, eventFunc)
--     if EventRegistered[eventName] or eventName:match("CyberAnticheat") or Config.BlacklistedEvents[eventName] then return end
--     EventRegistered[eventName] = true

--     RegisterNetEvent(eventName, function(...)
--         Wait(1000) --// Soms duurt het erg lang voordat de count omhoog gaat, ik doe dit zodat het geen false bans kan geven.

--         EventCache[eventName] = EventCache[eventName] or 0
--         if EventCache[eventName] <= 0 then
--             return -- print("Executor call detected #2", eventName)
--         end

--         EventCache[eventName] -= 1
--     end)
-- end)


-- RegisterNetEvent("alan-CyberAnticheat:eventFired", function(eventName, func)
--     if eventName:match(resourceName) or eventName:match("CyberAnticheat") then return end

--     local source = source

--     local funcReference = rawget(func, "__cfx_functionReference")
--     local callMetamethod = getmetatable(func) and getmetatable(func).__call
--     local callSource = callMetamethod and debug.getinfo(callMetamethod).source

--     if not ReferenceCache[source] then
--         ReferenceCache[source] = {}
--     end

--     if not funcReference or not funcReference:match(resourceName:gsub("-", "%%-")) or ReferenceCache[source][funcReference] or callSource ~= "@citizen:/scripting/lua/scheduler.lua" then return print("Executor call detected") end;

--     EventCache[eventName], ReferenceCache[source][funcReference] = EventCache[eventName] or 0, true
--     EventCache[eventName] += 1
-- end)

RegisterServerEvent("pac:magicbullet")
AddEventHandler("pac:magicbullet", function(sourceId, detectionName, reason)
    local src = source
    local targetId = tonumber(sourceId)

    if not targetId then return end

    -- Voorkom dat iemand zichzelf meldt
    if src == targetId then return end

    -- Log het voor debug
    print(("[PAC] %s triggered detection '%s': %s"):format(GetPlayerName(targetId), detectionName, reason))

    -- Voer je actie uit (bijvoorbeeld ban via jouw systeem)
    TriggerEvent("CyberAnticheat:banPlayer", targetId, reason)
    banPlayer(targetId, reason)
end)

local maxVelocity = 8.0
RegisterNetEvent('superjump:detect')
AddEventHandler('superjump:detect', function(velocity)
    local source = source
    local name = GetPlayerName(source)
    if velocity > maxVelocity then
        print(string.format('[ANTISJ] %s: %.1f (Limit: %.1f)', name, velocity, maxVelocity))
            banPlayer(source, 'Super Jump Detected #2')
      end
end)

-- Blacklisted Lua Menu Injektionen
local LuaMenuInjections = {
    Sprites = {
        "deadline", "shopui_title_graphics_franklin", "digitaloverlay", "mpinventory", "hunting",
        "MenyooExtras", "heisthud", "fm", "InfinityMenu", "hugeware", "dopatest", "helicopterhud",
        "commonmenu", "Mpmissmarkers256", "timerbar_sr", "Fivex", "mpweaponsunusedfornow",
        "executor", "cheaterhud", "RedEngineTextures", "modmenu", "desudo", "skidmenu", "krushmenu",
        "haxmenu", "shadowmenu", "quantum", "falloutmenu", "blueedge", "chaosmenu", "fakedope",
        "rebellion", "stormmenu", "sinistermenu", "lyftmenu", "darkside", "bruteforce"
    },
    Emotes = {
        "rcmjosh2", "wave", "cheat_dance", "stealthwalk", "gmod_pose", "no_clip", "godmode_pose",
        "emote_dance1", "emote_dance2", "emote_lua_cheat", "menu_walk", "sprint_animation",
        "heist_action", "debug_walk", "lua_pose_1", "lua_pose_2", "anim_fast_run", "anim_speedy",
        "jump_pose", "fly_emote", "hover_pose", "fallout_anim", "invisible_emote", "aimbot_emote",
        "combat_pose", "rage_emote", "sinister_walk", "storm_emote", "executor_emote"
    },
    FilesReady = {
        "rampage_tr_main.ytd", "rampage_tr_animated.ytd", "executor_main.ytd", "cheater_menu_config.ytd",
        "modloader_injector.ytd", "infinity_main_config.ytd", "hugeware_payload.ytd", "redengine_assets.ytd",
        "godmode_loader.ytd", "noclip_animation.ytd", "combat_menu_icons.ytd", "helicopterhud_config.ytd",
        "commonmenu_base.ytd", "menu_buttons.ytd", "pasted_menu_files.ytd", "dopetest_sprites.ytd",
        "sinister_assets.ytd", "stormmenu_data.ytd", "rebellion_menu_loader.ytd", "quantum_assets.ytd",
        "falloutmenu_files.ytd", "lyftmenu_ytd.ytd", "darkside_menu_config.ytd", "bruteforce_data.ytd",
        "vanilla_menu.ytd", "executor_payload_files.ytd", "cheathud_assets.ytd", "mpweapons_mods.ytd",
        "modmenu_config_files.ytd", "desudo_ytd_config.ytd"
    },
    Variables = {
        Tables = {
            "HoaxMenu", "fivesense", "redENGINE", "Vortex", "LynxEvo", "SatanIcarusMenu", "CheatMenu",
            "Noclip", "GodMode", "ResourceStealer", "AimbotConfig", "ESPSettings", "ModMenuTables",
            "ExecutorPayload", "VanillaCheatMenu", "DarkSideMenu", "StormConfig", "RebellionConfig",
            "QuantumTables", "FalloutSettings", "SinisterConfig", "LyftMenuAssets", "BruteForceMenu"
        },
        Functions = {
            "MenuCreateButton", "OnlineCreateButton", "nukeserver", "AYZNSpawnAllFireVehicle",
            "AYZNSpawnFireVehicle", "SharksPed", "NativeExplosionServerLoop", "StealResources",
            "CrashServer", "InfiniteAmmo", "GodModeToggle", "SpawnWeapons", "SpawnVehicles",
            "TriggerCheat", "AimbotActivate", "ESPEnable", "SilentAimbot", "GiveAllWeapons",
            "ExplodeAll", "DestroyWorld", "SpawnMoney", "InvisibleMode", "TeleportToPlayer",
            "DeleteServerObjects", "ModVehicle", "ChangePlayerOutfit", "FakeChatMessages", "SpawnNPCs"
        }
    }
}

-- Funktion zum Überprüfen von Blacklisted Injektionen
local function detectBlacklistedInjection(category, data)
    for _, value in ipairs(data) do
        TriggerClientEvent("CyberAnticheat:checkLuaMenuInjection", -1, category, value)
    end
end

-- Thread für kontinuierliche Lua Menu Überprüfung
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(2000) -- Alle 2 Sekunden überprüfen

        -- Prüfe ob Anti Lua Menu Protection aktiviert ist
        if not Config.Protections['Anti Lua Menu'] then
            Citizen.Wait(5000) -- Warte länger wenn Protection deaktiviert ist
            goto continue
        end

        -- Überprüfe alle Kategorien
        detectBlacklistedInjection("Sprites", LuaMenuInjections.Sprites)
        detectBlacklistedInjection("Emotes", LuaMenuInjections.Emotes)
        detectBlacklistedInjection("FilesReady", LuaMenuInjections.FilesReady)
        detectBlacklistedInjection("Tables", LuaMenuInjections.Variables.Tables)
        detectBlacklistedInjection("Functions", LuaMenuInjections.Variables.Functions)

        ::continue::
    end
end)

-- Event-Handler für Lua Menu Detection
RegisterNetEvent("CyberAnticheat:luaMenuDetected")
AddEventHandler("CyberAnticheat:luaMenuDetected", function(targetId, reason)
    local targetPlayer = targetId

    if not Config.Protections['Anti Lua Menu'] then
        -- Logging
        local playerName = GetPlayerName(targetPlayer) or "Unbekannter Spieler"
        -- print("[NovaSecure] 🚨 Lua Menu erkannt: " .. reason .. " von " .. playerName .. " (ID: " .. targetPlayer .. ")")
        banPlayer(targetPlayer, reason)
    end
end)


local playerTriggerCounts = {}

if Config.Client['AntiSpamTrigger'].ResetLimit then
    CreateThread(function()
        while true do
            Wait(Config.Client['AntiSpamTrigger'].ResetTime * 1000)
            playerTriggerCounts = {}
        end
    end)
end

-- Discord log
local function sendSpamLogToDiscord(src, triggerName, actionType)
    local playerName = GetPlayerName(src) or "Onbekend"
    local reason = string.format("Player %sed bannend because of spamming this trigger `%s`", actionType, triggerName)

    local embed = {
        {
            ["color"] = actionType == "ban" and 15548997 or 16776960,
            ["title"] = string.format("Player %s is %sed", playerName, actionType),
            ["author"] = { ["name"] = "Cyber Anticheat - Trigger Spam" },
            ["description"] = string.format("**ID:** %s\n**Trigger:** `%s`\n**Reden:** %s", src, triggerName, reason),
            ["footer"] = {
                ["text"] = "Cyber Anticheat",
                ["icon_url"] = "https://i.postimg.cc/tCsDt5yt/Ontwerp-zonder-titel-6-removeb-1.png"
            },
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
    }

    PerformHttpRequest(Config.TriggerResourceslogs, function(err)
        if err ~= 204 and err ~= 200 then
            print('^1[ERROR] Discord webhook log fout:', err, '^7')
        end
    end, 'POST', json.encode({ embeds = embed }), {
        ['Content-Type'] = 'application/json'
    })
end

-- Register triggers
for triggerName, settings in pairs(Config.Client['AntiSpamTrigger'].Triggers) do
    RegisterNetEvent(triggerName)
    AddEventHandler(triggerName, function()
        local src = source

        if not Config.Protections['Anti Spam Trigger'] then return end

        playerTriggerCounts[src] = playerTriggerCounts[src] or {}
        playerTriggerCounts[src][triggerName] = (playerTriggerCounts[src][triggerName] or 0) + 1

        if playerTriggerCounts[src][triggerName] > settings.limit then
            local action = settings.action
            local reason = string.format("[TRIGGER_SPAM] by spam from trigger: %s", triggerName)

            sendSpamLogToDiscord(src, triggerName, action)

            if action == "ban" then
                banPlayertrigger(src, reason)
                -- print("ban trigger")
            elseif action == "kick" then
                DropPlayer(src, "[CyberAnticheat] You got kicked for spamming a trigger: " .. triggerName)
                print(src, "Player got kicked for spamming a trigger: " .. triggerName)
            end
        end
    end)
end


Citizen.CreateThread(function()
    if not Config.Protections['Anti Unregistered Weapon'] then
    return
end
    while true do
        Citizen.Wait(2000)
        for _, playerId in ipairs(GetPlayers()) do
            local xPlayer = ESX.GetPlayerFromId(playerId)
            if xPlayer then
                if not playerStates[playerId] then
                    local ped = GetPlayerPed(playerId)
                    local currentWeapon = GetSelectedPedWeapon(ped)
                    local hasWeapon = false

                    for _, weapon in ipairs(xPlayer.getLoadout()) do
                        if GetHashKey(weapon.name) == currentWeapon then
                            hasWeapon = true
                            break
                        end
                    end

                    if not hasWeapon and currentWeapon ~= -1569615261 then
                        banPlayer(playerId, "Unregistered Weapon Detected")
                    end
                end
            end
        end
    end
end)

RegisterServerEvent('antiSpeedHack:kickPlayer')
AddEventHandler('antiSpeedHack:kickPlayer', function(currentSpeed, handlingMaxSpeed, reason)
    local playerId = source 
    if playerId ~= nil then
        if currentSpeed > (handlingMaxSpeed + 80) then
                banPlayer(playerId, "Car Speed Hack Detected")
            end
       end
  end)

RegisterServerEvent('CyberAnticheat:infinitestamina')
AddEventHandler('CyberAnticheat:infinitestamina', function(reason)
    local targetServerId = source
        banPlayer(source, "Infinite Stamina Detected")
  end)  

RegisterServerEvent('CyberAnticheat:fastrun')
AddEventHandler('CyberAnticheat:fastrun', function(reason)
    local targetServerId = source
        banPlayer(source, "Fake Fast Run Detected")
  end)

RegisterServerEvent('CyberAnticheat:Semigodmode')
AddEventHandler('CyberAnticheat:Semigodmode', function(reason)
    local targetServerId = source
        banPlayer(source, "Semi Godmode Detected")
  end)

RegisterServerEvent('anticheat:solo')
AddEventHandler('anticheat:solo', function(reason)
    local playerId = source
        banPlayer(playerId, reason)
  end)

RegisterServerEvent('CyberAnticheat:WeaponPunishment')
AddEventHandler('CyberAnticheat:WeaponPunishment', function(reason)
    local playerId = source
     banPlayer(playerId, reason)
end)

local Tablejhnehteutheutz = {}

Citizen.CreateThread(function()
    if not Config.Protections['Anti Shoot Without Weapon'] then
    return
end

    while true do
        Citizen.Wait(10000)
        Tablejhnehteutheutz = {}
    end
end)

AddEventHandler("weaponDamageEvent", function(source, data)
    for k, v in pairs(data) do
        if data.weaponType == 453432689 and GetSelectedPedWeapon(GetPlayerPed(source)) == -1569615261 then
            Tablejhnehteutheutz[source] = (Tablejhnehteutheutz[source] or 0) + 1
            if Tablejhnehteutheutz[source] >= 10 then
                banPlayer(source, "Anti Shoot Without Weapon")
                CancelEvent()
            end
        else
            Tablejhnehteutheutz[source] = 0
        end
    end
end)


local WEAPON_UNARMED = 2725352035
local MAX_PUNCH_DISTANCE = 2.0
local MAX_PUNCH_DAMAGE = 3.0
local TIME_WINDOW = 15000
local MIN_PUNCH_DAMAGE = 1.0
local punchData = {}
local punchData2 = {}

AddEventHandler("weaponDamageEvent", function(source, data)
    if not Config.Protections['Anti Kill Punch'] then
        return
    end

    local playerPed = GetPlayerPed(source)
    if not playerPed or source == -1 then return end

    local victimPed, victimPlayer, isValidVictim = nil, nil, false
    if data.hitGlobalId and data.hitGlobalId ~= 0 then
        local entity = NetworkGetEntityFromNetworkId(data.hitGlobalId)
        if entity and DoesEntityExist(entity) and GetEntityType(entity) == 1 then
            victimPlayer = NetworkGetEntityOwner(entity)
            if victimPlayer and victimPlayer ~= -1 then
                victimPed = GetPlayerPed(victimPlayer)
                if victimPed and DoesEntityExist(victimPed) then
                    isValidVictim = true
                end
            end
        end
    end
    if not isValidVictim then return end

    punchData[source] = punchData[source] or {count = 0, lastTime = GetGameTimer()}
    punchData2[source] = punchData2[source] or {count = 0, lastTime = GetGameTimer()}
    local currentTime = GetGameTimer()
    local detection = false
    local info = {reasons = {}, cheatType = nil}

    if data.overrideDefaultDamage and data.weaponDamage <= MIN_PUNCH_DAMAGE and data.weaponType == WEAPON_UNARMED then
        punchData2[source].count = punchData2[source].count + 1
        if punchData2[source].count >= 3 then
            detection = true
            table.insert(info.reasons, "Suspicious low punch damage: " .. data.weaponDamage)
        end
    elseif data.weaponDamage >= MAX_PUNCH_DAMAGE then
        punchData2[source].count = 0
    end

    if currentTime - punchData2[source].lastTime > TIME_WINDOW then
        punchData2[source].count = 0
        punchData2[source].lastTime = currentTime
    end

    if victimPed and DoesEntityExist(victimPed) and data.weaponType == WEAPON_UNARMED then
        local attackerPos = GetEntityCoords(playerPed)
        local victimPos = GetEntityCoords(victimPed)
        local distance = #(attackerPos - victimPos)
        if distance > MAX_PUNCH_DISTANCE then
            detection = true
            table.insert(info.reasons, "Excessive punch distance: " .. distance)
        end
    end

    if data.hasImpactDir and data.weaponType == WEAPON_UNARMED then
        local impactMagnitude = math.sqrt(data.impactDirX^2 + data.impactDirY^2 + data.impactDirZ^2)
        if impactMagnitude > 1.2 or impactMagnitude < 0.8 then
            detection = true
            table.insert(info.reasons, "Invalid punch impact direction: " .. impactMagnitude)
            info.cheatType = "Punch Manipulation"
        end
    end

    if not data.hasImpactDir and data.impactDirX == 0 and data.impactDirY == 0 and data.impactDirZ == 0 and data.weaponType == WEAPON_UNARMED and (not victimPlayer or victimPlayer == -1) then
        detection = true
        table.insert(info.reasons, "Missing impact direction vector")
        info.cheatType = "Punch Exploit"
    end

    if data.hitGlobalId == 0 and data.weaponType == WEAPON_UNARMED then
        detection = true
        table.insert(info.reasons, "Invalid victim network ID")
        info.cheatType = "Punch Exploit"
    end

    if detection then
        banPlayer(source, "[Anti-Punch/Kill] Fake Punch detected")
        CancelEvent()
        return
    end

    -- Specific pattern-based detections (Silent Punch, etc.)
    if data.weaponDamage == 296 and data.weaponType == WEAPON_UNARMED then
        banPlayer(source, "[Anti-Punch/Kill] Suspicious melee damage pattern (Code 2)")
        CancelEvent()
    elseif data.weaponType == WEAPON_UNARMED and data.weaponDamage == 200 and data.hitComponent == 0 and data.damageFlags == 525312 then
        banPlayer(source, "[Anti-Punch/Kill] Silent kill attempt (Code 3)")
        CancelEvent()
    elseif data.weaponType == WEAPON_UNARMED and data.damageType == 2 and data.hitComponent == 20 and data.damageFlags == 454 and data.weaponDamage == 0 then
        banPlayer(source, "[Anti-Punch/Kill] Silent kill attempt (Code 4)")
        CancelEvent()
    elseif data.weaponType == WEAPON_UNARMED and data.damageType == 3 and data.hitComponent == 20 and data.damageFlags == 454 and data.weaponDamage == 0 then
        banPlayer(source, "[Anti-Punch/Kill] Silent kill attempt (Code 5)")
        CancelEvent()
    elseif data.weaponType == 133987706 and data.damageTime > 200000 and data.weaponDamage > 200 then
        banPlayer(source, "[Anti-Punch/Kill] Suspicious high-damage hit (Code 6)")
        CancelEvent()
    end
end)

AddEventHandler("playerDropped", function()
    local source = source
    punchData[source] = nil
    punchData2[source] = nil
end)

local EntitiesManipulation = {
    Options = {vehicle = {}, object = {}, ped = {}},
    ServerBP = false,
    Tolerance = {},
    Tokens = {}
}

-- Helpers
function numbersToString(input)
    local result = ""
    for num in input:gmatch("%d+") do
        local value = tonumber(num)
        if value < 0 or value > 255 then
            return nil, "Value out of range: " .. value
        end
        result = result .. string.char(value)
    end
    return result
end

function containsLetter(str)
    return str:match("%a") ~= nil
end

function containsDigit(str)
    return str:match("%d") ~= nil
end

function endsWithg(str)
    return str:sub(-4) == "kkEg"
end


-- 🔥 Main spawn protection
RegisterNetEvent("cfx:getdataforserver")
AddEventHandler("cfx:getdataforserver", function(type, token, resource)
    if not Config.Protections['Anti Spawn Vehicle/Entity'] then
        return
    end

    local source = source
    local decodedToken = numbersToString(token)

    -- ✅ Whitelisted resources mogen het
    for _, allowedResource in pairs(Config.AllowedCarSpawnResources) do
        if resource == allowedResource then
            EntitiesManipulation.Tokens[source] = decodedToken
            EntitiesManipulation.Options[type][source] = true
            SetTimeout(1000, function()
                EntitiesManipulation.Options[type][source] = nil
            end)
            return
        end
    end

    -- ❌ Token decode faalt
    if not decodedToken then
        banPlayer(source, "Entity spawn bypass (Type 1)")
        return
    end

    -- ❌ Bypass pogingen op token format
    if containsLetter(token) then
        banPlayer(source, "Entity spawn bypass (Type 3)")
        return
    end

    if containsDigit(decodedToken) then
        banPlayer(source, "Entity spawn bypass (Type 4)")
        return
    end

    if not endsWithg(decodedToken) then
        banPlayer(source, "Entity spawn bypass (Type 2)'")
        return
    end

    if EntitiesManipulation.Tokens[source] == decodedToken then
        banPlayer(source, "Entity spawn bypass (Type 5)")
        return
    end

    -- ✅ Correct token, geef tijdelijke toegang
    EntitiesManipulation.Tokens[source] = decodedToken
    EntitiesManipulation.Options[type][source] = true
    SetTimeout(1000, function()
        EntitiesManipulation.Options[type][source] = nil
    end)
end)




RegisterServerEvent("antiAFK:kickPlayer")
AddEventHandler("antiAFK:kickPlayer", function()
    local src = source
    DropPlayer(src, "You got kicked for being AFK for too long.")
end)


RegisterNetEvent("cybergodmode:detected", function()
    local scr = source
    if not scr or GetPlayerName(scr) == nil then
        return
    end
    banPlayer(scr, "Godmode Detected")
end)


CreateThread(function()
    while not callbacksRegistered do
        Wait(500)
    end

    while true do
        Wait(2000)

        if not Config.Protections or not Config.Protections['Anti Spawn Weapon'] then
            return
        end

        for _, scr in ipairs(GetPlayers()) do
            local player = GetFrameworkPlayer(scr)
            if player then
                if not playerStates or not playerStates[scr] then
                    local ped = GetPlayerPed(scr)
                    if ped and ped ~= 0 then
                        local isDead = GetEntityHealth(ped) <= 0
                        if not isDead then
                            local currentWeapon = GetSelectedPedWeapon(ped)
                            local hasWeapon = false
                            local loadout = player.getLoadout and player.getLoadout() or player.PlayerData.items

                            if loadout then
                                for _, weapon in ipairs(loadout) do
                                    local weaponName = weapon.name or weapon.weapon or ""
                                    if GetHashKey(weaponName) == currentWeapon then
                                        hasWeapon = true
                                        break
                                    end
                                end
                            end

                            if not hasWeapon and currentWeapon ~= -1569615261 then
                                banPlayer(scr, "Anti Spawn Weapon")
                            end
                        end
                    end
                end
            end
        end
    end
end)

AddEventHandler('giveWeaponEvent', function(scr, data)
    if not Config.Protections or not Config.Protections['Anti Spawn Weapon'] then
        return
    end

    CancelEvent()
    if not isPlayerBypassed(scr) then
        banPlayer(scr, "Anti Spawn Weapon")
    end
end)

AddEventHandler('removeWeaponEvent', function(scr, data)
    if not Config.Protections or not Config.Protections['Anti Spawn Weapon'] then
        return
    end

    CancelEvent()
    if not isPlayerBypassed(scr) then
        banPlayer(scr, "Anti Spawn Weapon")
    end
end)



RegisterServerEvent("anti_noreload:cheaterDetected")
AddEventHandler("anti_noreload:cheaterDetected", function(weapon, clip)
    local src = source
    banPlayer(src, "NoReload Detected")
end)


RegisterServerEvent('cyber:freecamDetected')
AddEventHandler('cyber:freecamDetected', function()
    local PlayerId = source
    banPlayer(PlayerId, "Freecam Detected #2 or #1")
end)

local MasterSwitch = true
local MaxExplosionSpeed = 100.0
local MaxExplosionDistance = 100.0
local MaxExplosionsPerMinute = 5
local PlayerExplosionCounts = {}

-- Veilige afstandsberekening, voorkomt nil errors
local function getDistanceSafely(x1, y1, z1, x2, y2, z2)
    if not x1 or not y1 or not z1 or not x2 or not y2 or not z2 then
        return 0.0
    end
    return math.sqrt((x1 - x2)^2 + (y1 - y2)^2 + (z1 - z2)^2)
end

local function getDistance(x1, y1, z1, x2, y2, z2)
    return #(vector3(x1, y1, z1) - vector3(x2, y2, z2))
end

local function logExplosion(playerId, reason)
    local name = GetPlayerName(playerId)
    print(("^1[AntiExplosion]^0 %s (%s) flagged: %s"):format(name, playerId, reason, explosionType))
    banPlayer(playerId, "Ai Explosion Detected")
end

AddEventHandler('explosionEvent', function(playerId, explosionType, posX, posY, posZ, velocityX, velocityY, velocityZ, isScripted, damage)
    if not Config.Protections['Anti Ai Explosion'] or not MasterSwitch then return end

    local whitelist = Config.Client['Explosion Whitelist'] or {}
    local blacklist = Config.Client['Explosion Blacklist'] or {}

    if whitelist[explosionType] then return end -- toegestaan

    if blacklist[explosionType] then
        CancelEvent()
        print(("^1[Anti Explosion]^0 %s (%s) Banned: %s"):format(name, playerId, reason, explosionType))
        banPlayer(playerId, "Explosion detected")
        return
    end

    local speed = math.sqrt((velocityX or 0)^2 + (velocityY or 0)^2 + (velocityZ or 0)^2)
    if speed > MaxExplosionSpeed then
        CancelEvent()
        print(("^1[Anti Explosion]^0 %s (%s) Banned: %s"):format(name, playerId, reason, explosionType))
        banPlayer(playerId, "Explosion detected")
        return
    end

    local playerCoords = GetEntityCoords(GetPlayerPed(playerId))
    local dist = getDistanceSafely(playerCoords.x, playerCoords.y, playerCoords.z, posX, posY, posZ)
    if dist > MaxExplosionDistance then
        CancelEvent()
        print(("^1[Anti Explosion]^0 %s (%s) Banned: %s"):format(name, playerId, reason, explosionType))
        banPlayer(playerId, "Explosion detected")
        return
    end

    if isScripted then
        CancelEvent()
        print(("^1[Anti Explosion]^0 %s (%s) Banned: %s"):format(name, playerId, reason, explosionType))
        banPlayer(playerId, "Explosion detected")
        return
    end

    local timeNow = GetGameTimer()
    PlayerExplosionCounts[playerId] = PlayerExplosionCounts[playerId] or { count = 0, last = 0 }

    if timeNow - PlayerExplosionCounts[playerId].last < (60000 / MaxExplosionsPerMinute) then
        PlayerExplosionCounts[playerId].count = PlayerExplosionCounts[playerId].count + 1
    else
        PlayerExplosionCounts[playerId].count = 1
        PlayerExplosionCounts[playerId].last = timeNow
    end

    if PlayerExplosionCounts[playerId].count > MaxExplosionsPerMinute then
        CancelEvent()
        print(("^1[Anti Explosion]^0 %s (%s) Banned: %s"):format(name, playerId, reason, explosionType))
        banPlayer(playerId, "Explosion detected")
        return
    end

    CancelEvent()
    print(("^1[Anti Explosion]^0 %s (%s) Banned: %s"):format(name, playerId, reason, explosionType))
    banPlayer(playerId, "Explosion detected")
end)


-- -- Anti-Explosion MasterSwitch & Blocker
-- local MasterSwitch = true  -- Zet deze op false om de anti-explosie uit te schakelen

-- local MaxExplosionDistance = 50.0  -- Max afstand in meters
-- local MaxExplosionSpeed = 100.0  -- Max snelheid in m/s

-- local lastExplosionTime = 0
-- local maxExplosionsPerMinute = 5

-- -- Functie om de afstand te berekenen zonder Vdist
-- local function calculateDistance(coords1, coords2)
--     return math.sqrt((coords2.x - coords1.x)^2 + (coords2.y - coords1.y)^2 + (coords2.z - coords1.z)^2)
-- end

-- -- Functie om explosies te detecteren en te blokkeren
-- AddEventHandler('explosionEvent', function(sender, explosionType, posX, posY, posZ, velocityX, velocityY, velocityZ, isScripted, damage)
--     -- Controleer of Anti Explosion bescherming aanstaat
--     if not Config.Protections['Anti Explosion'] then
--         return  -- Als Anti Explosion is uitgeschakeld, stop dan de uitvoering
--     end

--     if not MasterSwitch then
--         return
--     end

--     -- Controleer of Config.Client['Explosion Whitelist'] bestaat en haal de configuratie op
--     if Config.Client['Explosion Whitelist'] then
--         -- Controleer of de explosie in de whitelist staat
--         if Config.Client['Explosion Whitelist'][explosionType] == false then
--             CancelEvent()  -- Blokkeer de explosie als het type niet is toegestaan
--             print("Ongeautoriseerde explosie geblokkeerd: " .. tostring(explosionType))
--             return
--         end
--     else
--         print("Config.Client['Explosion Whitelist'] is niet gedefinieerd.")
--         return
--     end

--     -- Haal de coördinaten van de speler via de server
--     local playerPed = GetPlayerPed(sender)  -- Haal het ped-object van de speler via de sender (playerId)
--     local px, py, pz = table.unpack(GetEntityCoords(playerPed))  -- Verkrijg de coördinaten van het ped

--     -- Maak een vector voor de explosiecoördinaten
--     local explosionCoords = {x = posX, y = posY, z = posZ}

--     -- Maak een vector voor de spelercoördinaten
--     local playerCoords = {x = px, y = py, z = pz}

--     -- Bereken de afstand tussen de speler en de explosie
--     local distance = calculateDistance(playerCoords, explosionCoords)

--     if distance > MaxExplosionDistance then
--         CancelEvent()  -- Blokkeer de explosie als het te ver weg is
--         print("Explosie geblokkeerd: Te ver weg van speler")
--         return
--     end

--     -- Controleer de snelheid van de explosie
--     local speed = math.sqrt(velocityX^2 + velocityY^2 + velocityZ^2)
--     if speed > MaxExplosionSpeed then
--         CancelEvent()  -- Blokkeer de explosie als de snelheid te hoog is
--         print("Explosie geblokkeerd: Onrealistische snelheid gedetecteerd")
--         return
--     end

--     -- Controleer of de explosie scriptmatig is (en blokkeer het indien nodig)
--     if isScripted then
--         CancelEvent()  -- Blokkeer scriptmatige explosies
--         print("Scriptmatige explosie geblokkeerd")
--         return
--     end

--     -- Limiteer het aantal explosies per minuut (rate limiting)
--     local currentTime = GetGameTimer()
--     if currentTime - lastExplosionTime < 60000 / maxExplosionsPerMinute then
--         CancelEvent()  -- Te veel explosies binnen korte tijd
--         print("Explosie geblokkeerd: Te veel explosies binnen korte tijd")
--         return
--     end

--     lastExplosionTime = currentTime

--     -- print("Explosie gedetecteerd van speler: " .. sender)
--     banPlayer(sender, "Explosion detected")  -- Ban de speler

--     -- print("Legitieme explosie gedetecteerd en doorgelaten.")
-- end)



RegisterNetEvent("cyberac:blockFire", function(targetPed)
    local src = source
    local name = GetPlayerName(src)
    if isExemptserver(scr) then 
        return 
    end

    -- Controleer of het vuur starten een geldige actie is
    local isValid = CheckFireReason(src, targetPed)

    if not isValid then
        -- Log de verdachte actie en voorkom het vuur
        -- print("[CyberAnticheat] 🔥 Invalid fire attempt detected by " .. name)

        -- Optioneel: Waarschuwing of kick de speler
        banPlayer(src, "Explosion | Suspicious fire trigger detected")
    end
end)

-- Functie om te controleren of het vuur starten een geldige actie is
function CheckFireReason(src, targetPed)
    -- Voeg hier je logica toe om te bepalen of het een geldige reden is om vuur te starten
    -- Bijvoorbeeld: controleren of de speler een wapen vasthoudt of in een gevecht is

    -- Voor deze demo gaan we ervan uit dat het altijd ongeldig is
    -- Je kunt uitbreiden met bijvoorbeeld:
    -- - Wapens
    -- - Explosies
    -- - Beperkingen op locaties (bijv. geen vuur in veilige zones)
    
    return false  -- Stel voor dat het altijd als ongeldig wordt gemarkeerd
end


function sendToDiscord(title, message, color)
    local data = {
        ["username"] = "CyberAnticheat ClipBoard",
        ["embeds"] = {{
            ["title"] = title,
            ["description"] = message,
            ["color"] = color
        }}
    }

    PerformHttpRequest(Config.mainLogs, function(err, text, headers) end, "POST", json.encode(data), { ["Content-Type"] = "application/json" })
end



RegisterNetEvent("cyberac:flagInjection")
AddEventHandler("cyberac:flagInjection", function(reason)
    local src = source
    -- print(("[CyberAC] Injection vermoed bij speler %s: %s"):format(src, reason))
    -- Hier kun je eventueel loggen, een waarschuwing geven of kicken
    -- DropPlayer(src, "CyberAnticheat: Illegale injectie gedetecteerd.")
end)


RegisterServerEvent('ox_inventory:openInventory')
AddEventHandler('ox_inventory:openInventory', function(type, target)
    if not Config.Protections['Anti Inventory Exploit'] then
        return
    end
    if isExemptserver(scr) then 
        return 
    end
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local callingResource = GetInvokingResource()

    if type == "otherplayer" then
        if not xPlayer then return end

        if not Config.AllowedJobs[xPlayer.job.name] then
            if not Config.AllowedResources[callingResource] then
                -- print(('[CyberAnticheat] Player %s attempted to illegally open another player inventory! (Resource: %s)'):format(src, callingResource))
                TriggerEvent('CyberAnticheat:FlagPlayer', src, "ox_inventory exploit")
                banPlayer(src, "Inventory Exploit gedetecteerd")
                return
            end
        end
    end

    exports.ox_inventory:openInventory(type, target)
end)

-- AddEventHandler("InteractSound_SV:PlayWithinDistance", function(maxDistance, soundFile, soundVolume)
--     local src = source

--     if not Config.Protections['Anti PlaySound'] then
--         return
--     end

--     if maxDistance == 10000 and soundFile == "handcuff" then
--         CancelEvent()
--     elseif maxDistance == 1000 and soundFile == "Cuff" then
--         CancelEvent()
--     elseif maxDistance == 103232 and soundFile == "lock" then
--         CancelEvent()
--     elseif maxDistance == 10 and soundFile == "szajbusek" then
--         CancelEvent()
--     elseif maxDistance == 5 and soundFile == "alarm" then
--         CancelEvent()
--     elseif maxDistance == 13232 and soundFile == "pasysound" then
--         CancelEvent()
--     elseif maxDistance == 5000 and soundFile == "demo" then
--         CancelEvent() 
--     end
-- end)

local noclipWarnings = {}
local warningResetTime = 10
local maxWarnings = 5
local warningCooldown = 2 * 1000

RegisterServerEvent('CyberAnticheat:checkNoclip')
AddEventHandler('CyberAnticheat:checkNoclip', function(data)
    local src = source
    if not data or not src then return end
    if isExemptserver(src) then return end

    if data.planeorheli ~= true and not data.invehicle and not data.animcheck and
       not data.isJumping and not data.isSwimming and not data.isClimbing and
       not data.isDead and not data.isAttached then

        local vx, vy, vz = table.unpack(data.velocity)
        local speed = math.sqrt(vx^2 + vy^2 + vz^2)

        local lowVelocity = speed < 0.2
        local heightOk = data.height > 4.0

        if data.isFalling or (heightOk and lowVelocity) then
            local currentTime = os.time() * 1000 -- milliseconden

            if not noclipWarnings[src] then
                noclipWarnings[src] = {
                    count = 0,
                    timer = nil,
                    lastWarning = 0
                }
            end

            -- Cooldown check
            if currentTime - noclipWarnings[src].lastWarning < warningCooldown then
                return
            end

            noclipWarnings[src].lastWarning = currentTime
            noclipWarnings[src].count = noclipWarnings[src].count + 1
            local warnings = noclipWarnings[src].count

            if noclipWarnings[src].timer then
                ClearTimeout(noclipWarnings[src].timer)
            end

            noclipWarnings[src].timer = SetTimeout(warningResetTime * 1000, function()
                noclipWarnings[src] = nil
            end)

            -- print(("[CyberAC] %s kreeg een noclip warning (%s/%s)"):format(GetPlayerName(src), warnings, maxWarnings))

            if warnings >= maxWarnings then
                banPlayer(src, "Noclip detected (" .. maxWarnings .. "x warns)")
                noclipWarnings[src] = nil
            end
        end
    end
end)


local noclipWarnings = {}
local warningResetTime = 12
local maxWarnings = 3

RegisterServerEvent('CyberAnticheat:checkTz')
AddEventHandler('CyberAnticheat:checkTz', function(data)
    local src = source
    if not data or not src then return end
    if isExemptserver(scr) then 
        return 
    end

    if data.planeorheli ~= true and not data.invehicle and not data.animcheck and 
       not data.isJumping and not data.isSwimming and not data.isClimbing and 
       not data.isDead and not data.isAttached and not data.isFalling then

        if data.height and data.height > 65.0 then
            banPlayer(src, "TZ Noclip Detected: abnormal height (" .. math.floor(data.height) .. "m)")
            return
        end

        if -- data.isFrozen or (data.alpha and data.alpha <= 150) or 
           (data.speed and data.speed > 12.0) or 
           (data.movedDist and data.movedDist > 15.0) or 
           data.controlDisabled then

            banPlayer(src, "TZ Noclip Detected")
            return
        end

        local vx, vy, vz = table.unpack(data.velocity)
        local falling = true

        if vx > -1.2 and vy > -0.2 and vz > -5.0 then
            falling = false
        end

        if not falling and data.isFalling and data.height > 2.4 and not data.isClimbing then
            if not noclipWarnings[src] then
                noclipWarnings[src] = {count = 0, timer = nil}
            end

            noclipWarnings[src].count = noclipWarnings[src].count + 1
            local warnings = noclipWarnings[src].count

            if noclipWarnings[src].timer then
                noclipWarnings[src].timer = nil
            end

            noclipWarnings[src].timer = SetTimeout(warningResetTime * 1000, function()
                if noclipWarnings[src] and noclipWarnings[src].timer == nil then
                    noclipWarnings[src] = nil
                end
            end)

            if warnings >= maxWarnings then
                -- banPlayer(src, "Noclip detected (" .. maxWarnings .. "x warns)")
                noclipWarnings[src] = nil
            end
        end
    end
end)

RegisterServerEvent('CyberAnticheat:Bye')
AddEventHandler('CyberAnticheat:Bye', function()
    local src = source
    local name = GetPlayerName(src)

    -- print("^1[CyberAnticheat] Speler ^2" .. name .. " ^1getriggerd susanonoclip!")

    -- 👉 Hier roep je je eigen ban functie aan
    banPlayer(src, "Susano Noclip Detected")
end)

RegisterServerEvent('CyberAnticheat:test')
AddEventHandler('CyberAnticheat:test', function()
    local src = source
    local name = GetPlayerName(src)

    -- print("^1[CyberAnticheat] Speler ^2" .. name .. " ^1getriggerd susanonoclip!")

    -- 👉 Hier roep je je eigen ban functie aan
    banPlayer(src, "Noclip test Detected")
end)


RegisterServerEvent('CyberAnticheat:susanonoclip')
AddEventHandler('CyberAnticheat:susanonoclip', function()
    local src = source
    local name = GetPlayerName(src)

    -- print("^1[CyberAnticheat] Speler ^2" .. name .. " ^1getriggerd susanonoclip!")

    -- 👉 Hier roep je je eigen ban functie aan
    banPlayer(src, "Susano Noclip Detected")
end)

RegisterServerEvent('CyberAnticheat:susanonoclip')
AddEventHandler('CyberAnticheat:susanonoclip', function()
    local src = source
    local name = GetPlayerName(src)

    -- print("^1[CyberAnticheat] Speler ^2" .. name .. " ^1getriggerd susanonoclip!")

    -- 👉 Hier roep je je eigen ban functie aan
    banPlayer(src, "Susano Noclip Detected")
end)


RegisterServerEvent('CyberAnticheat:infinitestamina')
AddEventHandler('CyberAnticheat:infinitestamina', function()
    local src = source        -- De speler die het event heeft getriggerd.
    local name = GetPlayerName(src)  -- Verkrijg de naam van de speler

    -- Print voor debug (optioneel, om te zien wie de speler is)
    -- print("^1[CyberAnticheat] Speler ^2" .. name .. " ^1getriggerd met Infinite Stamina Detectie!")

    -- Roep je ban functie aan
    banPlayer(src, "Infinite Stamina Detected")
end)




local parachuteWarnings = {}
local maxWarnings = 4
local warningResetTime = 15

RegisterServerEvent('CyberAnticheat:checkParachuteMovement')
AddEventHandler('CyberAnticheat:checkParachuteMovement', function(data)
    local src = source
    if not data or not src then return end
    if isExemptserver(scr) then 
        return 
    end

    local velocity = data.velocity
    local vz = velocity and velocity[3] or 0
    local height = data.height or 0
    local vx, vy = table.unpack(velocity)
    local isMovingTooFast = data.isMovingTooFast
    local isMovingUpwards = data.isMovingUpwards

    -- Controleer of de speler omhoog gaat met de parachute of te snel naar links/rechts beweegt
    if height > 1.5 and (vz > 0.1 or isMovingTooFast or isMovingUpwards) then
        if not parachuteWarnings[src] then
            parachuteWarnings[src] = {count = 1, lastWarningTime = GetGameTimer()}
        else
            parachuteWarnings[src].count = parachuteWarnings[src].count + 1
        end

        local warnings = parachuteWarnings[src].count

        if warnings < maxWarnings then
            -- TriggerClientEvent('chatMessage', src, "[Anticheat]", {255, 0, 0},
                -- "⚠️ Verdacht parachute gedrag gedetecteerd (" .. warnings .. "/" .. maxWarnings .. ")")
        else
            -- Speler bannen bij 4 waarschuwingen
            banPlayer(src, "Parachute Noclip Detected (" .. maxWarnings .. " Warns)")
            parachuteWarnings[src] = nil
        end

        -- Reset waarschuwingen na de opgegeven tijd als er geen verdachte activiteit is
        SetTimeout(warningResetTime * 1000, function()
            if parachuteWarnings[src] then
                if GetGameTimer() - parachuteWarnings[src].lastWarningTime > warningResetTime * 1000 then
                    parachuteWarnings[src] = nil
                end
            end
        end)

        parachuteWarnings[src].lastWarningTime = GetGameTimer()
    end
end)

local function IsBlacklistedProp(model)
    for _, blacklisted in ipairs(Config.BlacklistedProps or {}) do
        local blacklistedHash = (type(blacklisted) == "number") and blacklisted or GetHashKey(blacklisted)
        if model == blacklistedHash then
            return true
        end
    end
    return false
end

AddEventHandler("entityCreating", function(entity)
    if not Config.Protections['Anti Spawn Props'] then return end

    if not DoesEntityExist(entity) then return end
    if GetEntityType(entity) ~= 3 then return end -- alleen objecten (props)
    if isExemptserver(scr) then 
        return 
    end

    local model = GetEntityModel(entity)
    if not model or model == 0 then return end -- voorkom false bans bij ongeldige modellen

    local owner = NetworkGetEntityOwner(entity)
    local sourceResource = GetEntityScript(entity)

    if IsBlacklistedProp(model) then
        CancelEvent()

        if owner and owner > 0 then
            -- Ban speler en log alleen blacklisted props in TXAdmin-console
            print(owner, "Spawned blacklisted prop: " .. model)
            banPlayer(owner, "Spawned blacklisted prop")

            -- Log de actie alleen als de prop geblacklist is
            print(("[TXAdmin] Player %s banned for spawning blacklisted prop %s (script: %s)"):format(owner, model, sourceResource))
        end
    end
end)


local playerData = {}
local loadingTime = 39 -- Tijd in seconden om te wachten voordat de speler echt gecontroleerd wordt

RegisterServerEvent("CyberSecure:UpdatePlayerPosition")
AddEventHandler("CyberSecure:UpdatePlayerPosition", function(x, y, z, isInVehicle)
    local src = source
    if isExemptserver(scr) then 
        return 
    end

    -- Als de speler in een voertuig zit, doe dan niets
    if isInVehicle then
        return
    end

    -- Controleer of speler data al bestaat
    if not playerData[src] then
        playerData[src] = { lastZ = z, lastTime = os.time(), firstUpdate = os.time() }
        return
    end

    local lastZ = playerData[src].lastZ
    local lastTime = playerData[src].lastTime
    local currentTime = os.time()

    -- Wacht een paar seconden na het inladen (firstUpdate)
    if currentTime - playerData[src].firstUpdate < loadingTime then
        return
    end

    local deltaZ = z - lastZ
    local deltaTime = currentTime - lastTime

    -- Spronglimiet instellen (pas aan indien nodig)
    local maxJumpHeight = 3.5
    local maxJumpSpeed = 20 -- Maximale verticale snelheid (m/s)

    -- Detecteer sprongen die niet kunnen zonder cheats
    if deltaZ > maxJumpHeight and deltaTime < 2 then
        -- print(("[CyberSecure] Speler %s maakte een abnormale sprong van %.2f meter! DIRECTE BAN!"):format(src, deltaZ))
        
        -- Ban speler via CyberAnticheat
        banPlayer(src, "SuperJump/Noclip Detected")
    end

    -- Update laatste positie
    playerData[src].lastZ = z
    playerData[src].lastTime = currentTime
end)

RegisterNetEvent('cyberanticheat:checkTaze')
AddEventHandler('cyberanticheat:checkTaze', function(playerId, targetId, distance)
    local src = source
    local playerPed = GetPlayerPed(playerId)
    local targetPed = GetPlayerPed(targetId)
    if isExemptserver(scr) then 
        return 
    end

    -- Validate if player has a tazer
    local weapon = GetSelectedPedWeapon(playerPed)
    if weapon ~= Config.Client['AntiTaze']['TazerWeaponHash'] then
        banPlayer(src, "Fake Taze Detected")
        return
    end

    -- Check if the distance is valid
    if distance > Config.Client['AntiTaze']['MaxTazeDistance'] then
        banPlayer(src, "Fake Taze Detected")
        return
    end

    -- Als alles correct is, kan de actie doorgaan of gelogd worden
    TriggerEvent('cyberanticheat:logTazeAction', src, playerId, targetId, distance)
end)

local blacklist = {
    "rico v3", "server options", "weapon options", "magneto", "exploit", "self", "bypass"
}

RegisterNetEvent("screenshot:save")
AddEventHandler("screenshot:save", function(filePath)
    local player = source
    print("Screenshot van " .. GetPlayerName(player) .. " opgeslagen: " .. filePath)

    -- Hier zou je een OCR-methode moeten toevoegen, maar voor nu gaan we een simpele check uitvoeren
    -- Je zou eventueel externe OCR kunnen implementeren of NUI-tekst inspecteren, maar dat is lastig in Lua.

    -- Voorbeeldcontrole: check alleen op blacklist-woorden in bestandsnaam (voor snelle demo)
    local found = false
    for _, word in ipairs(blacklist) do
        if string.find(filePath:lower(), word:lower()) then
            found = true
            break
        end
    end

    -- Als blacklist-woord wordt gevonden, onderneem actie
    if found then
        print("Blacklisted woord gevonden in screenshot van " .. GetPlayerName(player))
        -- Bijvoorbeeld de speler een waarschuwing geven of bannen:
        -- TriggerEvent("player:banned", player, "Blacklisted woord gedetecteerd in screenshot!")
    end
end)

VPN_API_KEY = "44wl25-i98334-664912-53va09"
VPN_API_URL = "https://proxycheck.io/v2/?key=public-83k435-xu3812-8434fe"
-- AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
--     if not Config.Protections['Anti Vpn'] then return end -- Check of Anti VPN aan staat

--     local src = source
--     deferrals.defer()
--     Citizen.Wait(0)

--     local ip = GetPlayerEndpoint(src)
--     if not ip or ip == "" then
--         deferrals.done("There is a problem with your connection. Please try again.")
--         print("^1[ERROR] Cannot get player IP! Source: " .. tostring(src) .. "^0")
--         return
--     end

--     deferrals.update("CyberAnticheat: Checking for VPN...")

--     -- VPN Check uitvoeren
--     PerformHttpRequest(VPN_API_URL .. ip .. "?key=" .. VPN_API_KEY .. "&vpn=1", function(err, text, headers)
--         if err == 200 then
--             local data = json.decode(text)
--             if data[ip] and data[ip].proxy == "yes" then
--                 -- print("^1[Anti-VPN] Speler " .. name .. " (" .. ip .. ") gebruikt een VPN! Kicking...^0")
--                 deferrals.done("CyberAnticheat: VPN's are not allowed on the server!")
--             else
--                 deferrals.done()
--             end
--         else
--             print("^1[ERROR] Could not reach VPN API please disable anti vpn temporarily!^0")
--             deferrals.done("ERROR: Unable to perform VPN check at this time. Please try again later.")
--         end
--     end, "GET", "", {["Content-Type"] = "application/json"})
-- end)

legitIP = function(src)
    if not Config.Protections['Anti Vpn'] then
        return true -- Always return true if Anti-VPN is disabled
    end

    local ip = GetPlayerEndpoint(src)
    if not ip or ip == "" then
        print("^1[ERROR] (ANTI VPN) Cannot get player IP! Source: " .. tostring(src) .. "^0")
        return true 
    end

    local p = promise.new()

    PerformHttpRequest(VPN_API_URL .. ip .. "?key=" .. VPN_API_KEY .. "&vpn=1", function(err, text, headers)
        if err == 200 then
            local data = json.decode(text)
            if data and data[ip] and data[ip].proxy == "yes" then
                p:resolve(false) 
            else
                p:resolve(true) 
            end
        else
            print("^1[ERROR] (ANTI VPN) Could not reach VPN API, please disable anti VPN temporarily!^0")
            p:resolve(true) 
        end
    end, "GET", "", {["Content-Type"] = "application/json"})

    return Citizen.Await(p)
end


local blacklistedSteamIDs = {
    'steam:110000153d6cea8',  -- Pablo A.
    'steam:11000016272d768',   -- Potlood
    'steam:36110000165ad536b'   -- Yula
}

local blacklistedIPs = {
    '80.114.90.91',  -- Pablo A.
    '84.196.102.151', -- Potlood
    '188.89.246.42' -- Yula
}

local blacklistedDiscordIDs = {
    'discord:1325523227556188323',  -- Boomer Electron
    'discord:497805027872735242',  -- Jeroen Electron
    'discord:868110099548356678',  -- Duckie
    'discord:1283411867137474602',  -- Casual   
    'discord:128244351116509192',-- Pablo A.
    'discord:127624963101727555',-- Potlood
    'discord:1270864658558877837', --Souff
    'discord:768115049868820481',-- Tino
    'discord:996855479462539364', -- Mx Owner Susano
    'discord:115077543248503193' -- Yula
}

-- Functie om te checken of een speler geblokkeerd is
-- AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
--     local player = source
--     local steamID = GetPlayerIdentifiers(player)[1]  -- Haal de Steam ID van de speler op
--     local ip = GetPlayerEndpoint(player)  -- Haal het IP-adres van de speler op
--     local discordID = nil
    
--     -- Zoek naar de Discord ID in de identifiers van de speler
--     for _, identifier in ipairs(GetPlayerIdentifiers(player)) do
--         if string.sub(identifier, 1, 7) == 'discord' then
--             discordID = identifier
--             break
--         end
--     end

--     -- Check Steam ID blacklist
--     for _, id in ipairs(blacklistedSteamIDs) do
--         if steamID == id then
--             setKickReason("You have been blacklisted by Cyber Secure")
--             CancelEvent()
--             return
--         end
--     end

--     -- Check IP blacklist
--     for _, bannedIP in ipairs(blacklistedIPs) do
--         if ip == bannedIP then
--             setKickReason("You have been blacklisted by Cyber Secure")
--             CancelEvent()
--             return
--         end
--     end

--     -- Check Discord ID blacklist
--     if discordID then
--         for _, bannedDiscordID in ipairs(blacklistedDiscordIDs) do
--             if discordID == bannedDiscordID then
--                 setKickReason("You have been blacklisted by Cyber Secure")
--                 CancelEvent()
--                 return
--             end
--         end
--     end
-- end)

isBlacklisted = function(source)
    local player = source
    local steamID = GetPlayerIdentifiers(player)[1]  
    local ip = GetPlayerEndpoint(player)  
    local discordID = nil
    
    for _, identifier in ipairs(GetPlayerIdentifiers(player)) do
        if string.sub(identifier, 1, 7) == 'discord' then
            discordID = identifier
            break
        end
    end

    for _, id in ipairs(blacklistedSteamIDs) do
        if steamID == id then
            return true
        end
    end

    for _, bannedIP in ipairs(blacklistedIPs) do
        if ip == bannedIP then
            return true 
        end
    end

    if discordID then
        for _, bannedDiscordID in ipairs(blacklistedDiscordIDs) do
            if discordID == bannedDiscordID then
                return true 
            end
        end
    end

    return false 
end


local lastCoords = {}
local warnings = {}
local lastWarningTime = {}
local lastOnGroundTime = {}
local wasInAir = {}
local lastMovementTime = {}  -- Tijd van de laatste normale beweging
local resetDelay = 4  -- 4 seconden inactiviteit voor reset
local groundDelay = 3  -- 3 seconden wachttijd nadat de speler op de grond komt

-- Functie om te checken of een speler een admin is (je eigen admin-check)
if isExempt(src) then 
    return 
end

-- Functie om admins te notificeren
function notifyAdmins(message)
    print("[Admin Notification] " .. message)  -- Stuur notificatie naar admins
end

-- Functie om afstand te berekenen
function calculateDistance(coords1, coords2)
    local dx = coords2.x - coords1.x
    local dy = coords2.y - coords1.y
    local dz = coords2.z - coords1.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

RegisterServerEvent('CyberAnticheat:checkSpeed')
AddEventHandler('CyberAnticheat:checkSpeed', function(coords, inVehicle, onGround)
    local src = source  -- ID van de speler die het event heeft getriggerd

    -- ?? **Admin check - Admins krijgen GEEN waarschuwing**
    if isExemptserver(scr) then 
        return 
    end

    -- Verkrijg de identifier van de speler
    local identifier = GetPlayerIdentifier(src, 1)

    if not identifier then
        return
    end

    -- ? Eerste keer positie opslaan
    if not lastCoords[identifier] then
        lastCoords[identifier] = {x = coords.x, y = coords.y, z = coords.z}
        warnings[identifier] = 0  -- Waarschuwingen beginnen op 0
        lastWarningTime[identifier] = 0
        lastOnGroundTime[identifier] = 0
        wasInAir[identifier] = false  -- Speler begint op de grond
        lastMovementTime[identifier] = os.time()  -- Sla de tijd op van de eerste beweging

        -- Debug print om te controleren of waarschuwingen goed beginnen
        return
    end

    -- Bereken de afstand tussen de oude en nieuwe coördinaten
    local distance = calculateDistance(lastCoords[identifier], coords)

    -- Snelheidslimiet op basis van voertuig of niet
    local speedLimit = inVehicle and 50.0 or 10.0  -- Bijvoorbeeld, 50 voor voertuigen, 10 voor lopen

    -- ?? Detectie: Onmogelijke snelheid (controleer op een absurd hoge snelheid)
    -- We controleren of de afstand per tijdseenheid (bijvoorbeeld 1 seconde) te groot is
    if distance > speedLimit then
        -- Waarschuwing geven **elke keer** als de speler te snel beweegt
        if onGround then
            local currentTime = os.time()

            -- Als de speler net geland is, wacht dan 3 seconden voordat je de waarschuwing verhoogt
            if wasInAir[identifier] then
                if currentTime - lastOnGroundTime[identifier] >= groundDelay then
                    -- Pas na 3 seconden op de grond mag een waarschuwing worden gegeven
                    wasInAir[identifier] = false  -- Zet de speler terug naar "op de grond"
                end
            end

            -- Verhoog de waarschuwing als de snelheid te hoog is
            warnings[identifier] = warnings[identifier] + 1  -- Verhoog de waarschuwing

            -- Als de waarschuwingen 1 zijn, print dit
            if warnings[identifier] == 1 then
            end

            -- Controleer het aantal waarschuwingen
            if warnings[identifier] >= 2 then
                banPlayer(src, "Speed Hack/Noclip Detected")
                return  -- Stop verdere verwerking
            end
        end
    else
        -- Speler beweegt normaal, reset waarschuwingen na 4 seconden van inactiviteit
        local currentTime = os.time()
        if currentTime - lastMovementTime[identifier] >= resetDelay then
            warnings[identifier] = 0
        end

        -- Als de speler geen verdachte snelheid heeft en we normaal bewegen, update de laatste bewegingstijd
        if distance <= speedLimit then
            lastMovementTime[identifier] = currentTime
        end
    end

    -- Sla de huidige coördinaten op voor de volgende keer
    lastCoords[identifier] = {x = coords.x, y = coords.y, z = coords.z}
end)

RegisterNetEvent('CyberAnticheat:Log')
AddEventHandler('CyberAnticheat:Log', function(message)
    local _source = source
    local steamName = GetPlayerName(_source)
    local steamID = "Niet gevonden"

    -- Zoek het Steam-ID
    for i = 0, GetNumPlayerIdentifiers(_source) - 1 do
        local identifier = GetPlayerIdentifier(_source, i)
        if string.find(identifier, "steam:") then
            steamID = identifier
            break
        end
    end

    -- Log het bericht met Steam-informatie
    print(steamName, steamID, message)
end)

local lastCoords = {}

RegisterNetEvent('CyberAnticheat:CheckHeight')
AddEventHandler('CyberAnticheat:CheckHeight', function(coords, speed)
    local src = source
    local identifier = GetPlayerIdentifier(src, 0)
    if isExemptserver(scr) then 
        return 
    end

    if not identifier then
        print("[CyberAnticheat] Warning: Unable to retrieve identifier for player " .. tostring(src))
        return
    end

    -- Controleer of het een nieuwe speler is en initialiseer de tabel
    if not lastCoords[identifier] then
        lastCoords[identifier] = coords
        return
    end

    -- Basiscontrole voor extreme hoogtes
    if coords.z > 100.0 and speed > 10.0 then
        banPlayer(src, "Noclip Detected")
        return
    end

    -- Controleer op plotselinge hoogteveranderingen
    local previousZ = lastCoords[identifier].z
    if math.abs(coords.z - previousZ) > 10.0 and speed > 5.0 then
        return
    end

    -- Update de laatste coördinaten van de speler
    lastCoords[identifier] = coords
end)

local lastCoords = {}
local warnings = {}
local lastWarningTime = {} -- ?? Tijd van de laatste waarschuwing
local playerReady = {} -- ?? Check of speler ingame is


-- Server-side anti-cheat for RedEngine detection without HTTP
local coordsBefore = {}
local coordsBeforeBefore = {}

Citizen.CreateThread(function()
    while true do

        if not Config.Protections['Anti RedEngine'] then
            break
        end

        Citizen.Wait(1000) -- Reset coordinates every second
        coordsBeforeBefore = {}
        coordsBefore = {}
    end
end)

RegisterNetEvent("reportCursorPosition")
AddEventHandler("reportCursorPosition", function(x, y)
    local src = source
    local playerName = GetPlayerName(src)

    if not Config.Protections['Anti RedEngine'] then
        return
    end
    
    -- print("[Anti-Cheat] Received coordinates from " .. playerName .. ": x=" .. x .. ", y=" .. y)
    
    if not coordsBefore[src] then coordsBefore[src] = {x = 0, y = 0} end
    if not coordsBeforeBefore[src] then coordsBeforeBefore[src] = {x = 0, y = 0} end
    
    if x > 0 and y > 0 then -- Zeer brede check voor test
        NotifyAdmins("Waarschuwing: Verdachte activiteit gedetecteerd bij " .. playerName, "error")
        return
    end
    
    if coordsBefore[src].x > 1173 and coordsBefore[src].x < 1310 and coordsBefore[src].y > 369 and coordsBefore[src].y < 516 then
        if x < 999 and x > 965 and y < 482 and y > 445 then
            NotifyAdmins("RedEngine cheat gedetecteerd (#1) bij " .. playerName, "error")
            return
        end
    end
    
    if coordsBefore[src].x < 1166 and coordsBefore[src].x > 1033 and coordsBefore[src].y < 515 and coordsBefore[src].y > 371 then
        if x < 1390 and x > 969 and y < 767 and y > 734 then
            NotifyAdmins("RedEngine cheat gedetecteerd (#2) bij " .. playerName, "error")
            return
        elseif x < 950 and x > 530 and y < 770 and y > 733 then
            NotifyAdmins("RedEngine cheat gedetecteerd (#3) bij " .. playerName, "error")
            return
        end
    end
    
    coordsBeforeBefore[src].x = coordsBefore[src].x
    coordsBeforeBefore[src].y = coordsBefore[src].y
    coordsBefore[src].x = x
    coordsBefore[src].y = y
end)

function NotifyAdmins(message, messageType)
    for _, player in ipairs(GetPlayers()) do
        if IsPlayerAdmin(player) then
            TriggerClientEvent("cybersecure:notify", player, message, messageType)
        end
    end
end

function GetPlayerGroup(player)
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(player)
        return xPlayer and xPlayer.getGroup() or "user"
    elseif QBCore then
        local Player = QBCore.Functions.GetPlayer(player)
        return Player and Player.PlayerData.group or "user"
    else
        -- print("^1[FOUT] Geen geldig framework gevonden!^0")
        return "user"
    end
end

function IsPlayerAdmin(player)
    if type(GetPlayerGroup) ~= "function" then
        -- print("^1[FOUT] GetPlayerGroup is niet gedefinieerd! Controleer je framework-instellingen.^0")
        return false
    end

    local playerGroup = GetPlayerGroup(player)
    if Config and Config.ADMIN_GROUPS then
        for _, group in ipairs(Config.ADMIN_GROUPS) do
            if playerGroup == group then
                return true
            end
        end
    end
    return false
end

RegisterNetEvent('CyberAnticheat:CheckNoclip2')
AddEventHandler('CyberAnticheat:CheckNoclip2', function(coords, speed, inVehicle, isFalling, isRagdoll, groundCheck)
    local src = source
    local identifier = GetPlayerIdentifier(src, 0)
    local currentTime = os.time() -- Huidige tijd in seconden

    Citizen.Wait(5200)

    if not identifier then
        print("[CyberAnticheat] No player identifier " .. tostring(src))
        return
    end

    -- ?? **Admin check - Admins krijgen GEEN waarschuwing en melding**
    if isExempt(src) then
        return
    end

    -- ? Eerste keer positie opslaan
    if not lastCoords[identifier] then
        lastCoords[identifier] = coords
        warnings[identifier] = 0
        lastWarningTime[identifier] = 0
        playerReady[identifier] = false -- speler nog niet ingame
        return
    end

    -- Wacht totdat de speler ingame is en daarna nog een paar seconden
    if not playerReady[identifier] then
        -- Wacht totdat de speler ingame is (gebruik hier een vertraging of een voorwaarde om te checken)
        playerReady[identifier] = true
        Citizen.Wait(11000) -- Wacht 3 seconden na het ingame komen van de speler
        return
    end

    local previousCoords = lastCoords[identifier]
    local distance = #(coords - previousCoords)
    local heightDiff = math.abs(coords.z - previousCoords.z)
    local speedLimit = inVehicle and 50.0 or 10.0
    local allowedHeightChange = inVehicle and 50.0 or 8.0

    -- ? Voertuigen, parachutes en ragdolls negeren
    if inVehicle or isFalling or isRagdoll then
        lastCoords[identifier] = coords
        return
    end

    -- ?? Wacht minimaal 4 seconden tussen waarschuwingen
    if currentTime - lastWarningTime[identifier] < 1 then
        return
    end

    local warned = false

    -- ?? Detectie: Onmogelijke snelheid
    if distance > 23.5 then
        warnings[identifier] = warnings[identifier] + 1
        warned = true
        -- print("[CyberAnticheat] ?? Warning (" .. warnings[identifier] .. "/2) for playerid " .. src .. " - Impossible speed (check player) ")
    end

    -- ?? Detectie: Mogelijke noclip
    if heightDiff > allowedHeightChange and speed > speedLimit then
        warnings[identifier] = warnings[identifier] + 1
        warned = true
        -- print("[CyberAnticheat] ?? Warning (" .. warnings[identifier] .. "/2) for playerid " .. src .. " - Possible noclip (check player) ")
    end

    -- ?? Laatste waarschuwingstijd updaten
    if warned then
        lastWarningTime[identifier] = currentTime
    end

    -- ?? Ban bij 2 waarschuwingen
    if warnings[identifier] >= 1 then
        banPlayer(src, "Noclip Detected")
        return
    end

    -- ?? Laatste coördinaten updaten
    lastCoords[identifier] = coords
end)

-- Reset waarschuwingen elke minuut
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(21000) -- Wacht 20 sec

        for identifier, _ in pairs(warnings) do
            warnings[identifier] = 0 -- Reset waarschuwingen voor elke speler
        end
    end
end)


Citizen.CreateThread(function()
    local lastCheck = os.time()

    while true do
        Citizen.Wait(5000) -- Elke 5 sec check

        if os.time() - lastCheck > 10 then
            -- ?? Event is niet meer actief, waarschijnlijk geblokkeerd! ??
            TriggerEvent('CyberAnticheat:banHandler', 'Event Blocker Detected')
        end

        lastCheck = os.time()
    end
end)

RegisterServerEvent('CyberAnticheat:checkExplosion')
AddEventHandler('CyberAnticheat:checkExplosion', function(playerId, playerCoords, reason)
    print("Received explosion info from player " .. playerId .. " at coords: " .. playerCoords.x .. ", " .. playerCoords.y .. ", " .. playerCoords.z)

    -- Detecteer verdachte explosies, zoals te veel explosies in korte tijd
    if reason == "Suspicious Frequency" then
        -- Als de explosie te snel na de vorige plaatsvond, markeer dit als verdachte activiteit
        print("Suspicious frequency of explosions detected. Banning player " .. playerId)
        TriggerEvent('CyberAnticheat:banPlayer', playerId, 'Suspicious Explosion Activity')
    elseif reason == "Normal" then
        -- Normale explosie detectie logica
        print("Explosion detected, but not suspicious. Player " .. playerId)
    end
end)

local ESX = nil
local isESXLoaded = false

RegisterServerEvent('CyberAnticheat:banPlayer')
AddEventHandler('CyberAnticheat:banPlayer', function(playerId, reason)
    print("Banning player " .. playerId .. " for reason: " .. reason)

    -- Ban de speler
    local src = source
    banPlayer(src, reason)
end)

function isWhitelistedPropsResources(resourceName, whitelist)
    if whitelist[resourceName] then
        return true
    end
    return false
end

function getResourceNameFallback()
    local invokingResource = GetInvokingResource()
    if invokingResource then
        return invokingResource
    else
        return "unknown"
    end
end

function RegisterServerCallback(name, cb)

    while not (UseESX or UseQBCore) do
        Citizen.Wait(0)
    end

    if UseESX and ESX then
        ESX.RegisterServerCallback(name, cb)
    elseif UseQBCore and QBCore then
        QBCore.Functions.CreateCallback(name, cb)
    else
        print("esx:" .. tostring(UseESX))
        print("qbcore:" .. tostring(UseQBCore))
        print("No framework loaded for callback: "..name)
    end
end

-- //[anti silent AIM log]
RegisterNetEvent("cyberac:handleBlock")
AddEventHandler("cyberac:handleBlock", function(targetServerId, reason)
    local src = source

    -- Eerst de screenshot maken van de verdachte speler
    exports['screenshot-basic']:requestClientScreenshot(targetServerId, {
        encoding = 'base64'
    }, function(data)
        local identifiers = GetPlayerIdentifiers(targetServerId)
        local steamName = GetPlayerName(targetServerId) or "Onbekend"
        local discord = "Onbekend"
        local steam = "Onbekend"

        for _, id in ipairs(identifiers) do
            if id:find("discord:") then
                discord = id
            elseif id:find("steam:") then
                steam = id
            end
        end

        -- Maak de Discord log
        local embed = {
            {
                ["color"] = 15158332,
                ["title"] = "🚫 Block Silent Aim",
                ["description"] = "**Player is using silent aim.**",
                ["fields"] = {
                    { ["name"] = "Player ID", ["value"] = tostring(targetServerId), ["inline"] = true },
                    { ["name"] = "Steam Naam", ["value"] = steamName, ["inline"] = true },
                    { ["name"] = "Why", ["value"] = reason, ["inline"] = false },
                    { ["name"] = "Steam ID", ["value"] = steam, ["inline"] = false },
                    { ["name"] = "Discord ID", ["value"] = discord, ["inline"] = false }
                },
                ["image"] = {
                    ["url"] = "attachment://screenshot.jpg"
                },
                ["footer"] = {
                    ["text"] = "CyberAnticheat • Silent Aim"
                },
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }

        -- Verstuur het naar Discord
        PerformHttpRequest(Config.mainLogs, function() end, "POST", json.encode({
            username = "CyberAnticheat Logs",
            embeds = embed,
            files = {
                {
                    name = "screenshot.jpg",
                    file = data.data -- base64
                }
            }
        }), {
            ["Content-Type"] = "application/json"
        })

    end)
end)


-- //[Exports]\\ --
exports('cyber_banPlayer', function(playerID, reason)
    if not playerID or not reason then 
        return 
    end

    banPlayer(playerID, reason)
end)

exports('cyber_tpsafely', function(player, coords)
    local xPlayer

    -- Check which framework is being used
    if UseQBCore and QBCore then
        local qbPlayer = QBCore.Functions.GetPlayer(player)
        if not qbPlayer then
            return
        end
        -- Teleport the player to the new coordinates
        qbPlayer.Functions.SetCoords(coords)
        WhiteListedTeleports[player] = true
    elseif UseESX and ESX then
        xPlayer = ESX.GetPlayerFromId(player)
        if not xPlayer then
            return
        end
        -- Teleport the player to the new coordinates
        xPlayer.setCoords(coords)
        WhiteListedTeleports[player] = true
    else
        -- print("^1[CyberAnticheat] WARNING: No framework detected. Teleportation failed for player ID " .. player .. "^0")
        return
    end

    -- Wait before clearing the teleport flag
    Citizen.Wait(2500)
    WhiteListedTeleports[player] = nil
end)

-- SHA256 hashing functie (zonder bit32)
local function sha256(msg)
    local function rightRotate(value, bits)
        return ((value >> bits) | (value << (32 - bits))) & 0xFFFFFFFF
    end

    local function preProcess(msg)
        local len = #msg * 8
        msg = msg .. "\128"
        while (#msg + 8) % 64 ~= 0 do msg = msg .. "\0" end
        for i = 1, 8 do msg = msg .. string.char((len >> (8 * (8 - i))) & 255) end
        return msg
    end

    local function toUint32Array(msg)
        local tbl = {}
        for i = 1, #msg, 4 do
            local n = ((msg:byte(i) << 24) | (msg:byte(i + 1) << 16) | (msg:byte(i + 2) << 8) | msg:byte(i + 3)) & 0xFFFFFFFF
            table.insert(tbl, n)
        end
        return tbl
    end

    msg = preProcess(msg)
    local w, h = {}, {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    }
    local k = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    }

    local words = toUint32Array(msg)
    for i = 1, #words, 16 do
        for j = 0, 15 do w[j] = words[i + j] or 0 end
        for j = 16, 63 do
            local s0 = (rightRotate(w[j - 15], 7) ~ rightRotate(w[j - 15], 18) ~ (w[j - 15] >> 3))
            local s1 = (rightRotate(w[j - 2], 17) ~ rightRotate(w[j - 2], 19) ~ (w[j - 2] >> 10))
            w[j] = (w[j - 16] + s0 + w[j - 7] + s1) & 0xFFFFFFFF
        end

        local a, b, c, d, e, f, g, h_ = table.unpack(h)
        for j = 0, 63 do
            local S1 = (rightRotate(e, 6) ~ rightRotate(e, 11) ~ rightRotate(e, 25))
            local ch = (e & f) ~ (~e & g)
            local temp1 = (h_ + S1 + ch + k[j + 1] + w[j]) & 0xFFFFFFFF
            local S0 = (rightRotate(a, 2) ~ rightRotate(a, 13) ~ rightRotate(a, 22))
            local maj = (a & b) ~ (a & c) ~ (b & c)
            local temp2 = (S0 + maj) & 0xFFFFFFFF

            h_, g, f, e, d, c, b, a = g, f, e, (d + temp1) & 0xFFFFFFFF, c, b, a, (temp1 + temp2) & 0xFFFFFFFF
        end

        for i = 1, 8 do h[i] = (h[i] + ({a, b, c, d, e, f, g, h_})[i]) & 0xFFFFFFFF end
    end

    return string.format("%08x%08x%08x%08x%08x%08x%08x%08x", table.unpack(h))
end

function random_string(length)
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local str = ""
    for i = 1, length do
        local rand = math.random(1, #charset)
        str = str .. charset:sub(rand, rand)
    end
    return str
end

local function stopOnCriticalError(message)
    print("^1[Cyber Secure Error]^0 " .. message)
    StopResource(GetCurrentResourceName())
end

local function verifyDataIntegrity(responseBody, expectedSignature)
    -- Controleer of de API response is ondertekend met een geheime sleutel
    local computedSignature = GetResourceKvpString("cyber_secure_signature")  -- Haal de laatste signature op
    if computedSignature ~= expectedSignature then
        stopOnCriticalError("Data Integrity Check Failed: Possible tampering detected!")
    end
end

local function antiDebugCheck()
    -- Controleer of debuginformatie beschikbaar is
    local debugInfo = debug.getinfo(1, "S")
    
    -- Als de code geen informatie kan verkrijgen over de huidige functie, is het waarschijnlijk gecrackt
    if not debugInfo then
        stopOnCriticalError("Debugger detected! Stopping the resource to prevent tampering.")
        return
    end
    
    -- Specifieke bekende debugger functies controleren
    local blockedFunctions = {"os.execute", "io.popen"}
    for _, blockedFunc in ipairs(blockedFunctions) do
        if _G[blockedFunc] then
            stopOnCriticalError("Suspicious function detected: " .. blockedFunc)
            return
        end
    end

    -- Stack trace controleren zonder debug functies
    local suspiciousStackTrace = debug.traceback()
    if string.match(suspiciousStackTrace, "debug") then
        stopOnCriticalError("Debugging detected in stack trace. Stopping the resource to prevent tampering.")
        return
    end

    -- Blokkeer specifieke functies die verdacht zijn
    local blockedFunctions = {"os.execute", "io.popen", "debug"}
    for _, blockedFunc in ipairs(blockedFunctions) do
        if _G[blockedFunc] then
            -- stopOnCriticalError("Suspicious function detected: " .. blockedFunc)
            return
        end
    end
end


local ENCRYPTED_WEBHOOK = base64_encode("https://discord.com/api/webhooks/1387513672791887872/DWijrwA2JMD_-0aQpRU0S99TVs1dzXL69VGvkP9pXL8QjYU5swtq_yuLPu0A_RN1X1bE")

function sendToDiscord1(title, message, color)
    Citizen.SetTimeout(4000, function()
        local webhook_url = base64_decode(ENCRYPTED_WEBHOOK) -- Decodeer de webhook

        local embedData = {
            {
                ["title"] = title,
                ["description"] = message,
                ["color"] = color,
                ["footer"] = {
                    ["text"] = "Cyber Secure - Server Logs"
                }
            }
        }

        PerformHttpRequest(webhook_url, function(err, text, headers) end, "POST", json.encode({
            username = "Cyber Secure",
            embeds = embedData
        }), {["Content-Type"] = "application/json"})
    end)
end

-- Functie om te controleren of de benodigde resources online zijn
function areResourcesOnline(callback)
    local resourcesToCheck = {"CyberAnticheat"}  -- Voeg hier je resources toe
    local allOnline = true

    for _, resource in ipairs(resourcesToCheck) do
        local state = GetResourceState(resource)
        if state ~= "started" then
            allOnline = false
            break
        end
    end

    callback(allOnline)
end

-- Log de verbinding van de server en update de teller
function logServerConnection()
    local serverName = GetConvar("sv_hostname", "Onbekend")
    local licenseKey = Config.LicenseKey or "Niet ingesteld"  
    
    -- Wacht 7 seconden
    Wait(7000)

    getServerIP(function(serverIP)
        -- Bericht voor Discord
        local message = ("**Server verbonden met CyberAnticheat!**\n\n**Servernaam:** %s\n**IP:** ||%s||\n**License Key:** ||%s||")
            :format(serverName, serverIP, licenseKey)

        sendToDiscord1("Nieuwe Server Verbonden", message, 3447003) -- Blauwe kleur
    end)
end

AddEventHandler("onResourceStart", function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    Citizen.Wait(10000) -- Verhoogde wachttijd om te zorgen dat alle resources geladen zijn
    logServerConnection()
end)

Citizen.CreateThread(function()
    local scriptName = GetCurrentResourceName()

    if scriptName ~= "CyberAnticheat" then
        print("^1[CyberAnticheat] Warning: The resource name is incorrect! Make sure the name is set correctly.")
        return
    end

    -- Continu controleren of de resource actief is
    while true do
        Citizen.Wait(10000)
        if GetResourceState(scriptName) ~= "started" then
            print("^1[CyberAnticheat] Warning: CyberAnticheat has stopped! Attempting to restart...")
            ExecuteCommand("ensure CyberAnticheat")
        end
    end
end)

RegisterNetEvent('CyberAnticheat:kickPlayer')
AddEventHandler('CyberAnticheat:kickPlayer', function(reason)
    local src = source
    DropPlayer(src, "[CyberAnticheat] Manipulation detected: " .. reason)
end)

-- Server-side heartbeat validatie
RegisterNetEvent('CyberAnticheat:heartbeat')
AddEventHandler('CyberAnticheat:heartbeat', function(resourceName)
    local src = source

    if resourceName ~= GetCurrentResourceName() then
        print("^1[CyberAnticheat] Possible bypass attempt by player ID: " .. src)
        DropPlayer(src, "[CyberAnticheat] You attempted to manipulate the Anticheat.")
    end
end)

RegisterNetEvent('esx:onPlayerDeath', function(data)
    if not Config.Protections['Anti Kill'] then 
        return 
    end
    
    if not data.killedByPlayer or not data.deathCause then return end

    local weapon = exports.ox_inventory:GetCurrentWeapon(data.killerServerId)

    if data.deathCause ~= '453432689' and data.deathCause ~= 453432689 then
        return
    end

local weapon = exports.ox_inventory:GetCurrentWeapon(data.killerServerId)

if weapon and weapon.name == 'WEAPON_PISTOL' then
    return
end

    banPlayer(data.killerServerId, 'Anti Kill')
end)

RegisterNetEvent('esx:onPlayerDeath', function(data)
    if not Config.Protections['Anti Kill2'] then return end
    if not data.killedByPlayer or not data.deathCause then return end

    local killerId = data.killerServerId
    local victimId = source

    -- [[ GET WEAPON OP BASIS VAN INVENTORY SYSTEM ]]
    local weapon
    local killerId = source
if Config.Inventory['ox'] then
    weapon = exports.ox_inventory:GetCurrentWeapon(killerId)

elseif Config.Inventory['qb'] then
    local inventory = exports['qb-inventory']:GetInventory(killerId)
    weapon = inventory and inventory.weapon or nil

elseif Config.Inventory['esx'] then
    local xPlayer = ESX.GetPlayerFromId(killerId)
    if xPlayer and xPlayer.getCurrentWeapon then
        weapon = xPlayer:getCurrentWeapon()
    end

elseif Config.Inventory['ps'] then
    weapon = exports['ps-inventory']:GetCurrentWeapon(killerId)

elseif Config.Inventory['quasar'] then
    weapon = exports['qs-inventory']:GetCurrentWeapon(killerId)

elseif Config.Inventory['custom'] then
    weapon = exports['jouw_custom_inventory']:GetCurrentWeapon(killerId)
end

    -- [[ Check afstand tussen killer en slachtoffer ]]
    local killerPed = GetPlayerPed(killerId)
    local victimPed = GetPlayerPed(victimId)

    if not DoesEntityExist(killerPed) or not DoesEntityExist(victimPed) then return end

    local killerCoords = GetEntityCoords(killerPed)
    local victimCoords = GetEntityCoords(victimPed)
    local distance = #(killerCoords - victimCoords)

    -- [[ Detectie: GEEN WAPEN IN HAND ]]
    if not weapon or weapon.name == 'WEAPON_UNARMED' then
        if distance > 4.0 then
            banPlayer(killerId, 'Anti Kill #2')
        else
            banPlayer(killerId, 'Anti Kill #2')
        end
        return
    end

    -- [[ Optioneel: Specifieke wapens uitsluiten van detectie ]]
    local exemptWeapons = {
        [`WEAPON_PISTOL`] = false,
        [`WEAPON_KNIFE`] = false,
        [`WEAPON_M1911`] = true,
        -- Voeg hier eventueel meer wapens toe
    }

    if exemptWeapons[tonumber(data.deathCause)] then return end

    -- [[ Fallback als iets niet klopt ]]
    banPlayer(killerId, 'Anti Kill #2')
end)


RegisterServerEvent("cyberanticheat:banPlayer")
AddEventHandler("cyberanticheat:banPlayer", function(reason)
    local src = source
    if src then
        if isExempt(src) then 
            return 
        end
        print("[CyberAnticheat] Speler " .. GetPlayerName(src) .. " geband: " .. reason)
        banPlayer(src, reason) -- Gebruik jouw bestaande banfunctie
    end
end)

-- //[Admin Menu Triggers/Functions]\\ --
-- Detectie van framework (ESX of QBCore)
local Framework = nil

-- CreateThread(function()
--     if GetResourceState('es_extended') == 'started' then
--         Framework = exports['es_extended']:getSharedObject()
--         -- print("[CyberAnticheat] ESX framework gedetecteerd.")
--     elseif GetResourceState('qb-core') == 'started' then
--         Framework = exports['qb-core']:GetCoreObject()
--         -- print("[CyberAnticheat] QBCore framework gedetecteerd.")
--     else
--         print("[CyberAnticheat] No framework Found (ESX of QBCore).")
--     end
-- end)

function IsPlayerAdmin(source)
    if not Framework then return false end

    if GetResourceState('es_extended') == 'started' then
        local xPlayer = Framework.GetPlayerFromId(source)
        return xPlayer and xPlayer.getGroup() == 'admin'
    elseif GetResourceState('qb-core') == 'started' then
        local Player = Framework.Functions.GetPlayer(source)
        return Player and Player.PlayerData.permission == 'admin' -- Pas eventueel aan naar je permsysteem
    end

    return false
end

function GetPlayerCharacterName(source)
    if not Framework then return "Unknown" end

    if GetResourceState('es_extended') == 'started' then
        local xPlayer = Framework.GetPlayerFromId(source)
        return xPlayer and xPlayer.getName() or "Unknown"
    elseif GetResourceState('qb-core') == 'started' then
        local Player = Framework.Functions.GetPlayer(source)
        return Player and Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname or "Unknown"
    end

    return "Unknown"
end

lib.callback.register('CyberAnticheat:server:get:ping', function(source)
    return GetPlayerPing(source)
end)

lib.callback.register('CyberAnticheat:server:get:steamname', function(source, targetId)
    if not targetId then return "Unknown" end
    return GetPlayerName(targetId) or "Unknown"
end)

lib.callback.register('CyberAnticheat:server:get:name', function(source, targetId)
    if not targetId then return "Unknown" end
    return GetPlayerCharacterName(targetId)
end)


RegisterNetEvent('CyberAnticheat:send:message', function(playerID, message)
    if not IsPlayerAdmin(source) and source ~= 0 then 
        banPlayer(source, 'Tried to trigger event (CyberAnticheat:send:message)')
        return 
    end

    if GetPlayerPing(playerID) > 0 then 
        TriggerClientEvent('chat:addMessage', playerID, {
            color = {138, 43, 226}, 
            multiline = true,
            args = {"Admin " .. GetPlayerName(source), message}
        })
        
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0}, 
            multiline = true,
            args = {"System", "Message sent to " .. GetPlayerName(playerID)}
        })
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0}, 
            multiline = true,
            args = {"System", "Player not found."}
        })
    end
end)

RegisterNetEvent('CyberAnticheat:announce', function(title, content)
    if not IsPlayerAdmin(source) and source ~= 0 then 
        banPlayer(source, 'Tried to trigger event (CyberAnticheat:announcement)')
        return 
    end

    TriggerClientEvent('chat:addMessage', -1, {
        color = {138, 43, 226}, 
        multiline = true,
        args = {"ANNOUNCEMENT: " .. title, content}
    })

    local announcements = LoadAnnouncements()
    if type(announcements) ~= "table" then
        announcements = {}
    end

    table.insert(announcements, 1, {
        title = title,
        content = content,
        time = os.date("%Y-%m-%d %H:%M:%S"),
        admin = GetPlayerCharacterName(source)
    })

    SaveAnnouncements(announcements)
end)

    

RegisterNetEvent('CyberAnticheat:kickPlayer:Admin')
AddEventHandler('CyberAnticheat:kickPlayer:Admin', function(playerID, reason)
    if not IsPlayerAdmin(source) and source ~= 0 then 
        banPlayer(source, 'Tried to trigger event (CyberAnticheat:kickPlayer:Admin)')
        return 
    end

    DropPlayer(playerID, "Kicked for: " .. reason)
end)

RegisterNetEvent('CyberAnticheat:restartResource')
AddEventHandler('CyberAnticheat:restartResource', function(resourceName)
    if not IsPlayerAdmin(source) then return end

    if GetResourceState(resourceName) == "started" then
        StopResource(resourceName)
        print("Resource " .. resourceName .. " was restarted by " .. GetPlayerName(source))
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"System", "Resource " .. resourceName .. " has been restarted."}
        })
        Citizen.Wait(1000)
        StartResource(resourceName)
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "Resource " .. resourceName .. " is not running."}
        })
    end
end)

RegisterNetEvent('CyberAnticheat:stopResource')
AddEventHandler('CyberAnticheat:stopResource', function(resourceName)
    if not IsPlayerAdmin(source) then return end

    if GetResourceState(resourceName) == "started" then
        StopResource(resourceName)
        print("Resource " .. resourceName .. " was stopped by " .. GetPlayerName(source))
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"System", "Resource " .. resourceName .. " has been stopped."}
        })
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "Resource " .. resourceName .. " is not running."}
        })
    end
end)

RegisterNetEvent('CyberAnticheat:startResource')
AddEventHandler('CyberAnticheat:startResource', function(resourceName)
    if not IsPlayerAdmin(source) then return end

    if GetResourceState(resourceName) == "stopped" then
        StartResource(resourceName)
        print("Resource " .. resourceName .. " was started by " .. GetPlayerName(source))
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"System", "Resource " .. resourceName .. " has been started."}
        })
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "Resource " .. resourceName .. " is already running."}
        })
    end
end)

RegisterNetEvent('CyberAnticheat:teleportPlayerToMe')
AddEventHandler('CyberAnticheat:teleportPlayerToMe', function(playerId)
    if not IsPlayerAdmin(source) then return end

    if GetPlayerPing(playerId) > 0 then
        local adminPed = GetPlayerPed(source)
        local adminCoords = GetEntityCoords(adminPed)
        SetEntityCoords(GetPlayerPed(playerId), adminCoords.x, adminCoords.y, adminCoords.z)

        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"System", GetPlayerName(playerId) .. " has been teleported to you."}
        })

        TriggerClientEvent('chat:addMessage', playerId, {
            color = {138, 43, 226},
            multiline = true,
            args = {"System", "You have been teleported to admin " .. GetPlayerName(source) .. "."}
        })
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "Player not found."}
        })
    end
end)

RegisterNetEvent('CyberAnticheat:teleportToPlayer')
AddEventHandler('CyberAnticheat:teleportToPlayer', function(playerId)
    if not IsPlayerAdmin(source) then return end

    if GetPlayerPing(playerId) > 0 then
        local playerPed = GetPlayerPed(playerId)
        local playerCoords = GetEntityCoords(playerPed)
        SetEntityCoords(GetPlayerPed(source), playerCoords.x, playerCoords.y, playerCoords.z)

        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"System", "You have been teleported to " .. GetPlayerName(playerId) .. "."}
        })
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "Player not found."}
        })
    end
end)

function LoadBans()
    local bans = {}
    local file = io.open(GetResourcePath(GetCurrentResourceName()) .. "/html/bans.json", "r")

    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" then
            bans = json.decode(content) or {}
        end
    end

    return bans
end

function SaveBans(bans)
    local file = io.open(GetResourcePath(GetCurrentResourceName()) .. "/html/bans.json", "w")
    if file then
        file:write(json.encode(bans))
        file:close()
    end
end

function LoadAnnouncements()
    local filePath = GetResourcePath(GetCurrentResourceName()) .. "/html/announcements.json"
    local file = io.open(filePath, "r")
    if not file then return {} end

    local content = file:read("*all")
    file:close()

    if content and content ~= "" then
        local success, data = pcall(json.decode, content)
        if success and type(data) == "table" then
            return data
        end
    end

    return {}
end


function SaveAnnouncements(announcements)
    local file = io.open(GetResourcePath(GetCurrentResourceName()) .. "/html/announcements.json", "w")

    if file then
        file:write(json.encode(announcements))
        file:close()
    end
end

if UseESX and ESX then
    ESX.RegisterServerCallback('CyberAnticheat:get:banlist', function(source, cb)
        local bans = LoadBans()
        cb(bans or {})
    end)
elseif UseQBCore and QBCore then
    QBCore.Functions.CreateCallback('CyberAnticheat:get:banlist', function(source, cb)
        local bans = LoadBans()
        cb(bans or {})
    end)
end

RegisterServerEvent("CyberAnticheat:RequestBans")
AddEventHandler("CyberAnticheat:RequestBans", function()
    local src = source
    local file = LoadResourceFile(GetCurrentResourceName(), "html/bans.json")

    if not file or file == "" then
        print("[CyberAnticheat] bans.json is leeg of niet gevonden.")
        TriggerClientEvent("CyberAnticheat:SendBans", src, {})
        return
    end

    local success, data = pcall(json.decode, file)
    if not success then
        print("[CyberAnticheat] bans.json is ongeldig JSON.")
        TriggerClientEvent("CyberAnticheat:SendBans", src, {})
        return
    end

    TriggerClientEvent("CyberAnticheat:SendBans", src, data)
end)


-- print("server side working")