local AddOnName, KeystonePolaris = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true);

KeystonePolaris.Changelog[3700] = {
    version_string = "3.7",
    release_date = "2026/04/08",
    header = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            title = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t |cffffd700A smoother interface, at last|r",
            text = "This update gives the overall experience a real refresh. The positioning mode has been redesigned to feel more intuitive, easier to read, and more comfortable to use, while the settings layout is now clearer as well, making Keystone Polaris smoother to use every day. A huge thank you to [whatisboom] for the valuable help on this version.",
        },
        ["frFR"] = {
            title = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t |cffffd700Une interface plus agreable, enfin|r",
            text = "Cette mise a jour apporte un vrai coup de frais à l'expérience d'utilisation. Le mode de positionnement a été repensé pour être plus intuitif, plus lisible et plus confortable, tandis que l'organisation des options gagne aussi en clarté pour rendre Keystone Polaris plus agréable à utiliser au quotidien. Un énorme merci à [whatisboom] pour son aide précieuse sur cette version.",
        },
        ["koKR"] = {},
        ["ruRU"] = {},
        ["deDE"] = {},
        ["esES"] = {},
        ["esMX"] = {},
        ["itIT"] = {},
        ["ptBR"] = {}
    },
    important = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            "The positioning mode is now easier to use, with a clearer drag-and-drop flow, an alignment grid, a dimmed background, dedicated controls, and better visual feedback while moving the UI.",
        },
        ["frFR"] = {
            "Le mode de positionnement est maintenant plus simple à utiliser, avec un déplacement plus clair de l'interface, une grille d'alignement, un fond assombri, des contrôles dédiés et un meilleur retour visuel.",
        },
        ["koKR"] = {},
        ["ruRU"] = {},
        ["deDE"] = {},
        ["esES"] = {},
        ["esMX"] = {},
        ["itIT"] = {},
        ["ptBR"] = {}
    },
    new = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            "Added an [About] page with contributors and support links.",
            "Reworked the settings panel into a tree layout with dedicated sub-pages for a clearer and more comfortable navigation experience.",
        },
        ["frFR"] = {
            "Ajout d'une page [À propos] avec les contributeurs et les liens de support.",
            "Réorganisation du panneau d'options sous la forme d'une arborescence avec des sous-pages dédiées pour rendre la navigation plus claire et plus agréable.",
        },
        ["koKR"] = {},
        ["ruRU"] = {},
        ["deDE"] = {},
        ["esES"] = {},
        ["esMX"] = {},
        ["itIT"] = {},
        ["ptBR"] = {}
    },
    bugfix = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            "Fixed a few positioning mode issues that could show up in combat, when pressing [ESC], or while closing the mode.",
            "Fixed an issue where changing one color could unexpectedly affect another preview.",
            "Fixed the MDT mob percentage option so it now enables and disables more reliably.",
        },
        ["frFR"] = {
            "Correction de quelques soucis du mode de positionnement pouvant apparaître en combat, en appuyant sur [ESC] ou à la fermeture du mode.",
            "Correction d'un problème où modifier une couleur pouvait aussi changer un autre aperçu de manière inattendue.",
            "Correction de l'option MDT liée au pourcentage des monstres, qui s'active et se désactive désormais plus fiablement.",
        },
        ["koKR"] = {},
        ["ruRU"] = {},
        ["deDE"] = {},
        ["esES"] = {},
        ["esMX"] = {},
        ["itIT"] = {},
        ["ptBR"] = {}
    },
    improvment = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            "Updated [prefixColor] to use [color.prefix], with an automatic migration for existing settings.",
            "The [Group Reminder] popup now reopens where you left it after a reload.",
            "Improved the locale sync and validation workflow to make translations easier to maintain.",
        },
        ["frFR"] = {
            "Mise à jour du stockage de [prefixColor] vers [color.prefix], avec migration automatique des paramètres existants.",
            "La popup [Rappel de groupe] retrouve maintenant sa position après un rechargement de l'interface.",
            "Amélioration des outils de synchronisation et de validation des traductions pour faciliter la maintenance des locales.",
        },
        ["koKR"] = {},
        ["ruRU"] = {},
        ["deDE"] = {},
        ["esES"] = {},
        ["esMX"] = {},
        ["itIT"] = {},
        ["ptBR"] = {}
    }
}
