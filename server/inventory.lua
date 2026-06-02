Inventory = {}

local Bridge = exports['void_bridge']:GetBridge()

-- Retrieve current inventory system name
function Inventory.GetSystem()
    return Bridge.Inventory.GetSystem()
end

-- Check count of a regular item
function Inventory.GetItemCount(source, itemName)
    local invType = Inventory.GetSystem()
    if invType == "ox_inventory" then
        return exports.ox_inventory:GetItemCount(source, itemName) or 0
    elseif invType == "qb-inventory" then
        local QBCore = exports['qb-core']:GetCoreObject()
        local qbPlayer = QBCore.Functions.GetPlayer(source)
        if not qbPlayer then return 0 end
        local item = qbPlayer.Functions.GetItemByName(itemName)
        return item and item.amount or 0
    else
        -- Standalone / Fallback
        if Bridge.Inventory.HasItem(source, itemName, 1) then
            return 1
        end
        return 0
    end
end

-- Add items (re-routed through void_bridge)
function Inventory.AddItem(source, itemName, amount, metadata)
    return Bridge.Inventory.AddItem(source, itemName, amount, metadata)
end

-- Remove items (re-routed through void_bridge)
function Inventory.RemoveItem(source, itemName, amount)
    return Bridge.Inventory.RemoveItem(source, itemName, amount)
end

-- Bulk check if player can carry multiple items (weight limits)
function Inventory.CanCarryItems(source, items)
    local invType = Inventory.GetSystem()
    
    if invType == "ox_inventory" then
        local inv = exports.ox_inventory:GetInventory(source)
        if not inv then return false, "Could not fetch inventory metadata." end
        
        local totalWeight = 0
        for _, item in ipairs(items) do
            local itemData = exports.ox_inventory:Items(item.name)
            local itemWeight = itemData and itemData.weight or 0
            totalWeight = totalWeight + (itemWeight * item.quantity)
        end
        
        if (inv.weight + totalWeight) > inv.maxWeight then
            return false, "You cannot carry this much weight!"
        end
        return true
    elseif invType == "qb-inventory" then
        local QBCore = exports['qb-core']:GetCoreObject()
        local qbPlayer = QBCore.Functions.GetPlayer(source)
        if not qbPlayer then return false, "Player not found." end
        
        local currentWeight = 0
        if qbPlayer.Functions.GetItemsWeight then
            currentWeight = qbPlayer.Functions.GetItemsWeight()
        else
            for _, item in pairs(qbPlayer.PlayerData.items or {}) do
                local itemData = QBCore.Shared.Items[string.lower(item.name)]
                local itemWeight = itemData and itemData.weight or 0
                currentWeight = currentWeight + (itemWeight * item.amount)
            end
        end
        
        local maxWeight = 120000
        if qbPlayer.PlayerData.metadata and qbPlayer.PlayerData.metadata['attachment_weight'] then
            maxWeight = qbPlayer.PlayerData.metadata['attachment_weight']
        elseif QBCore.Config and QBCore.Config.Player and QBCore.Config.Player.MaxWeight then
            maxWeight = QBCore.Config.Player.MaxWeight
        end
        
        local totalWeight = 0
        for _, item in ipairs(items) do
            local itemData = QBCore.Shared.Items[string.lower(item.name)]
            local itemWeight = itemData and itemData.weight or 0
            totalWeight = totalWeight + (itemWeight * item.quantity)
        end
        
        if (currentWeight + totalWeight) > maxWeight then
            return false, "You do not have enough carrying capacity!"
        end
        return true
    else
        -- Standalone: skip weight checks
        return true
    end
end

-- Get dirty money balance from item-based configurations (e.g. markedbills with metadata worth)
function Inventory.GetDirtyMoneyBalance(source)
    local itemName = Config.DirtyMoney.name
    local invType = Inventory.GetSystem()
    
    if invType == "ox_inventory" then
        -- In Ox Inventory, markedbills may have custom metadata or be a simple count
        -- Let's check if the items have worth metadata first, otherwise default to item count
        local items = exports.ox_inventory:GetSlotsWithItem(source, itemName)
        if not items or #items == 0 then return 0 end
        
        local total = 0
        for _, item in ipairs(items) do
            if item.metadata and item.metadata.worth then
                total = total + (item.metadata.worth * item.count)
            else
                total = total + item.count
            end
        end
        return total
    elseif invType == "qb-inventory" then
        local QBCore = exports['qb-core']:GetCoreObject()
        local qbPlayer = QBCore.Functions.GetPlayer(source)
        if not qbPlayer then return 0 end
        
        local total = 0
        local items = qbPlayer.PlayerData.items or {}
        for _, item in pairs(items) do
            if item and item.name == itemName then
                if item.info and item.info.worth then
                    total = total + (item.info.worth * item.amount)
                elseif item.metadata and item.metadata.worth then
                    total = total + (item.metadata.worth * item.amount)
                else
                    total = total + item.amount
                end
            end
        end
        return total
    else
        -- Standalone
        return Inventory.GetItemCount(source, itemName)
    end
end

