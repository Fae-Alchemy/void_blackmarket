local LoadedBlackMarkets = {}

local Bridge = exports['void_bridge']:GetBridge()

-- Helper to check if player is an admin
local function IsPlayerAdmin(source)
    return Bridge.HasPermission(source, "admin") or Bridge.HasPermission(source, "god")
end

-- Helper to dynamically get the owner of a black market (integrating with cb-gangsystem)
local function GetMarketOwnerJob(market)
    if not market then return nil end
    if Config.GangSystem and Config.GangSystem.enabled then
        local resourceName = Config.GangSystem.resourceName or "cb-gangsystem"
        if GetResourceState(resourceName) == "started" then
            local coords = market.coords
            
            -- Safe lookup for gang zone ID
            local okZone, zoneID = pcall(function()
                return exports[resourceName]:GetGangZoneByCoords(coords.xyz or coords)
            end)
            
            if okZone and zoneID then
                -- Safe lookup for zone owner/controller database ID
                local okController, controllerID = pcall(function()
                    return exports[resourceName]:GetGangAtZoneReturnID(zoneID)
                end)
                
                if okController and controllerID then
                    -- Map the numeric/string controller ID to the gang tag string using GlobalState
                    local gangData = GlobalState["GangData"]
                    if gangData then
                        local gangInfo = gangData[tostring(controllerID)] or gangData[tonumber(controllerID)]
                        if gangInfo and gangInfo.tag and gangInfo.tag ~= "" then
                            return string.lower(gangInfo.tag)
                        end
                    end
                end
            end
        end
    end
    return market.owner_job
end


-- Helper to get a copy of LoadedBlackMarkets with owner jobs resolved dynamically
local function GetSyncedMarkets()
    local synced = {}
    for id, market in pairs(LoadedBlackMarkets) do
        synced[id] = {
            id = market.id,
            name = market.name,
            label = market.label,
            coords = market.coords,
            ped = market.ped,
            blip = market.blip,
            balance = market.balance,
            tax_rate = market.tax_rate,
            items = market.items,
            offline_access = market.offline_access,
            owner_job = GetMarketOwnerJob(market)
        }
    end
    return synced
end

-- Helper to get a synced copy of a single market
local function GetSyncedSingleMarket(marketId)
    local market = LoadedBlackMarkets[tostring(marketId)]
    if not market then return nil end
    return {
        id = market.id,
        name = market.name,
        label = market.label,
        coords = market.coords,
        ped = market.ped,
        blip = market.blip,
        balance = market.balance,
        tax_rate = market.tax_rate,
        items = market.items,
        offline_access = market.offline_access,
        owner_job = GetMarketOwnerJob(market)
    }
end


-- Helper to check if player is a boss of a specific job
local function IsPlayerBossOfJob(source, jobName)
    local player = Bridge.GetPlayer(source)
    if not player then return false end
    
    local fw = Bridge.GetFramework()
    local pData = player.GetData()
    
    -- Check Job Boss status
    if pData.job and pData.job.name == jobName then
        if fw == "qbcore" then
            local QBCore = exports['qb-core']:GetCoreObject()
            local qbPlayer = QBCore.Functions.GetPlayer(source)
            if qbPlayer and qbPlayer.PlayerData.job.isboss then
                return true
            end
        elseif fw == "esx" then
            if pData.job.gradeLabel and string.lower(pData.job.gradeLabel) == "boss" then
                return true
            end
        end
        if pData.job.grade >= Config.MinBossGrade then
            return true
        end
    end
    
    -- Check Gang Boss status (QBCore)
    if fw == "qbcore" and pData.gang and pData.gang.name == jobName then
        if pData.gang.isboss then
            return true
        end
        if pData.gang.grade >= Config.MinBossGrade then
            return true
        end
    end
    
    return false
end

-- Helper to check if any member of a job/gang is online
local function IsJobMemberOnline(jobName)
    local players = Bridge.GetPlayers()
    for _, pSrc in ipairs(players) do
        local player = Bridge.GetPlayer(tonumber(pSrc))
        if player then
            local pData = player.GetData()
            if pData.job and pData.job.name == jobName then
                return true
            end
            if pData.gang and pData.gang.name == jobName then
                return true
            end
        end
    end
    return false
