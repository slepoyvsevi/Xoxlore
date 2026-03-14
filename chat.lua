-- ╔══════════════════════════════════════╗
-- ║         ExecutorChat by bebramen     ║
-- ║  neverlose-ui · jsonbin relay        ║
-- ╚══════════════════════════════════════╝

-- ───────────────────────────────────────
--  НАСТРОЙКИ
-- ───────────────────────────────────────
local API_KEY = "$2a$10$kb0uSFE43jVviFrpj8klm.CHDyUUShGkqm7XzAxUnCFRu9HDo8SJ2"
local BIN_ID  = "69b44861b7ec241ddc672401"
local POLL    = 2

local PREFIXES = {
    ["bebramen22090"]   = { tag = "Царь",   color = Color3.fromRGB(0, 195, 255),   italic = true },
    ["europafm4"]       = { tag = "омежка", color = Color3.fromRGB(185, 100, 255), italic = true },
    ["rami_l1337"]      = { tag = "Крутой", color = Color3.fromRGB(255, 165, 0),   italic = true },
    ["ramil0341"]       = { tag = "Крутой", color = Color3.fromRGB(255, 165, 0),   italic = true },
    ["xn3ate"]          = { tag = "Крутой", color = Color3.fromRGB(255, 165, 0),   italic = true },
    ["ramil0341_sigma"] = { tag = "Крутой", color = Color3.fromRGB(255, 165, 0),   italic = true },
}

-- ───────────────────────────────────────
--  ЗАГРУЗКА БИБЛИОТЕКИ
-- ───────────────────────────────────────
loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/slepoyvsevi/Xoxlore/main/library.lua"
))()

-- ───────────────────────────────────────
--  СЕРВИСЫ
-- ───────────────────────────────────────
local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LP          = Players.LocalPlayer
local MYNAME      = LP.Name

-- ───────────────────────────────────────
--  СОСТОЯНИЕ
-- ───────────────────────────────────────
local lastId        = 0
local inputText     = ""
local dmInputCur    = ""
local activeDM      = nil
local knownUsers    = {}
local globalLog     = {}
local dmLog         = {}

-- ───────────────────────────────────────
--  JSONBIN
-- ───────────────────────────────────────
local function readBin()
    local ok, res = pcall(request, {
        Url     = "https://api.jsonbin.io/v3/b/" .. BIN_ID .. "/latest",
        Method  = "GET",
        Headers = { ["X-Master-Key"] = API_KEY },
    })
    if ok and res and res.StatusCode == 200 then
        return HttpService:JSONDecode(res.Body).record
    end
end

local function writeBin(msgs)
    pcall(request, {
        Url     = "https://api.jsonbin.io/v3/b/" .. BIN_ID,
        Method  = "PUT",
        Headers = { ["Content-Type"] = "application/json", ["X-Master-Key"] = API_KEY },
        Body    = HttpService:JSONEncode({ messages = msgs }),
    })
end

