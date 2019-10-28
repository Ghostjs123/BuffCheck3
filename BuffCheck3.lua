BuffCheck3 = {}
BuffCheck3.debugmode = true;

BuffCheck3_DefaultFrameSize = 100

BuffCheck3_TestTable = {}
BuffCheck3_SavedConsumes = {}
BuffCheck3_Config = {}
BuffCheck3.BagContents = {}

BuffCheck3_TimeSinceLastUpdate = 0
BuffCheck3.WasInCombat = false
BuffCheck3.WasSpellTargeting = false
BuffCheck3.WasHiddinInRaid = false

BuffCheck3_PrintFormat = "|c00f7f26c%s|r"

-- ConsumeFrame
BuffCheck3.AllActive = nil
BuffCheck3.AllConsumeButtons = {}
BuffCheck3.ActiveConsumes = {}
BuffCheck3.InactiveConsumes = {}

-- ConsumeList
BuffCheck3.AvailableButtons = {}
BuffCheck3.AddedButtons = {}

BuffCheck3.LockedBackdrop = {
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
    tileSize = 32,
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
    tile = true,
    tileEdge = false,
    edgeSize = 1,
    insets = {
        top = 12,
        right = 12,
        left = 11,
        bottom = 11
    }
}
BuffCheck3.UnlockedBackdrop = {
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
    tileSize = 32,
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
    tile = true,
    tileEdge = true,
    edgeSize = 32,
    insets = {
        top = 12,
        right = 12,
        left = 11,
        bottom = 11
    }
}

BuffCheck3.FoodBuffList = {
    "Well Fed",
    "Increased Stamina",
    "Increased Intellect",
    "Increased Agility",
    "Brain Food",
    "Blessed Sunfruit",
    "Blessed Sunfruit Juice",
    "Mana Regeneration"
}

SLASH_BUFFCHECK1 = "/bc"
SLASH_BUFFCHECK2 = "/buffcheck"
function SlashCmdList.BUFFCHECK(args)
    words = {}
    for word in args:gmatch("%w+") do table.insert(words, word) end

    for i = 1, table.getn(words) do
        words[i] = strlower(words[i])
    end

    if BuffCheck3:HasValue(words, "update") then
        BuffCheck3:ShowConsumeList()
    elseif BuffCheck3:HasValue(words, "show") then
        BuffCheck3:ShowFrame()
    elseif BuffCheck3:HasValue(words, "hide") then
        BuffCheck3:HideFrame()
    elseif BuffCheck3:HasValue(words, "lock") then
        BuffCheck3:LockFrame()
    elseif BuffCheck3:HasValue(words, "unlock") then
        BuffCheck3:UnlockFrame()
    elseif BuffCheck3:HasValue(words, "resize") then
        local size = BuffCheck3:GetSizeFromArgs(words)
        if size then
            BuffCheck3:ResizeFrame(size)
        else
            BuffCheck3:SendMessage("Missing Size")
        end
    elseif BuffCheck3:HasValue(words, "clear") then
        BuffCheck3:Clear()
    else
        BuffCheck3:SendMessage("Options: update, show, hide, lock, unlock, resize")
    end
end

function BuffCheck3:GetSizeFromArgs(args)
    if(args[2] and tonumber(args[2]) ~= nil) then
        return tonumber(args[2])
    end
    return nil
end

function BuffCheck3:OnLoad(self)
    self:RegisterEvent("ADDON_LOADED")
    -- self:RegisterEvent("PLAYER_AURAS_CHANGED") -- deprecated event
    self:RegisterEvent("UNIT_INVENTORY_CHANGED")
    self:RegisterEvent("BAG_UPDATE")
end

-- function BuffCheck3:SetDefaultConfig()
--     DEFAULT_CHAT_FRAME:AddMessage("setting to default")
--     BuffCheck3_Config["locked"] = false
--     BuffCheck3_Config["showing"] = true
--     BuffCheck3_Config["scale"] = BuffCheck3_DefaultFrameSize
-- end

