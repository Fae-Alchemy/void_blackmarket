local SyncMarkets = {}
local activeBlips = {}
local activePeds = {}
local activePoints = {}
local textUiShowing = false
local currentOpenMarketId = nil

local Bridge = exports['void_bridge']:GetBridge()

-- Clean up peds, blips, and point markers
local function CleanupAllEntities()
    for _, blip in pairs(activeBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    activeBlips = {}

    for _, point in pairs(activePoints) do
        point:remove()
    end
    activePoints = {}

    for id, ped in pairs(activePeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    activePeds = {}

    if textUiShowing then
        lib.hideTextUI()
        textUiShowing = false
    end
end

-- Open Black Market NUI Layout
local function OpenBlackMarket(marketId)
    local market = SyncMarkets[tostring(marketId)]
    if not market then return end
    
    currentOpenMarketId = marketId
    
    -- Request UI Context data from server
    lib.callback('void_blackmarket:server:GetMarketUIData', false, function(data)
        if not data then
            Bridge.Notify("Failed to fetch market data.", "error")
            return
        end
        
        SendNUIMessage({
            action = "openMarket",
            data = data,
            imagePath = Config.ItemImagePath
        })
        SetNuiFocus(true, true)
    end, marketId)
end

local function GetPlayerGangTag()
    if Config.GangSystem and Config.GangSystem.enabled then
        local myServerId = GetPlayerServerId(PlayerId())
        local gangMembers = GlobalState["GangMembers"]
        if gangMembers then
            local memberInfo = gangMembers[myServerId] or gangMembers[tostring(myServerId)] or gangMembers[tonumber(myServerId)]
            if memberInfo and memberInfo.gang_id then
                local gangData = GlobalState["GangData"]
                if gangData then
                    local gangInfo = gangData[tostring(memberInfo.gang_id)] or gangData[tonumber(memberInfo.gang_id)]
                    if gangInfo and gangInfo.tag and gangInfo.tag ~= "" then
                        return string.lower(gangInfo.tag)
                    end
                end
            end
        end
    end
    return nil
end

-- Helper to check if player is an owner (member of owner_job/gang)
local function IsPlayerOwner(market)
    if not market or not market.owner_job then return false end
    local pData = Bridge.GetPlayerData()
    if not pData then return false end
    
    local isJobOwner = pData.job and pData.job.name == market.owner_job
    local isGangOwner = pData.gang and pData.gang.name == market.owner_job
    
    if not isGangOwner then
        local myGangTag = GetPlayerGangTag()
        if myGangTag and myGangTag == string.lower(market.owner_job) then
            isGangOwner = true
        end
    end
    
    return isJobOwner or isGangOwner
end

-- Refresh only map blips (avoiding flickering / reloading peds and interaction zones)
local function RefreshBlips()
    for _, blip in pairs(activeBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    activeBlips = {}

    for id, market in pairs(SyncMarkets) do
        local coords = market.coords
        if market.blip and market.blip.sprite > 0 and IsPlayerOwner(market) then
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, market.blip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, market.blip.scale or 0.8)
            SetBlipColour(blip, market.blip.color or 1)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(market.label)
            EndTextCommandSetBlipName(blip)
            activeBlips[tostring(id)] = blip
        end
    end
end

-- Spawn entities and point markers for loaded black markets
local function InitializeBlackMarkets()
    CleanupAllEntities()
    RefreshBlips()
    
    for id, market in pairs(SyncMarkets) do
        local coords = market.coords
        
        -- 2. Build proximity ped spawning and interaction zones
        local pedHash = GetHashKey(market.ped or "g_m_m_mexboss_01")
        local pedEntity = nil
        
        local point = lib.points.new({
            coords = coords.xyz,
            distance = 30.0,
            onEnter = function(self)
                lib.requestModel(pedHash)
                pedEntity = CreatePed(0, pedHash, coords.x, coords.y, coords.z - 1.0, coords.w, false, false)
                SetEntityAsMissionEntity(pedEntity, true, true)
                SetPedFleeAttributes(pedEntity, 0, 0)
                SetPedKeepTask(pedEntity, true)
                SetBlockingOfNonTemporaryEvents(pedEntity, true)
                SetEntityInvincible(pedEntity, true)
                FreezeEntityPosition(pedEntity, true)
                
                activePeds[tostring(id)] = pedEntity
                
                -- Register Target System Interaction
                if Config.Interaction == "target" then
                    if Config.TargetScript == "ox_target" then
                        exports.ox_target:addLocalEntity(pedEntity, {
                            {
                                name = 'void_blackmarket:open_' .. id,
                                icon = 'fa-solid fa-mask',
                                label = 'Talk to ' .. market.label,
                                onSelect = function()
                                    OpenBlackMarket(id)
                                end
                            }
                        })
                    elseif Config.TargetScript == "qb-target" or Config.TargetScript == "qbx_target" then
                        exports[Config.TargetScript]:AddTargetEntity(pedEntity, {
                            options = {
                                {
                                    type = "client",
                                    icon = "fas fa-mask",
                                    label = "Talk to " .. market.label,
                                    action = function()
                                        OpenBlackMarket(id)
                                    end
                                }
                            },
                            distance = 2.0
                        })
                    end
                end
            end,
            onExit = function(self)
                if Config.Interaction == "target" and pedEntity then
                    if Config.TargetScript == "ox_target" then
                        exports.ox_target:removeLocalEntity(pedEntity)
                    elseif Config.TargetScript == "qb-target" or Config.TargetScript == "qbx_target" then
                        exports[Config.TargetScript]:RemoveTargetEntity(pedEntity)
                    end
                end
                if pedEntity and DoesEntityExist(pedEntity) then
                    DeleteEntity(pedEntity)
                end
                activePeds[tostring(id)] = nil
                
                if textUiShowing and currentOpenMarketId == id then
                    lib.hideTextUI()
                    textUiShowing = false
                end
            end,
            nearby = function(self)
                if Config.Interaction == "marker" then
                    if self.currentDistance < 5.0 then
                        DrawMarker(
                            2, -- chevron marker
                            coords.x, coords.y, coords.z - 0.15, 
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                            0.3, 0.3, 0.2, 
                            168, 85, 247, 150, -- Glowing Purple
                            false, true, 2, false, nil, nil, false
                        )
                        
                        if self.currentDistance < 1.8 then
                            if not textUiShowing then
                                lib.showTextUI("Press [E] to talk to Suspicious Dealer")
                                textUiShowing = true
                            end
                            if IsControlJustPressed(0, 38) then -- E key
                                OpenBlackMarket(id)
                            end
                        else
                            if textUiShowing then
                                lib.hideTextUI()
                                textUiShowing = false
                            end
                        end
                    end
                end
            end
        })
        
        table.insert(activePoints, point)
    end
end

-- Sync Events from Server
RegisterNetEvent('void_blackmarket:client:SyncMarkets', function(marketList)
    SyncMarkets = marketList
    InitializeBlackMarkets()
end)

RegisterNetEvent('void_blackmarket:client:SyncSingleMarket', function(marketId, marketData)
    SyncMarkets[tostring(marketId)] = marketData
    RefreshBlips()
    if currentOpenMarketId == marketId then
        -- Refresh open NUI data dynamically
        lib.callback('void_blackmarket:server:GetMarketUIData', false, function(data)
            if data then
                SendNUIMessage({
                    action = "refreshMarket",
                    data = data
                })
            end
        end, marketId)
    end
end)

-- Fetch lists on initialization
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    lib.callback('void_blackmarket:server:GetBlackMarkets', false, function(marketList)
        SyncMarkets = marketList
        InitializeBlackMarkets()
    end)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    RefreshBlips()
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function(GangInfo)
    RefreshBlips()
end)

RegisterNetEvent('esx:setJob', function(job)
    RefreshBlips()
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    lib.callback('void_blackmarket:server:GetBlackMarkets', false, function(marketList)
        SyncMarkets = marketList
        InitializeBlackMarkets()
    end)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Citizen.Wait(1000)
    lib.callback('void_blackmarket:server:GetBlackMarkets', false, function(marketList)
        SyncMarkets = marketList
        InitializeBlackMarkets()
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    CleanupAllEntities()
end)

-- --- NUI CALLBACK TRIGGERS ---

RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    currentOpenMarketId = nil
    cb('ok')
end)

RegisterNUICallback('purchaseItem', function(data, cb)
    lib.callback('void_blackmarket:server:BuyItem', false, function(res)
        cb(res)
    end, data)
end)

-- Money wash sequence (with tactile in-game progress bar)
RegisterNUICallback('washMoney', function(data, cb)
    SetNuiFocus(false, false) -- Temporarily exit NUI focus
    
    -- Play counting bills / laundering animation
    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, "PROP_HUMAN_PARKING_METER", 0, true)
    
    local completed = lib.progressBar({
        duration = Config.WashingTime,
        label = "Cleaning Bills...",
        useLib = true,
        disable = {
            car = true,
            move = true,
            combat = true,
            mouse = false
        }
    })
    
    ClearPedTasks(ped)
    
    if completed then
        lib.callback('void_blackmarket:server:WashMoney', false, function(res)
            -- Re-open UI
            OpenBlackMarket(data.marketId)
            cb(res)
        end, data)
    else
        OpenBlackMarket(data.marketId)
        cb({ success = false, message = "Washing aborted" })
    end
end)

