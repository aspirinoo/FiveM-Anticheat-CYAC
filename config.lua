Config = Config or {}
-- VERSION 6.0.0.6
-- MAKE YOUR CONFIG IN DASHBOARD HTTPS://MY.CYBERSECURES.EU

-- //[Main Config]\\ --
Config.Servername = "Server Name"
Config.LicenseKey = ""
Config.Discordinvite = "https://discord.gg/serverinvite"
Config.Language = "en" -- or "nl", "de", "fr", "sp", "el", "sv", "tr"
Config.ServerLogo = "https://cybersecures.eu/app/main/theme/assets/img/uploads/41eef524a401f5751cb260a061236eba.png?v=1737290234"
Config.MinimumOnlineSecondsBeforeBan = 45 -- Number of seconds a player must be online for a ban to take effect
Config.RequireSteam = true
Config.LogIPInformation = true

-- //[GROUPS TO EXCLUDE FROM BANS (WHITELIST GROUP) ]\\ --
-- not working use ace perms add_ace identifier.steam:110000112345678 cyberwhitelist.allow allow
Config.EXEMPT_GROUPS = { 
    ["owner"] = true,
    ["admin"] = true,
    ["staff"] = true
}

-- //[FOR THE COMMAND AND MENU (WHITELIST GROUP) ]\\ -- 
-- not working use ace perms add_ace identifier.steam:110000112345678 cybermenu.allow allow
Config.ADMIN_GROUPS = {
    ["admin"] = true
}

-- //[Inventory Config]\\ --
Config.Inventory = {
    ['esx'] = false,     -- Use Esx_addoninventory
    ['qb'] = false,     -- Use Qb_inventory
    ['ox'] = false,       -- Use ox_inventory
    ['ps'] = false,      -- Use ps-inventory
    ['quasar'] = false,  -- Use Quasar Inventory
    ['custom'] = false   -- Set to true to use your own inventory system
}

-- //[Custom Inventory Config]\\ --
if Config.Inventory['custom'] then
    Config.CustomInventory = {
        getWeapon = function()
            -- ⚠️ Customize this feature for your own inventory system! or set your own custom export here
            return exports["my-custom-inventory"]:getCurrentWeapon()
        end
    }
end