-- ───────────────────────────────────────
--  ФОРМАТИРОВАНИЕ
-- ───────────────────────────────────────
local function esc(s)
    return (tostring(s):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"))
end

local function hexcolor(c)
    return string.format("%02x%02x%02x",
        math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
end

local function formatMsg(sender, text)
    local pref   = PREFIXES[string.lower(sender or "")]
    local accent = hexcolor(Library.Theme["Accent"])
    local parts  = {}
    if pref then
        local col = hexcolor(pref.color)
        local tag = esc(pref.tag)
        if pref.italic then
            table.insert(parts, ('<font color="#%s"><i>[%s]</i></font> '):format(col, tag))
        else
            table.insert(parts, ('<font color="#%s">[%s]</font> '):format(col, tag))
        end
    end
    table.insert(parts, ('<font color="#%s"><b>%s</b></font>  '):format(accent, esc(sender)))
    table.insert(parts, esc(text))
    return table.concat(parts)
end

local function formatSystem(text)
    return ('<font color="#5a5a7a"><i>%s</i></font>'):format(esc(text))
end

local function pushGlobal(line)
    table.insert(globalLog, line)
    if #globalLog > 40 then table.remove(globalLog, 1) end
end

local function pushDM(user, line)
    if not dmLog[user] then dmLog[user] = {} end
    table.insert(dmLog[user], line)
    if #dmLog[user] > 40 then table.remove(dmLog[user], 1) end
end

-- ───────────────────────────────────────
--  СОЗДАНИЕ ОКНА  (реальный нл API)
-- ───────────────────────────────────────
local Window = Library:Window({
    Title       = "ExecutorChat",
    SubTitle    = "by bebramen22090",
    TabWidth    = 225,
    Size        = UDim2.fromOffset(677, 520),
    MenuKeybind = "Insert",
})

-- ══════════════════════════════════════
--  СТРАНИЦА 1: GLOBAL
-- ══════════════════════════════════════
local GlobalPage = Window:Page({ Title = "Global" })

-- Секция лога
local LogSec = GlobalPage:Section({ Title = "Чат" })
local GlobalLogLabel = LogSec:Label({ Title = "Подключение...", RichText = true })

-- Секция ввода
local SendSec = GlobalPage:Section({ Title = "Написать" })

local GlobalTB = SendSec:Textbox({
    Title       = "Сообщение",
    Placeholder = "Текст...",
    Numeric     = false,
    Callback    = function(v) inputText = v end,
})

SendSec:Button({
    Title    = "Отправить  ➤",
    Callback = function()
        local text = inputText
        inputText  = ""
        GlobalTB:Set("")

        if not text or text == "" or text:match("^%s*$") then return end
        if #text > 200 then text = text:sub(1, 200) end

        pushGlobal(formatMsg(MYNAME, text))
        GlobalLogLabel:Set(table.concat(globalLog, "\n"))

        task.spawn(function()
            local rec  = readBin()
            local msgs = (rec and rec.messages) or {}
            local nid  = (#msgs > 0 and msgs[#msgs].id or 0) + 1
            table.insert(msgs, { id=nid, type="global", sender=MYNAME, text=text })
            if #msgs > 60 then
                local t={}; for i=#msgs-59,#msgs do t[#t+1]=msgs[i] end; msgs=t
            end
            writeBin(msgs)
            if #msgs > 0 then lastId = msgs[#msgs].id end
        end)
    end,
})

-- ══════════════════════════════════════
--  СТРАНИЦА 2: DMs
-- ══════════════════════════════════════
local DMPage = Window:Page({ Title = "Messages" })

local DMTopSec  = DMPage:Section({ Title = "Онлайн" })
local DMStatus  = DMTopSec:Label({ Title = "Ждём других игроков...", RichText = false })

local DMPickSec = DMPage:Section({ Title = "Написать" })

local dmUserList = { "—" }

local DMDropdown = DMPickSec:Dropdown({
    Title    = "Получатель",
    List     = dmUserList,
    Default  = "—",
    Callback = function(val)
        activeDM = (val ~= "—") and val or nil
        if activeDM and dmLog[activeDM] then
            DMDialogLabel:Set(table.concat(dmLog[activeDM], "\n"))
        end
    end,
})

local DMTextbox = DMPickSec:Textbox({
    Title       = "Сообщение",
    Placeholder = "Текст...",
    Numeric     = false,
    Callback    = function(v) dmInputCur = v end,
})

DMPickSec:Button({
    Title    = "Отправить  ➤",
    Callback = function()
        if not activeDM then
            DMStatus:Set("Сначала выбери получателя!")
            return
        end
        local text = dmInputCur
        dmInputCur  = ""
        DMTextbox:Set("")

        if not text or text == "" or text:match("^%s*$") then return end
        if #text > 200 then text = text:sub(1, 200) end

        pushDM(activeDM, formatMsg(MYNAME, text))
        DMDialogLabel:Set(table.concat(dmLog[activeDM], "\n"))

        local target = activeDM
        task.spawn(function()
            local rec  = readBin()
            local msgs = (rec and rec.messages) or {}
            local nid  = (#msgs > 0 and msgs[#msgs].id or 0) + 1
            table.insert(msgs, { id=nid, type="dm", sender=MYNAME, to=target, text=text })
            if #msgs > 60 then
                local t={}; for i=#msgs-59,#msgs do t[#t+1]=msgs[i] end; msgs=t
            end
            writeBin(msgs)
            if #msgs > 0 then lastId = msgs[#msgs].id end
        end)
    end,
})

local DMDialSec   = DMPage:Section({ Title = "Диалог" })
DMDialogLabel     = DMDialSec:Label({ Title = "Выбери получателя выше", RichText = true })

-- ───────────────────────────────────────
--  ДОБАВИТЬ ЮЗЕРА В ДРОПДАУН
-- ───────────────────────────────────────
local function ensureDMUser(username)
    if username == MYNAME or knownUsers[username] then return end
    knownUsers[username] = true
    dmLog[username]      = {}

    table.insert(dmUserList, username)
    DMDropdown:Refresh(dmUserList)

    local onlineList = {}
    for u in pairs(knownUsers) do onlineList[#onlineList+1] = u end
    DMStatus:Set("Онлайн: " .. table.concat(onlineList, ", "))
end

-- ───────────────────────────────────────
--  INIT
-- ───────────────────────────────────────
task.spawn(function()
    local rec  = readBin()
    local msgs = (rec and rec.messages) or {}

    for _, m in ipairs(msgs) do
        if m.type == "join" and m.sender ~= MYNAME then
            ensureDMUser(m.sender)
        end
    end

    if #msgs > 0 then lastId = msgs[#msgs].id end

    local nid = (#msgs > 0 and msgs[#msgs].id or 0) + 1
    table.insert(msgs, { id=nid, type="join", sender=MYNAME })
    if #msgs > 60 then
        local t={}; for i=#msgs-59,#msgs do t[#t+1]=msgs[i] end; msgs=t
    end
    writeBin(msgs)
    if #msgs > 0 then lastId = msgs[#msgs].id end

    pushGlobal(formatSystem("✓ вошёл как " .. MYNAME))
    GlobalLogLabel:Set(table.concat(globalLog, "\n"))
end)

-- ───────────────────────────────────────
--  POLLING
-- ───────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(POLL)
        local ok, rec = pcall(readBin)
        if ok and rec and rec.messages then
            for _, m in ipairs(rec.messages) do
                if m.id > lastId then
                    lastId = m.id

                    if m.type == "join" and m.sender ~= MYNAME then
                        ensureDMUser(m.sender)
                        pushGlobal(formatSystem(m.sender .. " вошёл"))
                        GlobalLogLabel:Set(table.concat(globalLog, "\n"))

                    elseif m.type == "global" and m.sender ~= MYNAME then
                        pushGlobal(formatMsg(m.sender, m.text))
                        GlobalLogLabel:Set(table.concat(globalLog, "\n"))

                    elseif m.type == "dm" and m.to == MYNAME and m.sender ~= MYNAME then
                        ensureDMUser(m.sender)
                        pushDM(m.sender, formatMsg(m.sender, m.text))
                        if activeDM == m.sender then
                            DMDialogLabel:Set(table.concat(dmLog[m.sender], "\n"))
                        end
                        pushGlobal(formatSystem("💬 ЛС от " .. m.sender))
                        GlobalLogLabel:Set(table.concat(globalLog, "\n"))
                    end
                end
            end
        end
    end
end)