-- Crafting sequence (with tactile in-game progress bar)
RegisterNUICallback('craftItem', function(data, cb)
    SetNuiFocus(false, false)
    
    local ped = PlayerPedId()
    -- Repair/Tinkering Animation
    RequestAnimDict("amb@world_human_welding@male@idle_a")
    while not HasAnimDictLoaded("amb@world_human_welding@male@idle_a") do
        Citizen.Wait(10)
    end
    TaskPlayAnim(ped, "amb@world_human_welding@male@idle_a", "idle_a", 8.0, -8.0, -1, 49, 0, false, false, false)
    
    local completed = lib.progressBar({
        duration = data.duration,
        label = "Crafting: " .. data.label .. "...",
        useLib = true,
        disable = {
            car = true,
            move = true,
            combat = true,
            mouse = false
        }
    })
    
    ClearPedTasks(ped)
    RemoveAnimDict("amb@world_human_welding@male@idle_a")
    
    if completed then
        lib.callback('void_blackmarket:server:CraftItem', false, function(res)
            OpenBlackMarket(data.marketId)
            cb(res)
        end, data)
    else
        OpenBlackMarket(data.marketId)
        cb({ success = false, message = "Crafting cancelled" })
    end
end)

RegisterNUICallback('withdrawFunds', function(data, cb)
    lib.callback('void_blackmarket:server:WithdrawFunds', false, function(res)
        cb(res)
    end, data)
end)

