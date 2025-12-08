local AddOnName, KeystonePolaris = ...

-- Define a single source of truth for dungeon data
KeystonePolaris.WOTLK_DUNGEON_DATA = {
    -- Format: [shortName] = {id = dungeonID, bosses = {{bossID, percent, shouldInform, bossOrder, journalEncounterID}, ...}}
    PoS = { -- Pit of Saron
        id = 556,
        mapID = 658,
        displayName = "Pit of Saron",
        teleportID = 445424,
        bosses = {
            {1, 39.68, false, 1, 608, "Forgemaster Garfrost"},
            {2, 45.83, false, 2, 609, "Ick and Krick"},
            {3, 100, true, 3, 610, "Scourgelord Tyrannus"}
        }
    }
}