Config.Protections = {

    -- //[Player]\\ --
    ['Anti Noclip'] = true,
    ['Anti Noclip2'] = true,
    ['Anti Noclip3'] = true,
    ['Anti Noclip4'] = true,
    ['Anti Noclip5'] = true,
    ['Anti Bebetter Noclip'] = true,
    ['Anti Parachute Noclip'] = true,
    ['Anti Godmode'] = true,
    ['Anti Godmode2'] = true,
    ['Anti Godmode3'] = true,
    ['Anti Semi Godmode'] = true,
    ['Armour Detection'] = true,
    ['Anti invisible'] = true,
    ['Anti invisible2'] = true,
    ['Anti Teleport'] = true,
    ['Anti Teleport2'] = true,
    ['Anti Speedhack'] = true,
    ['Anti Fast Run'] = true,
    ['Anti SuperJump'] = true, -- can be helpfull to anti noclip TURN IT ON
    ['Anti SuperJump2'] = true,
    ['Anti Night/ThermalVision'] = true,
    ['Anti Infinite Stamina'] = true, -- [BETA]

    -- //[Game]\\ --  
    ['Anti Super Punch'] = true,
    ['Anti Model Changer'] = true,
    ['Anti Rape Player'] = true, -- [BETA]
    ['Anti Lua Freeze'] = true, -- [BETA]
    ['Anti Player On Fire'] = true, -- [BETA]
    ['Anti Npc Hijack'] = true,
    ['Anti Solo Session'] = true,
    
    -- //[Weapons]\\ -- 
    ['Anti Spawn Weapon'] = true, -- IF YOU WANT TO USE THIS FUNCTION SET ALSO THE SECOND ONE ON AND THIS ONE  
    ['Anti Spawn Weapon2'] = true,
    ['Anti Spawn Weapon3'] = true,
    ['Anti Spoofed Damage/Weapon'] = true, -- If you want hackers not spawn weapons turn this one on 
    ['Anti Shoot Without Weapon'] = true, -- [BETA]
    ['Anti NoRecoil'] = true, -- [BETA]
    ['Anti NoReload'] = true, -- [BETA]
    ['Anti Explosion Bullet'] = true, -- [BETA]
    ['Anti Infinite Ammo'] = true,
    ['Anti Silent Aim'] = true,
    ['Anti Kill Punch'] = true, -- [BETA]
    ['Anti Weapon Damage Changer'] = true, -- [BETA]
    ['Anti Explosion Bullet2'] = true, -- [BETA]

    -- //[Vehicle]\\ -- 
    ['Anti Carry Vehicle'] = true,
    ['Anti Throw Vehicle'] = true,
    ['Anti Boost vehicle'] = true,
    ['Anti Spawn Vehicle'] = true,
    ['Anti Spawn Vehicle2'] = true,
    ['Anti Spawn Vehicle3'] = true, -- [BETA]
    ['Anti Spawn Vehicle/Entity'] = true,
    ['Anti Vehicle Weapon'] = true, 
    ['Anti Plate Changer'] = true,
    ['Anti Launch/Fly Vehicle'] = true,
    ['Anti Car Speed Hack'] = true,
    ['Anti Kick Player Form Vehicle'] = true,

    -- //[Object/Particles]\\ --
    ['Anti Spawn Props'] = true, -- check de client config for this its down there
    ['Anti Aggresive Peds'] = true, -- [BETA]
    ['Blacklisted Particles'] = true, -- [BETA]

    -- //[Explosion]\\ --
    ['Anti Ai Explosion'] = true,
    ['Anti Explosion'] = true,
    ['Anti Silent Explosion'] = true,
    ['Anti Phone Explosion'] = true,
    ['Anti Invisible Explosion'] = true,

    -- //[Resources]\\ --
    ['Anti Spam Trigger'] = true, -- [BETA] 

    -- //[Cheats]\\ --
    ['Anti Freecam'] = true,
    ['Anti Freecam2'] = true,
    ['Anti Freecam3'] = true,
    ['Anti Spectate'] = true,

    -- //[Injector]\\ --
    ['Cheat Ai Detection'] = true,
    ['Anti Susano'] = true,
    ['Anti TZX'] = true,
    ['Anti Skript'] = true,
    ['Anti Lua Menu'] = true,

    -- //[Online]\\ --
    ['Anti Kill'] = true,
    ['Anti Kill2'] = true, 
    ['Anti Taze'] = true,
    ['Anti Inventory Exploit'] = true,  -- OX ONLY
    ['Anti Player Blips'] = true,  -- [BETA] MOET NOG IN CONFIG SITE

    -- //[Network]\\ --
    ['Anti Vpn'] = true, -- This functions help to no spoofing
    ['Anti Afk'] = true, -- BETA

}