function BuffCheck3:Init()
    if not BuffCheck3_Config["locked"] then
        BuffCheck3:UnlockFrame(false)
    else
        BuffCheck3:LockFrame(false)
    end

    if not BuffCheck3_Config["showing"] then
        BuffCheck3:HideFrame(false)
    else
        BuffCheck3:ShowFrame(false)
    end

    if BuffCheck3_Config["scale"] then
        BuffCheck3:ResizeFrame(BuffCheck3_Config["scale"])
    else
        BuffCheck3:ResizeFrame(BuffCheck3_DefaultFrameSize) -- default
    end

    BuffCheck3:UpdateBagContents()
    BuffCheck3:UpdateFrame()

    -- set the OnUpdate event
    BuffCheck3Frame:SetScript("OnUpdate", BuffCheck3_OnUpdate)

    BuffCheck3:SendMessage("Init Successful")
end

function BuffCheck3:OnEvent(event, arg1)
    if event == "ADDON_LOADED" and arg1 == "BuffCheck3" then
        BuffCheck3:Init()
    elseif event == "BAG_UPDATE" then
        BuffCheck3:UpdateBagContents()
        BuffCheck3:UpdateItemCounts()
    end
end

--=================================================================
-- OnUpdate handler - crucial to this addon

function BuffCheck3_OnUpdate(self, elapsed)
    BuffCheck3_TimeSinceLastUpdate = BuffCheck3_TimeSinceLastUpdate + elapsed
    if BuffCheck3_TimeSinceLastUpdate > 0.5 then
        BuffCheck3_TimeSinceLastUpdate = 0

        local incombat = UnitAffectingCombat("player")

        if incombat then
            -- make all the buttons opaque
            BuffCheck3.WasInCombat = true
            for _, f in pairs(BuffCheck3.InactiveConsumes) do
                f:SetAlpha(0.4)
            end
        else
            -- add/remove buttons as buffs update
            BuffCheck3:UpdateFrame()
        end

        -- fix all the opaque buttons
        if not incombat and BuffCheck3.WasInCombat then
            BuffCheck3.WasInCombat = false
            for _, f in pairs(BuffCheck3.AllConsumeButtons) do
                f:SetAlpha(1)
            end
        end

        -- WeaponFrame stuff - hide em if no longer trying to apply enchant
        if BuffCheck3.WasSpellTargeting and not SpellIsTargeting() then
            BuffCheck3.WasSpellTargeting = false
            BuffCheck3WeaponFrame:Hide()
        end
        if not BuffCheck3.WasSpellTargeting and SpellIsTargeting() then
            BuffCheck3.WasSpellTargeting = true
        end

        -- check for item gcd
        for _, f in pairs(BuffCheck3.InactiveConsumes) do
            local start, duration = GetItemCooldown(BuffCheck3:LinkToID(f.consume))
            f.cooldown(start, duration)
        end

        -- show in raids
        BuffCheck3:CheckGroupUpdate()
    end
end

--=================================================================
-- Consume List Functions

function BuffCheck3_MoveToAvailable(self)
    local index = BuffCheck3:GetIndexInTable(BuffCheck3_SavedConsumes, self.consume)
    if index == -1 then
        BuffCheck3:SendMessage("Error - could find " .. tostring(consume) .. " in BuffCheck3_SavedConsumes")
        return
    end
    table.remove(BuffCheck3_SavedConsumes, index)
    table.insert(BuffCheck3.AvailableButtons, self)
    local index = BuffCheck3:GetIndexInTable(BuffCheck3.AddedButtons, self)
    if index ~= -1 then
        table.remove(BuffCheck3.AddedButtons, index)
    end
    BuffCheck3:ShowConsumeButtons()
    -- update the frame
    BuffCheck3:UpdateFrame()
end