-- Remove dirty money item-based stacks from player's inventory
function Inventory.RemoveDirtyMoney(source, amount)
    local itemName = Config.DirtyMoney.name
    local invType = Inventory.GetSystem()
    
    if invType == "ox_inventory" then
        local items = exports.ox_inventory:GetSlotsWithItem(source, itemName)
        if not items or #items == 0 then return false end
        
        local totalAvailable = 0
        for _, item in ipairs(items) do
            if item.metadata and item.metadata.worth then
                totalAvailable = totalAvailable + (item.metadata.worth * item.count)
            else
                totalAvailable = totalAvailable + item.count
            end
        end
        
        if totalAvailable < amount then return false end
        
        local remainingToRemove = amount
        for _, item in ipairs(items) do
            local itemWorth = 1
            local hasWorth = false
            if item.metadata and item.metadata.worth then
                itemWorth = item.metadata.worth
                hasWorth = true
            end
            
            if hasWorth then
                local stackWorth = itemWorth * item.count
                if stackWorth <= remainingToRemove then
                    exports.ox_inventory:RemoveItem(source, itemName, item.count, nil, item.slot)
                    remainingToRemove = remainingToRemove - stackWorth
                else
                    -- We need to deduct part of the stack
                    if item.count == 1 then
                        local newWorth = itemWorth - remainingToRemove
                        exports.ox_inventory:SetMetadata(source, item.slot, { worth = newWorth })
                        remainingToRemove = 0
                    else
                        -- Remove 1 from count, add a new metadata item with left over worth
                        exports.ox_inventory:RemoveItem(source, itemName, 1, nil, item.slot)
                        local consumed = itemWorth
                        if consumed >= remainingToRemove then
                            local leftover = itemWorth - remainingToRemove
                            if leftover > 0 then
                                exports.ox_inventory:AddItem(source, itemName, 1, { worth = leftover })
                            end
                            remainingToRemove = 0
                        else
                            remainingToRemove = remainingToRemove - consumed
                        end
                    end
                end
            else
                if item.count <= remainingToRemove then
                    exports.ox_inventory:RemoveItem(source, itemName, item.count, nil, item.slot)
                    remainingToRemove = remainingToRemove - item.count
                else
                    exports.ox_inventory:RemoveItem(source, itemName, remainingToRemove, nil, item.slot)
                    remainingToRemove = 0
                end
            end
            
            if remainingToRemove <= 0 then break end
        end
        return true
    elseif invType == "qb-inventory" then
        local QBCore = exports['qb-core']:GetCoreObject()
        local qbPlayer = QBCore.Functions.GetPlayer(source)
        if not qbPlayer then return false end
        
        local totalAvailable = Inventory.GetDirtyMoneyBalance(source)
        if totalAvailable < amount then return false end
        
        local remainingToRemove = amount
        local items = qbPlayer.PlayerData.items or {}
        
        for _, item in pairs(items) do
            if item and item.name == itemName then
                local itemWorth = 1
                local hasWorth = false
                
                if item.info and item.info.worth then
                    itemWorth = item.info.worth
                    hasWorth = true
                elseif item.metadata and item.metadata.worth then
                    itemWorth = item.metadata.worth
                    hasWorth = true
                end
                
                if hasWorth then
                    local stackWorth = itemWorth * item.amount
                    if stackWorth <= remainingToRemove then
                        qbPlayer.Functions.RemoveItem(itemName, item.amount, item.slot)
                        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[itemName], 'remove', item.amount)
                        remainingToRemove = remainingToRemove - stackWorth
                    else
                        if item.amount == 1 then
                            if item.info then item.info.worth = itemWorth - remainingToRemove end
                            if item.metadata then item.metadata.worth = itemWorth - remainingToRemove end
                            qbPlayer.Functions.SetInventory(qbPlayer.PlayerData.items)
                            remainingToRemove = 0
                        else
                            qbPlayer.Functions.RemoveItem(itemName, 1, item.slot)
                            local consumed = itemWorth
                            if consumed >= remainingToRemove then
                                local leftover = itemWorth - remainingToRemove
                                if leftover > 0 then
                                    local info = { worth = leftover }
                                    qbPlayer.Functions.AddItem(itemName, 1, nil, info)
                                end
                                remainingToRemove = 0
                            else
                                remainingToRemove = remainingToRemove - consumed
                            end
                        end
                    end
                else
                    if item.amount <= remainingToRemove then
                        qbPlayer.Functions.RemoveItem(itemName, item.amount, item.slot)
                        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[itemName], 'remove', item.amount)
                        remainingToRemove = remainingToRemove - item.amount
                    else
                        qbPlayer.Functions.RemoveItem(itemName, remainingToRemove, item.slot)
                        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[itemName], 'remove', remainingToRemove)
                        remainingToRemove = 0
                    end
                end
            end
            
            if remainingToRemove <= 0 then break end
        end
        return true
    else
        -- Standalone
        return Bridge.Inventory.RemoveItem(source, itemName, amount)
    end
end

-- Get player's full inventory items list
function Inventory.GetPlayerInventory(source)
    local invType = Inventory.GetSystem()
    local itemsList = {}
    
    if invType == "ox_inventory" then
        local inv = exports.ox_inventory:GetInventory(source)
        if inv and inv.items then
            for _, item in pairs(inv.items) do
                if item and item.name and item.count > 0 then
                    local found = false
                    for _, existing in ipairs(itemsList) do
                        if existing.name == item.name then
                            existing.amount = existing.amount + item.count
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(itemsList, {
                            name = item.name,
                            label = item.label or item.name,
                            amount = item.count
                        })
                    end
                end
            end
        end
    elseif invType == "qb-inventory" then
        local QBCore = exports['qb-core']:GetCoreObject()
        local qbPlayer = QBCore.Functions.GetPlayer(source)
        if qbPlayer and qbPlayer.PlayerData.items then
            for _, item in pairs(qbPlayer.PlayerData.items) do
                if item and item.name and item.amount > 0 then
                    local found = false
                    for _, existing in ipairs(itemsList) do
                        if existing.name == item.name then
                            existing.amount = existing.amount + item.amount
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(itemsList, {
                            name = item.name,
                            label = item.label or item.name,
                            amount = item.amount
                        })
                    end
                end
            end
        end
    end
    
    return itemsList
end
