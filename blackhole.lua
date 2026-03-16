-- ================================
--        BLACKHOLE by bebramen
-- ================================

local Key = "bebramen22090" -- <-- меняй ключ здесь

local ValidKeys = {
    ["bebramen22090"] = true,
}

if not ValidKeys[Key] then
    warn("❌ Неверный ключ!")
    return
end

-- ================================

local LP = game:GetService("Players").LocalPlayer
local char = LP.Character or LP.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

local function makeParticle(att, name, cfg)
    local p = Instance.new("ParticleEmitter")
    p.Name = name
    for k,v in pairs(cfg) do p[k]=v end
    p.Parent = att
end

local part = Instance.new("Part")
part.Size = Vector3.new(1,1,1)
part.Transparency = 1
part.Anchored = false
part.CanCollide = false
part.CastShadow = false
part.Parent = workspace

local weld = Instance.new("WeldConstraint")
weld.Part0 = hrp
weld.Part1 = part
weld.Parent = part

local att = Instance.new("Attachment")
att.Position = Vector3.new(0,0,0)
att.Parent = part

local light = Instance.new("PointLight")
light.Color = Color3.fromRGB(255,100,0)
light.Brightness = 5
light.Range = 16
light.Parent = part

makeParticle(att,"blackhole",{
    RotSpeed=NumberRange.new(10,10),
    SpreadAngle=Vector2.new(-360,360),
    Color=ColorSequence.new(Color3.new(0,0,0)),
    VelocityInheritance=0,
    Rate=20,
    EmissionDirection=Enum.NormalId.Top,
    LightInfluence=0,
    Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.7,0),NumberSequenceKeypoint.new(1,1)}),
    Rotation=NumberRange.new(0,0),
    Lifetime=NumberRange.new(0.5,0.5),
    LightEmission=0,
    Speed=NumberRange.new(0.074,0.074),
    Texture="rbxassetid://14770848042",
    Size=NumberSequence.new({NumberSequenceKeypoint.new(0,2.22),NumberSequenceKeypoint.new(1,2.22)}),
})
makeParticle(att,"blackring",{
    RotSpeed=NumberRange.new(-360,360),
    SpreadAngle=Vector2.new(-360,360),
    Color=ColorSequence.new(Color3.new(0,0,0)),
    VelocityInheritance=0,
    Rate=20,
    EmissionDirection=Enum.NormalId.Top,
    LightInfluence=0,
    Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.2,1),NumberSequenceKeypoint.new(0.4,0),NumberSequenceKeypoint.new(0.6,0),NumberSequenceKeypoint.new(0.8,0),NumberSequenceKeypoint.new(1,1)}),
    Rotation=NumberRange.new(0,0),
    Lifetime=NumberRange.new(0.4,0.4),
    LightEmission=0,
    Speed=NumberRange.new(0.37,0.37),
    Texture="rbxassetid://2763450503",
    Size=NumberSequence.new({NumberSequenceKeypoint.new(0,2.96),NumberSequenceKeypoint.new(1,2.96)}),
})
makeParticle(att,"whitecenter",{
    RotSpeed=NumberRange.new(10,10),
    SpreadAngle=Vector2.new(-360,360),
    Color=ColorSequence.new(Color3.new(1,1,1)),
    VelocityInheritance=0,
    Rate=20,
    EmissionDirection=Enum.NormalId.Top,
    LightInfluence=0,
    Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.2,1),NumberSequenceKeypoint.new(0.4,1),NumberSequenceKeypoint.new(0.6,0),NumberSequenceKeypoint.new(0.8,0),NumberSequenceKeypoint.new(1,1)}),
    Rotation=NumberRange.new(0,0),
    Lifetime=NumberRange.new(0.5,0.5),
    LightEmission=1,
    Speed=NumberRange.new(0.37,0.37),
    Texture="rbxassetid://6644617442",
    Size=NumberSequence.new({NumberSequenceKeypoint.new(0,2.4),NumberSequenceKeypoint.new(1,2.4)}),
})
makeParticle(att,"whitering",{
    RotSpeed=NumberRange.new(-360,360),
    SpreadAngle=Vector2.new(-360,360),
    Color=ColorSequence.new(Color3.new(1,1,1)),
    VelocityInheritance=0,
    Rate=20,
    EmissionDirection=Enum.NormalId.Top,
    LightInfluence=0,
    Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.2,1),NumberSequenceKeypoint.new(0.4,1),NumberSequenceKeypoint.new(0.6,0),NumberSequenceKeypoint.new(0.8,0),NumberSequenceKeypoint.new(1,1)}),
    Rotation=NumberRange.new(0,0),
    Lifetime=NumberRange.new(0.4,0.4),
    LightEmission=0.5,
    Speed=NumberRange.new(0.37,0.74),
    Texture="rbxassetid://2763450503",
    Size=NumberSequence.new({NumberSequenceKeypoint.new(0,3.7),NumberSequenceKeypoint.new(1,3.7)}),
})
makeParticle(att,"dustring1",{
    RotSpeed=NumberRange.new(-10,10),
    SpreadAngle=Vector2.new(-360,360),
    Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(242,189,0)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,120,0)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),
    VelocityInheritance=0,
    Rate=10,
    EmissionDirection=Enum.NormalId.Top,
    LightInfluence=0,
    Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.1,0),NumberSequenceKeypoint.new(1,1)}),
    Lifetime=NumberRange.new(0.7,1),
    LightEmission=0.8,
    Speed=NumberRange.new(0.37,0.37),
    Texture="rbxassetid://11745241946",
    Size=NumberSequence.new({NumberSequenceKeypoint.new(0,7.4),NumberSequenceKeypoint.new(1,7.4)}),
})
makeParticle(att,"disk1",{
    RotSpeed=NumberRange.new(360,720),
    SpreadAngle=Vector2.new(0,0),
    Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,160,0))}),
    VelocityInheritance=0,
    Rate=10,
    EmissionDirection=Enum.NormalId.Top,
    LightInfluence=0,
    Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.2,0),NumberSequenceKeypoint.new(1,1)}),
    Lifetime=NumberRange.new(1,2),
    LightEmission=0.5,
    Speed=NumberRange.new(0.037,0.037),
    Texture="rbxassetid://9864060085",
    Size=NumberSequence.new({NumberSequenceKeypoint.new(0,4.81),NumberSequenceKeypoint.new(1,4.81)}),
})
makeParticle(att,"outerdisk",{
    RotSpeed=NumberRange.new(360,720),
    SpreadAngle=Vector2.new(0,0),
    Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(200,140,140)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(84,84,84)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),
    VelocityInheritance=0,
    Rate=10,
    EmissionDirection=Enum.NormalId.Top,
    LightInfluence=0,
    Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.2,0),NumberSequenceKeypoint.new(0.74,0),NumberSequenceKeypoint.new(1,1)}),
    Rotation=NumberRange.new(-360,360),
    Lifetime=NumberRange.new(1,2),
    LightEmission=0.5,
    Speed=NumberRange.new(0.037,0.037),
    Texture="rbxassetid://7150933366",
    Size=NumberSequence.new({NumberSequenceKeypoint.new(0,29.6),NumberSequenceKeypoint.new(1,29.6)}),
})

print("🌑 Blackhole активирован!")