function BuffCheck3_MoveToAdded(self)
    table.insert(BuffCheck3_SavedConsumes, self.consume)
    table.insert(BuffCheck3.AddedButtons, self)
    local index = BuffCheck3:GetIndexInTable(BuffCheck3.AvailableButtons, self)
    if index ~= -1 then
        table.remove(BuffCheck3.AvailableButtons, index)
    end
    BuffCheck3:ShowConsumeButtons()
    -- update the frame
    BuffCheck3:UpdateFrame()
end

function BuffCheck3:ShowConsumeList()
    BuffCheck3:UpdateBagContents()
    BuffCheck3:UpdateConsumeList()
    BuffCheck3ConsumeList:Show()
end

function BuffCheck3:HideConsumeList()
    BuffCheck3ConsumeList:Hide()
    if UnitInRaid("player") then
        BuffCheck3.WasHiddinInRaid = true
    end
end

function BuffCheck3:ConsumeListButtonExists(consume)
    for _, f in pairs(BuffCheck3.AvailableButtons) do
        if f.consume == consume then
            return true
        end
    end
    for _, f in pairs(BuffCheck3.AddedButtons) do
        if f.consume == consume then
            return true
        end
    end
    return false
end

function BuffCheck3:CreateConsumeListButton(consume)
    local parent = getglobal("BuffCheck3ConsumeList")
    local fname = "BuffCheck3ConsumeButton" .. (table.getn(BuffCheck3.AvailableButtons)
        + table.getn(BuffCheck3.AddedButtons))

     -- more info on the item
     local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(consume)

    -- create the button
    f = CreateFrame("Button", fname, parent, "BuffCheck3ConsumeRowTemplate")
    f.consume = consume

    -- set text
    local ftext = getglobal(fname.."Name")
    ftext:SetText(name)
    local r,g,b = GetItemQualityColor(quality)
    ftext:SetTextColor(r,g,b)

    -- set icon
    local icon = getglobal(fname.."Icon")
    icon:SetTexture(texture)
    icon:SetVertexColor(1,1,1)

    return f
end

-- main purpose is to create buttons and add em to the correct list
function BuffCheck3:UpdateConsumeList()
    -- create a button for each consume
    for consume, _ in pairs(BuffCheck3.BagContents) do
        -- check if the consume already has a button
        if not BuffCheck3:ConsumeListButtonExists(consume) then
            
            f = BuffCheck3:CreateConsumeListButton(consume)
            -- add to appropriate list
            local isadded = BuffCheck3:HasValue(BuffCheck3_SavedConsumes, consume)
            if not isadded then
                table.insert(BuffCheck3.AvailableButtons, f)
            else
                table.insert(BuffCheck3.AddedButtons, f)
            end
        end
    end
    -- show all the buttons
    BuffCheck3:ShowConsumeButtons()
end

function BuffCheck3:ShowConsumeButtons()
    local fheight = 24
    local prev = getglobal("BuffCheck3ConsumeList")
    for i, f in ipairs(BuffCheck3.AvailableButtons) do
        f:ClearAllPoints()
        if i == 1 then
            f:SetPoint("TOPLEFT", prev, 15, -fheight*2)
        else
            f:SetPoint("TOPLEFT", prev, 0, -fheight)
        end
        f:SetScript("OnClick", BuffCheck3_MoveToAdded)
        prev = f
    end
    
    prev = getglobal("BuffCheck3ConsumeList")
    for i, f in ipairs(BuffCheck3.AddedButtons) do
        f:ClearAllPoints()
        if i == 1 then
            f:SetPoint("TOP", prev, 106, -fheight*2)
        else
            f:SetPoint("TOPLEFT", prev, 0, -fheight)
        end
        f:SetScript("OnClick", BuffCheck3_MoveToAvailable)
        prev = f
    end

    local numAvail = table.getn(BuffCheck3.AvailableButtons)
    local numAdded = table.getn(BuffCheck3.AddedButtons)
    -- update height
    if numAvail > numAdded then
        BuffCheck3ConsumeList:SetHeight(60 + numAvail*fheight)
    else
        BuffCheck3ConsumeList:SetHeight(60 + numAdded*fheight)
    end

    -- if either lists are empty add a msg
    if numAvail == 0 then
        BuffCheck3:ShowNoAvailableMsg(true)
    else
        BuffCheck3:ShowNoAvailableMsg(false)
    end
    if numAdded == 0 then
        BuffCheck3:ShowNoAddedMsg(true)
    else
        BuffCheck3:ShowNoAddedMsg(false)
    end
