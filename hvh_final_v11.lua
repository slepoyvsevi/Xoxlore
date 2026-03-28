--[[
    HvH FINAL v11 | NeverLose UI
    РЕЙДЖБОТ ПОЛНОСТЬЮ ПЕРЕПИСАН ПОД ИГРОВУЮ ЛОГИКУ:
    - fireShot берётся ТОЧНО как в игре: Tool > Remotes > FireShot
    - Видимость: рекурсивный рейкаст (пробивает прозрачные/аксессуары) — 1:1 с игрой
    - Предикт: формула игры (dist/1000 * clamp(0.08,0.2) * 1.2)
    - canShoot: FloorMaterial + raycast вниз как в игре
    - AutoStop: BodyVelocity + WalkSpeed=0 как в игре
    - Кулдаун стрельбы: 0.05s (игровой)
    - Таргет-селект: приоритет по расстоянию до центра экрана * priority
    - Airshot: компенсация нашего падения при стрельбе в прыжке
    - Backtrack: история позиций
    - Resolver: ротация угла при промахах
]]

local UIS          = game:GetService("UserInputService")
local RS           = game:GetService("RunService")
local Plrs         = game:GetService("Players")
local WS           = game:GetService("Workspace")
local LP           = Plrs.LocalPlayer
local Lighting     = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RS_rep       = game:GetService("ReplicatedStorage")
local Debris       = game:GetService("Debris")
local TICK         = tick

-- ══════════════════════════════════════════
--  НАСТРОЙКИ
-- ══════════════════════════════════════════
local S = {
    -- FAKEDUCK
    fdEnabled = false,
    fdMode    = "Always",  -- Always = вечный дак, Hold = зажать, Toggle = переключить
    fdKey     = Enum.KeyCode.C,
    fdAmount  = 2.5,

    -- RAGEBOT — основное
    rbEnabled      = false,
    rbTeamCheck    = true,
    rbHitbox       = "Head",   -- Head / Torso / Both
    rbMaxDistance  = 1000,
    rbFireRate     = 0.05,     -- секунды между выстрелами
    rbHitchance    = 100,
    rbMinDamage    = 1,
    rbFov          = 360,      -- FOV для выбора цели (px от центра)

    -- RAGEBOT — фичи
    rbPrediction   = true,     -- включить предикт
    rbWallbang     = false,    -- стрелять сквозь стены
    rbResolver     = true,
    -- Legit Double Tap (игровой DT: телепорт вперёд по MoveDir)
    rbLegitDT        = false,
    rbLegitDTDelay   = 0.01,
    -- Aggressive Double Tap: телепорт К ВРАГУ по DTMarker, выстрел, возврат
    rbADT            = false,
    rbADTRange       = 6,       -- ст до врага (подходим вплотную)
    rbADTReturn      = true,    -- возврат после выстрела
    rbADTCooldown    = 0.9,     -- кулдаун (s)
    -- Rapid Fire: авто-реэквип SSG-08 (unequip→equip = сброс кулдауна сервера)
    rbRapidFire      = false,
    rbRFExtraShots   = 2,       -- кол-во доп. выстрелов (реэквипов)
    rbAirshot      = true,     -- разрешить стрелять в воздухе
    rbBacktrack    = false,
    rbBacktrackTime = 0.14,
    rbSilentAim      = true,   -- поворачивать HRP к цели перед выстрелом (как игра)
    rbBAim           = false,  -- Body Aim: при HP < 30 бить в торс
    rbAutoStop       = false,  -- autostop по событию hit

    -- VISUALS / CHAMS
    chamsSelfEnabled   = false,
    chamsTeamEnabled   = false,
    chamsEnemyEnabled  = false,
    chamsWeaponEnabled = false,
    chamsSelfStyle     = "Flat",
    chamsTeamStyle     = "Flat",
    chamsEnemyStyle    = "Neon",
    chamsWeaponStyle   = "Neon",
    chamsSelfColorVis  = Color3.fromRGB(100,200,255),
    chamsSelfColorHid  = Color3.fromRGB(50,100,180),
    chamsTeamColorVis  = Color3.fromRGB(60,255,120),
    chamsTeamColorHid  = Color3.fromRGB(30,130,60),
    chamsEnemyColorVis = Color3.fromRGB(255,60,60),
    chamsEnemyColorHid = Color3.fromRGB(180,20,20),
    chamsWeaponColor   = Color3.fromRGB(255,200,50),
    chamsSelfTransp    = 20,
    chamsTeamTransp    = 25,
    chamsEnemyTransp   = 20,
    chamsWeaponTransp  = 0,
    chamsSelfWall      = true,
    chamsTeamWall      = true,
    chamsEnemyWall     = true,
    chamsEnemyHPColor  = false,
    chamsWeaponRainbow = false,

    -- NO-SPREAD методы (выбери один, остальные отключи)
    nsEnabled        = false,
    nsMethod         = 1,   -- 1=CamLock 2=VelocitySnap 3=HRPSnap 4=DirOverride 5=CamTwist

        -- KILL EFFECT SPECIAL
    keFlashKill      = true,   -- синий экран + рывок при убийстве

    -- ANTI KILLBRICK
    akbEnabled       = false,
    akbMethod        = "NoTouch", -- "NoTouch" (без касания) или "Delete" (удалять)
    akbDeleteDelay   = 2,         -- интервал удаления (Delete метод)

    -- WORLD
    skyboxEnabled   = false,
    skyboxPreset    = "Night City",
    worldColor      = false,
    worldAmbient    = Color3.fromRGB(30,30,50),
    worldOutdoor    = Color3.fromRGB(20,20,40),
    worldBrightness = 30,
    worldFogStart   = 200,
    worldFogEnd     = 800,
    worldFogColor   = Color3.fromRGB(20,20,40),
}

-- ══════════════════════════════════════════
--  RUNTIME
-- ══════════════════════════════════════════
local R = {
    myChar=nil, myHRP=nil, myHead=nil, myHum=nil, cam=nil,
    playerCache={},
    rbLastShot=0,
    fdOriginalHip=nil, fdActive=false,
    -- autostop
    asBodyVel=nil, asOrigWalkSpeed=nil, asBusy=false,
}
local fdToggleState = false

-- aahelp / aahelp1 — нужны для silent aim (как в игре)
local aahelp  = RS_rep:FindFirstChild("aahelp")
local aahelp1 = RS_rep:FindFirstChild("aahelp1")
-- Ждём асинхронно чтобы не блокировать загрузку
task.spawn(function()
    aahelp  = RS_rep:WaitForChild("aahelp",  10)
    aahelp1 = RS_rep:WaitForChild("aahelp1", 10)
end)

-- hit event для autostop (как в игре: v99 = RS_rep:FindFirstChild("hit"))
-- Ищем по нескольким возможным именам
local hitEvent = nil
local HIT_EVENT_NAMES = {"hit", "Hit", "HitEvent", "hitEvent", "damage", "Damage"}
for _, ename in ipairs(HIT_EVENT_NAMES) do
    local ev = RS_rep:FindFirstChild(ename)
    if ev and ev:IsA("RemoteEvent") then hitEvent = ev; break end
end
-- DTMarker для DoubleTap (из игры: v6:FindFirstChild("DTMarker"))
local DTMarker = RS_rep:FindFirstChild("DTMarker")
if not DTMarker then
    DTMarker = Instance.new("RemoteEvent")
    DTMarker.Name   = "DTMarker"
    DTMarker.Parent = RS_rep
end
-- Асинхронно ждём hit event если не нашли
task.spawn(function()
    if not hitEvent then
        for _, ename in ipairs(HIT_EVENT_NAMES) do
            local ok, ev = pcall(function()
                return RS_rep:WaitForChild(ename, 3)
            end)
            if ok and ev and ev:IsA("RemoteEvent") then
                hitEvent = ev; break
            end
        end
    end
end)

-- ══════════════════════════════════════════
--  VELOCITY HISTORY
-- ══════════════════════════════════════════
local velHistory = {}
local function recordVel(pl, vel)
    if not velHistory[pl] then velHistory[pl]={} end
    local h=velHistory[pl]
    table.insert(h,{vel=vel,t=TICK()})
    while #h>8 do table.remove(h,1) end
end
local function smoothVel(pl)
    local h=velHistory[pl]
    if not h or #h==0 then return Vector3.zero end
    local sv,sw=Vector3.zero,0
    local now=TICK()
    for _,e in ipairs(h) do
        local w=math.exp(-(now-e.t)*4)
        sv=sv+e.vel*w; sw=sw+w
    end
    return sw<0.001 and Vector3.zero or sv/sw
end

-- ══════════════════════════════════════════
--  BACKTRACK
-- ══════════════════════════════════════════
local btHistory={}
local function recordBT(pl,char)
    if not btHistory[pl] then btHistory[pl]={} end
    local h=btHistory[pl]
    local snap={}
    for _,n in ipairs({"Head","UpperTorso","Torso","HumanoidRootPart"}) do
        local p=char:FindFirstChild(n)
        if p then snap[n]=p.CFrame end
    end
    table.insert(h,{snap=snap,t=TICK()})
    local now=TICK()
    while #h>0 and now-h[1].t>S.rbBacktrackTime+0.05 do
        table.remove(h,1)
    end
end
local function getBTPos(pl,partName)
    local h=btHistory[pl]; if not h or #h==0 then return nil end
    local now=TICK()
    for _,e in ipairs(h) do
        if now-e.t<=S.rbBacktrackTime and e.snap[partName] then
            return e.snap[partName].Position
        end
    end
    return nil
end

-- ══════════════════════════════════════════
--  LIBRARY
-- ══════════════════════════════════════════
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/ImInsane-1337/neverlose-ui/refs/heads/main/source/library.lua"
))()

local CheatName="MyProject"
Library.Folders={Directory=CheatName,Configs=CheatName.."/Configs",Assets=CheatName.."/Assets"}
Library:ChangeTheme("Accent",         Color3.fromRGB(255,80,80))
Library:ChangeTheme("AccentGradient", Color3.fromRGB(120,20,20))

local Window=Library:Window({Name="MyProject",SubName="hvh edition",Logo="120959262762131"})
Library:KeybindList("Keybinds")
Library:Watermark({"MyProject","hvh edition",120959262762131})
task.spawn(function()
    while true do
        local ok,fps=pcall(function() return math.floor(1/RS.RenderStepped:Wait()) end)
        Library:Watermark({"MyProject","hvh edition",120959262762131,"FPS:"..(ok and fps or "?")})
        task.wait(0.5)
    end
end)

-- ══════════════════════════════════════════
--  CATEGORY: MAIN
-- ══════════════════════════════════════════
Window:Category("Main")
local LegitPage   = Window:Page({Name="Legit",Icon="138827881557940"})
local MainSection = LegitPage:Section({Name="Main Features",Side=1})
local MiscSection = LegitPage:Section({Name="Misc",Side=2})

MainSection:Toggle({Name="Enabled",Flag="LegitEnabled",Default=true,Callback=function() end})
MainSection:Slider({Name="Speed Hack",Flag="SpeedSlider",Min=1,Max=100,Default=16,Suffix=" studs",Callback=function() end})

-- FakeDuck в Misc
MiscSection:Toggle({Name="Fake Duck",Flag="FDEnabled",Default=false,
    Callback=function(v)
        S.fdEnabled=v
        if not v then
            if R.myHum and R.fdOriginalHip then
                pcall(function() R.myHum.HipHeight=R.fdOriginalHip end)
            end
            R.fdOriginalHip=nil; R.fdActive=false
        end
        Library:Notification({Title="Fake Duck",Description=v and "ON" or "OFF",Duration=2})
    end})
MiscSection:Dropdown({Name="FD Mode",Flag="FDMode",Default={"Always"},Items={"Always","Hold","Toggle"},Multi=false,
    Callback=function(v) S.fdMode=v[1] or "Always" end})
MiscSection:Slider({Name="FD Amount",Flag="FDAmount",Min=1,Max=40,Default=25,
    Callback=function(v) S.fdAmount=v/10 end})
MiscSection:Keybind({Name="FD Key",Flag="FDKey",Default=Enum.KeyCode.C,
    Callback=function(v) S.fdKey=v end})
MiscSection:Button({Name="Test Notification",Callback=function()
    Library:Notification({Title="System",Description="Script работает!",Duration=4})
end})
MiscSection:Keybind({Name="Menu Toggle",Flag="MenuToggle",Default=Enum.KeyCode.Insert,Callback=function() end})

-- ══════════════════════════════════════════
--  CATEGORY: RAGEBOT
-- ══════════════════════════════════════════
Window:Category("Ragebot")
local RagePage = Window:Page({Name="Ragebot",Icon="138827881557940"})
local RageMain = RagePage:Section({Name="General",  Side=1})
local RageAim  = RagePage:Section({Name="Targeting",Side=1})
local RageFire = RagePage:Section({Name="Fire",     Side=2})
local RageAdv  = RagePage:Section({Name="Advanced", Side=2})

RageMain:Toggle({Name="Enable Ragebot",Flag="RBEnabled",Default=false,
    Callback=function(v) S.rbEnabled=v end})
RageMain:Toggle({Name="Team Check",Flag="RBTeamCheck",Default=true,
    Callback=function(v) S.rbTeamCheck=v end})
RageMain:Dropdown({Name="Hitbox",Flag="RBHitbox",Default={"Head"},Items={"Head","Torso","Both"},Multi=false,
    Callback=function(v) S.rbHitbox=v[1] or "Head" end})
RageMain:Slider({Name="Max Distance",Flag="RBMaxDist",Min=100,Max=1000,Default=1000,Suffix=" st",
    Callback=function(v) S.rbMaxDistance=v end})
RageMain:Slider({Name="Min Damage",Flag="RBMinDmg",Min=1,Max=352,Default=1,Suffix=" dmg",
    Callback=function(v) S.rbMinDamage=v end})
