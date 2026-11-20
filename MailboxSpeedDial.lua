if type(MailboxSpeedDialDB) ~= "table" then
    MailboxSpeedDialDB = {}
end

local savedRecipients = {}
if type(MailboxSpeedDialDB.recipients) == "table" then
    for _, recipient in ipairs(MailboxSpeedDialDB.recipients) do
        if type(recipient) == "string" and recipient:match("%S") then
            table.insert(savedRecipients, recipient)
        end
    end
end
MailboxSpeedDialDB.recipients = savedRecipients

local function Trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function MakeButton(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetText(label)
    return button
end

local panel = CreateFrame("Frame", "MailboxSpeedDialPanel", UIParent, "BasicFrameTemplateWithInset")
panel:SetSize(320, 340)
panel:SetClampedToScreen(true)
panel:EnableMouse(true)
panel:Hide()
panel.TitleText:SetText("Mailbox Speed Dial")

local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
hint:SetPoint("TOPLEFT", 14, -34)
hint:SetWidth(286)
hint:SetWordWrap(true)
hint:SetText("Type a name and click Add to add a recipient to your Speed Dial.")

local input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
input:SetSize(205, 22)
input:SetPoint("TOPLEFT", 18, -68)
input:SetAutoFocus(false)
input:SetMaxLetters(64)
input:HookScript("OnTextChanged", function(self)
    if self.filteringDigits then return end
    if self.IsInIMECompositionMode and self:IsInIMECompositionMode() then return end
    local text = self:GetText() or ""
    local filtered = text:gsub("%d", "")
    if filtered ~= text then
        local cursor = self:GetCursorPosition()
        local removedBeforeCursor = select(2, text:sub(1, cursor):gsub("%d", ""))
        self.filteringDigits = true
        self:SetText(filtered)
        self:SetCursorPosition(math.min(#filtered, math.max(0, cursor - removedBeforeCursor)))
        self.filteringDigits = false
    end
end)
input:SetScript("OnEnterPressed", function(self)
    self:GetParent().addButton:Click()
end)

local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -100)
scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 14)

local scrollContent = CreateFrame("Frame", nil, scrollFrame)
scrollContent:SetSize(260, 1)
scrollFrame:SetScrollChild(scrollContent)

local rows = {}
local RefreshRows
local function CreateRecipientRow(index)
    local row = CreateFrame("Frame", nil, scrollContent)
    row:SetSize(260, 22)
    row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, -((index - 1) * 23))

    row.select = MakeButton(row, "", 212, 21)
    row.select:SetPoint("LEFT", 0, 0)
    row.select:SetScript("OnClick", function()
        if SendMailNameEditBox then
            SendMailNameEditBox:SetText(row.name:GetText())
            SendMailNameEditBox:SetFocus()
            panel:Hide()
        end
    end)
    row.name = row.select:GetFontString()

    row.remove = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    row.remove:SetSize(22, 22)
    row.remove:SetPoint("LEFT", row.select, "RIGHT", 2, 0)
    row.remove:SetScript("OnClick", function()
        table.remove(MailboxSpeedDialDB.recipients, row.index)
        RefreshRows()
    end)
    row.remove:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Delete Recipient")
        GameTooltip:Show()
    end)
    row.remove:SetScript("OnLeave", GameTooltip_Hide)

    row.moveTop = CreateFrame("Button", nil, row)
    row.moveTop:SetSize(22, 22)
    row.moveTop:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
    row.moveTop:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Down")
    row.moveTop:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Disabled")
    row.moveTop:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Highlight", "ADD")
    for _, texture in ipairs({row.moveTop:GetNormalTexture(), row.moveTop:GetPushedTexture(), row.moveTop:GetDisabledTexture(), row.moveTop:GetHighlightTexture()}) do
        texture:SetTexCoord(0.20, 0.80, 0.25, 0.75)
    end
    row.moveTop:SetPoint("LEFT", row.remove, "RIGHT", 2, 0)
    row.moveTop:SetScript("OnClick", function()
        local index = row.index
        if index > 1 then
            local recipient = table.remove(MailboxSpeedDialDB.recipients, index)
            table.insert(MailboxSpeedDialDB.recipients, 1, recipient)
            RefreshRows()
            scrollFrame:SetVerticalScroll(0)
        end
    end)
    row.moveTop:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Move to Top")
        GameTooltip:Show()
    end)
    row.moveTop:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