end

-- Load all black markets from DB
local function LoadBlackMarkets()
    LoadedBlackMarkets = {}
    MySQL.query('SELECT * FROM void_blackmarkets', {}, function(results)
        if results then
            for _, row in ipairs(results) do
                local coords = json.decode(row.coords)
                local blip = json.decode(row.blip)
                local items = json.decode(row.items)
                
                local coordVec = vector4(coords.x, coords.y, coords.z, coords.h or 0.0)
                
                LoadedBlackMarkets[tostring(row.id)] = {
                    id = tostring(row.id),
                    name = row.name,
                    label = row.label,
                    coords = coordVec,
                    ped = row.ped,
                    blip = blip,
                    balance = tonumber(row.balance) or 0,
                    tax_rate = tonumber(row.tax_rate) or 10,
                    items = items or {},
                    offline_access = row.offline_access == 1,
                    owner_job = row.owner_job
                }
            end
        end
        if Config.Debug then
            local count = 0
            for _ in pairs(LoadedBlackMarkets) do count = count + 1 end
            print(("[void_blackmarket] Loaded %d black markets from database"):format(count))
        end
        
        -- Sync black markets to all active clients
        TriggerClientEvent('void_blackmarket:client:SyncMarkets', -1, GetSyncedMarkets())
    end)
end

-- DB Initialization on start
MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `void_blackmarkets` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `name` VARCHAR(50) NOT NULL UNIQUE,
            `label` VARCHAR(100) NOT NULL,
            `coords` TEXT NOT NULL,
            `ped` VARCHAR(50) NOT NULL DEFAULT 'g_m_m_mexboss_01',
            `blip` TEXT DEFAULT NULL,
            `balance` INT NOT NULL DEFAULT 0,
            `tax_rate` INT NOT NULL DEFAULT 10,
            `items` LONGTEXT NOT NULL DEFAULT '[]',
            `offline_access` TINYINT(1) NOT NULL DEFAULT 1,
            `owner_job` VARCHAR(50) NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]], {}, function()
        LoadBlackMarkets()
    end)
end)

-- RPC to get black markets list for joining clients
lib.callback.register('void_blackmarket:server:GetBlackMarkets', function(source)
    return GetSyncedMarkets()
end)

-- RPC to check admin permissions
lib.callback.register('void_blackmarket:server:CheckAdminPerms', function(source)
    return IsPlayerAdmin(source)
end)

-- RPC to fetch Market NUI details
lib.callback.register('void_blackmarket:server:GetMarketUIData', function(source, marketId)
    local market = LoadedBlackMarkets[tostring(marketId)]
    if not market then return nil end
    
    local player = Bridge.GetPlayer(source)
    if not player then return nil end
    
    local pData = player.GetData()
    local ownerJob = GetMarketOwnerJob(market)
    local isOwnerBoss = IsPlayerBossOfJob(source, ownerJob)
    local isOwnerMember = (pData.job and pData.job.name == ownerJob) or (pData.gang and pData.gang.name == ownerJob)
    
    -- Gather current materials count for crafting list
    local craftingRecipes = {}
    for _, recipe in ipairs(Config.CraftingRecipes) do
        local recData = {
            item = recipe.item,
            label = recipe.label,
            time = recipe.time,
            materials = {}
        }
        for _, mat in ipairs(recipe.materials) do
            local currentCount = Inventory.GetItemCount(source, mat.item)
            table.insert(recData.materials, {
                item = mat.item,
                label = mat.label,
                required = mat.count,
                current = currentCount
            })
        end
        table.insert(craftingRecipes, recData)
    end
    
    -- Check dirty money amount
    local dirtyAmount = 0
    if Config.DirtyMoney.type == "account" then
        dirtyAmount = player.GetMoney(Config.DirtyMoney.accountName) or 0
    else
        dirtyAmount = Inventory.GetDirtyMoneyBalance(source)
    end
    
    -- Format shop items and fetch localized labels if available
    local itemsList = {}
    local QBCore = nil
    if Bridge.GetFramework() == "qbcore" then
        QBCore = exports['qb-core']:GetCoreObject()
    end
    
    for _, it in ipairs(market.items) do
        local label = it.name
        if QBCore and QBCore.Shared and QBCore.Shared.Items[string.lower(it.name)] then
            label = QBCore.Shared.Items[string.lower(it.name)].label or label
        end
        table.insert(itemsList, {
            name = it.name,
            label = label,
            price = it.price,
            stock = it.stock
        })
    end
    
    -- Check if owner is online
    local ownerOnline = IsJobMemberOnline(ownerJob)
    
    return {
        marketId = market.id,
        label = market.label,
        ownerJob = ownerJob,
        balance = market.balance,
        taxRate = market.tax_rate,
        offlineAccess = market.offline_access,
        isOwnerBoss = isOwnerBoss,
        isOwnerMember = isOwnerMember,
        ownerOnline = ownerOnline,
        dirtyMoney = dirtyAmount,
        recipes = craftingRecipes,
        items = itemsList,
        dirtyMoneyName = Config.DirtyMoney.name,
        dirtyMoneyType = Config.DirtyMoney.type,
        dirtyMoneyAccount = Config.DirtyMoney.accountName,
        playerCash = player.GetMoney('cash')
    }
end)

