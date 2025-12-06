local AddOnName, KeystonePolaris = ...

-- Define a single source of truth for dungeon data
KeystonePolaris.MIDNIGHT_DUNGEON_DATA = {
    -- Format: [shortName] = {id = dungeonID, bosses = {{bossID, percent, shouldInform, bossOrder, journalEncounterID}, ...}}
    MAGI = { -- Magisters' Terrace
        id = 558,
        mapID = 2811,
        displayName = "Magisters' Terrace",
        teleportID = 445417,
        bosses = {
            {1, 37.75, false, 1, 2659, "Arcanotron Custos"},
            {2, 73.50, false, 2, 2661, "Seranel Sunlash"},
            {3, 100, false, 3, 2660, "Gemellus"},
            {4, 100, true, 4, 2662, "Degentrius"}
        }
    },
    MAIS = { -- Maisara Caverns
        id = 560,
        mapID = 2874,
        displayName = "Maisara Caverns",
        teleportID = 445417,
        bosses = {
            {1, 37.75, false, 1, 2810, "Muro'jin and Nekraxx"},
            {2, 73.50, false, 2, 2811, "Vordaza"},
            {3, 100, true, 3, 2812, "Rak'tul, Vessel of Souls"},
        }
    },
    NPX = { -- Nexus-Point Xenas
        id = 559,
        mapID = 2915,
        displayName = "Nexus-Point Xenas",
        teleportID = 445417,
        bosses = {
            {1, 37.75, false, 1, 2813, "Chief Corewright Kasreth"},
            {2, 73.50, false, 2, 2814, "Corewarden Nysarra"},
            {3, 100, true, 3, 2815, "Lothraxion"},
        }
    },
    WIS = { -- Windrunner Spire
        id = 557,
        mapID = 2805,
        displayName = "Windrunner Spire",
        teleportID = 445417,
        bosses = {
            {1, 37.75, false, 1, 2655, "Emberdawn"},
            {2, 73.50, false, 2, 2656, "Derelict Duo"},
            {3, 100, true, 3, 2657, "Commander Kroluk"},
            {4, 100, true, 4, 2658, "The Restless Heart"},
        }
    },
}
