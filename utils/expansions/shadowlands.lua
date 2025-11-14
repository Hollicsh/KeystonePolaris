local AddOnName, KeystonePolaris = ...

-- Define a single source of truth for dungeon data
KeystonePolaris.SL_DUNGEON_DATA = {
    -- Format: [shortName] = {id = dungeonID, bosses = {{bossID, percent, shouldInform, bossNum}, ...}}
    MoTS = {
        id = 375,
        mapID = 2290,
        teleportID = 354464,
        bosses = {
            {1, 33.10, false, 1},
            {2, 63.45, false, 2},
            {3, 100, true, 3}
        }
    },
    NW = {
        id = 376,
        mapID = 2286,
        teleportID = 354462,
        bosses = {
            {1, 22.59, false, 1},
            {2, 76.81, true, 2},
            {3, 100, true, 3},
            {4, 100, true, 4}
        }
    },
    ToP = {
        id = 382,
        mapID = 2293,
        teleportID = 354467,
        bosses = {
            {1, 7.01, false, 1},
            {2, 37.27, false, 2},
            {3, 71.59, false, 3},
            {4, 100, false, 4},
            {5, 100, true, 5}
        }
    },
    TSoW = {
        id = 391,
        mapID = 2441,
        teleportID = 367416,
        bosses = {
            {1, 31.67, false, 1},
            {2, 57.22, false, 2},
            {3, 91.67, true, 3},
            {4, 77.22, false, 4},
            {5, 100, true, 5}
        }
    },
    TSLG = {
        id = 392,
        mapID = 2441,
        teleportID = 367416,
        bosses = {
            {1, 51.45, false, 1},
            {2, 75.43, false, 2},
            {3, 100, true, 3}
        }
    },
    HoA = {
        id = 378,
        mapID = 2287,
        teleportID = 354465,
        bosses = {
            {1, 57.73, false, 1},
            {2, 79.83, false, 2},
            {3, 92.49, true, 3},
            {4, 100, true, 4}
        }
    }
}
