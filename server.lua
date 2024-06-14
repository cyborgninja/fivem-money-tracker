local QBCore = exports['qb-core']:GetCoreObject()

-- settings
local largeAmountThreshold = 10000 -- set amount threshold
local discordWebhookUrl = "" -- set discordWebhookUrl


-- send Discord message
local function sendToDiscord(playerName, amountChanged)
    local color = amountChanged > 0 and 3066993 or 15158332 -- green increase / red decrease
    local changeType = amountChanged > 0 and "increased" or "decreased"

    -- alert contents
    local title = "Money Alert"
    local description = table.concat({
        "**Player:** " .. playerName, -- e.g. Jhon Do
        "**Type:** " .. changeType, -- e.g. bank/cash
        "**Value:** $" .. math.abs(amountChanged) -- e.g. 20000
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
local function monitorPlayerMoney(playerId, oldMoney, newMoney, playerName)
    local amountChanged = newMoney - oldMoney
    if math.abs(amountChanged) >= largeAmountThreshold then
        sendToDiscord(playerName, amountChanged)
    end
end

-- override AddMoney
local originalAddMoney = QBCore.Functions.AddMoney
QBCore.Functions.AddMoney = function(self, moneyType, amount, reason, ...)
    local oldMoney = self.Functions.GetMoney(moneyType)
    local result = originalAddMoney(self, moneyType, amount, reason, ...)
    local newMoney = self.Functions.GetMoney(moneyType)
    TriggerEvent('QBCore:Server:OnMoneyChange', self.PlayerData.source, oldMoney, newMoney, moneyType, self.PlayerData.charinfo.firstname)
    return result
end

-- override RemoveMoney
local originalRemoveMoney = QBCore.Functions.RemoveMoney
QBCore.Functions.RemoveMoney = function(self, moneyType, amount, reason, ...)
    local oldMoney = self.Functions.GetMoney(moneyType)
    local result = originalRemoveMoney(self, moneyType, amount, reason, ...)
    local newMoney = self.Functions.GetMoney(moneyType)
    TriggerEvent('QBCore:Server:OnMoneyChange', self.PlayerData.source, oldMoney, newMoney, moneyType, self.PlayerData.charinfo.firstname)
    return result
end

-- check players money
RegisterNetEvent('QBCore:Server:OnMoneyChange')
AddEventHandler('QBCore:Server:OnMoneyChange', function(playerId, oldMoney, newMoney, moneyType, playerName)
    monitorPlayerMoney(playerId, oldMoney, newMoney, playerName)
end)

-- initialzation on player data load
RegisterNetEvent('QBCore:Server:PlayerLoaded')
AddEventHandler('QBCore:Server:PlayerLoaded', function(playerId, playerData)
    local player = QBCore.Functions.GetPlayer(playerId)
    if player then
        local oldCash = player.Functions.GetMoney('cash')
        local oldBank = player.Functions.GetMoney('bank')

        monitorPlayerMoney(playerId, oldCash, oldCash, player.PlayerData.charinfo.firstname)
        monitorPlayerMoney(playerId, oldBank, oldBank, player.PlayerData.charinfo.firstname)
    end
end)