RageMain:Slider({Name="Hitchance",Flag="RBHitchance",Min=1,Max=100,Default=100,Suffix="%",
    Callback=function(v) S.rbHitchance=v end})
RageMain:Slider({Name="FOV",Flag="RBFOV",Min=10,Max=360,Default=360,Suffix="px",
    Callback=function(v) S.rbFov=v end})

RageAim:Toggle({Name="Prediction",Flag="RBPred",Default=true,
    Callback=function(v) S.rbPrediction=v end})
RageAim:Toggle({Name="Resolver",Flag="RBResolver",Default=true,
    Callback=function(v) S.rbResolver=v end})
RageAim:Toggle({Name="Wallbang",Flag="RBWallbang",Default=false,
    Callback=function(v) S.rbWallbang=v end})
RageAim:Toggle({Name="Backtrack",Flag="RBBacktrack",Default=false,
    Callback=function(v) S.rbBacktrack=v end})
RageAim:Slider({Name="BT Window",Flag="RBBTTime",Min=50,Max=200,Default=140,Suffix="ms",
    Callback=function(v) S.rbBacktrackTime=v/1000 end})

RageAim:Toggle({Name="Airshot",Flag="RBAirshot",Default=true,
    Callback=function(v) S.rbAirshot=v end})
RageAim:Toggle({Name="Silent Aim",Flag="RBSilentAim",Default=true,
    Callback=function(v) S.rbSilentAim=v end})
RageAim:Toggle({Name="Body Aim (BAim)",Flag="RBBAim",Default=false,
    Callback=function(v) S.rbBAim=v
        Library:Notification({Title="BAim",Description=v and "ON: HP<30 → торс" or "OFF",Duration=2})
    end})
RageAim:Toggle({Name="Auto Stop",Flag="RBAutoStop",Default=false,
    Callback=function(v) S.rbAutoStop=v end})

RageFire:Slider({Name="Fire Rate",Flag="RBFireRate",Min=10,Max=500,Default=50,Suffix="ms",
    Callback=function(v) S.rbFireRate=v/1000 end})

-- Legit Double Tap (игровой — телепорт вперёд по MoveDir)
local RageLDT = RagePage:Section({Name="Legit DT", Side=2})
RageLDT:Toggle({Name="Legit DT",Flag="RBLegitDT",Default=false,
    Callback=function(v) S.rbLegitDT=v
        Library:Notification({Title="Legit DT",Description=v and "ON" or "OFF",Duration=2})
    end})
RageLDT:Slider({Name="DT Delay",Flag="RBLDTDelay",Min=1,Max=100,Default=10,Suffix="ms",
    Callback=function(v) S.rbLegitDTDelay=v/1000 end})

-- Aggressive Double Tap
local RageADT = RagePage:Section({Name="Aggressive DT", Side=2})
RageADT:Toggle({Name="Aggressive DT",Flag="RBADTEnabled",Default=false,
    Callback=function(v) S.rbADT=v
        Library:Notification({Title="Aggressive DT",
            Description=v and "ON — подходим к врагу, стреляем, возврат" or "OFF",Duration=3})
    end})
RageADT:Slider({Name="Approach Range",Flag="RBADTRange",Min=2,Max=12,Default=6,Suffix=" st",
    Callback=function(v) S.rbADTRange=v end})
RageADT:Toggle({Name="Return After",Flag="RBADTReturn",Default=true,
    Callback=function(v) S.rbADTReturn=v end})
RageADT:Slider({Name="Cooldown",Flag="RBADTCooldown",Min=3,Max=30,Default=9,Suffix="00ms",
    Callback=function(v) S.rbADTCooldown=v/10 end})

-- Rapid Fire (авто реэквип SSG-08 баг)
local RageRF = RagePage:Section({Name="Rapid Fire (SSG)", Side=2})
RageRF:Toggle({Name="Rapid Fire",Flag="RBRapidFire",Default=false,
    Callback=function(v) S.rbRapidFire=v
        Library:Notification({Title="Rapid Fire",
            Description=v and "ON — авто реэквип SSG-08" or "OFF",Duration=2})
    end})
RageRF:Slider({Name="Extra Shots",Flag="RBRFShots",Min=1,Max=5,Default=2,
    Callback=function(v) S.rbRFExtraShots=v end})


RageAdv:Slider({Name="Fire Rate ms",Flag="RBFireRateAdv",Min=5,Max=200,Default=50,Suffix="ms",
    Callback=function(v) S.rbFireRate=v/1000 end})


-- ══════════════════════════════════════════
--  CATEGORY: NO-SPREAD
--  Каждый метод пытается убрать разброс
--  разными способами — включи один, остальные OFF
--  Скажи какой работает, остальные удалим
-- ══════════════════════════════════════════
Window:Category("No-Spread")
local NSPage  = Window:Page({Name="No-Spread",Icon="138827881557940"})
local NSMain  = NSPage:Section({Name="Methods",Side=1})
local NSInfo  = NSPage:Section({Name="Info",   Side=2})

NSMain:Toggle({Name="Enable No-Spread",Flag="NSEnabled",Default=false,
    Callback=function(v) S.nsEnabled=v
        Library:Notification({Title="No-Spread",Description=v and "ON" or "OFF",Duration=2})
    end})
NSMain:Dropdown({Name="Method",Flag="NSMethod",Default={"1"},
    Items={"1","2","3","4","5"},Multi=false,
    Callback=function(v) S.nsMethod=tonumber(v[1]) or 1 end})

NSInfo:Label("1 = CamLock: камера смотрит на цель")
NSInfo:Label("2 = VelocitySnap: обнуляем угловую скорость")
NSInfo:Label("3 = HRPSnap: HRP смотрит точно на цель")
NSInfo:Label("4 = DirOverride: dir = точный вектор к цели")
NSInfo:Label("5 = CamTwist: lerp камеры на цель")
NSInfo:Label("Включи один — скажи работает или нет")

-- ══════════════════════════════════════════
--  CATEGORY: VISUALS
-- ══════════════════════════════════════════
Window:Category("Visuals")
local ChamsPage   = Window:Page({Name="Chams",Icon="138827881557940"})
local ChamsSelf   = ChamsPage:Section({Name="Self",  Side=1})
local ChamsTeam   = ChamsPage:Section({Name="Team",  Side=1})
local ChamsEnemy  = ChamsPage:Section({Name="Enemy", Side=2})
local ChamsWeapon = ChamsPage:Section({Name="Weapon",Side=2})

ChamsSelf:Toggle({Name="Enable",Flag="ChamsSelf",Default=false,Callback=function(v) S.chamsSelfEnabled=v end})
ChamsSelf:Dropdown({Name="Style",Flag="ChamsSelfStyle",Default={"Flat"},Items={"Flat","Neon","Outlined","Glass","Rainbow"},Multi=false,Callback=function(v) S.chamsSelfStyle=v[1] or "Flat" end})
ChamsSelf:Label("Fill"):Colorpicker({Name="SelfFill",Flag="ChamsSelfFill",Default=Color3.fromRGB(100,200,255),Callback=function(v) S.chamsSelfColorVis=v end})
ChamsSelf:Label("Outline"):Colorpicker({Name="SelfOut",Flag="ChamsSelfOut",Default=Color3.fromRGB(50,100,180),Callback=function(v) S.chamsSelfColorHid=v end})
ChamsSelf:Slider({Name="Transparency",Flag="ChamsSelfTransp",Min=0,Max=100,Default=20,Suffix="%",Callback=function(v) S.chamsSelfTransp=v end})
ChamsSelf:Toggle({Name="Through Walls",Flag="ChamsSelfWall",Default=true,Callback=function(v) S.chamsSelfWall=v end})

ChamsTeam:Toggle({Name="Enable",Flag="ChamsTeam",Default=false,Callback=function(v) S.chamsTeamEnabled=v end})
ChamsTeam:Dropdown({Name="Style",Flag="ChamsTeamStyle",Default={"Flat"},Items={"Flat","Neon","Outlined","Glass","Rainbow"},Multi=false,Callback=function(v) S.chamsTeamStyle=v[1] or "Flat" end})
ChamsTeam:Label("Vis"):Colorpicker({Name="TeamVis",Flag="ChamsTeamVis",Default=Color3.fromRGB(60,255,120),Callback=function(v) S.chamsTeamColorVis=v end})
ChamsTeam:Label("Hid"):Colorpicker({Name="TeamHid",Flag="ChamsTeamHid",Default=Color3.fromRGB(30,130,60),Callback=function(v) S.chamsTeamColorHid=v end})
ChamsTeam:Slider({Name="Transparency",Flag="ChamsTeamTransp",Min=0,Max=100,Default=25,Suffix="%",Callback=function(v) S.chamsTeamTransp=v end})
ChamsTeam:Toggle({Name="Through Walls",Flag="ChamsTeamWall",Default=true,Callback=function(v) S.chamsTeamWall=v end})

ChamsEnemy:Toggle({Name="Enable",Flag="ChamsEnemy",Default=false,Callback=function(v) S.chamsEnemyEnabled=v end})
ChamsEnemy:Dropdown({Name="Style",Flag="ChamsEnemyStyle",Default={"Neon"},Items={"Flat","Neon","Outlined","Glass","Rainbow"},Multi=false,Callback=function(v) S.chamsEnemyStyle=v[1] or "Neon" end})
ChamsEnemy:Label("Vis"):Colorpicker({Name="EnemyVis",Flag="ChamsEnemyVis",Default=Color3.fromRGB(255,60,60),Callback=function(v) S.chamsEnemyColorVis=v end})
ChamsEnemy:Label("Hid"):Colorpicker({Name="EnemyHid",Flag="ChamsEnemyHid",Default=Color3.fromRGB(180,20,20),Callback=function(v) S.chamsEnemyColorHid=v end})
ChamsEnemy:Slider({Name="Transparency",Flag="ChamsEnemyTransp",Min=0,Max=100,Default=20,Suffix="%",Callback=function(v) S.chamsEnemyTransp=v end})
ChamsEnemy:Toggle({Name="Through Walls",Flag="ChamsEnemyWall",Default=true,Callback=function(v) S.chamsEnemyWall=v end})
ChamsEnemy:Toggle({Name="HP Color",Flag="ChamsEnemyHP",Default=false,Callback=function(v) S.chamsEnemyHPColor=v end})

ChamsWeapon:Toggle({Name="Enable",Flag="ChamsWeapon",Default=false,Callback=function(v) S.chamsWeaponEnabled=v end})
ChamsWeapon:Dropdown({Name="Style",Flag="ChamsWeaponStyle",Default={"Neon"},Items={"Flat","Neon","Outlined","Glass","Rainbow"},Multi=false,Callback=function(v) S.chamsWeaponStyle=v[1] or "Neon" end})
ChamsWeapon:Label("Color"):Colorpicker({Name="WeaponColor",Flag="ChamsWeaponColor",Default=Color3.fromRGB(255,200,50),Callback=function(v) S.chamsWeaponColor=v end})
ChamsWeapon:Toggle({Name="Rainbow",Flag="ChamsWeaponRainbow",Default=false,Callback=function(v) S.chamsWeaponRainbow=v end})

-- Anti Killbrick страница
local MiscPage2 = Window:Page({Name="Misc",Icon="138827881557940"})
local AKBSec    = MiscPage2:Section({Name="Anti Killbrick",Side=1})
local FDSec2    = MiscPage2:Section({Name="FakeDuck Info",  Side=2})

AKBSec:Toggle({Name="Enable Anti KB",Flag="AKBEnabled",Default=false,
    Callback=function(v)
        S.akbEnabled=v
        Library:Notification({Title="Anti Killbrick",Description=v and "ON" or "OFF",Duration=2})
    end})
AKBSec:Dropdown({Name="Method",Flag="AKBMethod",Default={"NoTouch"},
    Items={"NoTouch","Delete"},Multi=false,
    Callback=function(v) S.akbMethod=v[1] or "NoTouch" end})
AKBSec:Slider({Name="Delete Interval",Flag="AKBDelay",Min=1,Max=10,Default=2,Suffix="s",
    Callback=function(v) S.akbDeleteDelay=v end})

FDSec2:Label("FakeDuck: включи и забудь")
FDSec2:Label("Mode Always = вечный дак")
FDSec2:Label("Включи FD в Misc > Fake Duck")

local WorldPage=Window:Page({Name="World",Icon="138827881557940"})
local SkyboxSec=WorldPage:Section({Name="Skybox",Side=1})
local WorldSec =WorldPage:Section({Name="World Color",Side=2})

SkyboxSec:Toggle({Name="Enable Skybox",Flag="SkyboxEnabled",Default=false,Callback=function(v) S.skyboxEnabled=v end})
SkyboxSec:Dropdown({Name="Preset",Flag="SkyboxPreset",Default={"Night City"},
    Items={"Night City","Arctic","Deep Space","Sunset","Stormy","Dawn","Neon Night"},Multi=false,
    Callback=function(v) S.skyboxPreset=v[1] or "Night City" end})
WorldSec:Toggle({Name="Enable",Flag="WorldColor",Default=false,Callback=function(v) S.worldColor=v end})
WorldSec:Label("Ambient"):Colorpicker({Name="WorldAmb",Flag="WorldAmb",Default=Color3.fromRGB(30,30,50),Callback=function(v) S.worldAmbient=v end})
WorldSec:Slider({Name="Brightness",Flag="WorldBri",Min=0,Max=100,Default=30,Suffix="%",Callback=function(v) S.worldBrightness=v end})
WorldSec:Slider({Name="Fog Start",Flag="WorldFogS",Min=0,Max=1000,Default=200,Suffix=" st",Callback=function(v) S.worldFogStart=v end})
WorldSec:Slider({Name="Fog End",Flag="WorldFogE",Min=100,Max=5000,Default=800,Suffix=" st",Callback=function(v) S.worldFogEnd=v end})