-- Create Black Market Event (Admin only)
RegisterNetEvent('void_blackmarket:server:CreateMarket', function(data)
    local src = source
    if not IsPlayerAdmin(src) then
        Bridge.Notify(src, "You are not authorized to create black markets.", "error")
        return
    end
    
    local name = string.lower(data.name)
    local label = data.label
    local ownerJob = string.lower(data.ownerJob)
    local pedModel = data.pedModel
    local blipSprite = tonumber(data.blipSprite) or 501
    local blipColor = tonumber(data.blipColor) or 1
    local blipScale = tonumber(data.blipScale) or 0.8
    local coords = data.coords
    
    local coordsData = {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        h = coords.w
    }
    
    local blipData = {
        sprite = blipSprite,
        color = blipColor,
        scale = blipScale
    }
    
    MySQL.insert('INSERT INTO void_blackmarkets (name, label, coords, ped, blip, owner_job) VALUES (?, ?, ?, ?, ?, ?)', {
        name,
        label,
        json.encode(coordsData),
        pedModel,
        json.encode(blipData),
        ownerJob
    }, function(insertId)
        if insertId then
            Bridge.Notify(src, "Black Market successfully created!", "success")
            LoadBlackMarkets()
        else
            Bridge.Notify(src, "Failed to write black market to database.", "error")
        end
    end)
end)

-- Delete Black Market (Admin only)
RegisterNetEvent('void_blackmarket:server:DeleteMarket', function(marketId)
    local src = source
    if not IsPlayerAdmin(src) then
        Bridge.Notify(src, "Not authorized.", "error")
        return
    end
    
    MySQL.query('DELETE FROM void_blackmarkets WHERE id = ?', { tonumber(marketId) }, function(result)
        Bridge.Notify(src, "Black Market deleted successfully!", "success")
        LoadBlackMarkets()
    end)
end)