end

function BuffCheck3:ShowNoAvailableMsg(shouldshow)
    if shouldshow then
        getglobal("BuffCheck3ConsumeListNoAvailableText"):Show()
    else
        getglobal("BuffCheck3ConsumeListNoAvailableText"):Hide()
    end
end

function BuffCheck3:ShowNoAddedMsg(shouldshow)
    if shouldshow then
        getglobal("BuffCheck3ConsumeListNoAddedText"):Show()
    else
        getglobal("BuffCheck3ConsumeListNoAddedText"):Hide()
    end
end

-- debug only
function BuffCheck3:PrintAllConsumes()
    BuffCheck3:tprint(BuffCheck3.BagContents)
end

--=================================================================
-- Command Functions

function BuffCheck3:ShowFrame(shouldprint)
    BuffCheck3_Config["showing"] = true
    BuffCheck3Frame:Show()
    if shouldprint ~= false then
        BuffCheck3:SendMessage("Interface showing")
    end
    if BuffCheck3.WasHiddinInRaid and UnitInRaid("player") then
        BuffCheck3.WasHiddinInRaid = false
    end
end

function BuffCheck3:HideFrame(shouldprint)
    BuffCheck3_Config["showing"] = false
    BuffCheck3Frame:Hide()
    if shouldprint ~= false then
        BuffCheck3:SendMessage("Interface hidden")
    end
end

function BuffCheck3:LockFrame(shouldprint)
    BuffCheck3_Config["locked"] = true
    BuffCheck3Frame:EnableMouse(false)
    BuffCheck3Frame:SetBackdrop(BuffCheck3.LockedBackdrop)
    if shouldprint ~= false then
        BuffCheck3:SendMessage("Interface locked")
    end
end

function BuffCheck3:UnlockFrame(shouldprint)
    BuffCheck3_Config["locked"] = false
    BuffCheck3Frame:EnableMouse(true)
    BuffCheck3Frame:SetBackdrop(BuffCheck3.UnlockedBackdrop)
    if shouldprint ~= false then
        BuffCheck3:SendMessage("Interface unlocked")
    end
end

function BuffCheck3:ResizeFrame(size)
    BuffCheck3_Config["scale"] = size
    BuffCheck3Frame:SetScale(BuffCheck3_Config["scale"] / 100)
    BuffCheck3WeaponFrame:SetScale(BuffCheck3_Config["scale"] / 100)
    BuffCheck3Frame:ClearAllPoints()
    BuffCheck3Frame:SetPoint("CENTER", "UIParent") -- inelegant solution, but w/e
end

function BuffCheck3:Clear()
    for k in pairs(BuffCheck3_SavedConsumes) do
        BuffCheck3_SavedConsumes[k] = nil
    end
end

--=================================================================
-- Main Addon Functions

function BuffCheck3:CheckGroupUpdate()
    if not BuffCheck3:IsShown() and UnitInRaid("player") and not BuffCheck3.WasHiddinInRaid then
        BuffCheck3:ShowFrame()
    end
end

function BuffCheck3:GetBagCount(consume)
    for con, count in pairs(BuffCheck3.BagContents) do
        if con == consume then
            return tostring(count)
        end
    end
    return "0"
end