-- //[Config kick or ban]\\
Config.EnforcementActions = {  -- ban or kick
    ['Anti Noclip'] = "ban",
    ['Anti Noclip2'] = "ban",
    ['Anti Noclip3'] = "ban",
    ['Anti Bebetter Noclip'] = "ban",
    ['Anti Parachute Noclip'] = "ban",
    ['Anti Godmode'] = "ban",
    ['Armour Detection'] = "ban",
    ['Anti invisible'] = "ban",
    ['Anti invisible2'] = "ban",
    ['Anti Teleport'] = "ban",
    ['Anti Speedhack'] = "ban",
    ['Anti SuperJump'] = "ban",
    ['Anti SuperJump2'] = "ban",
    ['Anti Night/ThermalVision'] = "ban",
    ['Anti Infinite Stamina'] = "ban",
    ['Anti Super Punch'] = "ban",
    ['Anti Model Changer'] = "ban",
    ['Anti Rape Player'] = "ban",
    ['Anti Lua Freeze'] = "ban",
    ['Anti Player On Fire'] = "ban",
    ['Anti Npc Hijack'] = "ban",
    ['Anti Spawn Weapon'] = "ban",
    ['Anti Spawn Weapon2'] = "ban",
    ['Anti Spawn Weapon3'] = "ban",
    ['Anti Spoofed Damage/Weapon'] = "ban",
    ['Anti Shoot Without Weapon'] = "ban",
    ['Anti NoRecoil'] = "ban",
    ['Anti NoReload'] = "ban",
    ['Anti Explosion Bullet'] = "ban",
    ['Anti Explosion Bullet2'] = "ban",
    ['Anti Infinite Ammo'] = "ban",
    ['Anti Silent Aim'] = "ban",
    ['Anti Kill Punch'] = "ban",
    ['Anti Carry Vehicle'] = "ban",
    ['Anti Throw Vehicle'] = "ban",
    ['Anti Boost vehicle'] = "ban",
    ['Anti Spawn Vehicle'] = "ban",
    ['Anti Spawn Vehicle/Entity'] = "ban",
    ['Anti Vehicle Weapon'] = "ban", 
    ['Anti Plate Changer'] = "ban",
    ['Anti Launch/Fly Vehicle'] = "ban",
    ['Anti Spawn Props'] = "ban",
    ['Anti Aggresive Peds'] = "ban",
    ['Anti Ai Explosion'] = "ban",
    ['Anti Explosion'] = "ban",
    ['Anti Silent Explosion'] = "ban",
    ['Anti Phone Explosion'] = "ban",
    ['Anti Invisible Explosion'] = "ban",
    ['Anti Freecam'] = "ban",
    ['Anti Freecam2'] = "ban",
    ['Anti Freecam3'] = "ban",
    ['Anti Spectate'] = "ban",
    ['Cheat Ai Detection'] = "ban",
    ['Anti Susano'] = "ban",
    ['Anti TZX'] = "ban",
    ['Anti Skript'] = "ban",
    ['Anti Lua Menu'] = "ban",
    ['Anti Kill'] = "ban",
    ['Anti Kill2'] = "ban",
    ['Anti Taze'] = "ban",
    ['Anti Inventory Exploit'] = "ban",
    ['Blacklisted Particles'] = "ban",
    ['Anti Godmode2'] = "ban",
    ['Anti Godmode3'] = "ban",
    ['Anti Teleport2'] = "ban",
    ['Anti Solo Session'] = "ban",
    ['Anti Car Speed Hack'] = "ban",
    ['Anti Noclip4'] = "ban",
    ['Anti Noclip5'] = "ban",
    ['Anti Weapon Damage Changer'] = "ban",
    ['Anti Player Blips'] = "ban",
    ['Anti Fast Run'] = "ban",
    ['Anti Semi Godmode'] = "ban"
}


-- //[Client Vehicle Config]\\ -

Config.AllowedCarSpawnResources = { "cardealer", "policejob", "ems_job" }

-- //[Inventory Exploit Config]\\ -
Config.AllowedResources = { "handup_search", "policejob", "ems_job" }
Config.InventoryAllowedJobs = { police = true, ambulance = true }