-- ══════════════════════════════════════════
--  CATEGORY: FEED & FX
-- ══════════════════════════════════════════
Window:Category("Feed & FX")
local FeedPage=Window:Page({Name="Feed & FX",Icon="138827881557940"})
local HLSec=FeedPage:Section({Name="Hit Log",Side=1})
local KESec=FeedPage:Section({Name="Kill Effects",Side=2})

local HL={enabled=true,maxEntries=8,lifetime=5}
HLSec:Toggle({Name="Enable Hit Log",Flag="HLEnabled",Default=true,Callback=function(v) HL.enabled=v end})
HLSec:Slider({Name="Max Entries",Flag="HLMaxEntries",Min=3,Max=15,Default=8,Suffix=" lines",Callback=function(v) HL.maxEntries=v end})
HLSec:Slider({Name="Lifetime",Flag="HLLifetime",Min=2,Max=15,Default=5,Suffix="s",Callback=function(v) HL.lifetime=v end})

local KE={enabled=true,style="Blackhole",particleColor=Color3.fromRGB(255,60,60),flashColor=Color3.fromRGB(255,60,60),size=1}
KESec:Toggle({Name="Enable Kill Effects",Flag="KEEnabled",Default=true,Callback=function(v) KE.enabled=v end})
KESec:Dropdown({Name="Style",Flag="KEStyle",Default={"Blackhole"},Items={"Particles","Flash","Blackhole","All"},Multi=false,
    Callback=function(v) KE.style=v[1] or "Blackhole" end})
KESec:Label("Color"):Colorpicker({Name="KEColor",Flag="KEColor",Default=Color3.fromRGB(255,60,60),Callback=function(v) KE.particleColor=v end})
KESec:Slider({Name="Size",Flag="KESize",Min=1,Max=5,Default=1,Suffix="x",Callback=function(v) KE.size=v end})
KESec:Toggle({Name="Flash Kill Effect",Flag="KEFlashKill",Default=true,
    Callback=function(v) S.keFlashKill=v
        Library:Notification({Title="Flash Kill",Description=v and "ON — синий экран+рывок" or "OFF",Duration=2})
    end})

-- Трасеры
local TracerPage = Window:Page({Name="Tracers",Icon="138827881557940"})
local TracerSec  = TracerPage:Section({Name="Bullet Tracers",Side=1})
TracerSec:Toggle({Name="Enable Tracers",Flag="TracerEnabled",Default=true,
    Callback=function(v) S.tracerEnabled=v end})
TracerSec:Dropdown({Name="Style",Flag="TracerStyle",Default={"Neon"},
    Items={"Neon","Electric","Laser","Rainbow"},Multi=false,
    Callback=function(v) S.tracerStyle=v[1] or "Neon" end})
TracerSec:Label("Color 1"):Colorpicker({Name="TracerC1",Flag="TracerC1",
    Default=Color3.fromRGB(255,50,50),Callback=function(v) S.tracerColor=v end})
TracerSec:Label("Color 2"):Colorpicker({Name="TracerC2",Flag="TracerC2",
    Default=Color3.fromRGB(255,200,50),Callback=function(v) S.tracerColor2=v end})
TracerSec:Slider({Name="Width",Flag="TracerWidth",Min=1,Max=20,Default=3,
    Callback=function(v) S.tracerWidth=v/25 end})
TracerSec:Slider({Name="Lifetime",Flag="TracerLife",Min=5,Max=50,Default=10,Suffix="0ms",
    Callback=function(v) S.tracerLifetime=v/100 end})
TracerSec:Toggle({Name="Impact Flash",Flag="TracerImpact",Default=true,
    Callback=function(v) S.tracerImpact=v end})

-- ══════════════════════════════════════════
--  GUI: ХИТЛОГ
-- ══════════════════════════════════════════
local hlFrame
pcall(function()
    local pg=LP:WaitForChild("PlayerGui",5); if not pg then return end
    local sg=Instance.new("ScreenGui"); sg.Name="HitLogGui"; sg.ResetOnSpawn=false
    sg.IgnoreGuiInset=true; sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.Parent=pg

    hlFrame=Instance.new("Frame"); hlFrame.Name="HitLog"; hlFrame.Size=UDim2.new(0,260,0,340)
    hlFrame.Position=UDim2.new(1,-268,1,-350); hlFrame.BackgroundTransparency=1
    hlFrame.ClipsDescendants=false; hlFrame.Parent=sg

    local hdr=Instance.new("Frame"); hdr.Size=UDim2.new(1,0,0,20); hdr.Position=UDim2.new(0,0,0,-24)
    hdr.BackgroundColor3=Color3.fromRGB(20,20,28); hdr.BackgroundTransparency=0.35
    hdr.BorderSizePixel=0; hdr.Parent=hlFrame
    local hc=Instance.new("UICorner"); hc.CornerRadius=UDim.new(0,4); hc.Parent=hdr
    local hs=Instance.new("UIStroke"); hs.Color=Color3.fromRGB(220,40,40); hs.Thickness=1; hs.Transparency=0.4; hs.Parent=hdr
    local hl2=Instance.new("TextLabel"); hl2.Size=UDim2.new(1,-8,1,0); hl2.Position=UDim2.new(0,8,0,0)
    hl2.BackgroundTransparency=1; hl2.Text="◈ HIT LOG"; hl2.TextColor3=Color3.fromRGB(220,40,40)
    hl2.TextSize=10; hl2.Font=Enum.Font.GothamBold; hl2.TextXAlignment=Enum.TextXAlignment.Left; hl2.Parent=hdr

    local lay=Instance.new("UIListLayout"); lay.SortOrder=Enum.SortOrder.LayoutOrder
    lay.VerticalAlignment=Enum.VerticalAlignment.Bottom; lay.Padding=UDim.new(0,3); lay.Parent=hlFrame
end)

local function createHLEntry(isHit,victimName,dist,headshot)
    if not hlFrame then return end
    local row=Instance.new("Frame"); row.Name="HLEntry"; row.Size=UDim2.new(1,0,0,24)
    row.BackgroundColor3=isHit and Color3.fromRGB(28,8,8) or Color3.fromRGB(8,8,28)
    row.BackgroundTransparency=1; row.BorderSizePixel=0; row.ClipsDescendants=true
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,4); c.Parent=row
    local stripe=Instance.new("Frame"); stripe.Size=UDim2.new(0,2,1,-4); stripe.Position=UDim2.new(0,0,0,2)
    stripe.BackgroundColor3=isHit and Color3.fromRGB(220,40,40) or Color3.fromRGB(60,60,220)
    stripe.BorderSizePixel=0; stripe.BackgroundTransparency=1; stripe.Parent=row
    local sc=Instance.new("UICorner"); sc.CornerRadius=UDim.new(0,2); sc.Parent=stripe
    local stk=Instance.new("UIStroke"); stk.Color=isHit and Color3.fromRGB(200,30,30) or Color3.fromRGB(30,30,200)
    stk.Thickness=0.8; stk.Transparency=1; stk.Parent=row

    local tagL=Instance.new("TextLabel"); tagL.Size=UDim2.new(0,44,1,0); tagL.Position=UDim2.new(0,6,0,0)
    tagL.BackgroundTransparency=1
    tagL.Text=isHit and (headshot and "★HIT" or "✔HIT") or "✘MISS"
    tagL.TextColor3=isHit and (headshot and Color3.fromRGB(255,80,80) or Color3.fromRGB(200,200,80)) or Color3.fromRGB(120,120,255)
    tagL.TextSize=10; tagL.Font=Enum.Font.GothamBold; tagL.TextXAlignment=Enum.TextXAlignment.Left
    tagL.TextTransparency=1; tagL.Parent=row

    local nickL=Instance.new("TextLabel"); nickL.Size=UDim2.new(0,110,1,0); nickL.Position=UDim2.new(0,54,0,0)
    nickL.BackgroundTransparency=1; nickL.Text=tostring(victimName); nickL.TextColor3=Color3.fromRGB(220,220,220)
    nickL.TextSize=11; nickL.Font=Enum.Font.Gotham; nickL.TextXAlignment=Enum.TextXAlignment.Left
    nickL.TextStrokeTransparency=0.6; nickL.TextTransparency=1; nickL.Parent=row

    local distL=Instance.new("TextLabel"); distL.Size=UDim2.new(0,60,1,0); distL.Position=UDim2.new(1,-64,0,0)
    distL.BackgroundTransparency=1; distL.Text=string.format("%.0f st",dist)
    distL.TextColor3=Color3.fromRGB(140,140,160); distL.TextSize=10; distL.Font=Enum.Font.Gotham
    distL.TextXAlignment=Enum.TextXAlignment.Right; distL.TextTransparency=1; distL.Parent=row

    for _,ch in ipairs(hlFrame:GetChildren()) do
        if ch:IsA("Frame") then ch.LayoutOrder=ch.LayoutOrder+1 end
    end
    row.LayoutOrder=0; row.Parent=hlFrame

    local entries={}
    for _,ch in ipairs(hlFrame:GetChildren()) do
        if ch:IsA("Frame") then table.insert(entries,ch) end
    end
    table.sort(entries,function(a,b) return a.LayoutOrder>b.LayoutOrder end)
    for i=HL.maxEntries+1,#entries do pcall(function() entries[i]:Destroy() end) end

    local fi=TweenInfo.new(0.18,Enum.EasingStyle.Quad)
    TweenService:Create(row,fi,{BackgroundTransparency=0.35}):Play()
    TweenService:Create(stripe,fi,{BackgroundTransparency=0}):Play()
    TweenService:Create(stk,fi,{Transparency=0.5}):Play()
    TweenService:Create(tagL,fi,{TextTransparency=0}):Play()
    TweenService:Create(nickL,fi,{TextTransparency=0}):Play()
    TweenService:Create(distL,fi,{TextTransparency=0}):Play()

    task.delay(HL.lifetime,function()
        if not row or not row.Parent then return end
        local fo=TweenInfo.new(0.5,Enum.EasingStyle.Quad)
        TweenService:Create(row,fo,{BackgroundTransparency=1}):Play()
        TweenService:Create(stripe,fo,{BackgroundTransparency=1}):Play()
        TweenService:Create(stk,fo,{Transparency=1}):Play()
        TweenService:Create(tagL,fo,{TextTransparency=1}):Play()
        TweenService:Create(nickL,fo,{TextTransparency=1}):Play()
        TweenService:Create(distL,fo,{TextTransparency=1}):Play()
        task.wait(0.55)
        if row and row.Parent then row:Destroy() end
    end)
end

-- ══════════════════════════════════════════
--  КИЛЛ-ЭФФЕКТЫ
-- ══════════════════════════════════════════
local function getCharByName(name)
    local pl=Plrs:FindFirstChild(name); return pl and pl.Character
end

local function spawnKillParticles(char)
    if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    pcall(function()
        local a=Instance.new("Part"); a.Size=Vector3.new(0.1,0.1,0.1); a.Anchored=true
        a.CanCollide=false; a.CanQuery=false; a.CanTouch=false; a.Transparency=1
        a.CFrame=hrp.CFrame; a.Parent=WS
        local att=Instance.new("Attachment",a)
        local pe=Instance.new("ParticleEmitter",att)
        pe.Color=ColorSequence.new(KE.particleColor,Color3.fromRGB(80,0,0))
        pe.LightEmission=0.5
        pe.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.3*KE.size),NumberSequenceKeypoint.new(1,0)})
        pe.Speed=NumberRange.new(8*KE.size,18*KE.size); pe.SpreadAngle=Vector2.new(80,80)
        pe.Lifetime=NumberRange.new(0.4,0.9); pe.Rate=0
        pe.Texture="rbxasset://textures/particles/smoke_main.dds"; pe:Emit(math.floor(12*KE.size))
        local pe2=Instance.new("ParticleEmitter",att)
        pe2.Color=ColorSequence.new(Color3.fromRGB(255,200,50),Color3.fromRGB(255,80,0))
        pe2.LightEmission=1
        pe2.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.08),NumberSequenceKeypoint.new(1,0)})
        pe2.Speed=NumberRange.new(12,25); pe2.SpreadAngle=Vector2.new(90,90)
        pe2.Lifetime=NumberRange.new(0.2,0.6); pe2.Rate=0
        pe2.Texture="rbxasset://textures/particles/sparkles_main.dds"; pe2:Emit(math.floor(20*KE.size))
        Debris:AddItem(a,1.5)
    end)
end

local function spawnKillFlash(char)
    if not char then return end
    pcall(function()
        local hl=Instance.new("Highlight"); hl.Adornee=char; hl.FillColor=KE.flashColor
        hl.OutlineColor=Color3.new(1,1,1); hl.FillTransparency=0; hl.OutlineTransparency=0
        hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=char
        TweenService:Create(hl,TweenInfo.new(0.3),{FillTransparency=1,OutlineTransparency=1}):Play()
        task.delay(0.35,function() if hl and hl.Parent then hl:Destroy() end end)
    end)
end

-- ══ FLASH KILL EFFECT ══════════════════════════
--  1. Синий экран (ColorCorrection → синий тинт)
--  2. Заморозка на 1 секунду (WalkSpeed=0, BodyVelocity)
--  3. Резкий рывок в направлении взгляда
--  4. Трейл на персонаже во время рывка
local flashKillBusy = false

