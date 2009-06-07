TargetBuffs = LibStub("AceAddon-3.0"):NewAddon("TargetBuffs", "AceEvent-3.0")

local db
local anchor
local TBIcons = CreateFrame("Frame",nil,UIParent)

local backdrop = {bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="", tile=false,}
local function CreateAnchor()
    local anchor = CreateFrame("Frame", "TBAnchor", UIParent)
    anchor:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 720, 240)
    anchor:SetBackdrop(backdrop)
	anchor:SetBackdropColor(1,0,1,1)
    anchor:SetWidth(10)
    anchor:SetHeight(10)
    anchor:EnableMouse(true)
	anchor:SetMovable(true)
    anchor:Show()
    anchor.icons = {}
    anchor.getPosition = function()
		local scale = anchor:GetEffectiveScale()
		local worldscale = UIParent:GetEffectiveScale()
		local x = anchor:GetLeft() * scale
		local y = (anchor:GetTop() * scale) - (UIParent:GetTop() * worldscale)

        return x, y
    end

    anchor.HideIcons = function() for k,icon in ipairs(anchor.icons) do icon:Hide() end end
	anchor:SetScript("OnMouseDown", function(self,button) if button == "LeftButton" then self:StartMoving() end end)
	anchor:SetScript("OnMouseUp", function(self, button) if button == "LeftButton" then self:StopMovingOrSizing(); TargetBuffs:SaveAnchorPosition() end end)
    return anchor
end

local function CreateIcon(iconArt)
    local icon = CreateFrame("Frame", nil, TBIcons)
    icon:SetWidth(30)
    icon:SetHeight(30)

    icon:SetFrameStrata("BACKGROUND")

    texture = icon:CreateTexture(nil,"ARTWORK")
    texture:SetAllPoints(icon)
    texture:SetTexture(iconArt)
    texture:SetTexCoord(0.07,0.9,0.07,0.9)
    texture:SetAlpha(1)

    icon.texture = texture

    return icon
end

local function UpdateAnchor(anchor, auras)
    anchor.HideIcons()

    for i, aura in ipairs(auras) do
        local icon = CreateIcon(aura["texture"])
        if i == 1 then
            if db.reverse and db.anchorAngle == "HORIZONTAL" then
                icon:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT")
            else
                icon:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT")
            end
        else
            if db.anchorAngle == "VERTICAL" then
                if db.reverse then
                    icon:SetPoint("BOTTOMLEFT", anchor.icons[i-1], "TOPLEFT")
                else
                    icon:SetPoint("TOPLEFT", anchor.icons[i-1], "BOTTOMLEFT")
                end
            else
                if db.reverse then
                    icon:SetPoint("BOTTOMRIGHT", anchor.icons[i-1], "BOTTOMLEFT")
                else
                    icon:SetPoint("BOTTOMLEFT", anchor.icons[i-1], "BOTTOMRIGHT")
                end
            end
        end

        icon:Show()
        anchor.icons[i] = icon
    end
end

function TargetBuffs:GetTargetAuras(type, buffEffect)
    local buffID = 1
    local auras  = {}

    while(true) do
        local name, _, texture, _, debuffType = UnitAura("target", buffID, buffEffect)
        if(not name) then break end

        if debuffType ~= nil and string.lower(debuffType) == type then
            table.insert(auras, { ["name"] = name, ["texture"] = texture })
        end

        buffID = buffID + 1
    end

    return auras
end

function TargetBuffs:HandleAuras(type)
    local buffEffect
    if UnitIsFriend("player", "target") then
        buffEffect = "HARMFUL"
    else
        buffEffect = "HELPFUL"
    end

    UpdateAnchor(anchor, self:GetTargetAuras(type, buffEffect))
end

function TargetBuffs:OnEnable()
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("UNIT_AURA")

    TargetBuffsDB = TargetBuffsDB or { anchorAngle = 'HORIZONTAL', reverse = false, scale = 1 }
    db = TargetBuffsDB

    anchor = CreateAnchor()

    self:CreateOptions()
    self:SetupAnchors()
end

function TargetBuffs:PLAYER_TARGET_CHANGED()
    self:HandleAuras("magic")
end

function TargetBuffs:UNIT_AURA()
    self:HandleAuras("magic")
end

function TargetBuffs:SetupAnchors()
    TBIcons:SetScale(db.scale or 1)

    if not db.anchorPosition then
        anchor:SetPoint("CENTER", UIParent, "CENTER")
    else
        local scale = anchor:GetEffectiveScale()
        local x = db.anchorPosition.x/scale
		local y = db.anchorPosition.y/scale
    	anchor:SetPoint("TOPLEFT", UIParent,"TOPLEFT", x, y)
	end

    if db.lock then anchor:Hide() else anchor:Show() end
end

function TargetBuffs:SaveAnchorPosition()
    x, y = anchor.getPosition()
    db.anchorPosition = { ["x"] = x, ["y"] = y }
end

-- Options --

local SO = LibStub("LibSimpleOptions-1.0")
function TargetBuffs:CreateOptions()
    local panel = SO.AddOptionsPanel("TargetBuffs", function() end)
    self.panel = panel
    SO.AddSlashCommand("TargetBuffs","/tb")
    local title, subText = panel:MakeTitleTextAndSubText("TargetBuffs", "Anchor settings")

    local anchorAngle = panel:MakeDropDown(
        'name', 'Anchor angle',
        'description', 'Should the bar be horizontal or vertical',
        'values', {
            'HORIZONTAL', "Horizontal",
            'VERTICAL', "Vertical",
        },
        'default', 'HORIZONTAL',
        'current', db.anchorAngle,
        'setFunc', function(value) db.anchorAngle = value; TargetBuffs:HandleAuras("magic") end)

    anchorAngle:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", -15, -30)

    local lockButton = panel:MakeButton(
         'name', 'Lock anchor',
         'description', 'Lock/unlock anchor',
         'func', function() end
         )

    if db.lock then lockButton:SetText("Unlock anchor") end

    lockButton.clickFunc = function()
        if lockButton:GetText() == "Unlock anchor" then
            lockButton:SetText("Lock anchor")
            db.lock = false
        else
            lockButton:SetText("Unlock anchor")
            db.lock = true
        end

        self:SetupAnchors()
    end

    lockButton:SetPoint("TOPLEFT", anchorAngle, "TOPRIGHT", -5, -2)

    local reverse = panel:MakeToggle(
         'name', 'Reverse',
         'description', 'Grow bar in other direction',
         'default', true,
         'getFunc', function() return db.reverse end,
         'setFunc', function(value) db.reverse = value; TargetBuffs:HandleAuras("magic") end)

    reverse:SetPoint("TOPLEFT", lockButton, "TOPRIGHT", 8, 2)

    local scale = panel:MakeSlider(
         'name', 'Scale',
         'description', 'Adjust the scale of icons',
         'minText', '0.1',
         'maxText', '5',
         'minValue', 0.1,
         'maxValue', 5,
         'step', 0.05,
         'default', 1,
         'current', db.scale,
         'setFunc', function(value) db.scale = value; TargetBuffs:SetupAnchors() end,
         'currentTextFunc', function(value) return string.format("%.2f",value) end)
    scale:SetPoint("TOPLEFT", anchorAngle, "BOTTOMLEFT", 20, -20)
end
