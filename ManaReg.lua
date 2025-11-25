-- ManaReg: Addon to track mana regeneration (5-second rule) and energy ticks
-- Compatible with WoW 3.3.5

local ManaReg = CreateFrame("Frame")
local addonName = "ManaReg"

-- Default settings
local defaults = {
    enabled = true,
    showManaRegen = true,
    showEnergyTick = true,
    barWidth = 200,
    barHeight = 20,
    barX = 0,
    barY = -200,
}

-- Saved variables
ManaRegDB = ManaRegDB or {}

-- Local variables for tracking
local fiveSecondRuleActive = false
local fiveSecondRuleStart = 0
local energyTickTime = 2.0 -- Energy ticks every 2 seconds
local lastEnergyTick = 0
local lastEnergyAmount = 0
local playerClass = ""
local updateThrottle = 0
local throttleInterval = 0.1 -- Update display every 0.1 seconds

-- Constants
local POWER_TYPE_ENERGY = 3

-- Create the UI frame
local statusBar = CreateFrame("Frame", "ManaRegStatusBar", UIParent)
statusBar:SetWidth(200)
statusBar:SetHeight(20)
statusBar:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
statusBar:Hide()

-- Create background
statusBar.bg = statusBar:CreateTexture(nil, "BACKGROUND")
statusBar.bg:SetAllPoints(statusBar)
statusBar.bg:SetTexture(0, 0, 0, 0.5)

-- Create status bar texture
statusBar.bar = statusBar:CreateTexture(nil, "ARTWORK")
statusBar.bar:SetPoint("LEFT", statusBar, "LEFT", 2, 0)
statusBar.bar:SetHeight(16)
statusBar.bar:SetTexture(0, 0.5, 1, 0.8)

-- Create text overlay
statusBar.text = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statusBar.text:SetPoint("CENTER", statusBar, "CENTER", 0, 0)
statusBar.text:SetText("")

-- Function to initialize settings
local function InitializeSettings()
    for key, value in pairs(defaults) do
        if ManaRegDB[key] == nil then
            ManaRegDB[key] = value
        end
    end
    
    -- Apply saved position
    statusBar:ClearAllPoints()
    statusBar:SetPoint("CENTER", UIParent, "CENTER", ManaRegDB.barX, ManaRegDB.barY)
    statusBar:SetWidth(ManaRegDB.barWidth)
    statusBar:SetHeight(ManaRegDB.barHeight)
end

-- Function to check if player should track mana regen
local function ShouldTrackManaRegen()
    local _, class = UnitClass("player")
    playerClass = class
    -- Classes that use mana and care about the 5-second rule
    return class == "MAGE" or class == "PRIEST" or class == "WARLOCK" or 
           class == "PALADIN" or class == "DRUID" or class == "SHAMAN"
end

-- Function to check if player should track energy
local function ShouldTrackEnergy()
    local powerType = UnitPowerType("player")
    -- Energy users
    return powerType == POWER_TYPE_ENERGY
end

-- Function to start the 5-second rule timer
local function StartFiveSecondRule()
    if not ManaRegDB.showManaRegen then return end
    
    fiveSecondRuleActive = true
    fiveSecondRuleStart = GetTime()
end

-- Function to update the display
local function UpdateDisplay()
    if not ManaRegDB.enabled then
        statusBar:Hide()
        return
    end
    
    local currentTime = GetTime()
    local shouldShow = false
    local displayText = ""
    local barProgress = 0
    
    -- Check mana regeneration status
    if ManaRegDB.showManaRegen and ShouldTrackManaRegen() then
        if fiveSecondRuleActive then
            local elapsed = currentTime - fiveSecondRuleStart
            local remaining = 5.0 - elapsed
            
            if remaining > 0 then
                displayText = string.format("Mana Regen: %.1fs", remaining)
                barProgress = elapsed / 5.0
                shouldShow = true
            else
                fiveSecondRuleActive = false
            end
        end
    end
    
    -- Check energy tick status
    if ManaRegDB.showEnergyTick and ShouldTrackEnergy() then
        local timeSinceLastTick = currentTime - lastEnergyTick
        local timeToNextTick = energyTickTime - (timeSinceLastTick % energyTickTime)
        
        if timeToNextTick > 0 and timeToNextTick <= energyTickTime then
            if displayText ~= "" then
                displayText = displayText .. " | "
            end
            displayText = displayText .. string.format("Energy Tick: %.1fs", timeToNextTick)
            barProgress = math.max(barProgress, 1 - (timeToNextTick / energyTickTime))
            shouldShow = true
        end
    end
    
    if shouldShow then
        statusBar.text:SetText(displayText)
        statusBar.bar:SetWidth(math.max(1, (ManaRegDB.barWidth - 4) * barProgress))
        statusBar:Show()
    else
        statusBar:Hide()
    end