local function spawnFlashKill()
    if flashKillBusy then return end
    if not S.keFlashKill then return end
    if not R.myChar or not R.myHRP or not R.myHum or not R.myHead then return end
    flashKillBusy = true

    local char = R.myChar
    local hrp  = R.myHRP
    local hum  = R.myHum
    local cam  = WS.CurrentCamera

    pcall(function()
        -- ── 1. Синий экран через ColorCorrectionEffect ──────────────────
        local pg = LP:FindFirstChildOfClass("PlayerGui")
        local flashGui, flashFrame
        if pg then
            flashGui = Instance.new("ScreenGui")
            flashGui.Name = "FlashKillGui"
            flashGui.ResetOnSpawn = false
            flashGui.IgnoreGuiInset = true
            flashGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            flashGui.Parent = pg

            flashFrame = Instance.new("Frame")
            flashFrame.Size = UDim2.new(1,0,1,0)
            flashFrame.BackgroundColor3 = Color3.fromRGB(0, 80, 255)
            flashFrame.BackgroundTransparency = 1
            flashFrame.BorderSizePixel = 0
            flashFrame.Parent = flashGui
        end

        -- Синий fade-in
        if flashFrame then
            TweenService:Create(flashFrame,
                TweenInfo.new(0.08, Enum.EasingStyle.Quad),
                {BackgroundTransparency=0.25}
            ):Play()
        end

        -- Blur эффект камеры
        local blur = Instance.new("BlurEffect")
        blur.Size = 0; blur.Parent = cam
        TweenService:Create(blur, TweenInfo.new(0.08), {Size=12}):Play()

        -- ── 2. Заморозка 1 секунда ──────────────────────────────────────
        local origWS = hum.WalkSpeed
        local origJP = hum.JumpPower
        hum.WalkSpeed = 0
        hum.JumpPower = 0

        local freezeBV = Instance.new("BodyVelocity")
        freezeBV.Velocity  = Vector3.zero
        freezeBV.MaxForce  = Vector3.new(1e5, 0, 1e5)
        freezeBV.P         = 1e4
        freezeBV.Parent    = hrp

        task.wait(1.0)  -- заморожены

        -- ── 3. Быстрый fade-out синего ──────────────────────────────────
        if flashFrame then
            TweenService:Create(flashFrame,
                TweenInfo.new(0.12, Enum.EasingStyle.Quad),
                {BackgroundTransparency=1}
            ):Play()
        end
        TweenService:Create(blur, TweenInfo.new(0.2), {Size=0}):Play()
        task.delay(0.25, function()
            if blur and blur.Parent then blur:Destroy() end
            if flashGui and flashGui.Parent then flashGui:Destroy() end
        end)

        -- Убираем заморозку
        if freezeBV and freezeBV.Parent then freezeBV:Destroy() end
        hum.WalkSpeed = origWS
        hum.JumpPower = origJP

        -- ── 4. Рывок — Bodyvelocity в направлении взгляда ───────────────
        if not (char and char.Parent and hrp and hrp.Parent) then
            flashKillBusy = false; return
        end

        local lookDir = hrp.CFrame.LookVector
        local dashDir = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
        local dashSpeed = 80  -- studs/s

        local dashBV = Instance.new("BodyVelocity")
        dashBV.Velocity  = dashDir * dashSpeed
        dashBV.MaxForce  = Vector3.new(1e5, 0, 1e5)
        dashBV.P         = 1e4
        dashBV.Parent    = hrp

        -- ── 5. Трейл на персонаже ───────────────────────────────────────
        local trailAtt0 = Instance.new("Attachment", hrp)
        trailAtt0.Position = Vector3.new(0, 0.5, 0)
        local trailAtt1 = Instance.new("Attachment", hrp)
        trailAtt1.Position = Vector3.new(0, -0.5, 0)

        local trail = Instance.new("Trail")
        trail.Attachment0  = trailAtt0
        trail.Attachment1  = trailAtt1
        trail.Lifetime     = 0.25
        trail.MinLength    = 0
        trail.FaceCamera   = true
        trail.LightEmission= 0.8
        trail.LightInfluence=0
        trail.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 180, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 100, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 30, 180)),
        })
        trail.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        trail.WidthScale = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1.2),
            NumberSequenceKeypoint.new(1, 0),
        })
        trail.Parent = hrp

        -- Рывок длится 0.35 секунды
        task.wait(0.35)

        -- Убираем рывок
        if dashBV and dashBV.Parent then dashBV:Destroy() end

        -- Трейл угасает сам (Lifetime), но attachment убираем
        task.delay(0.3, function()
            if trail and trail.Parent then trail:Destroy() end
            if trailAtt0 and trailAtt0.Parent then trailAtt0:Destroy() end
            if trailAtt1 and trailAtt1.Parent then trailAtt1:Destroy() end
        end)
    end)

    task.delay(2.5, function() flashKillBusy = false end)
end

-- ══ BULLET TRACERS ══════════════════════════════════════════════════════════
-- Beam-based трасеры: 3 слоя (glow + core + halo)
local tracerRainbowHue = 0

local function spawnTracer(fromPos, toPos, isHeadshot)
    if not S.tracerEnabled then return end
    local ok_t = pcall(function()
        local dist = (toPos - fromPos).Magnitude
        if dist < 0.5 then return end
        tracerRainbowHue = (tracerRainbowHue + 0.13) % 1

        local c1 = isHeadshot and Color3.fromRGB(255,200,0) or S.tracerColor
        local c2 = isHeadshot and Color3.fromRGB(255,255,100) or S.tracerColor2
        if S.tracerStyle == "Rainbow" then
            c1 = Color3.fromHSV(tracerRainbowHue,1,1)
            c2 = Color3.fromHSV((tracerRainbowHue+0.33)%1,1,1)
        elseif S.tracerStyle == "Electric" then
            c1 = Color3.fromRGB(80,160,255); c2 = Color3.fromRGB(200,235,255)
        end

        -- Якорные парты
        local p0 = Instance.new("Part")
        p0.Anchored=true; p0.CanCollide=false; p0.CanQuery=false; p0.CanTouch=false
        p0.CastShadow=false; p0.Size=Vector3.new(0.05,0.05,0.05); p0.Transparency=1
        p0.CFrame=CFrame.new(fromPos); p0.Parent=WS
        local p1 = Instance.new("Part")
        p1.Anchored=true; p1.CanCollide=false; p1.CanQuery=false; p1.CanTouch=false
        p1.CastShadow=false; p1.Size=Vector3.new(0.05,0.05,0.05); p1.Transparency=1
        p1.Position=toPos; p1.Parent=WS

        local a0 = Instance.new("Attachment",p0); a0.WorldPosition=fromPos
        local a1 = Instance.new("Attachment",p1); a1.WorldPosition=toPos

        local function makeBeam(w0, transparency_start, emis, colorseq)
            local b = Instance.new("Beam",p0)
            b.Attachment0=a0; b.Attachment1=a1
            b.Color=colorseq; b.LightEmission=emis; b.LightInfluence=0
            b.FaceCamera=true; b.Segments=4; b.TextureMode=Enum.TextureMode.Stretch
            b.Texture="rbxassetid://6631799885"
            b.Width0=w0; b.Width1=0
            b.Transparency=NumberSequence.new({
                NumberSequenceKeypoint.new(0,transparency_start),
                NumberSequenceKeypoint.new(0.65,transparency_start),
                NumberSequenceKeypoint.new(1,1)
            })
            return b
        end

        -- Слой 1: широкое свечение
        makeBeam(S.tracerWidth*5, 0.55,0.5,
            ColorSequence.new({ColorSequenceKeypoint.new(0,c1),ColorSequenceKeypoint.new(1,c2)}))
        -- Слой 2: основная линия
        makeBeam(S.tracerWidth*2, 0.0, 1.0,
            ColorSequence.new({ColorSequenceKeypoint.new(0,c1),ColorSequenceKeypoint.new(0.5,c2),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))}))
        -- Слой 3: белое ядро
        makeBeam(S.tracerWidth*0.5, 0.2, 1.0,
            ColorSequence.new(Color3.new(1,1,1)))

        -- Вспышка попадания
        if S.tracerImpact then
            local impPE = Instance.new("ParticleEmitter",a1)
            impPE.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(0.4,c1),ColorSequenceKeypoint.new(1,c2)})
            impPE.LightEmission=1; impPE.LightInfluence=0
            impPE.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.18),NumberSequenceKeypoint.new(1,0)})
            impPE.Speed=NumberRange.new(5,12); impPE.Lifetime=NumberRange.new(0.05,0.15)
            impPE.SpreadAngle=Vector2.new(60,60); impPE.Rate=0
            impPE.Texture="rbxasset://textures/particles/sparkles_main.dds"
            impPE:Emit(isHeadshot and 20 or 10)
            local impL=Instance.new("PointLight",p1)
            impL.Color=c1; impL.Brightness=isHeadshot and 8 or 4; impL.Range=isHeadshot and 10 or 6
            TweenService:Create(impL,TweenInfo.new(S.tracerLifetime*0.8),{Brightness=0,Range=0}):Play()
        end

        -- Угасание: сохраняем startWidth и линейно интерполируем к 0
        -- TweenService не анимирует Width0/Width1 у Beam — делаем вручную
        local lifetime = math.max(S.tracerLifetime, 0.06)
        -- Собираем beams вместе с их начальным Width
        local beamData = {}
        for _, b in ipairs(p0:GetChildren()) do
            if b:IsA("Beam") then
                table.insert(beamData, {beam=b, startW=b.Width0})
            end
        end
        task.spawn(function()
            local steps  = 15
            local stepT  = lifetime / steps
            for i = 1, steps do
                task.wait(stepT)
                local alpha = i / steps  -- 0 → 1 (полностью прозрачный)
                for _, bd in ipairs(beamData) do
                    local b = bd.beam
                    if b and b.Parent then
                        pcall(function()
                            -- Линейная интерполяция ширины: от startW к 0
                            b.Width0 = bd.startW * (1 - alpha)
                            b.Width1 = 0
                            -- Прозрачность: плавно к 1
                            local tr = math.min(1, alpha * 1.1)
                            b.Transparency = NumberSequence.new({
                                NumberSequenceKeypoint.new(0,   tr),
                                NumberSequenceKeypoint.new(0.5, tr),
                                NumberSequenceKeypoint.new(1,   1),
                            })
                        end)
                    end
                end
            end
            -- Гарантированное уничтожение
            pcall(function() if p0 and p0.Parent then p0:Destroy() end end)
            pcall(function() if p1 and p1.Parent then p1:Destroy() end end)
        end)
    end)
end

local function spawnBlackhole(cf)
    pcall(function()
        local a=Instance.new("Part"); a.Size=Vector3.new(1,1,1); a.Transparency=1
        a.Anchored=true; a.CanCollide=false; a.CastShadow=false; a.CFrame=cf; a.Parent=WS
        local att=Instance.new("Attachment",a)
        local l=Instance.new("PointLight",a); l.Color=Color3.fromRGB(255,100,0); l.Brightness=5; l.Range=16
        local function mp(cfg)
            local p=Instance.new("ParticleEmitter",att)
            for k,v in pairs(cfg) do pcall(function() p[k]=v end) end
        end
        mp({RotSpeed=NumberRange.new(10,10),SpreadAngle=Vector2.new(-360,360),Color=ColorSequence.new(Color3.new(0,0,0)),VelocityInheritance=0,Rate=20,EmissionDirection=Enum.NormalId.Top,LightInfluence=0,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.7,0),NumberSequenceKeypoint.new(1,1)}),Rotation=NumberRange.new(0,0),Lifetime=NumberRange.new(0.5,0.5),LightEmission=0,Speed=NumberRange.new(0.074,0.074),Texture="rbxassetid://14770848042",Size=NumberSequence.new({NumberSequenceKeypoint.new(0,2.22),NumberSequenceKeypoint.new(1,2.22)})})
        mp({RotSpeed=NumberRange.new(-360,360),SpreadAngle=Vector2.new(-360,360),Color=ColorSequence.new(Color3.new(0,0,0)),VelocityInheritance=0,Rate=20,EmissionDirection=Enum.NormalId.Top,LightInfluence=0,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.2,1),NumberSequenceKeypoint.new(0.4,0),NumberSequenceKeypoint.new(0.6,0),NumberSequenceKeypoint.new(0.8,0),NumberSequenceKeypoint.new(1,1)}),Rotation=NumberRange.new(0,0),Lifetime=NumberRange.new(0.4,0.4),LightEmission=0,Speed=NumberRange.new(0.37,0.37),Texture="rbxassetid://2763450503",Size=NumberSequence.new({NumberSequenceKeypoint.new(0,2.96),NumberSequenceKeypoint.new(1,2.96)})})
        mp({RotSpeed=NumberRange.new(10,10),SpreadAngle=Vector2.new(-360,360),Color=ColorSequence.new(Color3.new(1,1,1)),VelocityInheritance=0,Rate=20,EmissionDirection=Enum.NormalId.Top,LightInfluence=0,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.2,1),NumberSequenceKeypoint.new(0.4,1),NumberSequenceKeypoint.new(0.6,0),NumberSequenceKeypoint.new(0.8,0),NumberSequenceKeypoint.new(1,1)}),Rotation=NumberRange.new(0,0),Lifetime=NumberRange.new(0.5,0.5),LightEmission=1,Speed=NumberRange.new(0.37,0.37),Texture="rbxassetid://6644617442",Size=NumberSequence.new({NumberSequenceKeypoint.new(0,2.4),NumberSequenceKeypoint.new(1,2.4)})})
        mp({RotSpeed=NumberRange.new(-360,360),SpreadAngle=Vector2.new(-360,360),Color=ColorSequence.new(Color3.new(1,1,1)),VelocityInheritance=0,Rate=20,EmissionDirection=Enum.NormalId.Top,LightInfluence=0,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.2,1),NumberSequenceKeypoint.new(0.4,1),NumberSequenceKeypoint.new(0.6,0),NumberSequenceKeypoint.new(0.8,0),NumberSequenceKeypoint.new(1,1)}),Rotation=NumberRange.new(0,0),Lifetime=NumberRange.new(0.4,0.4),LightEmission=0.5,Speed=NumberRange.new(0.37,0.74),Texture="rbxassetid://2763450503",Size=NumberSequence.new({NumberSequenceKeypoint.new(0,3.7),NumberSequenceKeypoint.new(1,3.7)})})
        mp({RotSpeed=NumberRange.new(-10,10),SpreadAngle=Vector2.new(-360,360),Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(242,189,0)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,120,0)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),VelocityInheritance=0,Rate=10,EmissionDirection=Enum.NormalId.Top,LightInfluence=0,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.1,0),NumberSequenceKeypoint.new(1,1)}),Lifetime=NumberRange.new(0.7,1),LightEmission=0.8,Speed=NumberRange.new(0.37,0.37),Texture="rbxassetid://11745241946",Size=NumberSequence.new({NumberSequenceKeypoint.new(0,7.4),NumberSequenceKeypoint.new(1,7.4)})})
        mp({RotSpeed=NumberRange.new(360,720),SpreadAngle=Vector2.new(0,0),Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,160,0))}),VelocityInheritance=0,Rate=10,EmissionDirection=Enum.NormalId.Top,LightInfluence=0,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.2,0),NumberSequenceKeypoint.new(1,1)}),Lifetime=NumberRange.new(1,2),LightEmission=0.5,Speed=NumberRange.new(0.037,0.037),Texture="rbxassetid://9864060085",Size=NumberSequence.new({NumberSequenceKeypoint.new(0,4.81),NumberSequenceKeypoint.new(1,4.81)})})
        mp({RotSpeed=NumberRange.new(360,720),SpreadAngle=Vector2.new(0,0),Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(200,140,140)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(84,84,84)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),VelocityInheritance=0,Rate=10,EmissionDirection=Enum.NormalId.Top,LightInfluence=0,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.2,0),NumberSequenceKeypoint.new(0.74,0),NumberSequenceKeypoint.new(1,1)}),Rotation=NumberRange.new(-360,360),Lifetime=NumberRange.new(1,2),LightEmission=0.5,Speed=NumberRange.new(0.037,0.037),Texture="rbxassetid://7150933366",Size=NumberSequence.new({NumberSequenceKeypoint.new(0,29.6),NumberSequenceKeypoint.new(1,29.6)})})
        task.delay(3,function()
            if not a or not a.Parent then return end
            for _,em in ipairs(att:GetChildren()) do
                if em:IsA("ParticleEmitter") then TweenService:Create(em,TweenInfo.new(0.5),{Rate=0}):Play() end
            end
            task.delay(0.8,function() if a and a.Parent then a:Destroy() end end)
        end)
    end)