-- Buy Item Callback
lib.callback.register('void_blackmarket:server:BuyItem', function(source, data)
    local src = source
    local marketId = tostring(data.marketId)
    local itemName = data.itemName
    local quantity = tonumber(data.quantity) or 1
    
    local market = LoadedBlackMarkets[marketId]
    if not market then return { success = false, message = "Market not found" } end
    
    -- Check distance
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    if #(playerCoords - market.coords.xyz) > 15.0 then
        return { success = false, message = "Exploit check: Too far away!" }
    end
    
    -- Check if owner job is online or offline access is allowed
    local ownerJob = GetMarketOwnerJob(market)
    local isOwnerOnline = IsJobMemberOnline(ownerJob)
    if not isOwnerOnline and not market.offline_access then
        return { success = false, message = "The store is currently closed as the owners are offline." }
    end
    
    -- Find item in stock
    local itemIndex = nil
    local stockItem = nil
    for idx, it in ipairs(market.items) do
        if it.name == itemName then
            itemIndex = idx
            stockItem = it
            break
        end
    end
    
    if not stockItem then
        return { success = false, message = "Item not stocked at this market" }
    end
    
    if stockItem.stock < quantity then
        return { success = false, message = "Not enough stock available" }
    end
    
    -- Calculate price
    local price = stockItem.price * quantity
    local player = Bridge.GetPlayer(src)
    if not player then return { success = false, message = "Player error" } end
    
    -- Check cash
    local cash = player.GetMoney('cash')
    if cash < price then
        return { success = false, message = "You do not have enough cash" }
    end
    
    -- Check inventory carrying capacity
    local tempCart = { { name = itemName, quantity = quantity } }
    local canCarry, err = Inventory.CanCarryItems(src, tempCart)
    if not canCarry then
        return { success = false, message = err }
    end
    
    -- Process checkout
    if player.RemoveMoney('cash', price, "blackmarket-purchase") then
        -- Deduct stock
        market.items[itemIndex].stock = stockItem.stock - quantity
        
        -- Write new stock to DB
        MySQL.update('UPDATE void_blackmarkets SET items = ? WHERE id = ?', {
            json.encode(market.items),
            tonumber(marketId)
        })
        
        -- Add earnings to market bank balance
        market.balance = market.balance + price
        MySQL.update('UPDATE void_blackmarkets SET balance = ? WHERE id = ?', {
            market.balance,
            tonumber(marketId)
        })
        
        -- Grant item
        Inventory.AddItem(src, itemName, quantity)
        
        Bridge.Notify(src, ("Purchased %dx %s for $%d"):format(quantity, itemName, price), "success")
        
        -- Sync update to others
        TriggerClientEvent('void_blackmarket:client:SyncSingleMarket', -1, marketId, GetSyncedSingleMarket(marketId))
        
        return { success = true, balance = market.balance, items = market.items }
    else
        return { success = false, message = "Billing transaction failed" }
    end
end)

-- Wash Money Callback
lib.callback.register('void_blackmarket:server:WashMoney', function(source, data)
    local src = source
    local marketId = tostring(data.marketId)
    local amount = tonumber(data.amount) or 0
    
    if amount <= 0 then
        return { success = false, message = "Invalid amount" }
    end
    
    local market = LoadedBlackMarkets[marketId]
    if not market then return { success = false, message = "Market not found" } end
    
    -- Distance check
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    if #(playerCoords - market.coords.xyz) > 15.0 then
        return { success = false, message = "Too far away" }
    end
    
    local player = Bridge.GetPlayer(src)
    if not player then return { success = false, message = "Player error" } end
    
    -- Check dirty balance
    local dirtyBalance = 0
    if Config.DirtyMoney.type == "account" then
        dirtyBalance = player.GetMoney(Config.DirtyMoney.accountName) or 0
    else
        dirtyBalance = Inventory.GetDirtyMoneyBalance(source)
    end
    
    if dirtyBalance < amount then
        return { success = false, message = "You do not have that much dirty money" }
    end
    
    -- Calculate taxes and payout
    local taxPercent = market.tax_rate
    local taxAmount = math.floor(amount * (taxPercent / 100))
    local cleanPayout = amount - taxAmount
    
    -- Process deduction
    local deducted = false
    if Config.DirtyMoney.type == "account" then
        deducted = player.RemoveMoney(Config.DirtyMoney.accountName, amount, "blackmarket-wash")
    else
        deducted = Inventory.RemoveDirtyMoney(src, amount)
    end
    
    if deducted then
        -- Add clean payout to player
        player.AddMoney('cash', cleanPayout, "blackmarket-wash-payout")
        
        -- Add tax to market bank balance
        market.balance = market.balance + taxAmount
        MySQL.update('UPDATE void_blackmarkets SET balance = ? WHERE id = ?', {
            market.balance,
            tonumber(marketId)
        })
        
        Bridge.Notify(src, ("Washed $%d dirty money. Received $%d clean (Charged %d%% tax)."):format(amount, cleanPayout, taxPercent), "success")
        
        -- Sync update
        TriggerClientEvent('void_blackmarket:client:SyncSingleMarket', -1, marketId, GetSyncedSingleMarket(marketId))
        
        return { success = true, balance = market.balance }
    else
        return { success = false, message = "Deduction failed" }
    end
end)