RegisterNUICallback('updateSettings', function(data, cb)
    lib.callback('void_blackmarket:server:UpdateSettings', false, function(res)
        cb(res)
    end, data)
end)

RegisterNUICallback('depositStock', function(data, cb)
    lib.callback('void_blackmarket:server:DepositStock', false, function(res)
        cb(res)
    end, data)
end)

RegisterNUICallback('withdrawStock', function(data, cb)
    lib.callback('void_blackmarket:server:WithdrawStock', false, function(res)
        cb(res)
    end, data)
end)

RegisterNUICallback('updateStockPrice', function(data, cb)
    lib.callback('void_blackmarket:server:UpdateStockPrice', false, function(res)
        cb(res)
    end, data)
end)

RegisterNUICallback('verifyItemName', function(data, cb)
    lib.callback('void_blackmarket:server:VerifyItemName', false, function(res)
        cb(res)
    end, data.itemName)
end)

RegisterNUICallback('getPlayerInventory', function(data, cb)
    lib.callback('void_blackmarket:server:GetPlayerInventory', false, function(invList)
        cb(invList or {})
    end)
end)

-- Register NUI Callback for creator submission
RegisterNUICallback('submitCreateMarket', function(data, cb)
    SetNuiFocus(false, false)
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    local location = vector4(playerCoords.x, playerCoords.y, playerCoords.z, playerHeading)
    
    local payload = {
        name = data.name,
        label = data.label,
        ownerJob = data.ownerJob,
        pedModel = data.pedModel or 'g_m_m_mexboss_01',
        blipSprite = tonumber(data.blipSprite) or 501,
        blipColor = tonumber(data.blipColor) or 1,
        blipScale = tonumber(data.blipScale) or 0.8,
        coords = location
    }
    
    TriggerServerEvent('void_blackmarket:server:CreateMarket', payload)
    cb('ok')
end)

-- --- ADMIN COMMANDS ---

RegisterCommand('createblackmarket', function()
    -- Check permissions
    lib.callback('void_blackmarket:server:CheckAdminPerms', false, function(isAdmin)
        if not isAdmin then
            Bridge.Notify("You do not have permission to use this command.", "error")
            return
        end
        
        SendNUIMessage({
            action = "openCreator"
        })
        SetNuiFocus(true, true)
    end)
end, false)

-- Edit/Delete nearest Black Market Admin command
RegisterCommand('deleteblackmarket', function()
    lib.callback('void_blackmarket:server:CheckAdminPerms', false, function(isAdmin)
        if not isAdmin then
            Bridge.Notify("No permission.", "error")
            return
        end
        
        local playerCoords = GetEntityCoords(PlayerPedId())
        local nearestId = nil
        local nearestDist = 999.0
        
        for id, market in pairs(SyncMarkets) do
            local dist = #(playerCoords - market.coords.xyz)
            if dist < nearestDist then
                nearestDist = dist
                nearestId = id
            end
        end
        
        if nearestId and nearestDist < 5.0 then
            local alert = lib.alertDialog({
                header = 'Delete Black Market?',
                content = ('Are you sure you want to delete "%s" (%s)? This cannot be undone!'):format(SyncMarkets[nearestId].label, SyncMarkets[nearestId].name),
                centered = true,
                cancel = true
            })
            if alert == 'confirm' then
                TriggerServerEvent('void_blackmarket:server:DeleteMarket', nearestId)
            end
        else
            Bridge.Notify("No black market found within 5 meters.", "error")
        end
    end)
end, false)
