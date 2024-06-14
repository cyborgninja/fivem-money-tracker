local QBCore = exports['qb-core']:GetCoreObject()

-- settings
local largeAmountThreshold = 10000 -- set amount threshold
local discordWebhookUrl = "" -- set discordWebhookUrl

-- send Discord message
local function sendToDiscord(playerName, changeType, amountChanged, moneyType)
    local color
    if changeType == "add" then
        color = 3066993 -- green for increase
    else
        color = 15158332 -- red for decrease
    end

    -- alert contents
    local title = "Money Alert"
    local description = table.concat({
        "**Player:** " .. playerName, -- e.g. John Doe
        "**Type:** " .. changeType, -- e.g. add/remove
        "**Money Type:** " .. moneyType -- e.g. cash or bank
        "**Value:** " .. amountChanged -- e.g. 20000
    }, "\n")

    local embed = {
        {
            ["color"] = color,
            ["title"] = title,
            ["description"] = description,
            ["footer"] = {
                ["text"] = os.date("%Y-%m-%d %H:%M:%S")
            }
        }
    }

    PerformHttpRequest(discordWebhookUrl, function(err, text, headers) end, 'POST', json.encode({username = "Money Alert Bot", embeds = embed}), { ['Content-Type'] = 'application/json' })
end

-- Alert and check
local function monitorPlayerMoney(playerId, oldMoney, newMoney, moneyType, changeType)
    oldMoney = tonumber(oldMoney) or 0
    newMoney = tonumber(newMoney) or 0
    local amountChanged = newMoney - oldMoney
    if math.abs(amountChanged) >= largeAmountThreshold then
        local player = QBCore.Functions.GetPlayer(playerId)
        if player then
            local playerName = player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname
            sendToDiscord(playerName, changeType, amountChanged, moneyType)
        end
    end
end

-- override AddMoney
local originalAddMoney = QBCore.Functions.AddMoney
QBCore.Functions.AddMoney = function(source, moneyType, amount, reason, ...)
    local player = QBCore.Functions.GetPlayer(source)
    if player then
        local oldMoney = player.Functions.GetMoney(moneyType)
        local result = originalAddMoney(source, moneyType, amount, reason, ...)
        local newMoney = player.Functions.GetMoney(moneyType)
        local changeType = amount > 0 and "increased" or "decreased"
        TriggerEvent('QBCore:Server:OnMoneyChange', player.PlayerData.source, oldMoney, newMoney, moneyType, changeType)
        return result
    end
end

-- override RemoveMoney
local originalRemoveMoney = QBCore.Functions.RemoveMoney
QBCore.Functions.RemoveMoney = function(source, moneyType, amount, reason, ...)
    local player = QBCore.Functions.GetPlayer(source)
    if player then
        local oldMoney = player.Functions.GetMoney(moneyType)
        local result = originalRemoveMoney(source, moneyType, amount, reason, ...)
        local newMoney = player.Functions.GetMoney(moneyType)
        local changeType = amount > 0 and "increased" or "decreased"
        TriggerEvent('QBCore:Server:OnMoneyChange', player.PlayerData.source, oldMoney, newMoney, moneyType, changeType)
        return result
    end
end

-- check players money
RegisterNetEvent('QBCore:Server:OnMoneyChange')
AddEventHandler('QBCore:Server:OnMoneyChange', function(playerId, oldMoney, newMoney, moneyType, changeType)
    monitorPlayerMoney(playerId, oldMoney, newMoney, moneyType, changeType)
end)

-- initialization on player data load
RegisterNetEvent('QBCore:Server:PlayerLoaded')
AddEventHandler('QBCore:Server:PlayerLoaded', function(playerId, playerData)
    local player = QBCore.Functions.GetPlayer(playerId)
    if player then
        local oldCash = player.Functions.GetMoney('cash')
        local oldBank = player.Functions.GetMoney('bank')

        -- 初期化時の金額を監視
        monitorPlayerMoney(playerId, oldCash, oldCash, "cash", "initialized")
        monitorPlayerMoney(playerId, oldBank, oldBank, "bank", "initialized")
    end
end)