-- Craft Item Callback
lib.callback.register('void_blackmarket:server:CraftItem', function(source, data)
    local src = source
    local marketId = tostring(data.marketId)
    local itemName = data.itemName
    
    local market = LoadedBlackMarkets[marketId]
    if not market then return { success = false, message = "Market not found" } end
    
    -- Verify player is a member of the owner job
    local player = Bridge.GetPlayer(src)
    if not player then return { success = false, message = "Player error" } end
    local pData = player.GetData()
    local ownerJob = GetMarketOwnerJob(market)
    local isMember = (pData.job and pData.job.name == ownerJob) or (pData.gang and pData.gang.name == ownerJob)
    if not isMember then
        return { success = false, message = "Unauthorized: You are not a member of this territory organization." }
    end
    
    -- Check distance
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    if #(playerCoords - market.coords.xyz) > 15.0 then
        return { success = false, message = "Too far away" }
    end
    
    -- Find recipe
    local recipe = nil
    for _, rec in ipairs(Config.CraftingRecipes) do
        if rec.item == itemName then
            recipe = rec
            break
        end
    end
    
    if not recipe then return { success = false, message = "Recipe not found" } end
    
    -- Verify items in inventory
    for _, mat in ipairs(recipe.materials) do
        local count = Inventory.GetItemCount(src, mat.item)
        if count < mat.count then
            return { success = false, message = ("Insufficient materials: Missing %s"):format(mat.label) }
        end
    end
    
    -- Verify weight capacity
    local tempCart = { { name = itemName, quantity = 1 } }
    local canCarry, err = Inventory.CanCarryItems(src, tempCart)
    if not canCarry then return { success = false, message = err } end
    
    -- Remove materials
    for _, mat in ipairs(recipe.materials) do
        Inventory.RemoveItem(src, mat.item, mat.count)
    end
    
    -- Award item
    Inventory.AddItem(src, itemName, 1)
    Bridge.Notify(src, ("Successfully crafted 1x %s"):format(recipe.label), "success")
    
    return { success = true }
end)

-- Update Settings (Owner only)
lib.callback.register('void_blackmarket:server:UpdateSettings', function(source, data)
    local src = source
    local marketId = tostring(data.marketId)
    local taxRate = tonumber(data.taxRate) or 10
    local offlineAccess = data.offlineAccess and 1 or 0
    
    local market = LoadedBlackMarkets[marketId]
    if not market then return { success = false, message = "Market not found" } end
    
    -- Ownership check
    local ownerJob = GetMarketOwnerJob(market)
    if not IsPlayerBossOfJob(src, ownerJob) then
        return { success = false, message = "Unauthorized management action" }
    end
    
    -- Clamp tax rate between 5% and 30%
    if taxRate < 5 then taxRate = 5 elseif taxRate > 30 then taxRate = 30 end
    
    market.tax_rate = taxRate
    market.offline_access = offlineAccess == 1
    
    MySQL.update('UPDATE void_blackmarkets SET tax_rate = ?, offline_access = ? WHERE id = ?', {
        taxRate,
        offlineAccess,
        tonumber(marketId)
    }, function(rowsChanged)
        if rowsChanged > 0 then
            Bridge.Notify(src, "Settings successfully updated!", "success")
            TriggerClientEvent('void_blackmarket:client:SyncSingleMarket', -1, marketId, GetSyncedSingleMarket(marketId))
        end
    end)
    
    return { success = true, taxRate = taxRate, offlineAccess = market.offline_access }
end)