end

-- KFD
task.spawn(function()
    local kfd=RS_rep:WaitForChild("kfd",30)
    if not kfd then warn("[MyProject] kfd not found"); return end
    kfd.OnClientEvent:Connect(function(killer,victim,headshot,_weapon,extra)
        local ks=tostring(killer or "?"); local vs=tostring(victim or "?"); local isHS=headshot==true
        local dist=0
        if type(extra)=="number" then dist=extra
        else pcall(function()
            if R.myHRP then
                local vc=getCharByName(vs)
                if vc then local vh=vc:FindFirstChild("HumanoidRootPart")
                    if vh then dist=math.floor((vh.Position-R.myHRP.Position).Magnitude) end
                end
            end
        end) end
        if HL.enabled and ks==LP.Name then pcall(function() createHLEntry(true,vs,dist,isHS) end) end
        if KE.enabled and ks==LP.Name then
            local vc=getCharByName(vs); local cf=CFrame.new(0,0,0)
            if vc then local vh=vc:FindFirstChild("HumanoidRootPart"); if vh then cf=vh.CFrame end end
            if KE.style=="Particles" or KE.style=="All" then spawnKillParticles(vc) end
            if KE.style=="Flash"     or KE.style=="All" then spawnKillFlash(vc) end
            if KE.style=="Blackhole" or KE.style=="All" then spawnBlackhole(cf) end
            -- Flash Kill (синий экран + рывок — всегда поверх других эффектов)
            if S.keFlashKill then task.spawn(spawnFlashKill) end
        end
    end)
    Library:Notification({Title="MyProject",Description="kfd подключён!",Duration=4})
end)

-- ══════════════════════════════════════════
--  NO-SPREAD СИСТЕМА
--  5 методов — каждый пытается устранить разброс
--  Включи один, остальные выключи
--  Скажи какой работает — остальные удалим
-- ══════════════════════════════════════════

-- Метод 1: CamLock — фиксируем камеру смотрящей на цель перед выстрелом
-- Логика: если сервер берёт направление от камеры — это уберёт разброс
local function NS_Method1(targetPos)
    if not R.cam or not R.myHead then return end
    local cam = R.cam
    local fromPos = R.myHead.Position
    local dir = (targetPos - fromPos).Unit
    pcall(function()
        -- Сохраняем CFrame камеры
        local savedCF = cam.CFrame
        -- Направляем камеру точно на цель
        cam.CFrame = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + dir)
        task.delay(0.12, function()
            if cam and cam.Parent then
                cam.CFrame = savedCF
            end
        end)
    end)
end

-- Метод 2: VelocitySnap — обнуляем угловую скорость HRP
-- Логика: угловая скорость может вызывать смещение прицела
local function NS_Method2()
    if not R.myHRP then return end
    pcall(function()
        R.myHRP.AssemblyAngularVelocity = Vector3.zero
    end)
end

-- Метод 3: HRPSnap — поворачиваем HRP точно на цель
-- Логика: сервер читает CFrame HRP для определения направления
local function NS_Method3(targetPos)
    if not R.myHRP or not R.myHead then return end
    pcall(function()
        local savedCF = R.myHRP.CFrame
        local fromPos = R.myHRP.Position
        local dir = (targetPos - fromPos).Unit
        local dir2d = Vector3.new(dir.X, 0, dir.Z)
        if dir2d.Magnitude > 0.01 then
            R.myHRP.CFrame = CFrame.new(fromPos, fromPos + dir2d)
        end
        task.delay(0.12, function()
            if R.myHRP and R.myHRP.Parent then
                R.myHRP.CFrame = savedCF
            end
        end)
    end)
end

-- Метод 4: DirOverride — передаём в FireServer ТОЧНЫЙ нормализованный вектор
-- Логика: если наш dir уже идеальный Unit — сервер не добавит spread
-- (это то что мы уже делаем, но здесь добавляем микро-коррекцию через head.CFrame)
local function NS_Method4_GetDir(fromPos, targetPos)
    -- Пересчитываем dir через Head CFrame напрямую
    local dir = (targetPos - fromPos)
    -- Normalize вручную для максимальной точности
    local mag = dir.Magnitude
    if mag < 0.001 then return Vector3.new(0,0,-1) end
    return dir / mag
end

-- Метод 5: CamTwist — lerp позиции камеры на 1 кадр
-- Логика: некоторые игры берут направление из CFrame камеры
local ns5LastCF = nil
local function NS_Method5(targetPos)
    if not R.cam or not R.myHead then return end
    pcall(function()
        local cam = R.cam
        ns5LastCF = cam.CFrame
        local lookDir = (targetPos - cam.CFrame.Position).Unit
        cam.CFrame = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + lookDir)
        task.delay(0.08, function()
            if cam and cam.Parent and ns5LastCF then
                cam.CFrame = ns5LastCF
                ns5LastCF = nil
            end
        end)
    end)
end

-- Главная функция NoSpread — вызывается перед FireServer
local function NS_Apply(targetPos, dirRef)
    if not S.nsEnabled then return dirRef end
    local m = S.nsMethod

    if m == 1 then
        NS_Method1(targetPos)
        return dirRef
    elseif m == 2 then
        NS_Method2()
        return dirRef
    elseif m == 3 then
        NS_Method3(targetPos)
        return dirRef
    elseif m == 4 then
        -- Метод 4 возвращает новый dir
        if R.myHead then
            return NS_Method4_GetDir(R.myHead.Position, targetPos)
        end
        return dirRef
    elseif m == 5 then
        NS_Method5(targetPos)
        return dirRef
    end
    return dirRef
end

-- ══════════════════════════════════════════
--  RAGEBOT CORE
-- ══════════════════════════════════════════

local function CacheChar()
    local c=LP.Character
    if not c then R.myChar=nil;R.myHRP=nil;R.myHead=nil;R.myHum=nil;return end
    R.myChar=c; R.myHRP=c:FindFirstChild("HumanoidRootPart")
    R.myHead=c:FindFirstChild("Head"); R.myHum=c:FindFirstChildOfClass("Humanoid")
    R.cam=WS.CurrentCamera
end

-- ── WEAPON — Tool > Remotes > FireShot (точно как игра) ──────────────────
local cachedWeapon = nil
local function RB_GetWeapon()
    if not R.myChar then return nil end
    local tool = R.myChar:FindFirstChildOfClass("Tool")
    if not tool then cachedWeapon=nil; return nil end
    if cachedWeapon and cachedWeapon.tool==tool
    and cachedWeapon.fireShot and cachedWeapon.fireShot.Parent then
        return cachedWeapon
    end
    local remotes = tool:FindFirstChild("Remotes")
    if not remotes then return nil end
    local fs = remotes:FindFirstChild("FireShot")
    if not fs then return nil end
    cachedWeapon = { tool=tool, fireShot=fs,
                     reload=remotes:FindFirstChild("Reload"),
                     handle=tool:FindFirstChild("Handle") }
    return cachedWeapon
end

-- ── SILENT AIM — поворачивает HRP к цели как v_u_90 в игре ───────────────
-- Игра: отключает aahelp → ждёт 0.01s → поворачивает HRP → через 0.15s восстанавливает
local aimLockUntil = 0
local function RB_SilentAim(dir)
    if not S.rbSilentAim then return end
    local char = LP.Character; if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end

    local savedRot = hrp.CFrame.Rotation

    -- Выключаем antiaim helpers
    pcall(function() if aahelp  then aahelp:FireServer("disable")  end end)
    pcall(function() if aahelp1 then aahelp1:FireServer("disable") end end)

    task.wait(0.01)

    -- Поворачиваем HRP лицом к цели (только XZ)
    local dir2d = Vector3.new(dir.X, 0, dir.Z)
    if dir2d.Magnitude > 0.1 then
        hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + dir2d)
    end
    aimLockUntil = TICK() + 0.15

    -- Через 0.15s восстанавливаем
    task.delay(0.15, function()
        if char and hrp and hrp.Parent then
            hrp.CFrame = CFrame.new(hrp.Position) * savedRot
        end
        pcall(function() if aahelp  then aahelp:FireServer("enable")  end end)
        pcall(function() if aahelp1 then aahelp1:FireServer("enable") end end)
    end)
end

-- ── AUTOSTOP — BodyVelocity + WalkSpeed=0 как v_u_98 в игре ─────────────
-- Игра вызывает autostop по "hit" событию (не перед каждым выстрелом!)
-- Кулдаун 1 секунда (os.clock)
local asLastTime  = 0
local asBvActive  = false
local asOrigWS    = nil

local function RB_AutoStop_Do()
    if not S.rbAutoStop then return end
    if asBvActive then return end

    local char = LP.Character; if not char then return end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not (hum and hrp) then return end
    if hum.FloorMaterial == Enum.Material.Air then return end

    asLastTime = os.clock()
    asBvActive = true

    -- Убираем старый если есть
    local old = hrp:FindFirstChild("AutoStopVelocity")
    if old then old:Destroy() end

    asOrigWS = hum.WalkSpeed
    hum.WalkSpeed = 0

    local bv = Instance.new("BodyVelocity")
    bv.Name      = "AutoStopVelocity"
    bv.Velocity  = Vector3.new(0, 0, 0)
    bv.MaxForce  = Vector3.new(100000, 0, 100000)
    bv.P         = 10000
    bv.Parent    = hrp

    task.delay(0.3, function()
        if bv and bv.Parent then bv:Destroy() end
        if hum and hum.Parent and asOrigWS then hum.WalkSpeed = asOrigWS end
        asBvActive = false
    end)
end

-- Подключаемся к "hit" событию как в игре
task.spawn(function()
    -- Ждём появления события
    local ev = hitEvent or RS_rep:WaitForChild("hit", 15)
    if ev then
        ev.OnClientEvent:Connect(function()
            RB_AutoStop_Do()
        end)
    end
end)

-- ── ВИДИМОСТЬ — рекурсивный рейкаст как v_u_122 в игре ───────────────────
local function isTransparent(p)
    if not p or not p:IsA("BasePart") then return false end
    local n = p.Name:lower()
    if n:find("hamik") or n:find("paletka") then return true end
    if p.Parent then
        local pn = p.Parent.Name:lower()
        if pn:find("hamik") or pn:find("paletka") then return true end
    end
    if p.Transparency > 0.2 then return true end
    if not p.CanCollide then return true end
    return false
end

local function isPlayerPart(p)
    if not p or not p:IsA("BasePart") then return false end
    local par = p.Parent; if not par then return false end
    return par:FindFirstChild("Humanoid") ~= nil
        or par:IsA("Accessory") or par:IsA("Hat")
end

