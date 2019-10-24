BuffCheck3 = {}
BuffCheck3.debugmode = true;

BuffCheck3_DefaultFrameSize = 100

BuffCheck3_TestTable = {}
BuffCheck3_SavedConsumes = {}
BuffCheck3_Config = {}
BuffCheck3.BagContents = {}

BuffCheck3_TimeSinceLastUpdate = 0
BuffCheck3_PrintFormat = "|c00f7f26c%s|r"

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

    -- make a cooldown frame for each button
    -- local button
    -- for i = 1, bc2_button_count do
    --     button = getglobal("BuffCheck2Button"..i)
    --     local myCooldown = CreateFrame("Model", nil, button, "CooldownFrameTemplate")

    --     button.cooldown = function(start, duration)
    --         CooldownFrame_SetTimer(myCooldown, start, duration, 1)
    --     end
    -- end

    BuffCheck3:UpdateBagContents()
    BuffCheck3:UpdateFrame()
    BuffCheck3:UpdateItemCounts()

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
    if BuffCheck3_TimeSinceLastUpdate > 1 then
        BuffCheck3_TimeSinceLastUpdate = 0

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
end

function BuffCheck3_MoveToAdded(self)
    table.insert(BuffCheck3_SavedConsumes, self.consume)
    table.insert(BuffCheck3.AddedButtons, self)
    local index = BuffCheck3:GetIndexInTable(BuffCheck3.AvailableButtons, self)
    if index ~= -1 then
        table.remove(BuffCheck3.AvailableButtons, index)
    end
    BuffCheck3:ShowConsumeButtons()
end

function BuffCheck3:ShowConsumeList()
    BuffCheck3ConsumeList:Show()
    BuffCheck3:UpdateBagContents()
    BuffCheck3:UpdateConsumeList()
end

function BuffCheck3:HideConsumeList()
    BuffCheck3ConsumeList:Hide()
end

function BuffCheck3:ButtonExists(consume)
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

function BuffCheck3:UpdateConsumeList()
    local parent = getglobal("BuffCheck3ConsumeList")

    -- create a button for each consume
    for consume, _ in pairs(BuffCheck3.BagContents) do
        -- check if the consume already has a button
        if not BuffCheck3:ButtonExists(consume) then
            -- decide if available or added
            local isadded = BuffCheck3:HasValue(BuffCheck3_SavedConsumes, consume)
            local fname = "BuffCheck3ConsumeButton" .. (table.getn(BuffCheck3.AvailableButtons)
                + table.getn(BuffCheck3.AddedButtons))

            -- more info on the item
            local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(consume)
            
            -- create the button
            f = CreateFrame("Button", fname, parent, "BuffCheck3ConsumeRowTemplate")

            -- set text
            local ftext = getglobal(fname.."Name")
            ftext:SetText(name)
            local r,g,b = GetItemQualityColor(quality)
            ftext:SetTextColor(r,g,b)
            f.consume = consume

            -- set icon
            local icon = getglobal(fname.."Icon")
            icon:SetTexture(texture)
            icon:SetVertexColor(1,1,1)

            -- add to appropriate list
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
-- Consume Frame Functions

function BuffCheck3:ShowFrame(shouldprint)
    BuffCheck3_Config["showing"] = true
    BuffCheck3Frame:Show()
    if shouldprint ~= false then
        BuffCheck3:SendMessage("Interface showing")
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
    -- local backdrop = BuffCheck3Frame:GetBackdrop()
    -- BuffCheck3:tprint(backdrop)
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

function BuffCheck3:UpdateConsumeFrame()

end

--=================================================================
-- Main Addon Functions

function BuffCheck3:AddConsume(link)

end

function BuffCheck3:RemoveConsume(link)

end

function BuffCheck3:CheckGroupUpdate()
    if UnitInRaid("player") and not BuffCheck3:IsVisible() then
        BuffCheck3:ShowFrame()
    end
end

function BuffCheck3:UpdateBagContents()
    local link
    local itemType
    local itemCount
    for i = 0, 4 do
        for j = 0, GetContainerNumSlots(i) do
            local isC = IsConsumableItem(link)
            link = GetContainerItemLink(i, j)
            if link then -- nil if slot is empty
                local _, _, _, _, _, itemType = GetItemInfo(link)
                if itemType == "Consumable" then
                    _, itemCount, _, _, _ = GetContainerItemInfo(i, j)
                    if BuffCheck3.BagContents[link] then
                        BuffCheck3.BagContents[link] = BuffCheck3.BagContents[link] + itemCount
                    else
                        BuffCheck3.BagContents[link] = itemCount
                    end
                end
            end
        end
    end
end

-- updates the counts on the frame
function BuffCheck3:UpdateItemCounts()

end

function BuffCheck3:IsBuffPresent(consumename)
    local buffname, spellid = GetItemSpell(consumename)
    local name
    local words = {}
    for word in buffname:gmatch("%w+") do table.insert(words, word) end
    -- checking a weapon buff
    if words[1] == "Sharpen" or words[1] == "Enhance" then
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
    -- checking a consume buff
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
    return string.sub(sType, 0, 1) == "O" or string.sub(sType, 0, 1) == "D" or string.sub(sType, 0, 1) == "T"
end

-- uses the consume
function BuffCheck3:ButtonOnClick(consume)

end

function BuffCheck3:UpdateFrame()

end

--=================================================================
-- Tooltip Stuff

function BuffCheck3:ShowConsumeListTooltip(consume, name)
    local _, link = GetItemInfo(consume)
    GameTooltip:SetOwner(getglobal(name), "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
end

function BuffCheck3:ShowWeaponTooltip(id)

end

function BuffCheck3:HideWeaponTooltip(id)

end

--=================================================================
-- WeaponButton Stuff

function BuffCheck3:ShowWeaponButtons()

end

function BuffCheck3:HideWeaponButtons()

end

-- use cursor item on weapon
function BuffCheck3:WeaponButtonOnClick(id)

end

--=================================================================
-- Helper Functions

function BuffCheck3:SendMessage(msg)
    local msg = string.format(BuffCheck3_PrintFormat, msg)
    DEFAULT_CHAT_FRAME:AddMessage(string.format(BuffCheck3_PrintFormat, "BuffCheck3: ") .. msg)
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