-- Withdraw Funds Callback (Owner only)
lib.callback.register('void_blackmarket:server:WithdrawFunds', function(source, data)
    local src = source
    local marketId = tostring(data.marketId)
    local amount = tonumber(data.amount) or 0
    
    if amount <= 0 then return { success = false, message = "Invalid amount" } end
    
    local market = LoadedBlackMarkets[marketId]
    if not market then return { success = false, message = "Market not found" } end
    
    -- Ownership check
    local ownerJob = GetMarketOwnerJob(market)
    if not IsPlayerBossOfJob(src, ownerJob) then
        return { success = false, message = "Unauthorized" }
    end
    
    if market.balance < amount then
        return { success = false, message = "Insufficient funds in market balance" }
    end
    
    local player = Bridge.GetPlayer(src)
    if not player then return { success = false, message = "Player error" } end
    
    -- Deduct from market and credit player cash
    market.balance = market.balance - amount
    MySQL.update('UPDATE void_blackmarkets SET balance = ? WHERE id = ?', {
        market.balance,
        tonumber(marketId)
    }, function()
        player.AddMoney('cash', amount, "blackmarket-withdraw")
        Bridge.Notify(src, ("Withdrew $%d from black market balance."):format(amount), "success")
        TriggerClientEvent('void_blackmarket:client:SyncSingleMarket', -1, marketId, GetSyncedSingleMarket(marketId))
    end)
    
    return { success = true, balance = market.balance }
end)

-- Deposit Stock Callback (Owner only)
lib.callback.register('void_blackmarket:server:DepositStock', function(source, data)
    local src = source
    local marketId = tostring(data.marketId)
    local itemName = data.itemName
    local quantity = tonumber(data.quantity) or 1
    local price = tonumber(data.price) or 100
    
    local market = LoadedBlackMarkets[marketId]
    if not market then return { success = false, message = "Market not found" } end
    
    -- Owner member check (any grade of the job can stock)
    local ownerJob = GetMarketOwnerJob(market)
    local pData = Bridge.GetPlayer(src).GetData()
    local isMember = (pData.job and pData.job.name == ownerJob) or (pData.gang and pData.gang.name == ownerJob)
    if not isMember then
        return { success = false, message = "Unauthorized" }
    end
    
    -- Check inventory item
    local currentInv = Inventory.GetItemCount(src, itemName)
    if currentInv < quantity then
        return { success = false, message = "You do not have enough of this item in your pockets" }
    end
    
    -- Remove from inventory
    if Inventory.RemoveItem(src, itemName, quantity) then
        -- Insert/update in stock
        local found = false
        for _, it in ipairs(market.items) do
            if it.name == itemName then
                it.stock = it.stock + quantity
                it.price = price -- update default selling price
                found = true
                break
            end
        end
        
        if not found then
            table.insert(market.items, {
                name = itemName,
                price = price,
                stock = quantity
            })
        end
        
        -- Write back to DB
        MySQL.update('UPDATE void_blackmarkets SET items = ? WHERE id = ?', {
            json.encode(market.items),
            tonumber(marketId)
        }, function()
            Bridge.Notify(src, ("Deposited %dx %s into market stock."):format(quantity, itemName), "success")
            TriggerClientEvent('void_blackmarket:client:SyncSingleMarket', -1, marketId, GetSyncedSingleMarket(marketId))
        end)
        
        return { success = true, items = market.items }
    else
        return { success = false, message = "Failed to deposit item" }
    end
end)

