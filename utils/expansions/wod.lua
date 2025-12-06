local AddOnName, KeystonePolaris = ...

-- Define a single source of truth for dungeon data
KeystonePolaris.WOD_DUNGEON_DATA = {
    -- Format: [shortName] = {id = dungeonID, bosses = {{bossID, percent, shouldInform, bossOrder, journalEncounterID}, ...}}
    SKY = { -- Skyreach
        id = 161,
        mapID = 1209,
        teleportID = 445424,
        bosses = {
            {1, 39.68, false, 1, 965},
            {2, 45.83, false, 2, 966},
            {3, 81.26, true, 3, 967},
            {4, 100, true, 4, 968}
        }
    }
}