function BuffCheck3:UpdateBagContents()
    BuffCheck3.BagContents = {}
    local link
    local itemType
    local count
    local name
    for i = 0, 4 do
        for j = 1, GetContainerNumSlots(i) do
            _, count, _, _, _, _, link = GetContainerItemInfo(i, j)
            if link then
                name = GetItemInfo(link)
                _, _, _, _, _, itemType = GetItemInfo(link)
                if itemType == "Consumable" or string.match(name, "Sharpening") or string.match(name, "Weightstone") then
                    if BuffCheck3.BagContents[link] then
                        BuffCheck3.BagContents[link] = BuffCheck3.BagContents[link] + count
                    else
                        BuffCheck3.BagContents[link] = count
                    end
                end
            end
        end
    end
    -- also toss in saved consumes
    for _, consume in pairs(BuffCheck3_SavedConsumes) do
        if not BuffCheck3.BagContents[consume] then
            BuffCheck3.BagContents[consume] = 0
        end
    end
end

function BuffCheck3:IsFoodBuffPresent()
    for x = 1, 32 do
        local name = UnitBuff("player", x)
        if BuffCheck3:HasValue(BuffCheck3.FoodBuffList, name) then
            return true
        end
    end
    return false
end

function BuffCheck3:IsWeaponBuff(consume)
    local buffname, spellid = GetItemSpell(consume)
    local words = {}
    for word in buffname:gmatch("%w+") do table.insert(words, word) end
    return words[1] == "Sharpen" or words[1] == "Enhance"
end

function BuffCheck3:IsWeaponBuffName(buffname)
    local words = {}
    for word in buffname:gmatch("%w+") do table.insert(words, word) end
    return words[1] == "Sharpen" or words[1] == "Enhance"
end

function BuffCheck3:IsWeaponBuffsPresent()
    local hasMainHandEnchant, _, _, hasOffHandEnchant, _, _, _, _, _ = GetWeaponEnchantInfo()
    local mainHandLink = GetInventoryItemLink("player", GetInventorySlotInfo("MainHandSlot"))
    local offHandLink = GetInventoryItemLink("player", GetInventorySlotInfo("SecondaryHandSlot"))
    local faction = UnitFactionGroup("player")
    local class = UnitClass("player")
    if (faction == "Horde" and class ~= "Warrior" and class ~= "Rogue") or faction == "Alliance" then
        if BuffCheck3:ItemIsEnchantable(mainHandLink) and not hasMainHandEnchant then
            return false
        end
    end
    if BuffCheck3:ItemIsEnchantable(offHandLink) and not hasOffHandEnchant then
        return false
    end
    -- mainhand and offhand are enchanted in regards to faction and class
    return true
end

function BuffCheck3:IsBuffPresent(consume)
    local buffname, spellid = GetItemSpell(consume)

    -- occasionally happens with weird consumes
    if buffname == nil then
        return
    end
    
    -- checking food buffs
    if buffname == "Food" then
        return BuffCheck3:IsFoodBuffPresent()
    end

    -- checking weapon buff
    if BuffCheck3:IsWeaponBuffName(buffname) then
        return BuffCheck3:IsWeaponBuffsPresent()
    end

    -- checking consume buff
    for x = 1, 32 do
        local name = UnitBuff("player", x)
        if name == buffname then
            return true
        end
    end
    return false
end

function BuffCheck3:ItemIsEnchantable(itemlink)
    if itemlink == nil then return false end
    -- name, link, quality, iLevel, reqLevel, class, subclass
    local _, _, _, _, _, _, sType = GetItemInfo(itemlink)
    if sType == nil then return false end
    return string.sub(sType, 0, 1) == "O" or string.sub(sType, 0, 1) == "D" or string.sub(sType, 0, 1) == "T" or string.sub(sType, 0, 1) == "F"
end

--=================================================================
-- Consume Frame Functions