-- Рекурсивный рейкаст (пробивает прозрачные, аксессуары, других игроков)
local function RB_CanHit(from, to, myChar, targetChar, depth)
    depth = depth or 0
    if depth > 8 then return false end
    if not (from and to and myChar and targetChar) then return false end
    local dir  = to - from
    local dist = dir.Magnitude
    if dist < 0.05 or dist > 1500 then return false end

    -- Исключаем себя и цель с ВСЕМИ потомками (точно как игра v_u_122)
    local excl = {myChar, targetChar}
    for _, p in ipairs(myChar:GetDescendants()) do
        if p:IsA("BasePart") then table.insert(excl, p) end
    end
    for _, p in ipairs(targetChar:GetDescendants()) do
        if p:IsA("BasePart") then table.insert(excl, p) end
    end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = excl
    rp.IgnoreWater = true

    local hit = WS:Raycast(from, dir, rp)
    if not hit then return true end

    local inst = hit.Instance
    if inst:IsDescendantOf(targetChar) then return true end

    if isTransparent(inst) or isPlayerPart(inst) then
        local np = hit.Position + dir.Unit * 0.1
        if (to - np).Magnitude < 0.1 then return true end
        return RB_CanHit(np, to, myChar, targetChar, depth+1)
    end

    -- Стена — проверяем wallbang
    if S.rbWallbang then
        local rp2 = RaycastParams.new()
        rp2.FilterType = Enum.RaycastFilterType.Exclude
        rp2.FilterDescendantsInstances = excl
        rp2.IgnoreWater = true
        local hit2 = WS:Raycast(to, -dir.Unit * dist, rp2)
        if hit2 then
            return (hit2.Position - hit.Position).Magnitude <= 12
        end
    end
    return false
end

-- 3 точки как в игре (центр, +0.3, -0.3)
local function RB_IsHittable(from, to, myChar, targetChar)
    if RB_CanHit(from, to,                            myChar, targetChar) then return true end
    if RB_CanHit(from, to+Vector3.new(0, 0.3, 0),    myChar, targetChar) then return true end
    if RB_CanHit(from, to+Vector3.new(0, -0.3, 0),   myChar, targetChar) then return true end
    return false
end

-- ── RESOLVER ─────────────────────────────────────────────────────────────
local resolverDB = {}
local RES_OFFSETS = {0, 58, -58, 90, -90, 45, -45, 120, -120, 135, -135}

local function getResolver(pl)
    if not resolverDB[pl] then resolverDB[pl]={idx=1,misses=0} end
    return resolverDB[pl]
end

