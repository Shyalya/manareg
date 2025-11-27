local ADDON_NAME = "ManaReg"
local ManaReg = {}

-- SavedVariables Tabelle
ManaRegDB = ManaRegDB or {
    position = { point = "CENTER", relFrame = "UIParent", relPoint = "CENTER", x = 0, y = -150 },
}

ManaRegDB.colors = ManaRegDB.colors or {
    main = {0.2, 0.6, 1},
    fiveSecond = {1, 0.6, 0.1},
    tickMana = {0.2, 0.7, 1},
    tickEnergy = {1, 0.85, 0.2},
}
ManaRegDB.size = ManaRegDB.size or { width = 200, height = 20 }
ManaRegDB.comboLayoutMode = ManaRegDB.comboLayoutMode or "center"
ManaRegDB.locked = ManaRegDB.locked ~= false
ManaRegDB.subBarOutlineEnabled = (ManaRegDB.subBarOutlineEnabled ~= false) -- true standard
ManaRegDB.manaTickNormalized = (ManaRegDB.manaTickNormalized ~= false) -- Standard: normalisiert

-- Basisframe
local frame = CreateFrame("Frame", "ManaRegMainFrame", UIParent)
frame:SetSize(ManaRegDB.size.width, ManaRegDB.size.height)
frame:SetPoint(ManaRegDB.position.point, _G[ManaRegDB.position.relFrame] or UIParent, ManaRegDB.position.relPoint, ManaRegDB.position.x, ManaRegDB.position.y)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)

local bar = CreateFrame("StatusBar", nil, frame)
bar:SetAllPoints(frame)
bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
bar:SetMinMaxValues(0, 1)
bar:SetValue(0)
bar:GetStatusBarTexture():SetDrawLayer("BACKGROUND")
bar:SetFrameLevel(frame:GetFrameLevel())

local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
text:SetPoint("CENTER")
text:SetText("ManaReg")
text:SetDrawLayer("OVERLAY")
text:SetJustifyH("CENTER")
text:SetJustifyV("MIDDLE")
text:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
text:SetShadowOffset(0,0)

-- Zusatz Frames
local fsBar = CreateFrame("Frame", nil, frame)
fsBar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
fsBar:SetSize(ManaRegDB.size.width, 6)
fsBar:Hide()
local fsBg = fsBar:CreateTexture(nil, "BACKGROUND")
fsBg:SetAllPoints()
fsBg:SetColorTexture(0,0,0,0.5)
local fsFill = fsBar:CreateTexture(nil, "ARTWORK")
fsFill:SetPoint("TOPRIGHT")
fsFill:SetPoint("BOTTOMRIGHT")
fsFill:SetColorTexture(1,0.6,0.1,0.9)
fsFill:SetWidth(0)

local tickBar = CreateFrame("StatusBar", nil, frame)
tickBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
tickBar:SetPoint("TOPLEFT", fsBar, "BOTTOMLEFT", 0, -2)
tickBar:SetSize(ManaRegDB.size.width, 4)
tickBar:SetMinMaxValues(0,1)
tickBar:SetValue(0)
tickBar:Hide()

local comboFrame = CreateFrame("Frame", nil, frame)
comboFrame:SetPoint("BOTTOM", frame, "TOP", 0, 6)
comboFrame:SetSize(ManaRegDB.size.width, 18)
comboFrame:Hide()
-- Fester Standard: runde Punkte, Tooltip-Rahmen um Balken
-- Layering fix: ensure combo points above main frame
comboFrame:SetFrameStrata("HIGH")
comboFrame:SetFrameLevel(frame:GetFrameLevel() + 20)
local comboIcons = {}
local useFallbackSquares = true -- Fallback als Standard aktiv, da Texture unsichtbar war
local comboLayoutMode = ManaRegDB.comboLayoutMode -- geladener Modus (center Standard)
for i=1,5 do
    local ico = comboFrame:CreateTexture(nil, "ARTWORK")
    -- Classic Wrath / WotLK combo point texture path
    ico:SetTexture("Interface\\ComboFrame\\ComboPoint")
    ico:SetTexCoord(0,1,0,1)
    ico:Hide()
    comboIcons[i] = ico