-- Withdraw Stock Callback (Owner only)
lib.callback.register('void_blackmarket:server:WithdrawStock', function(source, data)
    local src = source
    local marketId = tostring(data.marketId)
    local itemName = data.itemName
    local quantity = tonumber(data.quantity) or 1
    
    local market = LoadedBlackMarkets[marketId]
    if not market then return { success = false, message = "Market not found" } end
    
    -- Owner member check
    local ownerJob = GetMarketOwnerJob(market)
    local pData = Bridge.GetPlayer(src).GetData()
    local isMember = (pData.job and pData.job.name == ownerJob) or (pData.gang and pData.gang.name == ownerJob)
    if not isMember then
        return { success = false, message = "Unauthorized" }
    end
    
    -- Find item
    local itemIndex = nil
    local stockItem = nil
    for idx, it in ipairs(market.items) do
        if it.name == itemName then
            itemIndex = idx
            stockItem = it
            break
        end
    end
    
    if not stockItem then return { success = false, message = "Item not found in stock" } end
    if stockItem.stock < quantity then return { success = false, message = "Insufficient stock available" } end
    
    -- Verify carrying capacity
    local tempCart = { { name = itemName, quantity = quantity } }
    local canCarry, err = Inventory.CanCarryItems(src, tempCart)
    if not canCarry then return { success = false, message = err } end
    
    -- Process withdrawal
    market.items[itemIndex].stock = stockItem.stock - quantity
    
    -- Remove item block from array if stock is 0
    if market.items[itemIndex].stock <= 0 then
        table.remove(market.items, itemIndex)
    end
    
    MySQL.update('UPDATE void_blackmarkets SET items = ? WHERE id = ?', {
        json.encode(market.items),
        tonumber(marketId)
    }, function()
        Inventory.AddItem(src, itemName, quantity)
        Bridge.Notify(src, ("Withdrew %dx %s from stock."):format(quantity, itemName), "success")
        TriggerClientEvent('void_blackmarket:client:SyncSingleMarket', -1, marketId, GetSyncedSingleMarket(marketId))
    end)
    
    return { success = true, items = market.items }
end)

-- Update Stock Price Callback (Owner only)
lib.callback.register('void_blackmarket:server:UpdateStockPrice', function(source, data)
    local src = source
    local marketId = tostring(data.marketId)
    local itemName = data.itemName
    local newPrice = tonumber(data.price) or 100
    
    if newPrice <= 0 then return { success = false, message = "Invalid price" } end
    
    local market = LoadedBlackMarkets[marketId]
    if not market then return { success = false, message = "Market not found" } end
    
    -- Owner member check
    local ownerJob = GetMarketOwnerJob(market)
    local pData = Bridge.GetPlayer(src).GetData()
    local isMember = (pData.job and pData.job.name == ownerJob) or (pData.gang and pData.gang.name == ownerJob)
    if not isMember then
        return { success = false, message = "Unauthorized" }
    end
    
    -- Find and update
    local found = false
    for _, it in ipairs(market.items) do
        if it.name == itemName then
            it.price = newPrice
            found = true
            break
        end
    end
    
    if found then
        MySQL.update('UPDATE void_blackmarkets SET items = ? WHERE id = ?', {
            json.encode(market.items),
            tonumber(marketId)
        }, function()
            Bridge.Notify(src, ("Updated %s price to $%d."):format(itemName, newPrice), "success")
            TriggerClientEvent('void_blackmarket:client:SyncSingleMarket', -1, marketId, GetSyncedSingleMarket(marketId))
        end)
        return { success = true, items = market.items }
    else
        return { success = false, message = "Item not found in stock" }
    end
end)

-- Verify Item Callback (Checks shared items table for metadata)
lib.callback.register('void_blackmarket:server:VerifyItemName', function(source, itemName)
    local QBCore = nil
    if Bridge.GetFramework() == "qbcore" then
        QBCore = exports['qb-core']:GetCoreObject()
    end
    
    if not QBCore or not QBCore.Shared or not QBCore.Shared.Items then
        return { exists = true, label = itemName }
    end
    
    local exists = QBCore.Shared.Items[string.lower(itemName)] ~= nil
    local label = exists and QBCore.Shared.Items[string.lower(itemName)].label or itemName
    return { exists = exists, label = label }
end)

-- Fetch player's current pocket inventory items
lib.callback.register('void_blackmarket:server:GetPlayerInventory', function(source)
    return Inventory.GetPlayerInventory(source)
end)