local function resolverOnMiss(pl)
    if not S.rbResolver then return end
    local rd = getResolver(pl)
    rd.misses = rd.misses + 1
    rd.idx = (rd.idx % #RES_OFFSETS) + 1
end

local function resolverApply(pl, pos)
    if not S.rbResolver then return pos end
    local rd  = getResolver(pl)
    local off = RES_OFFSETS[rd.idx] or 0
    if off == 0 then return pos end
    local char = pl.Character; if not char then return pos end
    local root = char:FindFirstChild("HumanoidRootPart"); if not root then return pos end
    local a = math.rad(off); local d = pos - root.Position
    return root.Position + Vector3.new(
        d.X*math.cos(a) - d.Z*math.sin(a), d.Y,
        d.X*math.sin(a) + d.Z*math.cos(a)
    )
end

-- ── ПРЕДИКТ — формула игры v_u_137 ───────────────────────────────────────
-- Игра: pos + vel * clamp(dist/1000, 0.08, 0.2) * 1.2 (только если vel >= 3)
-- Мы добавляем пинг поверх
local function RB_Predict(pd, targetPos, dist)
    if not S.rbPrediction then return targetPos end
    local vel = smoothVel(pd.player)
    if vel.Magnitude < 3 then return targetPos end

    -- Базовое время как в игре
    local t = math.clamp(dist / 1000, 0.08, 0.2) * 1.2

    -- Добавляем пинг если доступен
    local ok, ping = pcall(function() return LP:GetNetworkPing() end)
    if ok and ping and ping > 0 then
        t = t + math.clamp(ping, 0, 0.12)
    end

    -- Гравитация если враг в воздухе
    local grav = Vector3.zero
    if pd.humanoid then
        local st = pd.humanoid:GetState()
        if st == Enum.HumanoidStateType.Freefall
        or st == Enum.HumanoidStateType.FallingDown then
            local tt = dist / 1000  -- время полёта
            grav = Vector3.new(0, -WS.Gravity * tt * 0.4, 0)
        end
    end

    return targetPos + vel * t + grav
end

-- ── AIRSHOT — компенсация нашего падения ─────────────────────────────────
local function RB_Airshot(targetPos)
    if not S.rbAirshot then return targetPos end
    if not R.myHum or not R.myHRP then return targetPos end
    local st = R.myHum:GetState()
    if st ~= Enum.HumanoidStateType.Freefall
    and st ~= Enum.HumanoidStateType.Jumping
    and st ~= Enum.HumanoidStateType.FallingDown then return targetPos end
    local vy = R.myHRP.AssemblyLinearVelocity.Y
    if math.abs(vy) < 1 then return targetPos end
    local dist = R.myHead and (targetPos - R.myHead.Position).Magnitude or 100
    local t = math.clamp(dist / 1000, 0.08, 0.2)
    return targetPos + Vector3.new(0, -vy * t * 0.5, 0)
end

-- ── УРОН ─────────────────────────────────────────────────────────────────
-- Точно игровые множители из v_u_56
local DMULT = {
    Head=4, UpperTorso=1, LowerTorso=1, Torso=1, HumanoidRootPart=1,
    LeftUpperArm=0.75, LeftLowerArm=0.75, LeftHand=0.75,
    RightUpperArm=0.75, RightLowerArm=0.75, RightHand=0.75,
    LeftUpperLeg=0.6, LeftLowerLeg=0.6, LeftFoot=0.6,
    RightUpperLeg=0.6, RightLowerLeg=0.6, RightFoot=0.6,
    ["Left Leg"]=0.6, ["Right Leg"]=0.6,
}
local function RB_Damage(part, dist)
    local m = DMULT[part.Name] or 0.5
    -- Игровой distance falloff из v_u_190
    if     dist > 300 then m = m * 0.3
    elseif dist > 200 then m = m * 0.5
    elseif dist > 100 then m = m * 0.8 end
    return math.floor(54 * m)
end

-- ── КЭШ ИГРОКОВ — обновляем каждые 0.5s как в игре (v_u_139 / v_u_145) ──
local playerCache = {}
local cacheTime   = 0

local function UpdateCache()
    local now = TICK()
    if now - cacheTime < 0.5 then return end
    cacheTime = now
    playerCache = {}
    for _, pl in ipairs(Plrs:GetPlayers()) do
        if pl == LP then continue end
        if S.rbTeamCheck and LP.Team and pl.Team == LP.Team then continue end
        local char = pl.Character; if not char then continue end
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then continue end
        table.insert(playerCache, {
            player=pl, character=char, humanoid=hum, rootPart=hrp,
        })
    end
end

-- ── ВЫБОР ЦЕЛИ — точно как v_u_190 в игре ────────────────────────────────
-- BAim (v_u_48): если HP < 30 → торс priority=1, голова priority=3
-- Score = sqrt(dx^2 + dy^2) * priority — меньше = лучше
local function RB_SelectTarget()
    if not R.myHead or not R.cam then return nil end
    UpdateCache()
    if #playerCache == 0 then return nil end

    local cam    = R.cam
    local myPos  = R.myHead.Position
    local camPos = cam.CFrame.Position
    local vp     = cam.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5

    local best      = nil
    local bestScore = math.huge

    for _, pd in ipairs(playerCache) do
        local char = pd.character; if not char then continue end
        local dist = (pd.rootPart.Position - camPos).Magnitude
        if dist > S.rbMaxDistance then continue end

        local hp = pd.humanoid.Health

        -- BAim логика: если HP < 30 и BAim включён → бьём в торс
        local baimActive = S.rbBAim and hp < 30

        -- Приоритеты частей (точно как игра)
        local parts = {}
        local hitbox = S.rbHitbox

        -- Голова (если не BAim или HP >= 30)
        if (hitbox == "Head" or hitbox == "Both") and not baimActive then
            local h = char:FindFirstChild("Head")
            if h then table.insert(parts, {part=h, priority=1}) end
        end

        -- Торс (приоритет 1 при BAim, иначе 2)
        if hitbox == "Torso" or hitbox == "Both" or baimActive then
            local t = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
                   or char:FindFirstChild("LowerTorso")
            if t then table.insert(parts, {part=t, priority=baimActive and 1 or 2}) end
        end

        -- Голова при BAim идёт с priority 3
        if baimActive and (hitbox == "Head" or hitbox == "Both") then
            local h = char:FindFirstChild("Head")
            if h then table.insert(parts, {part=h, priority=3}) end
        end

        -- Ноги/HRP как fallback (priority 4)
        if hitbox == "Both" or #parts == 0 then
            local leg = char:FindFirstChild("LeftUpperLeg")
                     or char:FindFirstChild("RightUpperLeg")
                     or char:FindFirstChild("HumanoidRootPart")
            if leg then table.insert(parts, {part=leg, priority=4}) end
        end

        -- Fallback если вообще ничего нет
        if #parts == 0 then
            local h = char:FindFirstChild("Head")
            local t = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
            if h then table.insert(parts, {part=h, priority=1}) end
            if t then table.insert(parts, {part=t, priority=2}) end
        end

        for _, entry in ipairs(parts) do
            local part    = entry.part
            local partPos = part.Position

            -- FOV check
            if S.rbFov < 360 then
                local sp, inV = cam:WorldToViewportPoint(partPos)
                if not inV then continue end
                local dx, dy = sp.X - cx, sp.Y - cy
                if dx*dx + dy*dy > S.rbFov*S.rbFov then continue end
            end

            -- Проверка минимального урона
            if RB_Damage(part, dist) < S.rbMinDamage then continue end

            -- Применяем резолвер
            local checkPos = resolverApply(pd.player, partPos)

            -- Backtrack: дополнительные позиции
            local candidates = {checkPos}
            if S.rbBacktrack then
                local btP = getBTPos(pd.player, part.Name)
                if btP then table.insert(candidates, resolverApply(pd.player, btP)) end
            end

            for _, cp in ipairs(candidates) do
                if RB_IsHittable(myPos, cp, R.myChar, char) then
                    -- Score как в игре: sqrt(dx^2+dy^2) * priority
                    local sp, inV = cam:WorldToViewportPoint(cp)
                    if not inV then continue end
                    local dx, dy = sp.X - cx, sp.Y - cy
                    local score = math.sqrt(dx*dx + dy*dy) * entry.priority
                    if score < bestScore then
                        bestScore = score
                        best = {
                            player=pd.player, character=char,
                            humanoid=pd.humanoid, targetPart=part,
                            rootPart=pd.rootPart, hitPos=cp, dist=dist,
                        }
                    end
                    break  -- нашли видимую точку для этой части — идём дальше
                end
            end
        end
    end

    return best
end

-- ══════════════════════════════════════════
--  AGGRESSIVE DOUBLE TAP
--  Телепортируется ПО НАПРАВЛЕНИЮ К ВРАГУ
--  на rbADTRange ст, стреляет, возвращается.
--  Использует DTMarker как игровой DT.
--  НЕ телепортируется в стены: рейкаст вперёд.
-- ══════════════════════════════════════════
local adtBusy    = false
local adtLastT   = 0

local function ADT_Execute(target, weapon)
    if adtBusy then return end
    if not S.rbADT then return end
    if os.clock() - adtLastT < S.rbADTCooldown then return end
    if not R.myChar or not R.myHRP or not R.myHum or not R.myHead then return end
    if not target or not weapon then return end

    adtBusy  = true
    adtLastT = os.clock()

    local char    = R.myChar
    local hrp     = R.myHRP
    local hum     = R.myHum
    local origCF  = hrp.CFrame

    -- Вектор к врагу
    local enemyPos = target.rootPart.Position
    local toEnemy  = (enemyPos - hrp.Position)
    local toDir    = Vector3.new(toEnemy.X, 0, toEnemy.Z).Unit
    local dist     = toEnemy.Magnitude

    -- Целевая точка = на rbADTRange ст от врага в нашу сторону
    local approachDist = math.max(dist - S.rbADTRange, 1)
    local targetPt     = hrp.Position + toDir * approachDist

    -- Рейкаст — не улетаем в стену
    local rpA = RaycastParams.new()
    rpA.FilterDescendantsInstances = {char, target.character}
    rpA.FilterType = Enum.RaycastFilterType.Exclude
    rpA.IgnoreWater = true
    local wallHit = WS:Raycast(hrp.Position, toDir * approachDist, rpA)
    if wallHit then
        -- Встаём за 1.5 ст от стены
        local safeD = (wallHit.Position - hrp.Position).Magnitude - 1.5
        if safeD < 0.5 then
            adtBusy = false; return
        end
        targetPt = hrp.Position + toDir * safeD
    end

    -- Проверяем есть ли земля (не прыгаем в пропасть)
    local groundCheck = WS:Raycast(targetPt + Vector3.new(0,3,0), Vector3.new(0,-8,0), rpA)
    if not groundCheck then
        adtBusy = false; return
    end
    local finalPos = Vector3.new(targetPt.X, groundCheck.Position.Y + hum.HipHeight + 0.1, targetPt.Z)

    -- Сигнал серверу о DT
    pcall(function() DTMarker:FireServer("start", 4) end)

    -- Телепорт
    pcall(function()
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        char:PivotTo(CFrame.new(finalPos) * hrp.CFrame.Rotation)
        hrp.AssemblyLinearVelocity = Vector3.zero
    end)

    task.wait(0.02) -- даём физике устояться

    -- Обновляем позицию и цель после телепорта
    if not R.myHead then adtBusy=false; return end
    local t2 = RB_SelectTarget()
    if not t2 then
        pcall(function() DTMarker:FireServer("cancel") end)
        if S.rbADTReturn then
            pcall(function() char:PivotTo(origCF); hrp.AssemblyLinearVelocity=Vector3.zero end)
        end
        adtBusy = false; return
    end

    local newFrom = R.myHead.Position
    local hp2     = RB_Predict(t2, t2.hitPos, t2.dist)
    hp2 = RB_Airshot(hp2)
    local d2 = (hp2 - newFrom).Unit

    task.spawn(function() RB_SilentAim(d2) end)
    task.wait(0.015)

    local ok2 = pcall(function() weapon.fireShot:FireServer(newFrom, d2, t2.targetPart) end)
    if ok2 then lastShot = TICK() end

    -- Завершаем DT
    task.wait(0.08)
    pcall(function() DTMarker:FireServer("end") end)

    -- Возврат
    if S.rbADTReturn then
        task.wait(0.04)
        pcall(function()
            if char and R.myHRP then
                char:PivotTo(origCF)
                R.myHRP.AssemblyLinearVelocity  = Vector3.zero
                R.myHRP.AssemblyAngularVelocity = Vector3.zero
            end
        end)
    end

    task.delay(0.1, function() adtBusy = false end)
end

-- ══════════════════════════════════════════
--  RAPID FIRE — авто-реэквип SSG-08
--  Механика: unequip (дроп) → equip (подбор)
--  = сервер сбрасывает кулдаун оружия
--  Повторяем rbRFExtraShots раз после первого выстрела
-- ══════════════════════════════════════════
local rfBusy = false

local function RF_Execute(weapon, fromPos, dir, targetPart)
    if rfBusy then return end
    if not S.rbRapidFire then return end
    if not R.myChar or not R.myHRP or not R.myHum then return end

    rfBusy = true
    local char = R.myChar
    local tool = weapon.tool

    task.spawn(function()
        for i = 1, S.rbRFExtraShots do
            -- Получаем родителя до дропа (чтобы знать куда вернуть)
            local toolParent = tool.Parent
            if not toolParent then break end

            -- Unequip: убираем инструмент из персонажа в Backpack
            pcall(function()
                local bp = LP:FindFirstChildOfClass("Backpack")
                if bp then
                    tool.Parent = bp
                end
            end)

            task.wait(0.02) -- минимальное ожидание сервера

            -- Equip обратно
            pcall(function()
                hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum:EquipTool(tool) end
            end)

            task.wait(0.04) -- ждём пока оружие снова в руках

            -- Обновляем кэш оружия и стреляем
            cachedWeapon = nil
            local w2 = RB_GetWeapon()
            if not w2 then break end

            -- Обновляем цель
            local t2 = RB_SelectTarget()
            if t2 and R.myHead then
                local hp2 = RB_Predict(t2, t2.hitPos, t2.dist)
                hp2 = RB_Airshot(hp2)
                local newFrom = R.myHead.Position
                local d2 = (hp2 - newFrom).Unit
                task.spawn(function() RB_SilentAim(d2) end)
                task.wait(0.01)
                local okRF = pcall(function()
                    w2.fireShot:FireServer(newFrom, d2, t2.targetPart)
                end)
                if okRF then lastShot = TICK() end
            end
        end
        rfBusy = false
    end)
end

-- ══════════════════════════════════════════
--  ANTI KILLBRICK
--  Метод 1 "NoTouch": убираем Touched-связь у
--    всех KillBrick-партов через CanTouch=false
--    на наш персонаж (Nameless Admin метод)
--  Метод 2 "Delete": каждые N секунд удаляем
--    части с Damage/KillBrick в названии/тегах
-- ══════════════════════════════════════════

-- Определяет является ли часть килл-бриком
local function AKB_IsKillBrick(p)
    if not p or not p:IsA("BasePart") then return false end
    local n = p.Name:lower()
    if n:find("kill") or n:find("damage") or n:find("hurt") or n:find("lava")
    or n:find("acid") or n:find("death") or n:find("spike") or n:find("trap") then
        return true
    end
    -- Проверяем ScriptableObject / Script потомков с Damage
    for _, ch in ipairs(p:GetChildren()) do
        if ch:IsA("Script") or ch:IsA("LocalScript") then
            -- Наличие скрипта в части — признак килл-брика
            return true
        end
        if ch:IsA("NumberValue") and (ch.Name:lower():find("damage") or ch.Name:lower():find("kill")) then
            return true
        end
    end
    return false
end

-- NoTouch метод: применяем CanTouch=false к нашим частям
-- Аналог Nameless Admin: персонаж игнорирует Touched события
local akbNoTouchConn = {}

local function AKB_ApplyNoTouch()
    if not R.myChar then return end
    for _, p in ipairs(R.myChar:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function() p.CanTouch = false end)
        end
    end
end

local function AKB_RestoreTouch()
    if not R.myChar then return end
    for _, p in ipairs(R.myChar:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function() p.CanTouch = true end)
        end
    end
end

-- Delete метод: находим и удаляем килл-брики в радиусе
local function AKB_DeleteNearby()
    if not R.myHRP then return end
    local radius = 30  -- studs вокруг нас
    local myPos  = R.myHRP.Position
    local deleted = 0

    local function scanModel(model)
        for _, p in ipairs(model:GetDescendants()) do
            if AKB_IsKillBrick(p) then
                local dist = (p.Position - myPos).Magnitude
                if dist <= radius then
                    pcall(function() p:Destroy() end)
                    deleted = deleted + 1
                end
            end
        end
    end

    pcall(function() scanModel(WS) end)
    if deleted > 0 then
        print(string.format("[AKB] Deleted %d killbricks nearby", deleted))
    end
end

-- Основной цикл Anti Killbrick
local akbLastDelete = 0
local function AKB_Update()
    if not S.akbEnabled then
        -- Если выключили NoTouch — восстанавливаем
        if R.myChar then AKB_RestoreTouch() end
        return
    end

    if S.akbMethod == "NoTouch" then
        AKB_ApplyNoTouch()
    elseif S.akbMethod == "Delete" then
        local now = TICK()
        if now - akbLastDelete >= S.akbDeleteDelay then
            akbLastDelete = now
            task.spawn(AKB_DeleteNearby)
        end
    end
end

-- ── ГЛАВНЫЙ ЦИКЛ РЕЙДЖБОТА ───────────────────────────────────────────────
-- Точно воспроизводит логику v195 RenderStepped из игры:
-- v_u_24 = lastShot (кулдаун 1.3s после успешного выстрела — игровой "DT cooldown")
-- v_u_25 = shootLocked (0.1s после любого выстрела)
-- v_u_26 = noTargetTimer (0.05s задержка при появлении цели)
-- v_u_27 = hadNoTarget флаг
local lastShot      = 0   -- v_u_24: кулдаун после выстрела
local shootLocked   = false  -- v_u_25
local noTargetTimer = 0   -- v_u_26
local hadNoTarget   = false  -- v_u_27
local dtLastTime    = 0   -- кулдаун DoubleTap (как v_u_63 в игре, 1s)

RS.RenderStepped:Connect(function()
    if not S.rbEnabled then return end
    if not R.myChar or not R.myHead or not R.myHum then return end

    local hum = R.myHum; local hrp = R.myHRP
    if not hum or hum.Health <= 0 then return end

    -- Проверка состояния (в воздухе = нельзя стрелять, если airshot выключен)
    local myState = hum:GetState()
    local myInAir = myState == Enum.HumanoidStateType.Jumping
                 or myState == Enum.HumanoidStateType.Freefall
                 or myState == Enum.HumanoidStateType.FallingDown
    if myInAir and not S.rbAirshot then return end

    -- canShoot: FloorMaterial ~= Air ИЛИ raycast вниз 3.5
    -- (если airshot — пропускаем проверку)
    if not S.rbAirshot then
        if hum.FloorMaterial == Enum.Material.Air then
            local rp2 = RaycastParams.new()
            rp2.FilterType = Enum.RaycastFilterType.Exclude
            rp2.FilterDescendantsInstances = {R.myChar}
            if not WS:Raycast(hrp.Position, Vector3.new(0,-3.5,0), rp2) then
                return
            end
        end
    end

    local now = TICK()

    -- Кулдаун после выстрела (v_u_24 < S.rbFireRate)
    if now - lastShot < S.rbFireRate then return end
    if shootLocked then return end
    -- Aimlock от silent aim
    if now < aimLockUntil then return end

    -- Оружие
    local weapon = RB_GetWeapon()
    if not weapon then cachedWeapon=nil; return end

    -- Выбор цели
    local target = RB_SelectTarget()

    if not target then
        -- Нет цели — запускаем таймер как в игре (v_u_27/v_u_26)
        if not hadNoTarget then
            hadNoTarget   = true
            noTargetTimer = now
        end

        return
    end

    -- Цель появилась — если только что появилась, ждём 0.05s (v_u_26 delay)
    if hadNoTarget then
        hadNoTarget   = false
        noTargetTimer = now
    end
    if now - noTargetTimer < 0.05 then return end

    -- Hitchance
    if S.rbHitchance < 100 and math.random(1,100) > S.rbHitchance then return end

    -- Позиция
    local hitPos = target.hitPos
    hitPos = RB_Predict(target, hitPos, target.dist)
    hitPos = RB_Airshot(hitPos)

    local fromPos = R.myHead.Position
    local dir     = (hitPos - fromPos).Unit

    -- Silent Aim — вызываем СИНХРОННО перед выстрелом (как в игре v_u_90 вызывается ДО pcall)
    -- task.spawn создаёт race condition — HRP не успевает повернуться
    if S.rbSilentAim then
        RB_SilentAim(dir)
        -- task.wait(0.01) уже внутри RB_SilentAim, поэтому здесь не нужен
    end

    -- ── NO-SPREAD перед выстрелом ────────────────────────────────────────────
    dir = NS_Apply(hitPos, dir)

    -- ── ВЫСТРЕЛ ─────────────────────────────────────────────────────────────
    shootLocked = true
    local ok, err = pcall(function()
        weapon.fireShot:FireServer(fromPos, dir, target.targetPart)
    end)

    if not ok then
        warn("[RB] FireServer error:", err)
        cachedWeapon = nil
        shootLocked  = false
        return
    end

    lastShot = now
    RB_AutoStop_Do()

    -- Bullet Tracer (рейкаст до точки попадания)
    task.spawn(function()
        local trRP = RaycastParams.new()
        trRP.FilterType = Enum.RaycastFilterType.Exclude
        trRP.FilterDescendantsInstances = {R.myChar}
        local trHit = WS:Raycast(fromPos, dir * 900, trRP)
        local trEnd = trHit and trHit.Position or (fromPos + dir * 900)
        spawnTracer(fromPos, trEnd, target.targetPart.Name == "Head")
    end)

    -- Rapid Fire (авто реэквип SSG-08)
    if S.rbRapidFire and not rfBusy then
        RF_Execute(weapon, fromPos, dir, target.targetPart)
    end

    -- ── LEGIT DT — точная копия v_u_82() из игры ──────────────────────────
    -- DTMarker:FireServer("start",4) → телепорт по MoveDir на 4ст → 2й выстрел → "end"
    -- Кулдаун 1s (как v_u_63 в игре), сбрасывается при смерти
    if S.rbLegitDT and (os.clock() - dtLastTime >= 1) then
        dtLastTime = os.clock()
        task.spawn(function()
            local char = LP.Character; if not char then return end
            local hum  = char:FindFirstChildOfClass("Humanoid")
            local hrp  = char:FindFirstChild("HumanoidRootPart")
            if not (hum and hrp and hum.Health > 0) then return end

            -- Сигнал серверу — как в игре
            pcall(function() DTMarker:FireServer("start", 4) end)

            -- Направление = MoveDir или LookVector
            local mv = hum.MoveDirection
            if mv.Magnitude < 0.05 then mv = hrp.CFrame.LookVector end
            local d2d = Vector3.new(mv.X, 0, mv.Z).Unit
            local org = hrp.Position
            local tpt = org + d2d * 4

            local rpDT = RaycastParams.new()
            rpDT.FilterDescendantsInstances = {char}
            rpDT.FilterType = Enum.RaycastFilterType.Exclude
            rpDT.IgnoreWater = true

            -- Стена перед нами?
            local wh = WS:Raycast(org, d2d * 4, rpDT)
            if wh then tpt = org + d2d * math.max(0, (wh.Position-org).Magnitude - 2) end

            -- Земля в точке назначения?
            local gh = WS:Raycast(tpt + Vector3.new(0,5,0), Vector3.new(0,-20,0), rpDT)
            if not gh then
                pcall(function() DTMarker:FireServer("cancel") end); return
            end

            -- Телепорт (точно как игра)
            local fp = Vector3.new(tpt.X, gh.Position.Y + hum.HipHeight + 0.5, tpt.Z)
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            char:PivotTo(CFrame.new(fp) * hrp.CFrame.Rotation)
            task.defer(function()
                local h2 = char:FindFirstChild("HumanoidRootPart")
                if h2 then h2.AssemblyLinearVelocity = Vector3.zero end
            end)

            task.wait(S.rbLegitDTDelay)

            -- 2-й выстрел с новой позиции
            local ww = RB_GetWeapon()
            if ww and R.myHead then
                local tt = RB_SelectTarget()
                if tt then
                    local hp2 = RB_Predict(tt, tt.hitPos, tt.dist)
                    hp2 = RB_Airshot(hp2)
                    local nf = R.myHead.Position
                    local dd = (hp2 - nf).Unit
                    task.spawn(function() RB_SilentAim(dd) end)
                    task.wait(0.01)
                    local ok2 = pcall(function() ww.fireShot:FireServer(nf, dd, tt.targetPart) end)
                    if ok2 then
                        -- Трасер для 2го выстрела
                        task.spawn(function()
                            local rp2 = RaycastParams.new()
                            rp2.FilterType = Enum.RaycastFilterType.Exclude
                            rp2.FilterDescendantsInstances = {R.myChar}
                            local th2 = WS:Raycast(nf, dd*900, rp2)
                            spawnTracer(nf, th2 and th2.Position or nf+dd*900, tt.targetPart.Name=="Head")
                        end)
                    end
                end
            end

            -- Завершаем DT (как в игре: task.wait(0.1) → FireServer("end"))
            task.wait(0.1)
            pcall(function() DTMarker:FireServer("end") end)
        end)
    end

    -- Aggressive DT (телепорт к врагу + выстрел)
    if S.rbADT and not adtBusy then
        task.spawn(function() ADT_Execute(target, weapon) end)
    end

    task.delay(0.1, function() shootLocked = false end)

end)

-- ══════════════════════════════════════════
--  FAKEDUCK
--  Логика игры: C/LeftCtrl → HipHeight -= 1
--  У нас: включил — всегда активен (infinite duck)
--         fdMode Hold/Toggle тоже поддерживается
-- ══════════════════════════════════════════

-- Безопасно сохраняем оригинальный HipHeight один раз при старте/спавне
-- Сохраняем в отдельной переменной, R.fdOriginalHip НИКОГДА не nil если персонаж жив
local fdHipSaved = false

local fdAnimTrack  = nil  -- анимационный трек дака
local fdAnimLoaded = false

-- Метод через Animator (из рабочего скрипта пользователя)
-- AnimationId: 102226306945117 = idle duck, 124458965304788 = walk duck
local FD_IDLE_ANIM_ID  = "rbxassetid://102226306945117"
local FD_WALK_ANIM_ID  = "rbxassetid://124458965304788"
local fdIdleTrack = nil
local fdWalkTrack = nil

local function FD_LoadAnims()
    if fdAnimLoaded then return end
    if not R.myHum then return end
    local animator = R.myHum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = R.myHum
    end
    pcall(function()
        local a1 = Instance.new("Animation"); a1.AnimationId = FD_IDLE_ANIM_ID
        fdIdleTrack = animator:LoadAnimation(a1)
        fdIdleTrack.Priority = Enum.AnimationPriority.Action
        fdIdleTrack.Looped   = true

        local a2 = Instance.new("Animation"); a2.AnimationId = FD_WALK_ANIM_ID
        fdWalkTrack = animator:LoadAnimation(a2)
        fdWalkTrack.Priority = Enum.AnimationPriority.Action
        fdWalkTrack.Looped   = true

        fdAnimLoaded = true
    end)
end

local function FD_PlayAnim()
    FD_LoadAnims()
    if not fdIdleTrack then return end
    -- Переключаем idle/walk как в игре
    if R.myHRP then
        local spd = Vector3.new(R.myHRP.Velocity.X, 0, R.myHRP.Velocity.Z).Magnitude
        if spd > 0.5 then
            if fdIdleTrack and fdIdleTrack.IsPlaying then fdIdleTrack:Stop() end
            if fdWalkTrack and not fdWalkTrack.IsPlaying then fdWalkTrack:Play() end
        else
            if fdWalkTrack and fdWalkTrack.IsPlaying then fdWalkTrack:Stop() end
            if fdIdleTrack and not fdIdleTrack.IsPlaying then fdIdleTrack:Play() end
        end
    end
end

local function FD_StopAnim()
    pcall(function()
        if fdIdleTrack and fdIdleTrack.IsPlaying then fdIdleTrack:Stop() end
        if fdWalkTrack and fdWalkTrack.IsPlaying then fdWalkTrack:Stop() end
    end)
end

local function FD_SaveHip()
    if not R.myHum then return end
    if not fdHipSaved or not R.fdOriginalHip then
        local hip = R.myHum.HipHeight
        if hip > 0.5 then
            R.fdOriginalHip = hip
            fdHipSaved = true
        end
    end
end

local function FakeDuck_Update()
    if not R.myHum then return end
    FD_SaveHip()

    local shouldDuck = false
    if S.fdEnabled then
        if     S.fdMode == "Always" then shouldDuck = true
        elseif S.fdMode == "Hold"   then shouldDuck = UIS:IsKeyDown(S.fdKey)
        elseif S.fdMode == "Toggle" then shouldDuck = fdToggleState
        end
    end

    if shouldDuck then
        -- HipHeight метод
        if R.fdOriginalHip then
            local target = R.fdOriginalHip - S.fdAmount
            if math.abs(R.myHum.HipHeight - target) > 0.01 then
                R.myHum.HipHeight = target
            end
        end
        -- Animator метод (рабочий — из скрипта пользователя)
        FD_PlayAnim()
        R.fdActive = true
    else
        -- Восстанавливаем HipHeight
        if R.fdOriginalHip and math.abs(R.myHum.HipHeight - R.fdOriginalHip) > 0.01 then
            R.myHum.HipHeight = R.fdOriginalHip
        end
        FD_StopAnim()
        fdAnimLoaded = false
        fdIdleTrack  = nil
        fdWalkTrack  = nil
        R.fdActive = false
    end
end

UIS.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if S.fdEnabled and S.fdMode == "Toggle" and inp.KeyCode == S.fdKey then
        fdToggleState = not fdToggleState
    end
end)