end
local function LayoutComboIcons()
    local w = comboFrame:GetWidth()
    local spacing = 4
    local size
    if comboLayoutMode == "stretch" then
        local available = w - spacing * 4
        size = available / 5
        if size > 26 then size = 26 end
        if size < 12 then size = 12 end
        for i=1,5 do
            local el = comboIcons[i]
            el:ClearAllPoints()
            el:SetPoint("LEFT", comboFrame, "LEFT", (i-1)*(size+spacing), 0)
            el:SetWidth(size); el:SetHeight(size)
        end
    else -- center
        size = 18
        local totalWidth = size * 5 + spacing * 4
        local startX = (w - totalWidth) / 2
        for i=1,5 do
            local el = comboIcons[i]
            el:ClearAllPoints()
            el:SetPoint("LEFT", comboFrame, "LEFT", startX + (i-1)*(size+spacing), 0)
            el:SetWidth(size); el:SetHeight(size)
        end
    end
    comboFrame:SetHeight(size)
end

-- Sicherstellen, dass Combo Punkte immer über dem Hauptframe liegen
local function EnsureComboFrameLayer()
    comboFrame:SetFrameStrata("HIGH")
    comboFrame:SetFrameLevel(frame:GetFrameLevel() + 20)
    for _, ico in ipairs(comboIcons) do
        ico:SetDrawLayer("ARTWORK", 1)
    end
end

-- Parameter / Timer
local FIVE_SECONDS = 5
local MANA_TICK = 2
local ENERGY_TICK = 2
local lastManaCastTime = 0
local inFiveSecondRule = false
local tickElapsed = 0 -- energy tick tracker
local manaTickStartTime = GetTime() -- Startzeit des aktuellen Mana-Reg Ticks
local manaTickPaused = true -- pausiert während 5s Regel oder vollem Mana
local manaTickNormalized = ManaRegDB.manaTickNormalized
local lastDetectedManaRegen = 0
local lastManaValueForTick = UnitPower("player",0)
local haveActiveTickCycle = false
local energyCycleElapsed = 0
local tickDuration = MANA_TICK
local energyTickDurationOverride = ManaRegDB.energyTickDuration
local debugEnabled = false
local lastPowerValue = 0
local accum = 0

-- Utility
local function ApplyColors()
    local c = ManaRegDB.colors.fiveSecond
    fsFill:SetColorTexture(c[1], c[2], c[3], 0.9)
    local pType = UnitPowerType("player")
    if pType == 3 then
        local ce = ManaRegDB.colors.tickEnergy
        tickBar:SetStatusBarColor(ce[1], ce[2], ce[3], 0.8)
    else
        local cm = ManaRegDB.colors.tickMana
        tickBar:SetStatusBarColor(cm[1], cm[2], cm[3], 0.7)
    end
end

local function UpdateVisibility(pType)
    if pType == 0 then
        tickDuration = MANA_TICK
        if UnitPower("player",0) < UnitPowerMax("player",0) then
            tickBar:Show()
        else
            tickBar:Hide()
        end
        if inFiveSecondRule then fsBar:Show(); fsFill:Show() else fsBar:Hide(); fsFill:Hide() end
    elseif pType == 3 then
        fsBar:Hide(); fsFill:Hide()
        tickDuration = energyTickDurationOverride or ENERGY_TICK
        tickBar:Show()
    elseif pType == 1 then
        fsBar:Hide(); fsFill:Hide(); tickBar:Hide()
    else
        fsBar:Hide(); fsFill:Hide(); tickBar:Hide()
    end
    LayoutComboIcons()
end

local function UpdatePower()
    local pType = UnitPowerType("player")
    local current = UnitPower("player", pType)
    local max = UnitPowerMax("player", pType)
    bar:SetMinMaxValues(0, max)
    bar:SetValue(current)
    local color
    if pType == 0 then color = ManaRegDB.colors.main
    elseif pType == 1 then color = {1,0,0}
    elseif pType == 3 then color = {1,1,0}
    else color = {0.6,0.6,0.6} end
    bar:SetStatusBarColor(color[1], color[2], color[3])
    text:SetText(current.."/"..max)
    UpdateVisibility(pType)
    lastPowerValue = current
    ApplyColors()
