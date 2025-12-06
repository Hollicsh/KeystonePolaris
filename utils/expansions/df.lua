local AddOnName, KeystonePolaris = ...

-- Define a single source of truth for dungeon data
KeystonePolaris.DF_DUNGEON_DATA = {
    -- Format: [shortName] = {id = dungeonID, bosses = {{bossID, percent, shouldInform, bossOrder, journalEncounterID}, ...}}
    AA = { -- Algeth'ar Academy
        id = 402,
        mapID = 2526,
        teleportID = 445424,
        bosses = {
            {1, 39.68, false, 1, 2495},
            {2, 45.83, false, 2, 2512},
            {3, 81.26, true, 3, 2509},
            {4, 100, true, 4, 2514}
        }
    }
}
