--
-- 项目使用DeepSeek AI制作的
-- 代码开源 随意修改
--
-- 2025.09.19
--


-- ===== 多语言支持框架 =====
local L = {
    zhCN = {
        TITLE = "副本CD监控",
        LABEL = "副本次数%d",
        READY = "可用",
        RESET_BUTTON = "重置副本",
        REPORT_BUTTON = "队伍通报",
        TIME_FORMAT = "%02d:%02d",
        RESET_PATTERNS = {"已被重置"},
        RESET_ANNOUNCE = "副本已重置，请进入副本！",
        REPORT_FORMAT = "副本重置状态：%s",
        FRAME_LOCK = "框架已锁定",
        FRAME_UNLOCK = "框架已解锁",
        FRAME_LOCK_LOCAL = "锁定框架位置",
        FRAME_UNLOCK_LOCAL = "解锁框架位置",
        COMMAND_USAGE = "命令用法:"
    },
    enUS = {
        TITLE = "BoomTime",
        LABEL = "CD %d",
        READY = "Ready!",
        RESET_BUTTON = "Reset",
        REPORT_BUTTON = "Notice",
        TIME_FORMAT = "%02d:%02d",
        RESET_PATTERNS = {"has been reset"},
        RESET_ANNOUNCE = "The instance has been reset, please re-enter the instance!",
        REPORT_FORMAT = "Instance reset status: %s",
        FRAME_LOCK = "The framework is locked.",
        FRAME_UNLOCK = "The framework has been unlocked.",
        FRAME_LOCK_LOCAL = "Lock the frame position.",
        FRAME_UNLOCK_LOCAL = "Unlock frame position.",
        COMMAND_USAGE = "Command Usage:"
    }
	
	-- 可在此添加其他客户端语言拓展：zhTW, koKR, deDE, frFR.
}

-- 自动检测客户端语言
local locale = GetLocale()
if not L[locale] then
    locale = "enUS" -- 默认使用英文
end

-- ===== 数学函数预声明 =====
local floor, mod, format = math.floor, math.mod, string.format

-- ===== 全局变量初始化 =====
BoomtimeDB = BoomtimeDB or {}
local currentRealm = GetRealmName()

-- 初始化当前服务器数据结构
if not BoomtimeDB[currentRealm] then
    BoomtimeDB[currentRealm] = {
        lastResets = {},
        left = 200,
        top = 200,  -- 正数表示向下偏移
        height = 210,
        isLocked = false,
        isVisible = true
    }
end
local realmData = BoomtimeDB[currentRealm]

-- ===== 兼容旧版Lua的表长度函数 =====
local function tableLength(t)
    if not t then return 0 end
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- ===== 创建主框架 =====
local frame = CreateFrame("Frame", "BoomtimeFrame", UIParent)
frame:SetWidth(170)
frame:SetHeight(realmData.height)
frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = {left = 4, right = 4, top = 4, bottom = 4}
})
frame:SetBackdropColor(0, 0, 0, 0.8)
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)

-- ===== 关键修复：统一坐标系转换 =====
local function GetFramePosition()
    return frame:GetLeft(), UIParent:GetTop() - frame:GetTop()
end

-- ===== 关键修复：位置刷新函数 =====
local function RefreshFramePosition()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", realmData.left, -realmData.top)
end

-- ===== 关键修复：位置保存优化 =====
frame:SetScript("OnDragStop", function()
    if not realmData.isLocked then
        this:StopMovingOrSizing()
        -- 关键修复：统一使用坐标系转换函数
        realmData.left, realmData.top = GetFramePosition()
        realmData.height = this:GetHeight()
    end
end)


-- ===== 框架锁定功能修复 =====
local function ToggleFrameLock(isLocked)
    realmData.isLocked = isLocked
    
    if isLocked then
        frame:EnableMouse(false)
        frame:SetMovable(false)
        frame:RegisterForDrag()  -- 取消注册拖动
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99Boomtime|r: "..L[locale].FRAME_LOCK)
        RefreshFramePosition()  -- 关键：锁定后刷新位置
    else
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99Boomtime|r: "..L[locale].FRAME_UNLOCK)
        RefreshFramePosition()  -- 关键：解锁后刷新位置
    end