end

local function OnManaCast(manaSpent)
    if UnitPowerType("player") == 0 and manaSpent and manaSpent > 0 then
        local now = GetTime()
        lastManaCastTime = now
        inFiveSecondRule = true
        fsBar:Show(); fsFill:Show(); fsFill:SetWidth(fsBar:GetWidth())
        manaTickPaused = true
        haveActiveTickCycle = false
    end
end

-- Robuste Aktivierung der 5s Regel bei jedem echten Mana-Verbrauch
local function StartFiveSecondRule()
    if UnitPowerType("player") ~= 0 then return end
    local now = GetTime()
    lastManaCastTime = now
    inFiveSecondRule = true
    fsBar:Show(); fsFill:Show(); fsFill:SetWidth(fsBar:GetWidth())
    manaTickPaused = true
    haveActiveTickCycle = false
    lastManaValueForTick = UnitPower("player", 0)
    manaTickStartTime = now
    if debugEnabled then DEFAULT_CHAT_FRAME:AddMessage("[ManaReg] 5s Regel gestartet") end
end

local function UpdateComboPoints()
    local class = select(2, UnitClass("player"))
    local pType = UnitPowerType("player")
    local isCat = (class == "DRUID" and pType == 3)
    local show = (class == "ROGUE") or isCat
    if not show then comboFrame:Hide(); return end
    comboFrame:Show(); LayoutComboIcons()
    local cp = GetComboPoints("player", "target") or 0
    for i=1,5 do
        local el = comboIcons[i]
        el:Show()
        if useFallbackSquares then
            -- Fallback: simple square color blocks
            if cp > 0 and i <= cp then
                local ratio = (i-1)/4
                el:SetColorTexture(1 - ratio, ratio, 0, 1)
            else
                el:SetColorTexture(0.35,0.35,0.35,0.7)
            end
        else
            -- Texture mode
            el:SetColorTexture(0,0,0,0) -- ensure not overridden from previous fallback
            if cp > 0 and i <= cp then
                local ratio = (i-1)/4
                el:SetVertexColor(1 - ratio, ratio, 0, 1)
            else
                el:SetVertexColor(0.4,0.4,0.4,0.9)
            end
        end
    end
    if debugEnabled then DEFAULT_CHAT_FRAME:AddMessage("[ManaReg] CP="..cp) end
end

-- Dragging
local function IsDragAllowed()
    if ManaRegDB.locked then return false end
    return IsShiftKeyDown()
end
frame:SetScript("OnMouseDown", function(self, btn) if btn=="LeftButton" and IsDragAllowed() then self:StartMoving() end end)
frame:SetScript("OnMouseUp", function(self, btn) if btn=="LeftButton" then self:StopMovingOrSizing() local p,rp,x,y = self:GetPoint() ManaRegDB.position.point=p ManaRegDB.position.relFrame="UIParent" ManaRegDB.position.relPoint=rp ManaRegDB.position.x=x ManaRegDB.position.y=y end end)

-- Border Hilfsfunktionen
local function AddMainBorder(f)
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    f:SetBackdropColor(0,0,0,0.55)
    f:SetBackdropBorderColor(0.65,0.65,0.65,1)
end

local function AddThinOutline(f)
    -- Erstelle 1px Linien mittels Texturen ohne schweren Tooltip Rahmen
    local thickness = 1
    if f.outlineTextures then
        for _,tx in ipairs(f.outlineTextures) do tx:Hide() end
    end
    f.outlineTextures = {}
    local function edge(r1,r2,r3,a)
        return r1 or 0.15, r2 or 0.15, r3 or 0.15, a or 0.9
    end
    local colorR,colorG,colorB,colorA = edge()
    local top = f:CreateTexture(nil, "OVERLAY")
    top:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
    top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 1, 1)
    top:SetHeight(thickness)
    top:SetColorTexture(colorR,colorG,colorB,colorA)
    local bottom = f:CreateTexture(nil, "OVERLAY")
    bottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -1, -1)
    bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
    bottom:SetHeight(thickness)
    bottom:SetColorTexture(colorR,colorG,colorB,colorA)
    local left = f:CreateTexture(nil, "OVERLAY")
    left:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
    left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -1, -1)
    left:SetWidth(thickness)
    left:SetColorTexture(colorR,colorG,colorB,colorA)
    local right = f:CreateTexture(nil, "OVERLAY")
    right:SetPoint("TOPRIGHT", f, "TOPRIGHT", 1, 1)
    right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
    right:SetWidth(thickness)
    right:SetColorTexture(colorR,colorG,colorB,colorA)
    table.insert(f.outlineTextures, top)
    table.insert(f.outlineTextures, bottom)
    table.insert(f.outlineTextures, left)
    table.insert(f.outlineTextures, right)