-- ══════════════════════════════════════════
--  CHAMS
-- ══════════════════════════════════════════
local chamsMap={}; local weapHL=nil; local rainbowT=0
local STYLE_FILL={Flat={ft=0.5,ot=0},Neon={ft=0.25,ot=0},Outlined={ft=1,ot=0},Glass={ft=0.7,ot=0.2},Rainbow={ft=0.35,ot=0}}

local function removeChams(char)
    if chamsMap[char] then pcall(function() chamsMap[char]:Destroy() end); chamsMap[char]=nil end
end
local function applyChams(char,fillC,outC,transp,style,wall)
    removeChams(char)
    pcall(function()
        local cfg=STYLE_FILL[style] or STYLE_FILL.Flat
        local hl=Instance.new("Highlight"); hl.Adornee=char; hl.FillColor=fillC; hl.OutlineColor=outC
        hl.FillTransparency=math.clamp(cfg.ft+transp/100,0,1); hl.OutlineTransparency=cfg.ot
        hl.DepthMode=wall and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
        hl.Parent=char; chamsMap[char]=hl
    end)
end
local function updateChams(dt)
    rainbowT=(rainbowT+(dt or 0.05))%1
    local mc=LP.Character
    if mc then
        if S.chamsSelfEnabled then
            local f=S.chamsSelfColorVis
            if S.chamsSelfStyle=="Rainbow" then f=Color3.fromHSV(rainbowT,1,1) end
            applyChams(mc,f,S.chamsSelfColorHid,S.chamsSelfTransp,S.chamsSelfStyle,S.chamsSelfWall)
        else removeChams(mc) end
    end
    for _,pl in ipairs(Plrs:GetPlayers()) do
        if pl==LP then continue end
        local char=pl.Character; if not char then continue end
        local isTeam=LP.Team~=nil and (pl.Team==LP.Team)
        if isTeam and S.chamsTeamEnabled then
            local f=S.chamsTeamColorVis
            if S.chamsTeamStyle=="Rainbow" then f=Color3.fromHSV((rainbowT+0.33)%1,1,1) end
            applyChams(char,f,S.chamsTeamColorHid,S.chamsTeamTransp,S.chamsTeamStyle,S.chamsTeamWall)
        elseif not isTeam and S.chamsEnemyEnabled then
            local f=S.chamsEnemyColorVis
            if S.chamsEnemyHPColor then
                local h=char:FindFirstChildOfClass("Humanoid")
                if h then local hp=math.clamp(h.Health/math.max(h.MaxHealth,1),0,1)
                    f=Color3.fromRGB(math.floor((1-hp)*255),math.floor(hp*200),0) end
            end
            if S.chamsEnemyStyle=="Rainbow" then f=Color3.fromHSV((rainbowT+0.66)%1,1,1) end
            applyChams(char,f,S.chamsEnemyColorHid,S.chamsEnemyTransp,S.chamsEnemyStyle,S.chamsEnemyWall)
        else removeChams(char) end
    end
    if weapHL then pcall(function() weapHL:Destroy() end); weapHL=nil end
    if S.chamsWeaponEnabled and mc then
        local tool=mc:FindFirstChildOfClass("Tool")
        if tool then pcall(function()
            local cfg=STYLE_FILL[S.chamsWeaponStyle] or STYLE_FILL.Neon
            local col=S.chamsWeaponColor
            if S.chamsWeaponRainbow then col=Color3.fromHSV(rainbowT,1,1) end
            local hl=Instance.new("Highlight"); hl.Adornee=tool; hl.FillColor=col
            hl.OutlineColor=Color3.new(1,1,1)
            hl.FillTransparency=math.clamp(cfg.ft+S.chamsWeaponTransp/100,0,1)
            hl.OutlineTransparency=0.4; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent=tool; weapHL=hl
        end) end
    end
end

-- ══════════════════════════════════════════
--  WORLD
-- ══════════════════════════════════════════
local origAmb,origOut,origBri,origFS,origFE,origFC
pcall(function()
    origAmb=Lighting.Ambient; origOut=Lighting.OutdoorAmbient; origBri=Lighting.Brightness
    origFS=Lighting.FogStart; origFE=Lighting.FogEnd; origFC=Lighting.FogColor
end)
local wcActive=false
local SKYBOX_IDS={["Night City"]={Stars=3000},Arctic={Stars=500},["Deep Space"]={Stars=7000},
    Sunset={Stars=300},Stormy={Stars=0},Dawn={Stars=200},["Neon Night"]={Stars=5000}}
local origSky=Lighting:FindFirstChildWhichIsA("Sky")
local customSky,lastSkyPreset=nil,nil
local function applySkybox(n)
    pcall(function()
        if customSky then customSky:Destroy(); customSky=nil end
        local ex=Lighting:FindFirstChildWhichIsA("Sky"); if ex then ex.Parent=nil end
        local cfg=SKYBOX_IDS[n] or {Stars=3000}
        local sky=Instance.new("Sky"); sky.StarCount=cfg.Stars or 3000; sky.Parent=Lighting; customSky=sky
    end)
end
local function removeSkybox()
    pcall(function() if customSky then customSky:Destroy(); customSky=nil end
        if origSky then origSky.Parent=Lighting end end); lastSkyPreset=nil
end

-- ══════════════════════════════════════════
--  ФОНОВЫЕ ЗАДАЧИ
-- ══════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(0.05)
        for _,pl in ipairs(Plrs:GetPlayers()) do
            if pl==LP then continue end
            local char=pl.Character; if not char then continue end
            local hrp=char:FindFirstChild("HumanoidRootPart")
            if hrp then
                recordVel(pl,hrp.AssemblyLinearVelocity)
                recordBT(pl,char)
            end
        end
    end
end)

Plrs.PlayerRemoving:Connect(function(pl)
    velHistory[pl]=nil; btHistory[pl]=nil; resolverDB[pl]=nil
end)

-- ══════════════════════════════════════════
--  ГЛАВНЫЙ ЦИКЛ (Heartbeat)
-- ══════════════════════════════════════════
local frame=0
RS.Heartbeat:Connect(function()
    frame=(frame%1000)+1
    if frame%8==0 then CacheChar() end
    FakeDuck_Update()
    AKB_Update()

    if S.worldColor then
        pcall(function()
            Lighting.Ambient=S.worldAmbient; Lighting.OutdoorAmbient=S.worldOutdoor
            Lighting.Brightness=(S.worldBrightness/100)*2
            Lighting.FogStart=S.worldFogStart; Lighting.FogEnd=S.worldFogEnd; Lighting.FogColor=S.worldFogColor
        end)
        wcActive=true
    elseif wcActive then
        pcall(function()
            if origAmb then Lighting.Ambient=origAmb end; if origOut then Lighting.OutdoorAmbient=origOut end
            if origBri then Lighting.Brightness=origBri end; if origFS then Lighting.FogStart=origFS end
            if origFE then Lighting.FogEnd=origFE end; if origFC then Lighting.FogColor=origFC end
        end)
        wcActive=false
    end
end)

task.spawn(function()
    while true do
        task.wait(0.25)
        if S.skyboxEnabled then
            if S.skyboxPreset~=lastSkyPreset then applySkybox(S.skyboxPreset); lastSkyPreset=S.skyboxPreset end
        elseif lastSkyPreset then removeSkybox() end
        updateChams(0.25)
    end
end)

LP.CharacterRemoving:Connect(function()
    R.fdOriginalHip=nil; R.fdActive=false; fdHipSaved=false
    cachedWeapon=nil; resolverDB={}; fdToggleState=false
    akbLastDelete=0
    for char in pairs(chamsMap) do removeChams(char) end
    if weapHL then pcall(function() weapHL:Destroy() end); weapHL=nil end
    if asBvActive then
        local bv=R.myHRP and R.myHRP:FindFirstChild("AutoStopVelocity")
        if bv then pcall(function() bv:Destroy() end) end
        asBvActive=false
    end
    CacheChar()
end)

LP.CharacterAdded:Connect(function(char)
    R.fdOriginalHip=nil; R.fdActive=false; fdHipSaved=false
    cachedWeapon=nil; resolverDB={}; playerCache={}; cacheTime=0
    lastShot=0; shootLocked=false; asBvActive=false; asOrigWS=nil
    akbLastDelete=0; dtLastTime=0; adtBusy=false; adtLastT=0; rfBusy=false; flashKillBusy=false
    -- Ждём полной загрузки персонажа перед сохранением HipHeight
    task.spawn(function()
        task.wait(0.5)
        CacheChar()
        -- Сохраняем оригинальный HipHeight сразу после загрузки
        if R.myHum then
            local hip = R.myHum.HipHeight
            if hip > 0.5 then
                R.fdOriginalHip = hip
                fdHipSaved = true
            end
        end
    end)
end)

Plrs.PlayerRemoving:Connect(function(pl)
    if pl.Character then removeChams(pl.Character) end
end)

Library:Notification({Title="MyProject v11",Description="✔ Loaded! SmartWB + AntiKB + FD Fix",Duration=5})
print("[MyProject v11] Loaded! Ragebot rebuilt from game source.")