-- updates the counts on the frame
function BuffCheck3:UpdateItemCounts()
    for _, f in pairs(BuffCheck3.AllConsumeButtons) do
        local fcount = getglobal(f:GetName().."Count")
        local count = BuffCheck3:GetBagCount(f.consume)
        if fcount:GetText() ~= tostring(count) then
            fcount:SetText(count)
            if string.len(count) == 2 then
                fcount:ClearAllPoints()
                fcount:SetPoint("LEFT", f, "RIGHT", -16, -10)
            else
                fcount:ClearAllPoints()
                fcount:SetPoint("LEFT", f, "RIGHT", -10, -10)
            end
        end
    end
end

function BuffCheck3:ConsumeFrameButtonExists(consume)
    for _, f in pairs(BuffCheck3.AllConsumeButtons) do
        if f.consume == consume then
            return true
        end
    end
    return false
end

function BuffCheck3:CreateConsumeFrameButton(consume)
    local parent = getglobal("BuffCheck3Frame")
    local fname = "BuffCheck3FrameButton" .. table.getn(BuffCheck3.AllConsumeButtons)

    -- more info on the item
    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(consume)
    f = CreateFrame("Button", fname, parent, "BuffCheck3ButtonTemplate")
    f.consume = consume

    -- set icon
    local icon = getglobal(fname.."Icon")
    icon:SetTexture(texture)
    icon:SetVertexColor(1,1,1)

    --create cooldown frame
    local myCooldown = CreateFrame("Cooldown", f:GetName().."Cooldown", f, "CooldownFrameTemplate")
    myCooldown:SetAllPoints()

    f.cooldown = function(start, duration)
        myCooldown:SetCooldown(start, duration)
    end

    -- set the onclick attribute for SecureActionButton
    f:SetAttribute("item", consume)

    return f
end

-- manages the Active and Inactive List
function BuffCheck3:UpdateFrame()

    -- create a button for each consume if it doesnt already exist
    for _, consume in pairs(BuffCheck3_SavedConsumes) do
        if not BuffCheck3:ConsumeFrameButtonExists(consume) then
            -- create the button and add it to the list
            table.insert(BuffCheck3.AllConsumeButtons,
                BuffCheck3:CreateConsumeFrameButton(consume))
        end
    end
    -- sort the buttons into Active and Inactive
    BuffCheck3:SortConsumeFrameButtons()
    -- add counts to the buttons
    BuffCheck3:UpdateItemCounts()

    BuffCheck3:ShowInactiveConsumes()
end

function BuffCheck3:SortConsumeFrameButtons()
    BuffCheck3.ActiveConsumes = {}
    BuffCheck3.InactiveConsumes = {}
    for _, f in pairs(BuffCheck3.AllConsumeButtons) do
        -- only add consumes that are in SavedConsumes
        if BuffCheck3:HasValue(BuffCheck3_SavedConsumes, f.consume) then
            local isactive = BuffCheck3:IsBuffPresent(f.consume)
            if isactive then
                table.insert(BuffCheck3.ActiveConsumes, f)
            else
                table.insert(BuffCheck3.InactiveConsumes, f)
            end
        end
    end
end

function BuffCheck3:HideActiveButtons()
    for _, f in pairs(BuffCheck3.ActiveConsumes) do
        f:Hide()
    end
end

function BuffCheck3:ShowInactiveConsumes()
    local parent = getglobal("BuffCheck3Frame")
    local numInactive = table.getn(BuffCheck3.InactiveConsumes)

    -- update width
    BuffCheck3Frame:SetWidth(52 + 36*(numInactive -1))

    BuffCheck3:HideActiveButtons()
    for i, f in ipairs(BuffCheck3.InactiveConsumes) do
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", parent, "TOPLEFT", 11 + 36*(i-1), -11)
        f:Show()
    end

    -- if either lists are empty add a msg
    if numInactive == 0 then
        BuffCheck3:ShowAllActive()
    end
end

function BuffCheck3:ShowAllActive()
    BuffCheck3.AllActive = true
end

--=================================================================
-- Tooltip Stuff