end

local function ApplyBorders()
    AddMainBorder(frame)
    if ManaRegDB.subBarOutlineEnabled then
        AddThinOutline(fsBar)
        AddThinOutline(tickBar)
    else
        if fsBar.outlineTextures then for _,tx in ipairs(fsBar.outlineTextures) do tx:Hide() end end
        if tickBar.outlineTextures then for _,tx in ipairs(tickBar.outlineTextures) do tx:Hide() end end
    end
end

comboFrame:SetPoint("BOTTOM", frame, "TOP", 0, 6)

-- OnUpdate
frame:SetScript("OnUpdate", function(self, elapsed)
    accum = accum + elapsed
    if accum < 0.02 then return end
    local pType = UnitPowerType("player")
    local now = GetTime()
    local current = UnitPower("player", pType)
    if current ~= lastPowerValue then
        -- Sofort Hauptbalken aktualisieren bei jeder Änderung (bes. Energie Verbrauch)
        bar:SetValue(current)
        text:SetText(current.."/"..UnitPowerMax("player", pType))
        if pType == 3 and current > lastPowerValue then
            tickElapsed = 0
            energyCycleElapsed = 0
        end
        if pType == 0 then
            local maxMana = UnitPowerMax("player",0)
            if current == maxMana then
                manaTickPaused = true
                haveActiveTickCycle = false
            elseif current < maxMana and not inFiveSecondRule and manaTickPaused then
                manaTickPaused = false
                -- warten auf erste Regeneration bevor Balken wirklich läuft
            end
        end
        if debugEnabled and pType == 3 then DEFAULT_CHAT_FRAME:AddMessage("[ManaReg] Energie="..current) end
        lastPowerValue = current
    end
    if pType == 0 and inFiveSecondRule then
        local rem = FIVE_SECONDS - (now - lastManaCastTime)
        if rem <= 0 then
            inFiveSecondRule=false
            fsFill:SetWidth(0); fsFill:Hide(); fsBar:Hide()
            -- Regel endet: Mana Tick wieder aktivieren wenn nicht volles Mana
            if UnitPower("player",0) < UnitPowerMax("player",0) then
                manaTickPaused = false
                haveActiveTickCycle = false
            end
        else
            fsFill:SetWidth(fsBar:GetWidth()* (rem/FIVE_SECONDS))
        end
    end
    -- Mana Tick Fortschritt deterministisch über Zeitdifferenz
    local manaTickProgress
    if pType == 0 and not inFiveSecondRule and not manaTickPaused then
        local manaNow = UnitPower("player",0)
        if manaNow > lastManaValueForTick then
            -- Mana Anstieg erkannt -> Tick-Zyklus starten
            if not haveActiveTickCycle then
                haveActiveTickCycle = true
                manaTickStartTime = now
                if debugEnabled then DEFAULT_CHAT_FRAME:AddMessage("[ManaReg] Tick-Zyklus gestartet") end
            end
        end
        lastManaValueForTick = manaNow
        if haveActiveTickCycle then
            local diff = now - manaTickStartTime
            if diff >= tickDuration then
                local cycles = math.floor(diff / tickDuration)
                manaTickStartTime = manaTickStartTime + cycles * tickDuration
                diff = diff - cycles * tickDuration
            end
            manaTickProgress = diff / tickDuration
        end
    end
    if pType == 3 then energyCycleElapsed = energyCycleElapsed + accum if energyCycleElapsed >= tickDuration then energyCycleElapsed = energyCycleElapsed - tickDuration end end
    if tickBar:IsShown() then
        if pType == 0 then
            local v = (manaTickProgress and manaTickProgress or 0)
            tickBar:SetValue(v)
        elseif pType == 3 then
            tickBar:SetValue(energyCycleElapsed / tickDuration)
        end
    end
    UpdateComboPoints()
    accum = 0
end)

