-- ╔══════════════════════════════════════╗
-- ║         ExecutorChat by bebramen     ║
-- ║  Грузит neverlose-ui с GitHub        ║
-- ║  Global chat + DMs · jsonbin relay   ║
-- ╚══════════════════════════════════════╝

-- ───────────────────────────────────────
--  НАСТРОЙКИ — меняй здесь
-- ───────────────────────────────────────
local GITHUB_USER   = "ВАШ_НИК"       -- <-- твой ник на GitHub
local GITHUB_REPO   = "ВАШ_РЕПО"      -- <-- название репо
local GITHUB_BRANCH = "main"

local API_KEY  = "$2a$10$kb0uSFE43jVviFrpj8klm.CHDyUUShGkqm7XzAxUnCFRu9HDo8SJ2"
local BIN_ID   = "69b44861b7ec241ddc672401"
local POLL     = 2  -- секунды между опросом

-- Префиксы: имя_в_нижнем_регистре = { tag, цвет, курсив }
local PREFIXES = {
    ["bebramen22090"]    = { tag = "CREATOR", color = Color3.fromRGB(0, 195, 255),  italic = false },
    ["europafm4"]        = { tag = "омежка",  color = Color3.fromRGB(185, 100, 255), italic = true  },
    ["rami_l1337"]       = { tag = "Крутой",  color = Color3.fromRGB(255, 165, 0),   italic = true  },
    ["ramil0341"]        = { tag = "Крутой",  color = Color3.fromRGB(255, 165, 0),   italic = true  },
    ["xn3ate"]           = { tag = "Крутой",  color = Color3.fromRGB(255, 165, 0),   italic = true  },
    ["ramil0341_sigma"]  = { tag = "Крутой",  color = Color3.fromRGB(255, 165, 0),   italic = true  },
}

-- ───────────────────────────────────────
--  ЗАГРУЗКА БИБЛИОТЕКИ
-- ───────────────────────────────────────
local RAW = string.format(
    "https://raw.githubusercontent.com/%s/%s/%s/library.lua",
    GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH
)

local ok, err = pcall(function()
    loadstring(game:HttpGet(RAW))()
end)

if not ok then
    -- fallback: оригинальный репо автора
    loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/ImInsane-1337/neverlose-ui/main/source/library.lua"
    ))()
end

-- ───────────────────────────────────────
--  СЕРВИСЫ
-- ───────────────────────────────────────
local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local LP               = Players.LocalPlayer
local MYNAME           = LP.Name

-- ───────────────────────────────────────
--  СОЗДАНИЕ ОКНА ЧЕРЕЗ НЛ ЛИБУ
-- ───────────────────────────────────────
local Window = Library:Window({
    Title    = "ExecutorChat",
    SubTitle = "by bebramen22090",
    TabWidth = 225,
    Size     = UDim2.fromOffset(677, 520),
    MenuKeybind = "Insert",
})