function BuffCheck3:ShowConsumeListTooltip(consume, name)
    local _, link = GetItemInfo(consume)
    GameTooltip:SetOwner(getglobal(name), "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
end

function BuffCheck3:ShowConsumeFrameTooltip(consume, name)
    local _, link = GetItemInfo(consume)
    GameTooltip:SetOwner(getglobal(name), "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
end

function BuffCheck3:ShowWeaponTooltip(fname)
    local id = string.sub(fname, -1)
    if id == "1" then
        GameTooltip:SetOwner(getglobal("BuffCheck3WeaponButton"..id), "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetInventoryItem("player", GetInventorySlotInfo("MainHandSlot"))
        GameTooltip:Show()
    elseif id == "2" then
        GameTooltip:SetOwner(getglobal("BuffCheck3WeaponButton"..id), "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetInventoryItem("player", GetInventorySlotInfo("SecondaryHandSlot"))
        GameTooltip:Show()
    end
end

--=================================================================
-- WeaponButton Stuff

function BuffCheck3:ShowWeaponButtons(f)
    BuffCheck3WeaponFrame:ClearAllPoints()
    BuffCheck3WeaponFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -36)

    -- mainhand
    local mainHandTexture = GetInventoryItemTexture("player", GetInventorySlotInfo("MainHandSlot"))
    if mainHandTexture then
        BuffCheck3WeaponButton1Icon:SetTexture(mainHandTexture)
        BuffCheck3WeaponButton1:Show()
        
        -- set the onclick attribute for SecureActionButton
        local link = GetInventoryItemLink("player", GetInventorySlotInfo("MainHandSlot"))
        BuffCheck3WeaponButton1:SetAttribute("item", BuffCheck3:GetRawName(link))
    else
        BuffCheck3WeaponButton1:Hide()
    end

    -- offhand
    local offHandTexture = GetInventoryItemTexture("player", GetInventorySlotInfo("SecondaryHandSlot"))
    if offHandTexture then
        BuffCheck3WeaponButton2Icon:SetTexture(offHandTexture)
        BuffCheck3WeaponButton2:Show()
        
        -- set the onclick attribute for SecureActionButton
        local link = GetInventoryItemLink("player", GetInventorySlotInfo("SecondaryHandSlot"))
        BuffCheck3WeaponButton2:SetAttribute("item", BuffCheck3:GetRawName(link))
    else
        BuffCheck3WeaponButton2:Hide()
    end

    BuffCheck3WeaponFrame:Show()
end

--=================================================================
-- Helper Functions

function BuffCheck3:SendMessage(msg)
    local msg = string.format(BuffCheck3_PrintFormat, msg)
    DEFAULT_CHAT_FRAME:AddMessage(string.format(BuffCheck3_PrintFormat, "BuffCheck3: ") .. msg)
end

-- used for debug
function BuffCheck3:GetRawName(consume)
    -- matches text inside square brackets ex: [...] -> ...
    return string.match(consume, "%[(.+)%]")
end

function BuffCheck3:LinkToID(link)
    return string.match(link, ":(%d+)")
end

function BuffCheck3:HasValue(tab, val)
    for _, value in pairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

function BuffCheck3:GetIndexInTable(tab, val)
    for i, value in ipairs(tab) do
        if value == val then
            return i
        end
    end
    return -1
end

-- debug only
function BuffCheck3:tprint(tbl, indent)
    if not indent then indent = 0 end
    for k, v in pairs(tbl) do
        local formatting = string.rep("  ", indent) .. k .. ": "
        if type(v) == "table" then
            DEFAULT_CHAT_FRAME:AddMessage(formatting)
            BuffCheck3:tprint(v, indent+1)
        elseif type(v) == 'boolean' then
            DEFAULT_CHAT_FRAME:AddMessage(formatting .. tostring(v))
        else
            DEFAULT_CHAT_FRAME:AddMessage(formatting .. v)
        end
    end
end

function BuffCheck3:Test()
    for _, f in pairs(BuffCheck3.InactiveConsumes) do
        f.cooldown(GetTime(), 10)
    end
end