-- Version Check Functionality
local function CheckForUpdates()
    local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version', 0)
    if not currentVersion then return end

    PerformHttpRequest('https://raw.githubusercontent.com/Fae-Alchemy/void_blackmarket/main/fxmanifest.lua', function(statusCode, responseText, headers)
        if statusCode ~= 200 then
            print(("^5[void_blackmarket]^7 ^3[Update Checker]^7 ^1Failed to check for updates (Status Code: %s)^7"):format(tostring(statusCode)))
            return
        end

        local latestVersion = responseText:match("version%s+'([%d%.]+)'") or responseText:match('version%s+"([%d%.]+)"')
        if latestVersion then
            if latestVersion ~= currentVersion then
                print("^5--------------------------------------------------------------------------------^7")
                print(("^5[void_blackmarket]^7 ^3[Update Checker]^7 ^1A new update is available!^7"):format(latestVersion))
                print(("^5[void_blackmarket]^7 Current Version: ^1%s^7 | Latest Version: ^2%s^7"):format(currentVersion, latestVersion))
                print("^5[void_blackmarket]^7 Please update to ensure compatibility and access new features.")
                print("^5[void_blackmarket]^7 Download: ^5https://github.com/Fae-Alchemy/void_blackmarket^7")
                print("^5--------------------------------------------------------------------------------^7")
            else
                if Config.Debug then
                    print(("^5[void_blackmarket]^7 ^3[Update Checker]^7 ^2Resource is up to date (v%s)^7"):format(currentVersion))
                end
            end
        else
            print("^5[void_blackmarket]^7 ^3[Update Checker]^7 ^1Failed to parse version from remote manifest.^7")
        end
    end, 'GET')
end

-- Trigger update check on startup
CreateThread(function()
    Wait(5000) -- Wait 5 seconds after server boot
    CheckForUpdates()
end)

-- Background thread to monitor turf changes and sync to clients
CreateThread(function()
    -- Wait for database loading to populate LoadedBlackMarkets
    while not next(LoadedBlackMarkets) do
        Wait(1000)
    end
    
    local lastOwners = {}
    for id, market in pairs(LoadedBlackMarkets) do
        lastOwners[id] = GetMarketOwnerJob(market)
    end
    
    while true do
        Wait(30000) -- Check every 30 seconds
        if Config.GangSystem and Config.GangSystem.enabled then
            local changed = false
            for id, market in pairs(LoadedBlackMarkets) do
                local currentOwner = GetMarketOwnerJob(market)
                if lastOwners[id] ~= currentOwner then
                    if Config.Debug then
                        print(("[void_blackmarket] Market %s owner changed from %s to %s"):format(market.name, tostring(lastOwners[id]), tostring(currentOwner)))
                    end
                    lastOwners[id] = currentOwner
                    changed = true
                end
            end
            if changed then
                TriggerClientEvent('void_blackmarket:client:SyncMarkets', -1, GetSyncedMarkets())
            end
        end
    end
end)

CreateThread(function()
    Wait(5000)
    print("^3[void_blackmarket] DEBUG: Checking loaded markets zone ownership:^7")
    local resourceName = Config.GangSystem.resourceName or "cb-gangsystem"
    for id, market in pairs(LoadedBlackMarkets) do
        local coords = market.coords
        local okZone, zoneID = pcall(function()
            return exports[resourceName]:GetGangZoneByCoords(coords.xyz or coords)
        end)
        
        if not okZone then
            print(("^1[void_blackmarket] Market %s: GetGangZoneByCoords crashed!^7"):format(market.name))
        elseif not zoneID then
            print(("^3[void_blackmarket] Market %s: Not in any gang zone (neutral/none)^7"):format(market.name))
        else
            local okController, controllerID = pcall(function()
                return exports[resourceName]:GetGangAtZoneReturnID(zoneID)
            end)
            if not okController then
                print(("^1[void_blackmarket] Market %s: GetGangAtZoneReturnID crashed for zone %s!^7"):format(market.name, zoneID))
            elseif not controllerID then
                print(("^3[void_blackmarket] Market %s: Zone %s has no controller gang^7"):format(market.name, zoneID))
            else
                local gangData = GlobalState["GangData"]
                local gangTag = nil
                if gangData then
                    local gangInfo = gangData[tostring(controllerID)] or gangData[tonumber(controllerID)]
                    if gangInfo then
                        gangTag = gangInfo.tag
                    end
                end
                print(("^2[void_blackmarket] Market %s: In zone %s owned by gang ID %s (tag: %s)^7"):format(market.name, zoneID, tostring(controllerID), tostring(gangTag)))
            end
        end
    end
end)