end


-- ===== 命令处理器 =====
local function HandleCommand(msg)
    if msg == "lock" then
        ToggleFrameLock(true)
    elseif msg == "unlock" then
        ToggleFrameLock(false)
    else
        -- 显示帮助信息
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99Boomtime|r "..L[locale].COMMAND_USAGE)
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99/bt lock|r - "..L[locale].FRAME_LOCK_LOCAL)
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99/bt unlock|r - "..L[locale].FRAME_UNLOCK_LOCAL)
    end
end

-- ===== 注册斜杠命令 =====
SlashCmdList["BOOMTIME"] = HandleCommand
SLASH_BOOMTIME1 = "/bt"
SLASH_BOOMTIME2 = "/boomtime"

-- ===== 初始化框架移动状态修复 =====
frame:SetScript("OnDragStart", function() 
    if not realmData.isLocked then
        this:StartMoving() 
    end
end)

frame:SetScript("OnDragStop", function()
    if not realmData.isLocked then
        this:StopMovingOrSizing()
        realmData.left = this:GetLeft()
        realmData.top = this:GetTop()
        realmData.height = this:GetHeight()
    end
end)

-- ===== 创建标题文本 =====
local titleText = frame:CreateFontString(nil, "OVERLAY")
titleText:SetFontObject(GameFontNormalLarge)
titleText:SetPoint("TOP", frame, "TOP", 0, -10)
titleText:SetText(L[locale].TITLE)

-- ===== 创建5个标签和倒计时文本 =====
local labelTexts = {}
local timeTexts = {}

local contentStartY = -45
for i = 1, 5 do
    local label = frame:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(GameFontNormal)
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, contentStartY - 25 * (i-1))
    label:SetText(format(L[locale].LABEL, i))
    labelTexts[i] = label
    
    local timeText = frame:CreateFontString(nil, "OVERLAY")
    timeText:SetFontObject(GameFontHighlight)
    timeText:SetPoint("LEFT", label, "RIGHT", 10, 0)
    timeText:SetText(L[locale].READY)
    timeTexts[i] = timeText
end

-- ===== 创建按钮容器 =====
local buttonContainer = CreateFrame("Frame", nil, frame)
buttonContainer:SetWidth(160)
buttonContainer:SetHeight(30)
buttonContainer:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)

-- ===== 队伍通报按钮 =====
local reportBtn = CreateFrame("Button", nil, buttonContainer, "OptionsButtonTemplate")
reportBtn:SetWidth(80)
reportBtn:SetHeight(25)
reportBtn:SetPoint("LEFT", buttonContainer, "LEFT", 0, 0)
reportBtn:SetText(L[locale].REPORT_BUTTON)
reportBtn:SetScript("OnClick", function()
    -- 获取当前副本状态信息
    local statusLines = {}
    for i = 1, 5 do
        local text = timeTexts[i]:GetText()
        -- 核心优化：添加方括号包裹倒计时/就绪状态
        local displayText = "[" .. text .. "]"
        table.insert(statusLines, format(L[locale].LABEL..": %s", i, displayText))
    end
    local fullMessage = format(L[locale].REPORT_FORMAT, table.concat(statusLines, ", "))
    
    -- 检测队伍类型并发送通报
    local numRaid = GetNumRaidMembers()
    local numParty = GetNumPartyMembers()
    
    if numRaid > 0 then
        SendChatMessage(fullMessage, "RAID")
    elseif numParty > 0 then
        SendChatMessage(fullMessage, "PARTY")
    end
end)

-- ===== 重置按钮 =====
local resetBtn = CreateFrame("Button", nil, buttonContainer, "OptionsButtonTemplate")
resetBtn:SetWidth(80)
resetBtn:SetHeight(25)
resetBtn:SetPoint("LEFT", reportBtn, "RIGHT", 0, 0)
resetBtn:SetText(L[locale].RESET_BUTTON)
resetBtn:SetScript("OnClick", function()
    ResetInstances()
end)