-- ───────────────────────────────────────
--  ВСПОМОГАЛКИ
-- ───────────────────────────────────────
local function esc(s)
    return (tostring(s):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"))
end

local function hexcolor(c)
    return string.format("%02x%02x%02x",
        math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
end

-- ───────────────────────────────────────
--  JSONBIN
-- ───────────────────────────────────────
local lastId = 0

local function readBin()
    local ok, res = pcall(request, {
        Url     = "https://api.jsonbin.io/v3/b/" .. BIN_ID .. "/latest",
        Method  = "GET",
        Headers = { ["X-Master-Key"] = API_KEY },
    })
    if ok and res.StatusCode == 200 then
        local data = HttpService:JSONDecode(res.Body)
        return data.record
    end
end

local function writeBin(msgs)
    pcall(request, {
        Url     = "https://api.jsonbin.io/v3/b/" .. BIN_ID,
        Method  = "PUT",
        Headers = {
            ["Content-Type"] = "application/json",
            ["X-Master-Key"] = API_KEY,
        },
        Body = HttpService:JSONEncode({ messages = msgs }),
    })
end

-- ───────────────────────────────────────
--  СТРАНИЦА 1: GLOBAL
-- ───────────────────────────────────────
local GlobalPage = Window:Page({ Title = "Global" })

--  ScrollingFrame для сообщений
local GlobalScroll = GlobalPage:ScrollBox({
    Size = UDim2.new(1, 0, 1, -44),
})

--  Инпут + кнопка отправки — встроенный элемент Textbox нл либы
local GlobalInput = GlobalPage:Textbox({
    Title       = "",
    Placeholder = "Написать в общий чат...",
    Callback    = function(text)
        -- отправится по Enter или потере фокуса
    end,
})

-- ───────────────────────────────────────
--  СТРАНИЦА 2: DMs
-- ───────────────────────────────────────
local DMPage = Window:Page({ Title = "Messages" })

local DMHint = DMPage:Label({
    Title = "← Выбери пользователя из списка слева",
})

local DMScroll   = {}   -- [username] = ScrollBox
local DMInput    = nil
local activeDM   = nil

-- ───────────────────────────────────────
--  РЕНДЕР СООБЩЕНИЯ
-- ───────────────────────────────────────
--  Нл либа обычно предоставляет :Label() / :RichLabel()
--  Используем RichLabel если есть, иначе Label

local msgCount = 0

local function buildRichText(sender, text)
    local pref = PREFIXES[string.lower(sender or "")]
    local parts = {}

    if pref then
        local tag = esc(pref.tag)
        local col = hexcolor(pref.color)
        if pref.italic then
            table.insert(parts, string.format('<font color="#%s"><i>[%s]</i></font> ', col, tag))
        else
            table.insert(parts, string.format('<font color="#%s">[%s]</font> ', col, tag))
        end
    end

    -- имя акцентом
    local accentHex = hexcolor(Library.Theme["Accent"])
    table.insert(parts, string.format('<font color="#%s"><b>%s</b></font>  ', accentHex, esc(sender)))
    -- текст
    table.insert(parts, esc(text))

    return table.concat(parts)
end

local function addMsg(page, sender, text, isSystem)
    msgCount += 1

    if isSystem then
        page:Label({
            Title = text,
            LayoutOrder = msgCount,
        })
    else
        if page.RichLabel then
            page:RichLabel({
                Title = buildRichText(sender, text),
                LayoutOrder = msgCount,
            })
        else
            page:Label({
                Title = string.format("[%s]  %s", sender, text),
                LayoutOrder = msgCount,
            })
        end
    end
end

-- ───────────────────────────────────────
--  ЮЗЕРЫ ИЗ DM (join-based discovery)
-- ───────────────────────────────────────
local knownUsers = {}

local function ensureDMUser(username)
    if username == MYNAME or knownUsers[username] then return end
    knownUsers[username] = true

    -- Добавляем кнопку в левую панель через нл Page с именем юзера
    local userPage = Window:Page({ Title = username })
    DMScroll[username] = userPage

    -- Показываем инпут когда страница активна
    userPage:Textbox({
        Title       = "",
        Placeholder = "Написать " .. username .. "...",
        Callback    = function(text)
            if not text or text == "" then return end
            addMsg(userPage, MYNAME, text, false)
            task.spawn(function()
                local rec  = readBin()
                local msgs = (rec and rec.messages) or {}
                local nid  = (#msgs > 0 and msgs[#msgs].id or 0) + 1
                table.insert(msgs, {
                    id     = nid,
                    type   = "dm",
                    sender = MYNAME,
                    to     = username,
                    text   = text,
                })
                if #msgs > 60 then
                    local t = {}
                    for i = #msgs - 59, #msgs do t[#t+1] = msgs[i] end
                    msgs = t
                end
                writeBin(msgs)
                if #msgs > 0 then lastId = msgs[#msgs].id end
            end)
        end,
    })
end

-- ───────────────────────────────────────
--  ОТПРАВКА В GLOBAL
-- ───────────────────────────────────────
GlobalInput.Callback = function(text)
    if not text or text == "" or text:match("^%s*$") then return end
    if #text > 200 then text = text:sub(1, 200) end

    addMsg(GlobalPage, MYNAME, text, false)

    task.spawn(function()
        local rec  = readBin()
        local msgs = (rec and rec.messages) or {}
        local nid  = (#msgs > 0 and msgs[#msgs].id or 0) + 1
        table.insert(msgs, {
            id     = nid,
            type   = "global",
            sender = MYNAME,
            text   = text,
        })
        if #msgs > 60 then
            local t = {}
            for i = #msgs - 59, #msgs do t[#t+1] = msgs[i] end
            msgs = t
        end
        writeBin(msgs)
        if #msgs > 0 then lastId = msgs[#msgs].id end
    end)
end

-- ───────────────────────────────────────
--  ИНИЦИАЛИЗАЦИЯ — join + история
-- ───────────────────────────────────────
task.spawn(function()
    local rec  = readBin()
    local msgs = (rec and rec.messages) or {}

    -- восстанавливаем известных юзеров из истории
    for _, m in ipairs(msgs) do
        if m.type == "join" and m.sender ~= MYNAME then
            ensureDMUser(m.sender)
        end
    end

    if #msgs > 0 then lastId = msgs[#msgs].id end

    -- объявляем себя
    local nid = (#msgs > 0 and msgs[#msgs].id or 0) + 1
    table.insert(msgs, { id = nid, type = "join", sender = MYNAME })
    if #msgs > 60 then
        local t = {}
        for i = #msgs - 59, #msgs do t[#t+1] = msgs[i] end
        msgs = t
    end
    writeBin(msgs)
    if #msgs > 0 then lastId = msgs[#msgs].id end

    addMsg(GlobalPage, "", "✓ подключён как " .. MYNAME, true)
end)

-- ───────────────────────────────────────
--  POLLING
-- ───────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(POLL)

        local ok2, rec = pcall(readBin)
        if ok2 and rec and rec.messages then
            for _, m in ipairs(rec.messages) do
                if m.id > lastId then
                    lastId = m.id

                    if m.type == "join" and m.sender ~= MYNAME then
                        ensureDMUser(m.sender)
                        addMsg(GlobalPage, "", m.sender .. " вошёл", true)

                    elseif m.type == "global" and m.sender ~= MYNAME then
                        addMsg(GlobalPage, m.sender, m.text, false)

                    elseif m.type == "dm" and m.to == MYNAME and m.sender ~= MYNAME then
                        ensureDMUser(m.sender)
                        if DMScroll[m.sender] then
                            addMsg(DMScroll[m.sender], m.sender, m.text, false)
                        end
                    end
                end
            end
        end
    end
end)