end

-- Event handler
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonLoaded = ...
        if addonLoaded == addonName then
            InitializeSettings()
            print("|cff00ff00ManaReg|r loaded. Type /manareg for options.")
        end
    elseif event == "PLAYER_LOGIN" then
        -- Set initial energy tick time and energy amount
        lastEnergyTick = GetTime()
        if ShouldTrackEnergy() then
            lastEnergyAmount = UnitPower("player", POWER_TYPE_ENERGY)
        end
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit = ...
        if unit == "player" and ShouldTrackManaRegen() then
            -- Start the 5-second rule when player begins casting
            StartFiveSecondRule()
        end
    elseif event == "UNIT_POWER_UPDATE" then
        local unit, powerType = ...
        if unit == "player" and powerType == "ENERGY" then
            -- Detect energy tick by checking if energy increased
            local currentEnergy = UnitPower("player", POWER_TYPE_ENERGY)
            if currentEnergy > lastEnergyAmount then
                -- Energy increased, likely a tick occurred
                lastEnergyTick = GetTime()
            end
            lastEnergyAmount = currentEnergy
        end
    end
end

-- Register events
ManaReg:RegisterEvent("ADDON_LOADED")
ManaReg:RegisterEvent("PLAYER_LOGIN")
ManaReg:RegisterEvent("UNIT_SPELLCAST_START")
ManaReg:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
ManaReg:RegisterEvent("UNIT_POWER_UPDATE")
ManaReg:SetScript("OnEvent", OnEvent)

-- OnUpdate handler for smooth display updates with throttling
statusBar:SetScript("OnUpdate", function(self, elapsed)
    updateThrottle = updateThrottle + elapsed
    if updateThrottle >= throttleInterval then
        updateThrottle = 0
        UpdateDisplay()
    end
end)

-- Slash command handler
local function SlashCommandHandler(msg)
    msg = string.lower(msg or "")
    
    if msg == "toggle" then
        ManaRegDB.enabled = not ManaRegDB.enabled
        print("|cff00ff00ManaReg|r " .. (ManaRegDB.enabled and "enabled" or "disabled"))
        UpdateDisplay()
    elseif msg == "mana" then
        ManaRegDB.showManaRegen = not ManaRegDB.showManaRegen
        print("|cff00ff00ManaReg|r Mana regen tracking " .. (ManaRegDB.showManaRegen and "enabled" or "disabled"))
    elseif msg == "energy" then
        ManaRegDB.showEnergyTick = not ManaRegDB.showEnergyTick
        print("|cff00ff00ManaReg|r Energy tick tracking " .. (ManaRegDB.showEnergyTick and "enabled" or "disabled"))
    elseif msg == "reset" then
        ManaRegDB = {}
        InitializeSettings()
        print("|cff00ff00ManaReg|r Settings reset to defaults")
    else
        print("|cff00ff00ManaReg|r Commands:")
        print("  /manareg toggle - Enable/disable addon")
        print("  /manareg mana - Toggle mana regen tracking")
        print("  /manareg energy - Toggle energy tick tracking")
        print("  /manareg reset - Reset settings to defaults")
    end
end

SLASH_MANAREG1 = "/manareg"
SlashCmdList["MANAREG"] = SlashCommandHandler

-- Make statusBar draggable
statusBar:SetMovable(true)
statusBar:EnableMouse(true)
statusBar:RegisterForDrag("LeftButton")
statusBar:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
statusBar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    ManaRegDB.barX = xOfs
    ManaRegDB.barY = yOfs
    print("|cff00ff00ManaReg|r Position saved")
end)
