Config = {}

-- Debug Mode: Enables print diagnostics
Config.Debug = true

-- Dirty Money settings (used for money washing)
Config.DirtyMoney = {
    type = "item", -- Options: "item" or "account"
    name = "markedbills", -- Item name if type is "item" (e.g. markedbills)
    accountName = "black_money" -- Account name if type is "account" (e.g. black_money)
}

-- Interaction setup
-- Options: "target" (use Target script) or "marker" (use DrawMarker + text ui)
Config.Interaction = "target"
Config.TargetScript = "ox_target" -- Options: "ox_target", "qb-target", "qbx_target"

-- Minimum boss grade level to open the Management panel (if the player job doesn't define isboss metadata)
Config.MinBossGrade = 4

-- Wash settings
Config.WashingTime = 5000 -- Time in ms to wash money (progress bar)

-- UI Web Path for Item Images (Loads straight from active inventory to avoid duplicate assets)
Config.ItemImagePath = "nui://ox_inventory/web/images/"

-- Gang System integration (specifically for cb-gangsystem turf ownership check)
Config.GangSystem = {
    enabled = true, -- Set to true to automatically link black market ownership to controlled turfs
    resourceName = "cb-gangsystem" -- Name of the cb-gangsystem resource folder
}

-- Crafting Recipes
-- Configure crafting times and required items
Config.CraftingRecipes = {
    {
        item = "lockpick",
        label = "Lockpick",
        time = 5000, -- Time in ms
        materials = {
            { item = "iron", count = 3, label = "Iron Ore" },
            { item = "steel", count = 1, label = "Steel Bar" }
        }
    },
    {
        item = "weapon_pistol",
        label = "Pistol",
        time = 15000,
        materials = {
            { item = "steel", count = 15, label = "Steel Bar" },
            { item = "pistol_parts", count = 1, label = "Pistol Frame" },
            { item = "spring", count = 3, label = "Metal Spring" }
        }
    },
    {
        item = "pistol_ammo",
        label = "Pistol Ammo (x24)",
        time = 6000,
        materials = {
            { item = "copper", count = 5, label = "Copper Chunk" },
            { item = "gunpowder", count = 2, label = "Gunpowder" }
        }
    },
    {
        item = "thermite",
        label = "Thermite Charge",
        time = 20000,
        materials = {
            { item = "iron", count = 10, label = "Iron Ore" },
            { item = "aluminum_powder", count = 8, label = "Aluminum Powder" }
        }
    }
}