-- //[Client Config]\\ --
Config.Client = {
    ['MAX ARMOUR'] = 20,
    ['Max Distance Teleporting'] = 500.0,
    ['Anti invisible'] = {
        ['Whitelisted Areas'] = {
            {coords = vec3(-34.0726, -1097.2799, 26.4224), radius = 20}
        }
    },
    ['Plate Changing'] = {
        ['Whitelisted Areas'] = {
            {coords = vec3(-34.0726, -1097.2799, 26.4224), radius = 20}
        }
    },
    ['Noclip/Freecam Whitelist'] = { 
        ['Whitelisted Areas'] = {
            {coords = vec3(-34.0726, -1097.2799, 26.4224), radius = 20}
       }
    },    
    ['God Mode Protections'] = {
        ['1'] = false,
        ['2'] = true,
        ['3'] = true,
        ['4'] = true,
    },
    ['Explosion Whitelist'] = {
        [2] = false,
        [4] = false,
        [7] = false,
    },
    ['Explosion Blacklist'] = {
        [59] = true, -- Vliegtuigbom
        [60] = true, -- Gastank
        [61] = true, -- Benzinetank
    },
    ['AntiGiveWeaponList'] = {
        "WEAPON_KNIFE", "WEAPON_PISTOL", "WEAPON_PUMPSHOTGUN", "WEAPON_ASSAULTRIFLE", "WEAPON_DAGGER",
        "WEAPON_BAT", "WEAPON_BOTTLE", "WEAPON_CROWBAR", "WEAPON_FLASHLIGHT", "WEAPON_GOLFCLUB",
        "WEAPON_HAMMER", "WEAPON_HATCHET", "WEAPON_KNUCKLE", "WEAPON_MACHETE", "WEAPON_SWITCHBLADE",
        "WEAPON_NIGHTSTICK", "WEAPON_WRENCH", "WEAPON_BATTLEAXE", "WEAPON_POOLCUE", "WEAPON_STONE_HATCHET",
        "WEAPON_PISTOL_MK2", "WEAPON_COMBATPISTOL", "WEAPON_APPISTOL", "WEAPON_STUNGUN", "WEAPON_PISTOL50",
        "WEAPON_SNSPISTOL", "WEAPON_SNSPISTOL_MK2", "WEAPON_HEAVYPISTOL", "WEAPON_VINTAGEPISTOL",
        "WEAPON_FLAREGUN", "WEAPON_MARKSMANPISTOL", "WEAPON_REVOLVER", "WEAPON_REVOLVER_MK2", "WEAPON_DOUBLEACTION",
        "WEAPON_RAYPISTOL", "WEAPON_CERAMICPISTOL", "WEAPON_NAVYREVOLVER", "WEAPON_MICROSMG", "WEAPON_SMG",
        "WEAPON_SMG_MK2", "WEAPON_ASSAULTSMG", "WEAPON_COMBATPDW", "WEAPON_MACHINEPISTOL", "WEAPON_MINISMG",
        "WEAPON_RAYCARBINE", "WEAPON_PUMPSHOTGUN_MK2", "WEAPON_SAWNOFFSHOTGUN", "WEAPON_ASSAULTSHOTGUN",
        "WEAPON_BULLPUPSHOTGUN", "WEAPON_MUSKET", "WEAPON_HEAVYSHOTGUN", "WEAPON_DBSHOTGUN", "WEAPON_AUTOSHOTGUN",
        "WEAPON_ASSAULTRIFLE_MK2", "WEAPON_CARBINERIFLE", "WEAPON_CARBINERIFLE_MK2", "WEAPON_ADVANCEDRIFLE",
        "WEAPON_SPECIALCARBINE", "WEAPON_SPECIALCARBINE_MK2", "WEAPON_BULLPUPRIFLE", "WEAPON_BULLPUPRIFLE_MK2",
        "WEAPON_COMPACTRIFLE", "WEAPON_MG", "WEAPON_COMBATMG", "WEAPON_COMBATMG_MK2", "WEAPON_GUSENBERG",
        "WEAPON_SNIPERRIFLE", "WEAPON_HEAVYSNIPER", "WEAPON_HEAVYSNIPER_MK2", "WEAPON_MARKSMANRIFLE",
        "WEAPON_MARKSMANRIFLE_MK2", "WEAPON_RPG", "WEAPON_GRENADELAUNCHER", "WEAPON_GRENADELAUNCHER_SMOKE",
        "WEAPON_MINIGUN", "WEAPON_FIREWORK", "WEAPON_RAILGUN", "WEAPON_HOMINGLAUNCHER", "WEAPON_COMPACTLAUNCHER",
        "WEAPON_RAYMINIGUN", "WEAPON_GRENADE", "WEAPON_BZGAS", "WEAPON_SMOKEGRENADE", "WEAPON_FLARE",
        "WEAPON_MOLOTOV", "WEAPON_STICKYBOMB", "WEAPON_PROXMINE", "WEAPON_SNOWBALL", "WEAPON_PIPEBOMB",
        "WEAPON_BALL", "WEAPON_FIREEXTINGUISHER", "WEAPON_HAZARDCAN"
    },
    ['AntiTaze'] = {
        ['TazerWeaponHash'] = GetHashKey("WEAPON_STUNGUN"),
        ['MaxTazeDistance'] = 10.0  
    },
    ['AntiAFK'] = {
        MaxAFKTime = 300,
    },
    ['BlacklistedParticles'] = {
        "scr_xs_dr", "scr_rcbarry1", "scr_rcbarry2"
    },
    ['AntiSpamTrigger'] = { 
        ResetLimit = true,
        ResetTime = 10,
        Triggers = {
            ["inventory:open"] = {
                limit = 10,
                action = "kick"
            },
            ["example:trigger"] = {
                limit = 5,
                action = "ban"
            },
        }
    }
}


-- //[Props Config]\\ --

-- here can you translate hash to prop name https://gtahash.ru/
Config.BlacklistedProps = {
    "prop_ld_bomb",
    "prop_air_bigradar",   
}

-- //[DISCORD LOGS]\\ -- 
Config.mainLogs = "" -- Main Logs
Config.TriggerResourceslogs = "" -- Trigger and Resources Logs
Config.logsConnection = "" -- Connection/Disconnection Logs
Config.logsBans = "" -- Bans/Unbans Logs