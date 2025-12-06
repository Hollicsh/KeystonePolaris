local AddOnName, KeystonePolaris = ...

-- Define a single source of truth for dungeon data
KeystonePolaris.LEGION_DUNGEON_DATA = {
    -- Format: [shortName] = {id = dungeonID, bosses = {{bossID, percent, shouldInform, bossOrder, journalEncounterID}, ...}}
    SotT = { -- Seat of the Triumvirate
        id = 239,
        mapID = 1753,
        teleportID = 445424,
        bosses = {
            {1, 39.68, false, 1, 1979},
            {2, 45.83, false, 2, 1980},
            {3, 81.26, true, 3, 1981},
            {4, 100, true, 4, 1982}
        }
    }
}