-- Events
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterUnitEvent("UNIT_POWER", "player")
eventFrame:RegisterUnitEvent("UNIT_ENERGY", "player")
eventFrame:RegisterUnitEvent("UNIT_RAGE", "player")
eventFrame:RegisterUnitEvent("UNIT_RUNIC_POWER", "player")
eventFrame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
eventFrame:RegisterUnitEvent("UNIT_MANA", "player")
eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_INSTANT")
eventFrame:RegisterEvent("UNIT_COMBO_POINTS")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_COMBO_POINTS")
local preCastMana
eventFrame:SetScript("OnEvent", function(self, event, unit, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then UpdatePower(); UpdateComboPoints() return end
    if unit == "player" then
        if event == "UNIT_POWER" or event == "UNIT_MAXPOWER" or event == "UNIT_MANA" or event == "UNIT_ENERGY" or event == "UNIT_RAGE" or event == "UNIT_RUNIC_POWER" then 
            UpdatePower()
            -- Direkt bei UNIT_POWER/UNIT_MANA prüfen ob Mana abnimmt (= Spell gecastet)
            if (event == "UNIT_POWER" or event == "UNIT_MANA") and UnitPowerType("player") == 0 then
                local currentMana = UnitPower("player", 0)
                if lastManaValueForTick > currentMana then
                    -- Mana ist weniger geworden = Spell gecastet
                    local spent = lastManaValueForTick - currentMana
                    if debugEnabled then DEFAULT_CHAT_FRAME:AddMessage("[ManaReg] Mana spent: "..spent) end
                    OnManaCast(spent)
                end
                lastManaValueForTick = currentMana
            end
        end
        if event == "UNIT_SPELLCAST_START" and UnitPowerType("player") == 0 then preCastMana = UnitPower("player",0) end
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if preCastMana then local spent = preCastMana - UnitPower("player",0); OnManaCast(spent) end
            preCastMana = nil
        end
        if event == "UNIT_SPELLCAST_INSTANT" and UnitPowerType("player") == 0 then
            local currentMana = UnitPower("player",0)
            if not preCastMana then preCastMana = currentMana end
            local spent = preCastMana - currentMana
            if spent > 0 then
                OnManaCast(spent)
            end
            preCastMana = nil
        end
    end
    if event == "UNIT_COMBO_POINTS" or event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_COMBO_POINTS" then UpdateComboPoints() end
end)

-- Lock/Unlock
local function SetLocked(state) ManaRegDB.locked = state end

-- Slash Commands
SLASH_MANAREG1 = "/manareg"
SlashCmdList["MANAREG"] = function(msg)
    local args = {}
    for t in string.gmatch(msg, "[^%s]+") do table.insert(args,t) end
    local cmd = (args[1] and string.lower(args[1])) or "help"
    if cmd == "help" then
        print("ManaReg Befehle:")
        print("/manareg lock | unlock")
        print("/manareg width <zahl>")
        print("/manareg height <zahl>")
        print("/manareg color main|fs|tickmana|tickenergy r g b")
        print("/manareg energyduration <sek>")
        print("/manareg reset")
        print("/manareg debug")
    print("/manareg bordertoggle")
    print("/manareg cpfallback")
    print("/manareg cpshape")
    print("/manareg cplayout center|stretch")
    print("/manareg subborder on|off")
    print("/manareg manatickmode normalized|auth")
        return
    elseif cmd == "lock" then SetLocked(true); print("ManaReg: gesperrt.")
    elseif cmd == "unlock" then SetLocked(false); print("ManaReg: entsperrt (Shift+LMB).")
    elseif cmd == "width" and tonumber(args[2]) then local w=tonumber(args[2]); ManaRegDB.size.width=w; frame:SetWidth(w); fsBar:SetWidth(w); tickBar:SetWidth(w); comboFrame:SetWidth(w); EnsureComboFrameLayer()
    elseif cmd == "height" and tonumber(args[2]) then local h=tonumber(args[2]); ManaRegDB.size.height=h; frame:SetHeight(h); EnsureComboFrameLayer()
    elseif cmd == "color" and args[2] and tonumber(args[3]) and tonumber(args[4]) and tonumber(args[5]) then
        local which = string.lower(args[2]); local r,g,b = tonumber(args[3]),tonumber(args[4]),tonumber(args[5])
        if ManaRegDB.colors[which] then ManaRegDB.colors[which]={r,g,b} else print("Unbekannte Kategorie") end
        ApplyColors()
    elseif cmd == "energyduration" and tonumber(args[2]) then local v=tonumber(args[2]); if v>=0.5 and v<=5 then ManaRegDB.energyTickDuration=v; energyTickDurationOverride=v; print("Energie-Tick:"..v) else print("Ungültig (0.5-5)") end
    elseif cmd == "reset" then
        ManaRegDB.position = { point = "CENTER", relFrame = "UIParent", relPoint = "CENTER", x = 0, y = -150 }
        frame:ClearAllPoints(); frame:SetPoint(ManaRegDB.position.point, UIParent, ManaRegDB.position.relPoint, ManaRegDB.position.x, ManaRegDB.position.y)
        ManaRegDB.size = { width = 200, height = 20 }
        frame:SetSize(ManaRegDB.size.width, ManaRegDB.size.height); fsBar:SetWidth(ManaRegDB.size.width); tickBar:SetWidth(ManaRegDB.size.width); comboFrame:SetWidth(ManaRegDB.size.width); EnsureComboFrameLayer()
    elseif cmd == "debug" then debugEnabled = not debugEnabled; print("Debug "..(debugEnabled and "AN" or "AUS"))
    elseif cmd == "texttoggle" then
        if text:IsShown() then text:Hide() print("Text ausgeblendet") else text:Show() print("Text eingeblendet") end
    elseif cmd == "bordertoggle" then
        print("Border: fest aktiviert in Standard.")
    elseif cmd == "cpfallback" or cmd == "cpshape" then
        useFallbackSquares = not useFallbackSquares
        print("Combo Punkte Form: "..(useFallbackSquares and "Quadrate" or "Texture"))
        UpdateComboPoints()
    elseif cmd == "cplayout" and args[2] then
        local mode = string.lower(args[2])
        if mode == "center" or mode == "stretch" then
            comboLayoutMode = mode
            ManaRegDB.comboLayoutMode = mode
            print("Combo Punkte Layout gespeichert: "..mode)
            LayoutComboIcons(); UpdateComboPoints()
        else
            print("Ungültig: center|stretch")
        end
    elseif cmd == "subborder" and args[2] then
        local opt = string.lower(args[2])
        if opt == "on" then ManaRegDB.subBarOutlineEnabled = true; print("Sub-Bar Outline: AN") elseif opt == "off" then ManaRegDB.subBarOutlineEnabled = false; print("Sub-Bar Outline: AUS") else print("Ungültig: on|off") end
        ApplyBorders()
    elseif cmd == "manatickmode" and args[2] then
        local m = string.lower(args[2])
        if m == "normalized" then
            manaTickNormalized = true; ManaRegDB.manaTickNormalized = true; print("Mana Tick Modus: NORMALISIERT")
            if not manaTickPaused then manaTickStartTime = GetTime() end
        elseif m == "auth" or m == "authentic" then
            manaTickNormalized = false; ManaRegDB.manaTickNormalized = false; print("Mana Tick Modus: AUTHENTISCH")
            -- Authentisch: lässt StartTime unverändert
        else
            print("Ungültig: normalized|auth")
        end
    else print("/manareg help") end
end

-- Exporte
ManaReg.frame = frame
ManaReg.bar = bar
ManaReg.text = text
ManaReg.UpdatePower = UpdatePower
ManaReg.fsBar = fsBar
ManaReg.tickBar = tickBar
ManaReg.comboFrame = comboFrame
_G[ADDON_NAME] = ManaReg

-- Initialisieren
EnsureComboFrameLayer()
UpdatePower()
ApplyBorders()
UpdateComboPoints()