RefreshRows = function()
    local recipients = MailboxSpeedDialDB.recipients
    for index, recipient in ipairs(recipients) do
        local row = rows[index]
        if not row then
            row = CreateRecipientRow(index)
            rows[index] = row
        end
        row.index = index
        row.name:SetText(recipient)
        row.moveTop:SetEnabled(index > 1)
        row:Show()
    end
    for index = #recipients + 1, #rows do
        rows[index]:Hide()
    end
    scrollContent:SetHeight(math.max(1, #recipients * 23))
    scrollFrame:UpdateScrollChildRect()
end

local addButton = MakeButton(panel, "Add", 52, 22)
addButton:SetPoint("LEFT", input, "RIGHT", 8, 0)
panel.addButton = addButton
addButton:SetScript("OnClick", function()
    local fieldText = input:GetText() or ""
    local name = Trim(fieldText:gsub("%d", ""))
    if name ~= fieldText then
        input:SetText(name)
    end
    if name == "" then
        input:SetFocus()
        return
    end
    for _, existing in ipairs(MailboxSpeedDialDB.recipients) do
        if existing:lower() == name:lower() then
            input:SetText("")
            input:SetFocus()
            return
        end
    end
    table.insert(MailboxSpeedDialDB.recipients, 1, name)
    input:SetText("")
    RefreshRows()
    scrollFrame:SetVerticalScroll(0)
    input:SetFocus()
end)

local function CreateSpeedDialTab(parent)
    local button = CreateFrame("Button", nil, parent, "LargeSideTabButtonTemplate")
    button.Icon:SetTexture("Interface\\AddOns\\MailboxSpeedDial\\MailboxSpeedDialIcon.png")
    if button.SetFillToInterior then
        button:SetFillToInterior(true)
    end
    button.tooltipText = "Mailbox Speed Dial"
    button:SetChecked(false)
    return button
end

local toggle = CreateSpeedDialTab(MailFrame or UIParent)
toggle:Hide()
toggle:SetScript("OnClick", function(self)
    if panel:IsShown() then
        panel:Hide()
    else
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, 0)
        panel:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", 0, 0)
        RefreshRows()
        panel:Show()
        self:SetChecked(true)
        input:SetFocus()
    end
end)
panel:HookScript("OnHide", function()
    toggle:SetChecked(false)
end)

local function AttachToMailFrame()
    if not MailFrame or not SendMailFrame or not SendMailNameEditBox then return end
    panel:SetParent(MailFrame)
    panel:SetFrameStrata(MailFrame:GetFrameStrata())
    panel:SetFrameLevel(MailFrame:GetFrameLevel() + 1)
    toggle:SetParent(MailFrame)
    toggle:ClearAllPoints()
    toggle:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 0, -58)
    toggle:SetFrameLevel(MailFrame:GetFrameLevel() + 5)
    local function UpdateTabVisibility()
        local sendMailOpen = MailFrame:IsShown() and SendMailFrame:IsShown()
        toggle:SetShown(sendMailOpen)
        if not sendMailOpen then
            panel:Hide()
        end
    end

    if not SendMailFrame.mailboxSpeedDialVisibilityHooked then
        SendMailFrame:HookScript("OnShow", UpdateTabVisibility)
        SendMailFrame:HookScript("OnHide", UpdateTabVisibility)
        SendMailFrame.mailboxSpeedDialVisibilityHooked = true
    end
    UpdateTabVisibility()

    if not MailFrame.mailboxSpeedDialHideHooked then
        MailFrame:HookScript("OnHide", function()
            UpdateTabVisibility()
        end)
        MailFrame:HookScript("OnShow", UpdateTabVisibility)
        MailFrame.mailboxSpeedDialHideHooked = true
    end
    if not MailFrame.mailboxSpeedDialTabHooked and MailFrameTab_OnClick then
        hooksecurefunc("MailFrameTab_OnClick", UpdateTabVisibility)
        MailFrame.mailboxSpeedDialTabHooked = true
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("MAIL_SHOW")
loader:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "PLAYER_LOGIN" or event == "MAIL_SHOW" or loadedAddon == "Blizzard_MailFrame" then
        AttachToMailFrame()
    end
end)
