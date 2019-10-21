BuffCheck3 = {}
BuffCheck3.debugmode = true;

BuffCheck3_DefaultFrameSize = 100

BuffCheck3_TestTable = {}
BuffCheck3_SavedConsumes = {}
BuffCheck3_Config = {}
BuffCheck3.BagContents = {}

BuffCheck3_PrintFormat = "|c00f7f26c%s|r";

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
        BuffCheck3_Config["showing"] = true
        BuffCheck3:ShowFrame()
    elseif BuffCheck3:HasValue(words, "hide") then
        BuffCheck3_Config["showing"] = false
        BuffCheck3:HideFrame()
    elseif BuffCheck3:HasValue(words, "lock") then
        BuffCheck3_Config["locked"] = true
        BuffCheck3:LockFrame()
    elseif BuffCheck3:HasValue(words, "unlock") then
        BuffCheck3_Config["locked"] = false
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

function BuffCheck3:GetLinkFromArgs(args)

end

function BuffCheck3:GetSizeFromArgs(args)
    if(args[2] and tonumber(args[2]) ~= nil) then
        return tonumber(args[2])
    end
    return nil
end

function BuffCheck3:OnLoad(self)
    self:RegisterEvent("ADDON_LOADED")
    -- self:RegisterEvent("PLAYER_AURAS_CHANGED")
    self:RegisterEvent("UNIT_INVENTORY_CHANGED")
    -- self:RegisterEvent("PARTY_MEMBERS_CHANGED")
    self:RegisterEvent("BAG_UPDATE")
end

function BuffCheck3:Init()
    if buffcheck2_Config["locked"] then
        BuffCheck3:LockFrame()
    else
        BuffCheck3:UnlockFrame()
    end

    if BuffCheck3_Config["showing"] then
        BuffCheck3:ShowFrame()
    else
        BuffCheck3:HideFrame()
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

function BuffCheck3:OnEvent(self, event)
    if event == "ADDON_LOADED" then
        BuffCheck3:Init()
    elseif event == "PLAYER_AURAS_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
        BuffCheck3:UpdateFrame()
    elseif event == "PARTY_MEMBERS_CHANGED" then
        BuffCheck3:CheckGroupUpdate() -- show if in raid
    elseif event == "BAG_UPDATE" then
        BuffCheck3:UpdateBagContents()
        BuffCheck3:UpdateItemCounts()
    end
end

--=================================================================
-- Consume List Functions

function BuffCheck3:ShowConsumeList()

end

function BuffCheck3:HideConsumeList()

end

function BuffCheck3:UpdateConsumeList()

end

--=================================================================
-- Consume Frame Functions

function BuffCheck3:ShowFrame()

end

function BuffCheck3:HideFrame()

end

function BuffCheck3:LockFrame()

end

function BuffCheck3:UnlockFrame()

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
    BuffCheck3:tprint(BuffCheck3.BagContents)
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

--=================================================================
-- Tooltip Stuff

function BuffCheck3:ShowTooltip(consume, id)

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