-- ===== 核心功能：统一状态显示 =====
local function UpdateAllTimers()
    local now = time()
    local resetData = realmData.lastResets or {}
    
    for i = 1, 5 do
        if resetData[i] then
            local elapsed = now - resetData[i]
            if elapsed < 3600 then
                local remain = 3600 - elapsed
                local mins = floor(remain / 60)
                local secs = mod(remain, 60)
                -- 保持UI界面原始格式（无方括号）
                timeTexts[i]:SetText(format(L[locale].TIME_FORMAT, mins, secs))
            else
                timeTexts[i]:SetText(L[locale].READY)
            end
        else
            timeTexts[i]:SetText(L[locale].READY)
        end
    end
end

-- ===== 多语言重置检测 =====
local function IsResetMessage(msg)
    for _, pattern in ipairs(L[locale].RESET_PATTERNS) do
        if string.find(msg, pattern) then
            return true
        end
    end
    return false
end

-- ===== 队伍类型检测与通报 =====
local function AnnounceResetSuccess()
    local numRaid = GetNumRaidMembers()
    local numParty = GetNumPartyMembers()
    
    if numRaid > 0 then
        SendChatMessage(L[locale].RESET_ANNOUNCE, "RAID")
    elseif numParty > 0 then
        SendChatMessage(L[locale].RESET_ANNOUNCE, "PARTY")
    else
        SendChatMessage(L[locale].RESET_ANNOUNCE, "SAY")
    end
end

-- ===== 事件监听 =====
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:SetScript("OnEvent", function()
    local msg = arg1
    if IsResetMessage(msg) then
        if not realmData.lastResets then realmData.lastResets = {} end
        table.insert(realmData.lastResets, 1, time())
        if tableLength(realmData.lastResets) > 5 then
            table.remove(realmData.lastResets, 6)
        end
        UpdateAllTimers()
        AnnounceResetSuccess()
    end
end)

-- ===== 定时器逻辑 =====
local timer = 0
frame:SetScript("OnUpdate", function()
    local elapsed = arg1
    timer = timer + elapsed
    if timer >= 0.1 then
        UpdateAllTimers()
        timer = 0
    end
end)
-- ===== 初始化修复（关键修复） =====
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "Boomtime" then
        if not BoomtimeDB then BoomtimeDB = {} end
        if not BoomtimeDB[currentRealm] then
            BoomtimeDB[currentRealm] = {
                lastResets = {},
                left = 200,
                top = 200,
                height = 250,
                isLocked = false,
                isVisible = true
            }
        end
        realmData = BoomtimeDB[currentRealm]
        
        -- 确保数据结构完整
        if not realmData.lastResets then realmData.lastResets = {} end
        if realmData.isVisible == nil then realmData.isVisible = true end
        
        -- 关键修复：位置刷新
        RefreshFramePosition()
        
        -- 应用当前语言设置
        titleText:SetText(L[locale].TITLE)
        for i = 1, 5 do
            labelTexts[i]:SetText(format(L[locale].LABEL, i))
        end
        resetBtn:SetText(L[locale].RESET_BUTTON)
        reportBtn:SetText(L[locale].REPORT_BUTTON)
        
        -- 强制显示框架
        if realmData.isVisible then
            frame:Show()
        else
            frame:Hide()
        end
        
        -- 应用锁定状态
        ToggleFrameLock(realmData.isLocked)
        
        UpdateAllTimers()
    end
end)


-- ===== 框架拖动修复 =====
frame:SetScript("OnDragStop", function()
    if not realmData.isLocked then
        this:StopMovingOrSizing()
        
        -- 关键修复：正确获取坐标
        local left = this:GetLeft()
        local top = UIParent:GetTop() - this:GetTop()
        
        realmData.left = left
        realmData.top = top
        realmData.height = this:GetHeight()
    end
end)

