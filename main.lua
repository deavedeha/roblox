local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
assert(type(getgenv) == "function" and type(cloneref) == "function",
    "Forum X requires getgenv and cloneref; this is not a standard Studio LocalScript.")
local G = getgenv()

if G.ForumX_Kill then pcall(G.ForumX_Kill) end

do
    local CoreGui = cloneref(game:GetService("CoreGui"))
    for _, n in pairs({"Forum X","Aimbot FOV Overlay"}) do
        local old = CoreGui:FindFirstChild(n)
        if old then old:Destroy() end
    end
    if G.ForumX_Drawings then
        for _, l in pairs(G.ForumX_Drawings) do pcall(function() l:Remove() end) end
        G.ForumX_Drawings = nil
    end
    for _, d in pairs(workspace:GetDescendants()) do
        if d:IsA("Folder") and (d.Name=="ForumXESP" or d.Name=="ForumX_ESP") then d:Destroy() end
    end
end

local MOUSE_LABELS = {
    [Enum.UserInputType.MouseButton1]="LMB",
    [Enum.UserInputType.MouseButton2]="RMB",
    [Enum.UserInputType.MouseButton3]="MMB",
}

local function keybindLabel(kb)
    if not kb then return "(none)" end
    if kb.type == "custom" then return kb.label end
    if kb.type == "mouse" then return MOUSE_LABELS[kb.btn] or "Mouse" end
    if kb.type == "key" then return kb.keyCode.Name end
    return "(unknown)"
end

local function keybindMatches(kb, input)
    if not kb then return false end
    if kb.type == "mouse" then return input.UserInputType == kb.btn end
    return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == kb.keyCode
end

local spoofedHumanoid = nil
local spoofWS_val = 16
local spoofJP_val = 50
local spoofJH_val = 7.2
local spoofActive_flag = false

local ST = {
    noclipEnabled=false, noclipSpeed=40, noclipKey=nil, noclipConns={},
    currentPos=Vector3.new(),
    menuKey={type="key",keyCode=Enum.KeyCode.Insert},
    menuColor=Color3.fromRGB(255,255,255),
    cfTpKey=nil, cfTpDist=10, cfTpLoop=false, cfTpConn=nil,
    wsEnabled=false, wsValue=16,
    jumpEnabled=false, jumpValue=50,
    savedWS=nil, savedJP=nil, savedJH=nil, savedUJP=nil,
    speedConn=nil,
    promptBypass=false, promptConn=nil, savedDur={},
    promptRange=false, promptRangeConn=nil, promptRangeVal=65, savedPR={},
    antiAfk=false, antiAfkConn=nil,
    autoInteract=false, autoInteractConn=nil, autoInteractDist=15,
    nearFling=false, nearFlingActive=false, nearFlingConn=nil, nearFlingKey=nil,
    cameraFOV=false, cameraFOVValue=90, origFOV=nil,
    v1Targets={}, v1Running=false,
    plConns={},
    spectating=nil, origCamType=nil, origCamSubject=nil, specConn=nil, activeSpecBtn=nil,
    espMax=10000,
    espFlags={name=false,distance=false,healthBar=false,healthBarMode="top",chams=false,teamCheck=false,teamName=false,box=false,npc=false},
    nameCol=Color3.fromRGB(255,105,180),
    distCol=Color3.fromRGB(230,230,240),
    hpColL=Color3.fromRGB(100,220,130),
    hpColT=Color3.fromRGB(100,220,130),
    chamsMode="outline", chamsColorGroup="Normal",
    chamsCol=Color3.fromRGB(255,105,180),
    chamsCol2=Color3.fromRGB(255,105,180),
    chamsWhitelistCol=Color3.fromRGB(100,230,150),
    chamsTeamCol=Color3.fromRGB(100,180,255),
    npcCol=Color3.fromRGB(255,255,255),
    boxCol=Color3.fromRGB(255,255,255),
    teamCol=Color3.fromRGB(255,180,60),
    espConn=nil, espEntries={}, lastNpcScan=0,
    aimbotEnabled=false, aimbotActive=false,
    aimbotMode="Hold",
    aimbotMethod="Mouse",
    aimbotFOV=150,
    aimbotKey=nil,
    aimbotSmooth=0.5,
    aimbotTargetPart="Head",
    aimbotTeamCheck=false, aimbotWallCheck=false,
    aimbotFovColor=Color3.fromRGB(255,255,255),
    aimbotFovHidden=false, aimbotConn=nil,
    whitelistPlayers={}, whitelistTeams={},
    skelCol=Color3.fromRGB(255,255,255), skelLastScan=0,
}

local S = ST.espFlags
local FOLDER = "ForumX_ESP"
local skelLinePool = {}
G.ForumX_Drawings = skelLinePool
G.ForumX_Running = true
getgenv().OldPos = nil
getgenv().FPDH = workspace.FallenPartsDestroyHeight

local waitKey, keyTarget, keyBtn, keyTimeout, keyOnSet = false, nil, nil, nil, nil
local sliderConns = {}
local inputConn, inputEndedConn, charConn, dragMoveConn, dragEndConn
local activePicker = nil
local layoutCtr, contentH = 0, 0
local skelTargets = {}
local skeletonConn = nil
local frameCount = 0
local aimbotPartBtns = {}
local aimbotLastTarget = nil

local MENU_W = 720
local MENU_H = 530
local SIDE_W = 148
local ROW_H = 44
local ROW_PAD = 7
local CONTENT_X = SIDE_W + 12
local INNER_W = MENU_W - CONTENT_X - 8 - 16

local function findRoot(ch)
    if not ch then return nil end
    return ch:FindFirstChild("HumanoidRootPart")
        or ch:FindFirstChild("UpperTorso")
        or ch:FindFirstChild("Torso")
        or ch:FindFirstChild("Head")
        or ch:FindFirstChildWhichIsA("BasePart")
        or ch.PrimaryPart
end

local function findHuman(ch)
    if not ch then return nil end
    return ch:FindFirstChildOfClass("Humanoid")
        or ch:FindFirstChildOfClass("AnimationController")
end

local function getHPUniversal(ch, hum)
    if hum and hum:IsA("Humanoid") then
        local max = hum.MaxHealth
        local cur = hum.Health
        if max > 0 then return math.clamp(cur,0,max), max end
    end
    if ch then
        local attrNames = {"Health","HP","health","hp","CurrentHealth","Shield","Armor"}
        local maxNames = {"MaxHealth","MaxHP","maxHealth","maxHp","MaxHealth","MaxShield","MaxArmor"}
        for i, attr in ipairs(attrNames) do
            local ok1, cur = pcall(function() return ch:GetAttribute(attr) end)
            local ok2, max = pcall(function() return ch:GetAttribute(maxNames[i]) end)
            if ok1 and ok2 and type(cur)=="number" and type(max)=="number" and max > 0 then
                return math.clamp(cur,0,max), max
            end
        end
        local hpVal = ch:FindFirstChild("Health") or ch:FindFirstChild("HP") or ch:FindFirstChild("Hp")
        local maxVal = ch:FindFirstChild("MaxHealth") or ch:FindFirstChild("MaxHP") or ch:FindFirstChild("MaxHp")
        if hpVal and maxVal then
            local cur = hpVal.Value
            local max = maxVal.Value
            if type(cur)=="number" and type(max)=="number" and max > 0 then
                return math.clamp(cur,0,max), max
            end
        end
        local stats = ch:FindFirstChild("Stats") or ch:FindFirstChild("PlayerStats") or ch:FindFirstChild("HumanoidData")
        if stats then
            local hv = stats:FindFirstChild("Health") or stats:FindFirstChild("HP")
            local mv = stats:FindFirstChild("MaxHealth") or stats:FindFirstChild("MaxHP")
            if hv and mv and type(hv.Value)=="number" and mv.Value > 0 then
                return math.clamp(hv.Value,0,mv.Value), mv.Value
            end
        end
    end
    return 1, 1
end

local function isCharAlive(ch, hum)
    if not ch or not ch.Parent then return false end
    if hum and hum:IsA("Humanoid") then return hum.Health > 0 end
    local ok, hp = pcall(function() return ch:GetAttribute("Health") or ch:GetAttribute("HP") end)
    if ok and type(hp)=="number" then return hp > 0 end
    return true
end

local function isSameTeam(plrA, plrB)
    if not plrA or not plrB then return false end
    if plrA == plrB then return true end
    local okA, tA = pcall(function() return plrA.Team end)
    local okB, tB = pcall(function() return plrB.Team end)
    if okA and okB and tA ~= nil and tB ~= nil then return tA == tB end
    local chA, chB = plrA.Character, plrB.Character
    if chA and chB then
        local attrs = {"Team","TeamName","team","teamName","TeamID","Side","Faction"}
        for _, attr in ipairs(attrs) do
            local okA2, vA = pcall(function() return chA:GetAttribute(attr) end)
            local okB2, vB = pcall(function() return chB:GetAttribute(attr) end)
            if okA2 and okB2 and vA ~= nil and vB ~= nil then return vA == vB end
        end
    end
    local okA3, vA3 = pcall(function() return plrA:GetAttribute("Team") or plrA:GetAttribute("TeamName") end)
    local okB3, vB3 = pcall(function() return plrB:GetAttribute("Team") or plrB:GetAttribute("TeamName") end)
    if okA3 and okB3 and vA3 ~= nil and vB3 ~= nil then return vA3 == vB3 end
    return false
end

local function getTeamName(plr)
    if not plr then return nil end
    local ok, t = pcall(function() return plr.Team end)
    if ok and t then
        local ok2, n = pcall(function() return t.Name end)
        if ok2 and n and n ~= "" then return n end
    end
    local ch = plr.Character
    if ch then
        local ok3, v = pcall(function() return ch:GetAttribute("TeamName") or ch:GetAttribute("Team") end)
        if ok3 and type(v)=="string" and v ~= "" then return v end
    end
end

local function hsvToRgb(h,s,v)
    h=h%1; local i=math.floor(h*6); local f=h*6-i
    local p,q,t2=v*(1-s),v*(1-f*s),v*(1-(1-f)*s)
    if i%6==0 then return v,t2,p elseif i%6==1 then return q,v,p
    elseif i%6==2 then return p,v,t2 elseif i%6==3 then return p,q,v
    elseif i%6==4 then return t2,p,v else return v,p,q end
end

local function rgbToHsv(r,g,b)
    local mx,mn=math.max(r,g,b),math.min(r,g,b); local d=mx-mn; local h=0
    if d>0 then
        if mx==r then h=((g-b)/d)%6 elseif mx==g then h=(b-r)/d+2 else h=(r-g)/d+4 end
        h=h/6
    end
    return h, mx==0 and 0 or d/mx, mx
end

local function uic(r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r); return c end
local function uis(col,tr,th) local s=Instance.new("UIStroke"); s.Color=col; s.Transparency=tr; s.Thickness=th; return s end

local function isPlayerChar(m)
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character == m then return true end
    end
    return false
end

local function wantsESP()
    return S.name or S.distance or S.healthBar or S.chams or S.teamName or S.box
end

local autoInteractCircleLines = {}
local autoInteractCircleConn = nil
local AI_SEGMENTS = 48

local function destroyAutoInteractESP()
    if autoInteractCircleConn then
        autoInteractCircleConn:Disconnect()
        autoInteractCircleConn = nil
    end
    for _, l in ipairs(autoInteractCircleLines) do
        pcall(function() l:Remove() end)
    end
    autoInteractCircleLines = {}
end

local function createAutoInteractESP()
    destroyAutoInteractESP()
    for i = 1, AI_SEGMENTS do
        local ok, l = pcall(function() return Drawing.new("Line") end)
        if ok and l then
            l.Thickness = 1.5
            l.Color = Color3.fromRGB(100, 220, 255)
            l.Transparency = 0.3
            l.Visible = false
            autoInteractCircleLines[i] = l
        end
    end
    autoInteractCircleConn = RunService.RenderStepped:Connect(function()
        local ch = LocalPlayer.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if not hrp or not ST.autoInteract then
            for _, l in ipairs(autoInteractCircleLines) do if l then l.Visible = false end end
            return
        end
        local cam = workspace.CurrentCamera
        local center = hrp.Position
        local radius = ST.autoInteractDist
        local stepAngle = (2 * math.pi) / AI_SEGMENTS
        for i = 1, AI_SEGMENTS do
            local l = autoInteractCircleLines[i]
            if not l then continue end
            local a1 = stepAngle * (i - 1)
            local a2 = stepAngle * i
            local p1 = center + Vector3.new(math.cos(a1)*radius, 0, math.sin(a1)*radius)
            local p2 = center + Vector3.new(math.cos(a2)*radius, 0, math.sin(a2)*radius)
            local ok1, s1 = pcall(function() return cam:WorldToViewportPoint(p1) end)
            local ok2, s2 = pcall(function() return cam:WorldToViewportPoint(p2) end)
            if ok1 and ok2 and s1.Z > 0 and s2.Z > 0 then
                l.From = Vector2.new(s1.X, s1.Y)
                l.To   = Vector2.new(s2.X, s2.Y)
                l.Visible = true
            else
                l.Visible = false
            end
        end
    end)
end

local aiPromptCache = {}
local aiCacheTime = 0
local AI_CACHE_TTL = 1.5
local AI_INTERVAL = 0.35
local aiLastRun = 0
local aiDescConn = nil
local aiDescRemConn = nil

local function rebuildPromptCache()
    aiPromptCache = {}
    for _, d in pairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            local part = d.Parent
            if part and part:IsA("BasePart") then
                table.insert(aiPromptCache, {prompt=d, part=part})
            end
        end
    end
    aiCacheTime = os.clock()
end

local function enableAutoInteract()
    ST.autoInteract = true
    rebuildPromptCache()
    createAutoInteractESP()
    aiDescConn = workspace.DescendantAdded:Connect(function(d)
        if d:IsA("ProximityPrompt") then
            task.defer(function()
                local part = d.Parent
                if part and part:IsA("BasePart") and d.Enabled then
                    table.insert(aiPromptCache, {prompt=d, part=part})
                end
            end)
        end
    end)
    aiDescRemConn = workspace.DescendantRemoving:Connect(function(d)
        if d:IsA("ProximityPrompt") then
            for i = #aiPromptCache, 1, -1 do
                if aiPromptCache[i].prompt == d then
                    table.remove(aiPromptCache, i); break
                end
            end
        end
    end)
    ST.autoInteractConn = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - aiLastRun < AI_INTERVAL then return end
        aiLastRun = now
        local ch = LocalPlayer.Character
        local r = ch and ch:FindFirstChild("HumanoidRootPart")
        if not r then return end
        if now - aiCacheTime > AI_CACHE_TTL then rebuildPromptCache() end
        local myPos = r.Position
        local dist = ST.autoInteractDist
        for i = #aiPromptCache, 1, -1 do
            local entry = aiPromptCache[i]
            local prompt = entry.prompt
            local part = entry.part
            if not prompt or not prompt.Parent or not part or not part.Parent then
                table.remove(aiPromptCache, i); continue
            end
            if not prompt.Enabled then continue end
            local ok, d = pcall(function() return (part.Position - myPos).Magnitude end)
            if ok and d <= math.min(prompt.MaxActivationDistance, dist) then
                pcall(function() fireproximityprompt(prompt, prompt.HoldDuration) end)
            end
        end
    end)
end

local function disableAutoInteract()
    ST.autoInteract = false
    if ST.autoInteractConn then ST.autoInteractConn:Disconnect(); ST.autoInteractConn = nil end
    if aiDescConn then aiDescConn:Disconnect(); aiDescConn = nil end
    if aiDescRemConn then aiDescRemConn:Disconnect(); aiDescRemConn = nil end
    aiPromptCache = {}
    destroyAutoInteractESP()
end

local function getDefaultSpeeds()
    local ch = LocalPlayer.Character; if not ch then return 16,50,7.2,false end
    local hum = ch:FindFirstChildOfClass("Humanoid"); if not hum then return 16,50,7.2,false end
    local ws,jp,jh,ujp = 16,50,7.2,false
    pcall(function() ws = hum.WalkSpeed end)
    pcall(function() jp = hum.JumpPower end)
    pcall(function() jh = hum.JumpHeight end)
    pcall(function() ujp = hum.UseJumpPower end)
    return ws,jp,jh,ujp
end

local speedChanges = {humanoid=nil, walk=nil, jump=nil}
local function restoreSpeeds()
    local hum=speedChanges.humanoid
    spoofActive_flag=false; spoofedHumanoid=nil
    if hum and hum.Parent then
        if speedChanges.walk~=nil then hum.WalkSpeed=speedChanges.walk end
        if speedChanges.jump then
            hum.JumpPower=speedChanges.jump.power
            hum.JumpHeight=speedChanges.jump.height
            hum.UseJumpPower=speedChanges.jump.usePower
        end
    end
    speedChanges={humanoid=nil,walk=nil,jump=nil}
end

local function applySpeedPhysics()
    if ST.wsEnabled~=true and ST.jumpEnabled~=true then return end
    local ch=LocalPlayer.Character
    local hum=ch and ch:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if speedChanges.humanoid~=hum then
        restoreSpeeds()
        speedChanges.humanoid=hum
    end
    if ST.wsEnabled==true then
        if speedChanges.walk==nil then speedChanges.walk=hum.WalkSpeed end
        hum.WalkSpeed=ST.wsValue
    elseif speedChanges.walk~=nil then
        hum.WalkSpeed=speedChanges.walk; speedChanges.walk=nil
    end
    if ST.jumpEnabled==true then
        if not speedChanges.jump then
            speedChanges.jump={power=hum.JumpPower,height=hum.JumpHeight,usePower=hum.UseJumpPower}
        end
        hum.UseJumpPower=true
        hum.JumpPower=ST.jumpValue
    elseif speedChanges.jump then
        hum.JumpPower=speedChanges.jump.power
        hum.JumpHeight=speedChanges.jump.height
        hum.UseJumpPower=speedChanges.jump.usePower
        speedChanges.jump=nil
    end
end

local SPEED_BIND = "ForumX_Speed"
local activeSpeedBind = nil

local function stopSpeedLoop()
    if activeSpeedBind then
        RunService:UnbindFromRenderStep(activeSpeedBind)
        activeSpeedBind = nil
    end
    ST.speedConn = nil
end

local function ensureSpeedLoop()
    if ST.wsEnabled~=true and ST.jumpEnabled~=true then return end
    if ST.speedConn then return end
    ST.speedConn = true

    local bindName = SPEED_BIND
    activeSpeedBind = bindName

    RunService:BindToRenderStep(bindName, Enum.RenderPriority.First.Value - 1, function()
        if not ST.wsEnabled and not ST.jumpEnabled then
            stopSpeedLoop()
            restoreSpeeds()
            ST.savedWS=nil; ST.savedJP=nil; ST.savedJH=nil; ST.savedUJP=nil
            return
        end
        applySpeedPhysics()
    end)
end

local FovGui = Instance.new("ScreenGui")
FovGui.Name="Aimbot FOV Overlay"
FovGui.Parent=cloneref(game:GetService("CoreGui"))
FovGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
FovGui.IgnoreGuiInset=true; FovGui.DisplayOrder=999; FovGui.ResetOnSpawn=false

local FovRing = Instance.new("Frame")
FovRing.Parent=FovGui; FovRing.AnchorPoint=Vector2.new(0.5,0.5)
FovRing.Position=UDim2.new(0.5,0,0.5,0); FovRing.BackgroundTransparency=1
FovRing.BorderSizePixel=0; FovRing.Size=UDim2.new(0,ST.aimbotFOV*2,0,ST.aimbotFOV*2); FovRing.Visible=false
uic(1000).Parent=FovRing

local FovStroke=Instance.new("UIStroke")
FovStroke.Thickness=2; FovStroke.Color=ST.aimbotFovColor
FovStroke.Transparency=0; FovStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; FovStroke.Parent=FovRing

local function refreshFOVRing()
    FovRing.Visible=(ST.aimbotEnabled and not ST.aimbotFovHidden)
    FovRing.Size=UDim2.new(0,ST.aimbotFOV*2,0,ST.aimbotFOV*2)
    FovStroke.Color=ST.aimbotFovColor
end

local ScreenGui=Instance.new("ScreenGui")
ScreenGui.Name="Forum X"; ScreenGui.Parent=cloneref(game:GetService("CoreGui"))
ScreenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
local menuTextObjects=setmetatable({},{__mode="k"})
local function applyMenuText(object)
    local color=object:GetAttribute("MenuHeading") and ST.menuColor or Color3.fromRGB(255,255,255)
    if object.TextColor3~=color then object.TextColor3=color end
    if object:IsA("TextBox") and object.PlaceholderColor3~=Color3.fromRGB(255,255,255) then
        object.PlaceholderColor3=Color3.fromRGB(255,255,255)
    end
end
local function styleMenuText(object)
    if not (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then return end
    menuTextObjects[object]=true
    applyMenuText(object)
    object:GetAttributeChangedSignal("MenuHeading"):Connect(function() applyMenuText(object) end)
    object:GetPropertyChangedSignal("TextColor3"):Connect(function() applyMenuText(object) end)
    if object:IsA("TextBox") then
        object:GetPropertyChangedSignal("PlaceholderColor3"):Connect(function() applyMenuText(object) end)
    end
end
ScreenGui.DescendantAdded:Connect(styleMenuText)
local function themeSurface(object)
    object.BackgroundColor3=Color3.fromRGB(0,0,0)
end
local function refreshMenuColor()
    for object in pairs(menuTextObjects) do
        if object.Parent then applyMenuText(object) end
    end
end

local MainFrame=Instance.new("Frame")
MainFrame.Parent=ScreenGui; themeSurface(MainFrame)
MainFrame.BackgroundTransparency=0; MainFrame.BorderSizePixel=0
MainFrame.Position=UDim2.new(0.18,0,0.12,0); MainFrame.Size=UDim2.new(0,MENU_W,0,MENU_H)
MainFrame.Active=true; MainFrame.ClipsDescendants=true
uic(12).Parent=MainFrame; uis(Color3.fromRGB(255,255,255),0.82,1).Parent=MainFrame

local openAimMode=nil
local function updateModeButtons() end

local TitleBar=Instance.new("Frame")
TitleBar.Parent=MainFrame; themeSurface(TitleBar)
TitleBar.BackgroundTransparency=0; TitleBar.BorderSizePixel=0
TitleBar.Size=UDim2.new(1,0,0,48); TitleBar.ZIndex=5
uic(12).Parent=TitleBar
do
    local badge=Instance.new("Frame"); badge.Name="TitleBadge"; badge.Parent=TitleBar
    badge.Position=UDim2.new(0,12,0,9); badge.Size=UDim2.new(0,SIDE_W-24,0,30)
    badge.BackgroundTransparency=1; badge.BorderSizePixel=0; badge.ZIndex=6
    local tl=Instance.new("TextLabel"); tl.Parent=badge; tl.BackgroundTransparency=1
    tl.Size=UDim2.new(1,0,1,0)
    tl.Font=Enum.Font.GothamMedium; tl.Text="Forum X"
    tl:SetAttribute("MenuHeading",true)
    tl.TextColor3=Color3.fromRGB(255,255,255); tl.TextSize=15
    tl.TextXAlignment=Enum.TextXAlignment.Center; tl.ZIndex=7
    local divider=Instance.new("Frame"); divider.Name="HeaderDivider"; divider.Parent=TitleBar
    divider.BackgroundColor3=Color3.fromRGB(255,255,255); divider.BackgroundTransparency=0.85
    divider.BorderSizePixel=0; divider.Position=UDim2.new(0,12,1,-1)
    divider.Size=UDim2.new(1,-24,0,1); divider.ZIndex=6
end

local function makeTitleBtn(xOff,bgCol,txt,ts)
    local b=Instance.new("TextButton"); b.Parent=TitleBar
    b.BackgroundColor3=bgCol; b.BackgroundTransparency=0.45; b.BorderSizePixel=0
    b.Position=UDim2.new(1,xOff,0,10); b.Size=UDim2.new(0,28,0,28)
    b.Font=Enum.Font.GothamBold; b.Text=txt; b.TextColor3=Color3.fromRGB(255,255,255)
    b.TextSize=ts; b.ZIndex=5
    uic(6).Parent=b; return b
end
local MinBtn=makeTitleBtn(-78,Color3.fromRGB(255,255,255),"-",18); MinBtn.BackgroundTransparency=0.88
local CloseBtn=makeTitleBtn(-42,Color3.fromRGB(255,70,70),"",14)
for _,rotation in ipairs({45,-45}) do
    local stroke=Instance.new("Frame"); stroke.Parent=CloseBtn
    stroke.AnchorPoint=Vector2.new(0.5,0.5); stroke.Position=UDim2.new(0.5,0,0.5,0)
    stroke.Size=UDim2.new(0,12,0,2); stroke.Rotation=rotation
    stroke.BackgroundColor3=Color3.fromRGB(255,255,255); stroke.BorderSizePixel=0; stroke.ZIndex=6
end

local BodyFrame=Instance.new("Frame")
BodyFrame.Parent=MainFrame; BodyFrame.BackgroundTransparency=1; BodyFrame.BorderSizePixel=0
BodyFrame.Position=UDim2.new(0,0,0,48); BodyFrame.Size=UDim2.new(1,0,1,-48)

local SideBar=Instance.new("Frame")
SideBar.Parent=BodyFrame; themeSurface(SideBar)
SideBar.BackgroundTransparency=1; SideBar.BorderSizePixel=0
SideBar.Position=UDim2.new(0,0,0,5); SideBar.Size=UDim2.new(0,SIDE_W,1,-10)

do
    local dv=Instance.new("Frame"); dv.Parent=BodyFrame
    dv.BackgroundColor3=Color3.fromRGB(255,255,255); dv.BackgroundTransparency=0.9
    dv.BorderSizePixel=0; dv.Position=UDim2.new(0,SIDE_W+4,0,5); dv.Size=UDim2.new(0,1,1,-10)
end

local ContentFrame=Instance.new("ScrollingFrame")
ContentFrame.Parent=BodyFrame; ContentFrame.BackgroundTransparency=1; ContentFrame.BorderSizePixel=0
ContentFrame.Position=UDim2.new(0,CONTENT_X,0,5); ContentFrame.Size=UDim2.new(1,-(CONTENT_X+8),1,-10)
ContentFrame.CanvasSize=UDim2.new(0,0,0,0); ContentFrame.ScrollBarThickness=6
ContentFrame.ScrollBarImageColor3=Color3.fromRGB(255,255,255)
ContentFrame.ScrollBarImageTransparency=0.2; ContentFrame.VerticalScrollBarInset=Enum.ScrollBarInset.ScrollBar; ContentFrame.ClipsDescendants=true
do local ll=Instance.new("UIListLayout"); ll.Padding=UDim.new(0,ROW_PAD); ll.SortOrder=Enum.SortOrder.LayoutOrder; ll.Parent=ContentFrame end

local dragging,dragStart,dragStartPos=false,nil,nil
TitleBar.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        dragging=true; dragStart=i.Position; dragStartPos=MainFrame.Position
    end
end)
dragMoveConn=UserInputService.InputChanged:Connect(function(i)
    if not dragging then return end
    if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
        local d=i.Position-dragStart
        MainFrame.Position=UDim2.new(dragStartPos.X.Scale,dragStartPos.X.Offset+d.X,dragStartPos.Y.Scale,dragStartPos.Y.Offset+d.Y)
    end
end)
dragEndConn=UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)

local function cancelKeybindCapture(revertText)
    if not waitKey then return end
    if keyBtn and revertText then keyBtn.Text = revertText end
    if keyBtn then TweenService:Create(keyBtn,TweenInfo.new(0.15),{BackgroundTransparency=0.82}):Play() end
    waitKey=false; keyTarget=nil; keyBtn=nil; keyOnSet=nil
    if keyTimeout then pcall(task.cancel,keyTimeout); keyTimeout=nil end
end

local function startKeybindCapture(target, btn, currentKb, onSet)
    if waitKey then cancelKeybindCapture(keybindLabel(currentKb)) end
    waitKey=true; keyTarget=target; keyBtn=btn; keyOnSet=onSet
    btn.Text="..."
    TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundTransparency=0.55}):Play()
    keyTimeout=task.delay(2,function()
        if not waitKey or keyTarget~=target then
            keyTimeout=nil
            return
        end
        local tgt,btn2,onSet2=keyTarget,keyBtn,keyOnSet
        waitKey=false; keyTarget=nil; keyBtn=nil; keyOnSet=nil
        if keyTimeout then pcall(task.cancel,keyTimeout); keyTimeout=nil end
        if onSet2 then onSet2(nil) end
        if btn2 then btn2.Text=keybindLabel(nil); TweenService:Create(btn2,TweenInfo.new(0.15),{BackgroundTransparency=0.82}):Play() end
    end)
end
local catBtns={}
local function createTabBtn(name,label,idx)
    local btn=Instance.new("TextButton"); btn.Parent=SideBar
    btn.BackgroundColor3=Color3.fromRGB(255,255,255); btn.BackgroundTransparency=1
    btn.BorderSizePixel=0; btn.Position=UDim2.new(0,8,0,10+(idx-1)*46)
    btn.Size=UDim2.new(1,-16,0,38); btn.Font=Enum.Font.GothamBold
    btn.Text=label; btn.TextColor3=Color3.fromRGB(180,180,200); btn.TextSize=13; btn.TextTransparency=0
    btn:SetAttribute("MenuHeading",true)
    uic(7).Parent=btn; catBtns[name]=btn; return btn
end

local function setActiveTab(name)
    for n,b in pairs(catBtns) do
        if n==name then
            TweenService:Create(b,TweenInfo.new(0.2),{BackgroundTransparency=0.85,TextTransparency=0,TextColor3=Color3.fromRGB(255,255,255)}):Play()
        else
            TweenService:Create(b,TweenInfo.new(0.2),{BackgroundTransparency=1,TextTransparency=0,TextColor3=Color3.fromRGB(180,180,200)}):Play()
        end
    end
end

local function clearSliders()
    for _,c in pairs(sliderConns) do c:Disconnect() end; sliderConns={}
end

local function closePicker()
    if activePicker then activePicker:Destroy(); activePicker=nil end
end

local function clearContent()
    openAimMode=nil
    cancelKeybindCapture(); clearSliders(); closePicker()
    for _,c in pairs(ST.plConns) do pcall(function() c:Disconnect() end) end; ST.plConns={}
    for _,ch in pairs(ContentFrame:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
    layoutCtr=0; contentH=0
end

local function finalize()
    ContentFrame.CanvasSize=UDim2.new(0,0,0,contentH+6)
end

local function createRow(h)
    h=h or ROW_H; layoutCtr+=1; contentH+=h+ROW_PAD
    local row=Instance.new("Frame"); row.Parent=ContentFrame
    row.BackgroundColor3=Color3.fromRGB(255,255,255); row.BackgroundTransparency=0.93
    row.BorderSizePixel=0; row.Size=UDim2.new(1,-6,0,h); row.LayoutOrder=layoutCtr
    uic(8).Parent=row; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=row; return row
end

local function mkLabel(parent,text,xOff,wid,sz,plain)
    local l=Instance.new("TextLabel"); l.Parent=parent; l.BackgroundTransparency=1
    l.Position=UDim2.new(0,xOff,0,0); l.Size=UDim2.new(0,wid,1,0)
    if not plain then l:SetAttribute("MenuHeading",true) end
    l.Font=Enum.Font.Gotham; l.Text=text; l.TextColor3=Color3.fromRGB(220,220,235)
    l.TextSize=sz or 11; l.TextXAlignment=Enum.TextXAlignment.Left
    l.TextTruncate=Enum.TextTruncate.None; l.TextWrapped=true
    local preferredSize=sz or 11
    local fitting=false
    local function fitText()
        if fitting or l.AbsoluteSize.X<=0 or l.AbsoluteSize.Y<=0 then return end
        fitting=true
        local bounds=l.AbsoluteSize
        local textService=game:GetService("TextService")
        local selected=preferredSize
        for size=preferredSize,8,-1 do
            local measured=textService:GetTextSize(l.Text,size,l.Font,Vector2.new(math.max(1,bounds.X-4),10000))
            selected=size
            if measured.X<=bounds.X and measured.Y<=bounds.Y-2 then break end
        end
        l.TextSize=selected
        fitting=false
    end
    l:GetPropertyChangedSignal("Text"):Connect(fitText)
    l:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitText)
    task.defer(fitText)
    return l
end

local function mkToggle(parent,state,cb)
    local sw=Instance.new("TextButton"); sw.Parent=parent; sw.Text=""; sw.AutoButtonColor=false
    sw.BackgroundColor3=Color3.fromRGB(255,255,255); sw.BackgroundTransparency=0.78
    sw.BorderSizePixel=0; sw.Position=UDim2.new(1,-54,0.5,-12); sw.Size=UDim2.new(0,44,0,24); sw.ClipsDescendants=true
    uic(1000).Parent=sw; uis(Color3.fromRGB(255,255,255),0.55,1).Parent=sw
    local fill=Instance.new("Frame"); fill.Parent=sw
    fill.BackgroundColor3=Color3.fromRGB(255,255,255); fill.BackgroundTransparency=0.5
    fill.BorderSizePixel=0; fill.Size=UDim2.new(0,0,1,0); fill.ZIndex=2; uic(1000).Parent=fill
    local knob=Instance.new("Frame"); knob.Parent=sw
    knob.BackgroundColor3=Color3.fromRGB(255,255,255); knob.BorderSizePixel=0
    knob.Size=UDim2.new(0,18,0,18); knob.Position=UDim2.new(0,3,0,3); knob.ZIndex=3; uic(1000).Parent=knob
    local function ref(s2)
        local ti=TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
        TweenService:Create(fill,ti,{Size=s2 and UDim2.new(1,0,1,0) or UDim2.new(0,0,1,0),BackgroundTransparency=s2 and 0.3 or 0.5}):Play()
        TweenService:Create(knob,ti,{Position=s2 and UDim2.new(1,-21,0,3) or UDim2.new(0,3,0,3)}):Play()
        TweenService:Create(sw,TweenInfo.new(0.18),{BackgroundTransparency=s2 and 0.6 or 0.78}):Play()
    end
    ref(state)
    sw.MouseButton1Click:Connect(function() state=not state; ref(state); cb(state) end)
    return sw
end

local function mkToggleAt(parent,xOff,state,cb)
    local sw=Instance.new("TextButton"); sw.Parent=parent; sw.Text=""; sw.AutoButtonColor=false
    sw.BackgroundColor3=Color3.fromRGB(255,255,255); sw.BackgroundTransparency=0.78
    sw.BorderSizePixel=0; sw.Position=UDim2.new(0,xOff,0.5,-12); sw.Size=UDim2.new(0,44,0,24); sw.ClipsDescendants=true
    uic(1000).Parent=sw; uis(Color3.fromRGB(255,255,255),0.55,1).Parent=sw
    local fill=Instance.new("Frame"); fill.Parent=sw; fill.BackgroundColor3=Color3.fromRGB(255,255,255); fill.BackgroundTransparency=0.5
    fill.BorderSizePixel=0; fill.Size=UDim2.new(0,0,1,0); fill.ZIndex=2; uic(1000).Parent=fill
    local knob=Instance.new("Frame"); knob.Parent=sw; knob.BackgroundColor3=Color3.fromRGB(255,255,255)
    knob.BorderSizePixel=0; knob.Size=UDim2.new(0,18,0,18); knob.Position=UDim2.new(0,3,0,3); knob.ZIndex=3; uic(1000).Parent=knob
    local function ref(s2)
        local ti=TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
        TweenService:Create(fill,ti,{Size=s2 and UDim2.new(1,0,1,0) or UDim2.new(0,0,1,0),BackgroundTransparency=s2 and 0.3 or 0.5}):Play()
        TweenService:Create(knob,ti,{Position=s2 and UDim2.new(1,-21,0,3) or UDim2.new(0,3,0,3)}):Play()
        TweenService:Create(sw,TweenInfo.new(0.18),{BackgroundTransparency=s2 and 0.6 or 0.78}):Play()
    end
    ref(state)
    sw.MouseButton1Click:Connect(function() state=not state; ref(state); cb(state) end)
    return sw
end

local activeContextMenu = nil
local function closeContextMenu()
    if activeContextMenu then activeContextMenu:Destroy(); activeContextMenu=nil end

end
local function mkKeybindBtn(parent,xOff,wid,kb,target,onSet)
    local btn=Instance.new("TextButton"); btn.Parent=parent
    btn.BackgroundColor3=Color3.fromRGB(255,255,255); btn.BackgroundTransparency=0.82
    btn.BorderSizePixel=0; btn.Position=UDim2.new(0,xOff,0.5,-12); btn.Size=UDim2.new(0,wid,0,24)
    btn.Font=Enum.Font.GothamBold; btn.Text=keybindLabel(kb)
    btn.TextColor3=Color3.fromRGB(255,255,255); btn.TextSize=10; btn.TextTruncate=Enum.TextTruncate.None; btn.TextScaled=true
    local textLimit=Instance.new("UITextSizeConstraint"); textLimit.MaxTextSize=10; textLimit.MinTextSize=6; textLimit.Parent=btn
    uic(6).Parent=btn; uis(Color3.fromRGB(255,255,255),0.6,1).Parent=btn
    local currentKb=kb
    
    btn.MouseButton1Click:Connect(function()
        closeContextMenu()
        if waitKey and keyTarget==target then cancelKeybindCapture(keybindLabel(currentKb)); return end
        startKeybindCapture(target,btn,currentKb,function(newKb) currentKb=newKb; btn.Text=keybindLabel(newKb); onSet(newKb) end)
    end)
    return btn
end


local function mkSlider(parent,trackX,trackW,minV,maxV,init,cb)
    local track=Instance.new("Frame"); track.Parent=parent
    track.BackgroundColor3=Color3.fromRGB(255,255,255); track.BackgroundTransparency=0.85
    track.BorderSizePixel=0; track.Position=UDim2.new(0,trackX,0.5,-2); track.Size=UDim2.new(0,trackW,0,6)
    uic(1000).Parent=track
    local fill=Instance.new("Frame"); fill.Parent=track
    fill.BackgroundColor3=Color3.fromRGB(255,255,255); fill.BorderSizePixel=0; fill.Size=UDim2.new(0,0,1,0)
    uic(1000).Parent=fill
    local function setV(v) fill.Size=UDim2.new(math.clamp((v-minV)/(maxV-minV),0,1),0,1,0) end
    local ds=false
    local function fromX(px)
        local rel=math.clamp((px-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1)
        fill.Size=UDim2.new(rel,0,1,0); cb(minV+(maxV-minV)*rel)
    end
    track.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then ds=true; fromX(i.Position.X) end
    end)
    table.insert(sliderConns,UserInputService.InputChanged:Connect(function(i)
        if ds and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then fromX(i.Position.X) end
    end))
    table.insert(sliderConns,UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then ds=false end
    end))
    setV(init); return setV
end

local function mkValLabel(parent,xOff,wid,init,minV,maxV,onCommit)
    local btn=Instance.new("TextButton"); btn.Parent=parent; btn.BackgroundTransparency=1
    btn.Position=UDim2.new(0,xOff,0.5,-11); btn.Size=UDim2.new(0,wid,0,22)
    btn.Font=Enum.Font.GothamBold; btn.Text=tostring(init)
    btn.TextColor3=Color3.fromRGB(255,255,255); btn.TextSize=12
    btn.TextXAlignment=Enum.TextXAlignment.Center; btn.AutoButtonColor=false
    local editing=false
    btn.MouseButton1Click:Connect(function()
        if editing then return end; editing=true
        local box=Instance.new("TextBox"); box.Parent=parent
        box.BackgroundColor3=Color3.fromRGB(20,20,28); box.BackgroundTransparency=0.1
        box.BorderSizePixel=0; box.Position=UDim2.new(0,xOff,0.5,-11); box.Size=UDim2.new(0,wid,0,22)
        box.Font=Enum.Font.GothamBold; box.TextSize=12
        box.TextColor3=Color3.fromRGB(255,255,255); box.Text=btn.Text
        box.ClearTextOnFocus=false; box.ZIndex=10; uic(5).Parent=box
        btn.TextTransparency=1; box:CaptureFocus()
        box.FocusLost:Connect(function(enter)
            if enter then
                local n=tonumber(box.Text)
                if n then n=math.clamp(math.floor(n+0.5),minV,maxV); btn.Text=tostring(onCommit(n)) end
            end
            box:Destroy(); btn.TextTransparency=0; editing=false
        end)
    end)
    return btn
end

local function openColorPicker(title,currentColor,onColor,reloadFn)
    closePicker(); cancelKeybindCapture(); clearSliders()
    local ov=Instance.new("Frame"); themeSurface(ov); ov.BackgroundTransparency=0.1
    ov.BorderSizePixel=0; ov.Position=UDim2.new(0,CONTENT_X,0,5)
    ov.Size=UDim2.new(1,-(CONTENT_X+8),1,-10); ov.ZIndex=30; ov.Parent=BodyFrame; activePicker=ov
    uic(8).Parent=ov
    do
        local hdr=Instance.new("TextLabel"); hdr.Parent=ov; hdr.BackgroundTransparency=1
        hdr.Position=UDim2.new(0,14,0,8); hdr.Size=UDim2.new(1,-80,0,24)
        hdr.Font=Enum.Font.GothamBold; hdr.Text=title
        hdr.TextColor3=Color3.fromRGB(140,160,255); hdr.TextSize=13; hdr.TextXAlignment=Enum.TextXAlignment.Left; hdr.ZIndex=31
    end
    local back=Instance.new("TextButton"); back.Parent=ov
    back.BackgroundColor3=Color3.fromRGB(255,255,255); back.BackgroundTransparency=0.85
    back.BorderSizePixel=0; back.Position=UDim2.new(1,-64,0,10); back.Size=UDim2.new(0,50,0,22)
    back.Font=Enum.Font.GothamBold; back.Text="Back"; back.TextColor3=Color3.fromRGB(255,255,255); back.TextSize=11; back.ZIndex=31
    uic(6).Parent=back
    local ph,ps,pv=rgbToHsv(currentColor.R,currentColor.G,currentColor.B)
    local svBase=Instance.new("TextButton"); svBase.Parent=ov; svBase.Text=""; svBase.AutoButtonColor=false
    svBase.BackgroundColor3=Color3.new(hsvToRgb(ph,1,1)); svBase.BorderSizePixel=0
    svBase.Position=UDim2.new(0,14,0,44); svBase.Size=UDim2.new(0,220,0,170); svBase.ZIndex=31
    uic(6).Parent=svBase
    do
        local svShade=Instance.new("Frame"); svShade.Parent=svBase
        svShade.BackgroundColor3=Color3.new(0,0,0); svShade.BorderSizePixel=0; svShade.Size=UDim2.new(1,0,1,0); svShade.ZIndex=32
        local shGrad=Instance.new("UIGradient"); shGrad.Rotation=90
        shGrad.Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0))
        shGrad.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}); shGrad.Parent=svShade
    end
    local svPtr=Instance.new("Frame"); svPtr.Parent=svBase
    svPtr.BackgroundColor3=Color3.new(1,1,1); svPtr.BorderSizePixel=0; svPtr.Size=UDim2.new(0,10,0,10); svPtr.ZIndex=33
    uic(1000).Parent=svPtr
    local hueBar=Instance.new("TextButton"); hueBar.Parent=ov; hueBar.Text=""; hueBar.AutoButtonColor=false
    hueBar.BorderSizePixel=0; hueBar.Position=UDim2.new(0,14,0,224); hueBar.Size=UDim2.new(0,220,0,14); hueBar.ZIndex=31
    uic(1000).Parent=hueBar
    do
        local hGrad=Instance.new("UIGradient")
        hGrad.Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(255,0,0)),ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255,255,0)),
            ColorSequenceKeypoint.new(0.33,Color3.fromRGB(0,255,0)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(0,255,255)),
            ColorSequenceKeypoint.new(0.67,Color3.fromRGB(0,0,255)),ColorSequenceKeypoint.new(0.83,Color3.fromRGB(255,0,255)),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(255,0,0)),
        }); hGrad.Parent=hueBar
    end
    local hPtr=Instance.new("Frame"); hPtr.Parent=hueBar
    hPtr.BackgroundColor3=Color3.new(1,1,1); hPtr.BorderSizePixel=0
    hPtr.Size=UDim2.new(0,4,1,4); hPtr.Position=UDim2.new(ph,-2,0,-2); hPtr.ZIndex=32; uic(1000).Parent=hPtr
    local prev=Instance.new("Frame"); prev.Parent=ov; prev.BackgroundColor3=currentColor
    prev.BorderSizePixel=0; prev.Position=UDim2.new(0,250,0,44); prev.Size=UDim2.new(0,80,0,80); prev.ZIndex=31; uic(8).Parent=prev
    local rgbLbl=Instance.new("TextLabel"); rgbLbl.Parent=ov; rgbLbl.BackgroundTransparency=1
    rgbLbl.Position=UDim2.new(0,250,0,132); rgbLbl.Size=UDim2.new(0,130,0,16)
    rgbLbl.Font=Enum.Font.GothamBold; rgbLbl.TextColor3=Color3.fromRGB(200,200,215); rgbLbl.TextSize=11
    rgbLbl.TextXAlignment=Enum.TextXAlignment.Left; rgbLbl.ZIndex=31
    local function applyPicker()
        local r2,g2,b2=hsvToRgb(ph,ps,pv); local c2=Color3.new(r2,g2,b2)
        svBase.BackgroundColor3=Color3.new(hsvToRgb(ph,1,1))
        svPtr.Position=UDim2.new(ps,-5,1-pv,-5); hPtr.Position=UDim2.new(ph,-2,0,-2)
        prev.BackgroundColor3=c2
        rgbLbl.Text=string.format("%d, %d, %d",math.floor(r2*255+.5),math.floor(g2*255+.5),math.floor(b2*255+.5))
        onColor(c2)
    end
    local svDrag=false
    svBase.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            svDrag=true
            ps=math.clamp((i.Position.X-svBase.AbsolutePosition.X)/math.max(svBase.AbsoluteSize.X,1),0,1)
            pv=1-math.clamp((i.Position.Y-svBase.AbsolutePosition.Y)/math.max(svBase.AbsoluteSize.Y,1),0,1)
            applyPicker()
        end
    end)
    table.insert(sliderConns,UserInputService.InputChanged:Connect(function(i)
        if svDrag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            ps=math.clamp((i.Position.X-svBase.AbsolutePosition.X)/math.max(svBase.AbsoluteSize.X,1),0,1)
            pv=1-math.clamp((i.Position.Y-svBase.AbsolutePosition.Y)/math.max(svBase.AbsoluteSize.Y,1),0,1)
            applyPicker()
        end
    end))
    table.insert(sliderConns,UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then svDrag=false end
    end))
    local hueDrag=false
    hueBar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            hueDrag=true
            ph=math.clamp((i.Position.X-hueBar.AbsolutePosition.X)/math.max(hueBar.AbsoluteSize.X,1),0,0.999)
            applyPicker()
        end
    end)
    table.insert(sliderConns,UserInputService.InputChanged:Connect(function(i)
        if hueDrag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            ph=math.clamp((i.Position.X-hueBar.AbsolutePosition.X)/math.max(hueBar.AbsoluteSize.X,1),0,0.999)
            applyPicker()
        end
    end))
    table.insert(sliderConns,UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then hueDrag=false end
    end))
    applyPicker()
    back.MouseButton1Click:Connect(function() closePicker(); reloadFn() end)
end

local function mkHpModeIcon(parent,xOff)
    local btn=Instance.new("TextButton"); btn.Parent=parent
    btn.BackgroundTransparency=1; btn.Text=""; btn.AutoButtonColor=false
    btn.Position=UDim2.new(0,xOff,0.5,-13); btn.Size=UDim2.new(0,30,0,26)
    local body=Instance.new("Frame"); body.Parent=btn
    body.BackgroundColor3=Color3.fromRGB(255,255,255); body.BackgroundTransparency=0.88
    body.BorderSizePixel=0; body.Position=UDim2.new(0,7,0,4); body.Size=UDim2.new(0,16,0,18)
    uic(3).Parent=body; uis(Color3.fromRGB(255,255,255),0.5,1).Parent=body
    local bar=Instance.new("Frame"); bar.Parent=btn; bar.BorderSizePixel=0; uic(1).Parent=bar
    local function refresh(mode,col)
        if mode=="left" then bar.Size=UDim2.new(0,3,0,18); bar.Position=UDim2.new(0,4,0,4)
        else bar.Size=UDim2.new(0,16,0,3); bar.Position=UDim2.new(0,7,0,1) end
        bar.BackgroundColor3=col
    end
    return btn, refresh
end

local function mkChamsModeIcon(parent,xOff)
    local btn=Instance.new("TextButton"); btn.Parent=parent
    btn.BackgroundTransparency=1; btn.Text=""; btn.AutoButtonColor=false
    btn.Position=UDim2.new(0,xOff,0.5,-13); btn.Size=UDim2.new(0,30,0,26)
    local sq=Instance.new("Frame"); sq.Parent=btn; sq.BorderSizePixel=0
    sq.Position=UDim2.new(0,7,0,5); sq.Size=UDim2.new(0,16,0,16); uic(4).Parent=sq
    local stroke=uis(Color3.fromRGB(255,255,255),0,1.5); stroke.Parent=sq
    local function refresh(mode,col)
        stroke.Color=col
        if mode=="outline" then sq.BackgroundTransparency=1; stroke.Thickness=2; stroke.Transparency=0
        else sq.BackgroundColor3=col; sq.BackgroundTransparency=0.2; stroke.Thickness=1; stroke.Transparency=0.3 end
    end
    return btn, refresh
end

local function enableNoclip()
    for _,c in pairs(ST.noclipConns) do c:Disconnect() end
    ST.noclipConns={}
    local char=LocalPlayer.Character; if not char then return end
    local root=char:FindFirstChild("HumanoidRootPart"); if not root then return end
    ST.noclipEnabled=true
    ST.currentPos=root.Position
    local c1=RunService.Stepped:Connect(function()
        local ch=LocalPlayer.Character; if not ch then return end
        for _,p in pairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide=false end
        end
    end)
    local c2=RunService.Heartbeat:Connect(function(dt)
        local ch=LocalPlayer.Character; if not ch then return end
        local r=ch:FindFirstChild("HumanoidRootPart"); if not r then return end
        local cam=workspace.CurrentCamera.CFrame
        local mv=Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv-cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv-cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv=mv+Vector3.new(0,1,0) end
        if mv.Magnitude>0.001 then mv=mv.Unit end
        ST.currentPos=ST.currentPos+mv*(ST.noclipSpeed*dt)
        r.AssemblyLinearVelocity=Vector3.new()
        r.AssemblyAngularVelocity=Vector3.new()
        local look=Vector3.new(cam.LookVector.X,0,cam.LookVector.Z)
        if look.Magnitude<0.001 then look=Vector3.new(0,0,-1) end
        r.CFrame=CFrame.new(ST.currentPos)*CFrame.Angles(0,math.atan2(-look.X,-look.Z),0)
    end)
    ST.noclipConns={c1,c2}
end

local function disableNoclip()
    ST.noclipEnabled=false
    for _,c in pairs(ST.noclipConns) do c:Disconnect() end
    ST.noclipConns={}
    local char=LocalPlayer.Character; if not char then return end
    for _,p in pairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide=true end
    end
    local r=char:FindFirstChild("HumanoidRootPart")
    if r then r.AssemblyLinearVelocity=Vector3.new(); r.AssemblyAngularVelocity=Vector3.new() end
end

local function toggleNoclip()
    if ST.noclipEnabled then disableNoclip() else enableNoclip() end
end

local function doCFTP()
    local ch=LocalPlayer.Character; if not ch then return end
    local r=ch:FindFirstChild("HumanoidRootPart"); if not r then return end
    local hum=ch:FindFirstChildOfClass("Humanoid")
    local moveDir=hum and hum.MoveDirection or Vector3.new()
    local tpDir
    if moveDir.Magnitude>0.1 then tpDir=moveDir else
        local cam=workspace.CurrentCamera.CFrame
        tpDir=Vector3.new(cam.LookVector.X,0,cam.LookVector.Z)
    end
    tpDir=tpDir.Unit; local newPos=r.Position+tpDir*ST.cfTpDist
    r.CFrame=CFrame.new(newPos)*(r.CFrame-r.Position)
    if ST.noclipEnabled then ST.currentPos=newPos end
end

local function startCFTPLoop()
    if ST.cfTpLoop then return end
    ST.cfTpLoop = true
    ST.cfTpConn = RunService.Heartbeat:Connect(function()
        if ST.cfTpLoop then
            doCFTP()
        else
            if ST.cfTpConn then ST.cfTpConn:Disconnect(); ST.cfTpConn = nil end
        end
    end)
end

local function stopCFTPLoop()
    ST.cfTpLoop = false
    if ST.cfTpConn then
        ST.cfTpConn:Disconnect()
        ST.cfTpConn = nil
    end
end

local function enablePromptBypass()
    ST.promptBypass=true
    local function proc(i)
        if i:IsA("ProximityPrompt") then
            if ST.savedDur[i]==nil then ST.savedDur[i]=i.HoldDuration end; i.HoldDuration=0
        end
    end
    for _,d in pairs(workspace:GetDescendants()) do proc(d) end
    ST.promptConn=workspace.DescendantAdded:Connect(proc)
end

local function disablePromptBypass()
    ST.promptBypass=false
    if ST.promptConn then ST.promptConn:Disconnect(); ST.promptConn=nil end
    for p,d in pairs(ST.savedDur) do if p and p.Parent then p.HoldDuration=d end end
    ST.savedDur={}
end

local function applyPR(i)
    if i:IsA("ProximityPrompt") then
        if ST.savedPR[i]==nil then ST.savedPR[i]=i.MaxActivationDistance end
        i.MaxActivationDistance=math.max(i.MaxActivationDistance,ST.promptRangeVal)
    end
end

local function enablePR()
    ST.promptRange=true; ST.savedPR={}
    for _,d in pairs(workspace:GetDescendants()) do applyPR(d) end
    ST.promptRangeConn=workspace.DescendantAdded:Connect(applyPR)
end

local function disablePR()
    ST.promptRange=false
    if ST.promptRangeConn then ST.promptRangeConn:Disconnect(); ST.promptRangeConn=nil end
    for p,d in pairs(ST.savedPR) do if p and p.Parent then p.MaxActivationDistance=d end end
    ST.savedPR={}
end

local function enableAntiAfk()
    ST.antiAfk=true
    ST.antiAfkConn=LocalPlayer.Idled:Connect(function()
        pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
    end)
end

local function disableAntiAfk()
    ST.antiAfk=false
    if ST.antiAfkConn then ST.antiAfkConn:Disconnect(); ST.antiAfkConn=nil end
end

local function SkidFling(TP,isActiveFn)
    local Ch=LocalPlayer.Character; local Hum=Ch and Ch:FindFirstChildOfClass("Humanoid")
    local RP2=Hum and Hum.RootPart; local TC=TP.Character; if not TC then return end
    local TH=TC:FindFirstChildOfClass("Humanoid"); local TRP=TH and TH.RootPart
    local THead=TC:FindFirstChild("Head"); local Acc=TC:FindFirstChildOfClass("Accessory")
    local Hdl=Acc and Acc:FindFirstChild("Handle")
    if not (Ch and Hum and RP2) then return end
    if RP2.Velocity.Magnitude<50 then getgenv().OldPos=RP2.CFrame end
    if TH and TH.Sit then return end
    if THead then workspace.CurrentCamera.CameraSubject=THead
    elseif Hdl then workspace.CurrentCamera.CameraSubject=Hdl
    elseif TH and TRP then workspace.CurrentCamera.CameraSubject=TH end
    if not TC:FindFirstChildWhichIsA("BasePart") then return end
    local function FPos(BP,Pos,Ang)
        RP2.CFrame=CFrame.new(BP.Position)*Pos*Ang
        Ch:SetPrimaryPartCFrame(CFrame.new(BP.Position)*Pos*Ang)
        RP2.Velocity=Vector3.new(9e7,9e7*10,9e7)
        RP2.RotVelocity=Vector3.new(9e8,9e8,9e8)
    end
    local function SFB(BP)
        local T2=tick(); local Ang=0
        repeat
            if RP2 and TH then
                if BP.Velocity.Magnitude<50 then
                    Ang+=100
                    FPos(BP,CFrame.new(0,1.5,0)+TH.MoveDirection*BP.Velocity.Magnitude/1.25,CFrame.Angles(math.rad(Ang),0,0)); task.wait()
                    FPos(BP,CFrame.new(0,-1.5,0)+TH.MoveDirection*BP.Velocity.Magnitude/1.25,CFrame.Angles(math.rad(Ang),0,0)); task.wait()
                else
                    FPos(BP,CFrame.new(0,1.5,TH.WalkSpeed),CFrame.Angles(math.rad(90),0,0)); task.wait()
                    FPos(BP,CFrame.new(0,-1.5,-TH.WalkSpeed),CFrame.Angles(0,0,0)); task.wait()
                end
            end
        until T2+2<tick() or not isActiveFn()
    end
    workspace.FallenPartsDestroyHeight=0/0
    local BV=Instance.new("BodyVelocity"); BV.Parent=RP2; BV.Velocity=Vector3.new(); BV.MaxForce=Vector3.new(9e9,9e9,9e9)
    Hum:SetStateEnabled(Enum.HumanoidStateType.Seated,false)
    if TRP then SFB(TRP) elseif THead then SFB(THead) elseif Hdl then SFB(Hdl) end
    BV:Destroy(); Hum:SetStateEnabled(Enum.HumanoidStateType.Seated,true); workspace.CurrentCamera.CameraSubject=Hum
    if getgenv().OldPos then
        local oldCF=getgenv().OldPos
        RP2.CFrame=oldCF*CFrame.new(0,3,0); Ch:SetPrimaryPartCFrame(oldCF*CFrame.new(0,3,0))
        RP2.AssemblyLinearVelocity=Vector3.new(); RP2.AssemblyAngularVelocity=Vector3.new(); task.wait(0.05)
        local timeout=tick()+4
        repeat
            if not RP2 or not RP2.Parent or not Ch or not Ch.Parent then break end
            RP2.CFrame=oldCF*CFrame.new(0,0.5,0); Ch:SetPrimaryPartCFrame(oldCF*CFrame.new(0,0.5,0))
            RP2.AssemblyLinearVelocity=Vector3.new(); RP2.AssemblyAngularVelocity=Vector3.new()
            Hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            for _,p in pairs(Ch:GetChildren()) do if p:IsA("BasePart") then p.Velocity=Vector3.new(); p.RotVelocity=Vector3.new() end end
            task.wait(0.05)
        until (RP2.Position-oldCF.p).Magnitude<8 or tick()>timeout
        workspace.FallenPartsDestroyHeight=getgenv().FPDH
    end
end

local function getNearestPlayer()
    local ch=LocalPlayer.Character; local r=ch and ch:FindFirstChild("HumanoidRootPart"); if not r then return nil end
    local best,bestD=nil,math.huge
    for _,plr in pairs(Players:GetPlayers()) do
        if plr~=LocalPlayer and plr.Character then
            local pr=findRoot(plr.Character)
            if pr then
                local ok,d=pcall(function() return (pr.Position-r.Position).Magnitude end)
                if ok and d<bestD then bestD=d; best=plr end
            end
        end
    end
    return best
end

local function NearFlingTick(tp)
    local ch=LocalPlayer.Character; local hrp=ch and ch:FindFirstChild("HumanoidRootPart")
    if not hrp or not tp.Character then return end
    pcall(function()
        local vel=hrp.Velocity; hrp.Velocity=vel*1000000+Vector3.new(0,1000000,0)
        RunService.RenderStepped:Wait()
        if hrp and hrp.Parent then hrp.Velocity=vel end
        RunService.Stepped:Wait()
        if hrp and hrp.Parent then hrp.Velocity=vel+Vector3.new(0,0.1,0) end
    end)
end

local function enableNearFling()
    if ST.nearFlingActive then return end
    ST.nearFling=true; ST.nearFlingActive=true
    ST.nearFlingConn=RunService.Heartbeat:Connect(function()
        if not ST.nearFlingActive then return end
        local t=getNearestPlayer(); if t then NearFlingTick(t) end
    end)
end

local function disableNearFling()
    ST.nearFling=false; ST.nearFlingActive=false
    if ST.nearFlingConn then ST.nearFlingConn:Disconnect(); ST.nearFlingConn=nil end
end

local function toggleNearFling()
    if ST.nearFling then disableNearFling() else enableNearFling() end
end

local function enableCameraFOV()
    ST.cameraFOV=true
    local cam=workspace.CurrentCamera
    if cam then
        if ST.origFOV==nil then
            ST.origFOV=cam.FieldOfView
        end
        cam.FieldOfView=ST.cameraFOVValue
    end
end

local function disableCameraFOV()
    ST.cameraFOV=false
    local cam=workspace.CurrentCamera
    if cam and ST.origFOV then
        cam.FieldOfView=ST.origFOV
        ST.origFOV=nil
    end
end

local function v1Loop()
    if ST.v1Running then return end
    ST.v1Running=true
    task.spawn(function()
        while true do
            local snapshot={}
            for name,plr in pairs(ST.v1Targets) do table.insert(snapshot,{name=name,plr=plr}) end
            if #snapshot==0 then break end
            for _,item in ipairs(snapshot) do
                local name,plr=item.name,item.plr
                if ST.v1Targets[name] and plr and plr.Parent then
                    SkidFling(plr,function() return ST.v1Targets[name]~=nil end)
                else ST.v1Targets[name]=nil end
                task.wait(0.1)
            end
            task.wait(0.3)
        end
        ST.v1Running=false
    end)
end

local function toggleV1(plr,btn)
    if ST.v1Targets[plr.Name] then ST.v1Targets[plr.Name]=nil; btn.Text="V1 Fling"; btn.BackgroundTransparency=0.82
    else ST.v1Targets[plr.Name]=plr; btn.Text="V1 +"; btn.BackgroundTransparency=0.5; v1Loop() end
end

local function stopSpectate()
    if not ST.spectating then return end
    ST.spectating=nil
    if ST.specConn then ST.specConn:Disconnect(); ST.specConn=nil end
    task.spawn(function()
        pcall(function()
            local cam=workspace.CurrentCamera
            cam.CameraType=Enum.CameraType.Custom
            local myChar=LocalPlayer.Character
            if myChar then
                local myHum=myChar:FindFirstChildOfClass("Humanoid")
                if myHum then cam.CameraSubject=myHum end
            end
        end)
    end)
    if ST.activeSpecBtn then
        pcall(function() ST.activeSpecBtn.Text="Spectate"; ST.activeSpecBtn.BackgroundTransparency=0.82 end)
        ST.activeSpecBtn=nil
    end
end

local function startSpectate(tp)
    local ch=tp.Character; if not ch then return false end
    if not ST.spectating then
        ST.origCamType=workspace.CurrentCamera.CameraType
        ST.origCamSubject=workspace.CurrentCamera.CameraSubject
    end
    ST.spectating=tp
    pcall(function()
        local cam=workspace.CurrentCamera
        cam.CameraType=Enum.CameraType.Custom
        local hum=ch:FindFirstChildOfClass("Humanoid")
        local subject=hum or findRoot(ch)
        if subject then cam.CameraSubject=subject end
    end)
    if ST.specConn then ST.specConn:Disconnect() end
    ST.specConn=RunService.Heartbeat:Connect(function()
        if ST.spectating~=tp then return end
        pcall(function()
            local pch=tp.Character; if not pch then return end
            local cam=workspace.CurrentCamera
            if cam.CameraType~=Enum.CameraType.Custom then cam.CameraType=Enum.CameraType.Custom end
            local hum=pch:FindFirstChildOfClass("Humanoid")
            local subject=hum or findRoot(pch)
            if subject and cam.CameraSubject~=subject then cam.CameraSubject=subject end
        end)
    end)
    return true
end

local function toggleSpectate(tp,btn)
    if ST.spectating==tp then
        stopSpectate(); btn.Text="Spectate"; btn.BackgroundTransparency=0.82
    else
        if ST.activeSpecBtn and ST.activeSpecBtn~=btn then
            pcall(function() ST.activeSpecBtn.Text="Spectate"; ST.activeSpecBtn.BackgroundTransparency=0.82 end)
        end
        ST.spectating=nil
        if ST.specConn then ST.specConn:Disconnect(); ST.specConn=nil end
        local ok=startSpectate(tp)
        if ok then btn.Text="Spec +"; btn.BackgroundTransparency=0.5; ST.activeSpecBtn=btn end
    end
end

local function tpToPlayer(tp)
    local ch=LocalPlayer.Character; local r=ch and ch:FindFirstChild("HumanoidRootPart")
    local tr=tp.Character and findRoot(tp.Character); if not r or not tr then return end
    pcall(function()
        local hum=ch:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
        local cf=CFrame.new(tr.Position+Vector3.new((math.random()-.5)*4,3,(math.random()-.5)*4))
        r.CFrame=cf
        if ST.noclipEnabled then ST.currentPos=cf.Position end
        for _,p in pairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then p.Velocity=Vector3.new(); p.RotVelocity=Vector3.new() end
        end
    end)
end

Players.PlayerRemoving:Connect(function(plr)
    ST.v1Targets[plr.Name]=nil
    if ST.spectating==plr then stopSpectate() end
end)

local function aimbotIsVisible(part)
    if not ST.aimbotWallCheck then return true end
    local ch=LocalPlayer.Character; if not ch or not part then return false end
    local cam=workspace.CurrentCamera
    local origin=cam.CFrame.Position
    local dir=part.Position-origin
    if dir.Magnitude<0.001 then return true end
    local params=RaycastParams.new()
    params.FilterDescendantsInstances={ch}
    params.FilterType=Enum.RaycastFilterType.Exclude
    local result=workspace:Raycast(origin,dir.Unit*math.min(dir.Magnitude,2000),params)
    if not result then return true end
    return result.Instance and result.Instance:IsDescendantOf(part.Parent)
end

local function aimbotGetTarget()
    local cam=workspace.CurrentCamera
    local vpSize=cam.ViewportSize
    local center=Vector2.new(vpSize.X/2,vpSize.Y/2)
    local bestDist=ST.aimbotFOV
    local bestPart=nil
    for _,plr in pairs(Players:GetPlayers()) do
        if plr==LocalPlayer then continue end
        if ST.aimbotTeamCheck and isSameTeam(LocalPlayer,plr) then continue end
        if ST.whitelistPlayers[plr.Name] then continue end
        if plr.Team and ST.whitelistTeams[plr.Team.Name] then continue end
        local ch=plr.Character
        if not ch or not ch.Parent then continue end
        local part=nil
        if ST.aimbotTargetPart~="" then part=ch:FindFirstChild(ST.aimbotTargetPart) end
        if not part then part=ch:FindFirstChild("Head") end
        if not part then part=ch:FindFirstChild("HumanoidRootPart") end
        if not part then part=findRoot(ch) end
        if not part then continue end
        local ok,pos,onScreen=pcall(function() return cam:WorldToViewportPoint(part.Position) end)
        if not ok or not onScreen or pos.Z<=0 then continue end
        local screenPos=Vector2.new(pos.X,pos.Y)
        local dist=(screenPos-center).Magnitude
        if dist<bestDist then
            if aimbotIsVisible(part) then bestDist=dist; bestPart=part end
        end
    end
    return bestPart
end

local function startAimbotLoop()
    if ST.aimbotConn then return end
    ST.aimbotConn=RunService.RenderStepped:Connect(function(dt)
        pcall(function()
            refreshFOVRing()
            if not ST.aimbotEnabled or not ST.aimbotActive then aimbotLastTarget=nil; return end
            local ch=LocalPlayer.Character; if not ch then return end
            
            local part=aimbotLastTarget
            if not part or not part.Parent then
                part=aimbotGetTarget()
                if not part then aimbotLastTarget=nil; return end
                aimbotLastTarget=part
            end
            
            local cam=workspace.CurrentCamera
            
            if ST.aimbotMethod=="Camera" then
                local targetPos=part.Position
                local camPos=cam.CFrame.Position
                local newLook=(targetPos-camPos).Unit
                local smooth=ST.aimbotSmooth
                if smooth<=0 then
                    cam.CFrame=CFrame.new(camPos,targetPos)
                else
                    local frameAlpha=1-(1-smooth)^(dt*60)
                    local currentLook=cam.CFrame.LookVector
                    local smoothedLook=currentLook:Lerp(newLook,frameAlpha)
                    cam.CFrame=CFrame.new(camPos,camPos+smoothedLook)
                end
                aimbotLastTarget=part
            else
                local vpSize=cam.ViewportSize
                local center=Vector2.new(vpSize.X/2,vpSize.Y/2)
                local ok,pos,onScreen=pcall(function() return cam:WorldToViewportPoint(part.Position) end)
                if not ok or not onScreen or pos.Z<=0 then return end
                local targetScreen=Vector2.new(pos.X,pos.Y)
                local delta=targetScreen-center
                if delta.Magnitude<0.3 then aimbotLastTarget=part; return end
                local smooth=ST.aimbotSmooth
                local moveX,moveY
                if smooth<=0 then moveX=delta.X; moveY=delta.Y
                else
                    local frameAlpha=1-(1-smooth)^(dt*60)
                    moveX=delta.X*frameAlpha; moveY=delta.Y*frameAlpha
                end
                pcall(mousemoverel,moveX,moveY)
                aimbotLastTarget=part
            end
        end)
    end)
end

local function stopAimbotLoop()
    if ST.aimbotConn then ST.aimbotConn:Disconnect(); ST.aimbotConn=nil end
    aimbotLastTarget=nil
end

local function enableAimbot()
    ST.aimbotEnabled=true; startAimbotLoop(); refreshFOVRing()
end

local function disableAimbot()
    ST.aimbotEnabled=false; ST.aimbotActive=false; stopAimbotLoop(); FovRing.Visible=false
end

local function aimbotKeyPressed(input)
    if not ST.aimbotEnabled then return end
    if keybindMatches(ST.aimbotKey,input) then
        if ST.aimbotMode=="Hold" then
            aimbotLastTarget=nil
            ST.aimbotActive=true
        elseif ST.aimbotMode=="Toggle" then
            if ST.aimbotActive then aimbotLastTarget=nil end
            ST.aimbotActive=not ST.aimbotActive
        end
    end
end


local function aimbotKeyReleased(input)
    if not ST.aimbotEnabled or ST.aimbotMode~="Hold" then return end
    if keybindMatches(ST.aimbotKey,input) then aimbotLastTarget=nil; ST.aimbotActive=false end
end

local playerChams={entries={},connection=nil,lastWarning=0,folder=nil}
function playerChams.drop(player)
    local entry=playerChams.entries[player]
    if not entry then return end
    if entry.highlight then entry.highlight:Destroy() end
    if entry.model then entry.model:Destroy() end
    playerChams.entries[player]=nil
end
function playerChams.clear()
    if playerChams.connection then playerChams.connection:Disconnect(); playerChams.connection=nil end
    for player in pairs(playerChams.entries) do playerChams.drop(player) end
    if playerChams.folder then playerChams.folder:Destroy(); playerChams.folder=nil end
end
function playerChams.copyPart(part)
    local copy=part:Clone()
    assert(copy,"Cannot copy non-archivable part: "..part.Name)
    for _,child in ipairs(copy:GetDescendants()) do
        if child.Parent and not child:IsA("DataModelMesh") and not child:IsA("Bone") then child:Destroy() end
    end
    copy.Anchored=true; copy.CanCollide=false; copy.CanTouch=false; copy.CanQuery=false
    copy.CastShadow=false; copy.LocalTransparencyModifier=0; copy.Transparency=0.99
    copy.Material=Enum.Material.SmoothPlastic; copy.Reflectance=0
    copy.CFrame=part.CFrame; copy.Size=part.Size
    return copy
end
function playerChams.scan(entry)
    local seen={}
    for _,part in ipairs(entry.character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name~="HumanoidRootPart" and not part:FindFirstAncestorOfClass("Tool") then
            local body=part.Parent==entry.character and part.Name~="Hitbox" and part.Name~="RootPart"
            if part.Transparency<1 or body then
                seen[part]=true
                if not entry.parts[part] or not entry.parts[part].Parent then
                    local ok,copy=pcall(playerChams.copyPart,part)
                    if ok then copy.Parent=entry.model; entry.parts[part]=copy
                    elseif os.clock()-playerChams.lastWarning>5 then
                        playerChams.lastWarning=os.clock(); warn("[Forum X Chams] "..tostring(copy))
                    end
                end
            end
        end
    end
    for original,copy in pairs(entry.parts) do
        if not seen[original] then copy:Destroy(); entry.parts[original]=nil end
    end
end
function playerChams.allowed(player,character)
    local own=findRoot(LocalPlayer.Character)
    local root=findRoot(character)
    if not own or not root or (root.Position-own.Position).Magnitude>ST.espMax then return false end
    return true
end
function playerChams.color(player)
    if ST.whitelistPlayers[player.Name] or (player.Team and ST.whitelistTeams[player.Team.Name]) then
        return ST.chamsWhitelistCol
    end
    if isSameTeam(LocalPlayer,player) then return ST.chamsTeamCol end
    return ST.chamsMode=="outline" and ST.chamsCol2 or ST.chamsCol
end
function playerChams.sync()
    if not S.chams then playerChams.clear(); return end
    if not playerChams.folder or not playerChams.folder.Parent then
        playerChams.folder=Instance.new("Folder")
        playerChams.folder.Name="ForumX_ChamsRender"
        playerChams.folder.Parent=workspace
    end
    local seen={}
    for _,player in ipairs(Players:GetPlayers()) do
        if player~=LocalPlayer then
            seen[player]=true
            local ok,err=pcall(function()
                local character=player.Character
                local entry=playerChams.entries[player]
                if entry and (entry.character~=character or not character or not character.Parent or not entry.model.Parent or not entry.highlight.Parent) then
                    playerChams.drop(player); entry=nil
                end
                if not character or not character.Parent then return end
                if not playerChams.allowed(player,character) then playerChams.drop(player); return end
                if not entry then
                    local model=Instance.new("Model"); model.Name="FX_Render_"..player.UserId
                    model:SetAttribute("ForumXChamsProxy",true)
                    local humanoid=Instance.new("Humanoid")
                    humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
                    humanoid.BreakJointsOnDeath=false; humanoid.RequiresNeck=false
                    humanoid.PlatformStand=true; humanoid.AutoRotate=false; humanoid.Parent=model
                    local highlight=Instance.new("Highlight"); highlight.Name="FX_PlayerChams"
                    highlight.Adornee=model; highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.Parent=model
                    model.Parent=playerChams.folder
                    entry={character=character,model=model,highlight=highlight,parts={}}
                    playerChams.entries[player]=entry
                end
                playerChams.scan(entry)
                local h=entry.highlight
                local outline=ST.chamsMode=="outline"
                h.FillColor=playerChams.color(player)
                h.OutlineColor=h.FillColor; h.FillTransparency=outline and 1 or 0.5
                h.OutlineTransparency=0; h.Enabled=true
            end)
            if not ok and os.clock()-playerChams.lastWarning>5 then
                playerChams.lastWarning=os.clock(); warn("[Forum X Chams] "..player.Name..": "..tostring(err))
            end
        end
    end
    for player in pairs(playerChams.entries) do if not seen[player] then playerChams.drop(player) end end
end
function playerChams.start()
    playerChams.sync()
    if not S.chams or playerChams.connection then return end
    local elapsed=0
    playerChams.connection=RunService.RenderStepped:Connect(function(dt)
        if not S.chams or not G.ForumX_Running then playerChams.clear(); return end
        elapsed+=dt
        if elapsed>=0.5 then elapsed=0; playerChams.sync() end
        for player,entry in pairs(playerChams.entries) do
            if not playerChams.allowed(player,entry.character) then
                playerChams.drop(player)
                continue
            end
            for original,copy in pairs(entry.parts) do
                if original.Parent and copy.Parent then
                    copy.CFrame=original.CFrame; copy.Size=original.Size
                    for _,bone in ipairs(original:GetDescendants()) do
                        if bone:IsA("Bone") then
                            local mirrored=copy:FindFirstChild(bone.Name,true)
                            if mirrored and mirrored:IsA("Bone") then mirrored.Transform=bone.Transform end
                        end
                    end
                end
            end
        end
    end)
end

local function buildESP(ch,isNPC)
    if not ch or not ch.Parent then return nil end
    for _,e in pairs(ST.espEntries) do if e.ch==ch then return nil end end
    local hum=findHuman(ch)
    local r=findRoot(ch)
    if not r then return nil end
    local oldHolder=ch:FindFirstChild(FOLDER)
    if oldHolder then oldHolder:Destroy() end
    local holder=Instance.new("Folder"); holder.Name=FOLDER; holder.Parent=ch
    local bb=Instance.new("BillboardGui")
    bb.AlwaysOnTop=true; bb.Size=UDim2.new(0,120,0,40); bb.StudsOffset=Vector3.new(0,3.5,0)
    bb.Adornee=r; bb.Enabled=false; bb.ResetOnSpawn=false; bb.ClipsDescendants=false; bb.Parent=holder
    local nameLabel=Instance.new("TextLabel")
    nameLabel.BackgroundTransparency=1; nameLabel.Size=UDim2.new(1,0,0,14); nameLabel.Position=UDim2.new(0,0,0,0)
    nameLabel.Font=Enum.Font.GothamBold; nameLabel.TextSize=11; nameLabel.TextStrokeTransparency=0.2
    nameLabel.TextStrokeColor3=Color3.new(0,0,0); nameLabel.Text=""; nameLabel.Parent=bb
    nameLabel.AnchorPoint=Vector2.new(0.5,0)
    nameLabel.Position=UDim2.new(0.5,0,0,0)
    local nameScale=Instance.new("UIScale"); nameScale.Parent=nameLabel
    local teamLabel=Instance.new("TextLabel")
    teamLabel.BackgroundTransparency=1; teamLabel.Size=UDim2.new(1,0,0,11); teamLabel.Position=UDim2.new(0,0,0,14)
    teamLabel.Font=Enum.Font.Gotham; teamLabel.TextSize=10; teamLabel.TextStrokeTransparency=0.3
    teamLabel.TextStrokeColor3=Color3.new(0,0,0); teamLabel.Text=""; teamLabel.Parent=bb
    local distLabel=Instance.new("TextLabel")
    distLabel.BackgroundTransparency=1; distLabel.Size=UDim2.new(1,0,0,10); distLabel.Position=UDim2.new(0,0,0,26)
    distLabel.Font=Enum.Font.Gotham; distLabel.TextSize=10; distLabel.TextStrokeTransparency=0.3
    distLabel.TextStrokeColor3=Color3.new(0,0,0); distLabel.Text=""; distLabel.Parent=bb
    distLabel.AnchorPoint=Vector2.new(0.5,0)
    distLabel.Position=UDim2.new(0.5,0,0,26)
    local distanceScale=Instance.new("UIScale"); distanceScale.Parent=distLabel

    local hpBB_L=Instance.new("BillboardGui")
    hpBB_L.AlwaysOnTop=true; hpBB_L.Size=UDim2.new(0,3,0,30); hpBB_L.StudsOffset=Vector3.new(-1.2,0,0)
    hpBB_L.Adornee=r; hpBB_L.Enabled=false; hpBB_L.ResetOnSpawn=false; hpBB_L.Parent=holder
    local hpTrack_L=Instance.new("Frame")
    hpTrack_L.BackgroundColor3=Color3.fromRGB(10,10,10); hpTrack_L.BackgroundTransparency=0.2
    hpTrack_L.BorderSizePixel=0; hpTrack_L.Size=UDim2.new(1,0,1,0); hpTrack_L.Parent=hpBB_L; uic(1).Parent=hpTrack_L
    local hpFill_L=Instance.new("Frame")
    hpFill_L.BackgroundColor3=Color3.fromRGB(100,220,130); hpFill_L.BorderSizePixel=0
    hpFill_L.AnchorPoint=Vector2.new(0,1); hpFill_L.Position=UDim2.new(0,0,1,0)
    hpFill_L.Size=UDim2.new(1,0,1,0); hpFill_L.Parent=hpTrack_L; uic(1).Parent=hpFill_L
    local hpBB_T=Instance.new("BillboardGui")
    hpBB_T.AlwaysOnTop=true; hpBB_T.Size=UDim2.new(0,40,0,3); hpBB_T.StudsOffset=Vector3.new(0,4.5,0)
    hpBB_T.Adornee=r; hpBB_T.Enabled=false; hpBB_T.ResetOnSpawn=false; hpBB_T.Parent=holder
    local hpTrack_T=Instance.new("Frame")
    hpTrack_T.BackgroundColor3=Color3.fromRGB(10,10,10); hpTrack_T.BackgroundTransparency=0.2
    hpTrack_T.BorderSizePixel=0; hpTrack_T.Size=UDim2.new(1,0,1,0); hpTrack_T.Parent=hpBB_T; uic(1).Parent=hpTrack_T
    local hpFill_T=Instance.new("Frame")
    hpFill_T.BackgroundColor3=Color3.fromRGB(100,220,130); hpFill_T.BorderSizePixel=0
    hpFill_T.Size=UDim2.new(1,0,1,0); hpFill_T.Parent=hpTrack_T; uic(1).Parent=hpFill_T
    local boxLines={}
    for i=1,12 do
        local ok,line=pcall(function() return Drawing.new("Line") end)
        if not ok or not line then
            for _,old in ipairs(boxLines) do old:Remove() end
            boxLines={}; break
        end
        line.Visible=false; line.Thickness=2; line.Color=Color3.new(1,1,1); line.Transparency=1
        table.insert(boxLines,line)
    end

    return {
        ch=ch,hum=hum,r=r,plr=Players:GetPlayerFromCharacter(ch),
        isNPC=isNPC,holder=holder,bb=bb,highlight=nil,
        nL=nameLabel,tL=teamLabel,dL=distLabel,
        hpBB_L=hpBB_L,hpFill_L=hpFill_L,hpBB_T=hpBB_T,hpFill_T=hpFill_T,
        lN=nil,lT=nil,lD=nil,lR=-1,boxLines=boxLines,distanceScale=distanceScale,nameScale=nameScale
    }
end

local function destroyESP(i)
    local e=ST.espEntries[i]
    if e then pcall(function() if e.holder then e.holder:Destroy() end; if e.boxLines then for _,line in ipairs(e.boxLines) do line:Remove() end end end) end
    table.remove(ST.espEntries,i)
end

local function applyESP(e,myR)
    if not e.ch or not e.ch.Parent then return end
    local newRoot=findRoot(e.ch)
    if newRoot and newRoot~=e.r then
        e.r=newRoot
        pcall(function() e.bb.Adornee=newRoot; e.hpBB_L.Adornee=newRoot; e.hpBB_T.Adornee=newRoot end)
    end
    if not e.hum or not e.hum.Parent then e.hum=findHuman(e.ch) end
    local dist=999999
    if myR and e.r and e.r.Parent then
        local ok,d=pcall(function() return (e.r.Position-myR.Position).Magnitude end)
        if ok then dist=d end
    end
    local showChams=e.isNPC and S.npc and myR~=nil and dist<=ST.espMax
    if showChams then
        if not e.highlight or not e.highlight.Parent then
            local h=Instance.new("Highlight")
            h.Name="FX_Chams"; h.Adornee=e.ch
            h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
            h.Parent=e.holder; e.highlight=h
        end
        e.highlight.Enabled=true
        if e.isNPC then
            e.highlight.FillColor=ST.npcCol; e.highlight.OutlineColor=ST.npcCol
            e.highlight.FillTransparency=0.6; e.highlight.OutlineTransparency=0
        elseif ST.chamsMode=="outline" then
            e.highlight.FillColor=ST.chamsCol2; e.highlight.OutlineColor=ST.chamsCol2
            e.highlight.FillTransparency=1; e.highlight.OutlineTransparency=0
        else
            e.highlight.FillColor=ST.chamsCol; e.highlight.OutlineColor=ST.chamsCol
            e.highlight.FillTransparency=0.5; e.highlight.OutlineTransparency=0
        end
    elseif e.highlight then
        e.highlight:Destroy(); e.highlight=nil
    end
    if myR and dist>ST.espMax then
        e.bb.Enabled=false; e.hpBB_L.Enabled=false; e.hpBB_T.Enabled=false
        for _,line in ipairs(e.boxLines) do line.Visible=false end; return
    end
    local mate=false
    if S.teamCheck and not e.isNPC and e.plr then mate=isSameTeam(LocalPlayer,e.plr) end
    local sN=S.name and not mate
    local sD=S.distance and not mate
    local sT=S.teamName and not e.isNPC and not mate
    local sH=S.healthBar and not mate
    local bbOn=(sN or sD or sT) and not mate
    e.bb.Enabled=bbOn; e.nL.Visible=sN; e.tL.Visible=sT; e.dL.Visible=sD
    e.hpBB_L.Enabled=sH and S.healthBarMode=="left"
    e.hpBB_T.Enabled=sH and S.healthBarMode=="top"
    if sN or sD then
        local viewDistance=dist
        local camera=workspace.CurrentCamera
        if camera and e.r and e.r.Parent then
            viewDistance=(camera.CFrame.Position-e.r.Position).Magnitude
        end
        local falloff=1/math.sqrt(1+math.max(0,viewDistance-25)/220)
        if e.distanceScale then e.distanceScale.Scale=math.clamp(falloff,0.8,1) end
        if e.nameScale then e.nameScale.Scale=math.clamp(falloff,0.75,1) end
    end
    if sN then
        local n=e.isNPC and ("NPC | "..e.ch.Name) or e.ch.Name
        if e.lN~=n then e.lN=n; e.nL.Text=n end
        e.nL.TextColor3=e.isNPC and ST.npcCol or ST.nameCol
    end
    if sT then
        local tn=getTeamName(e.plr) or ""; local td=tn~="" and ("["..tn.."]") or ""
        if e.lT~=td then e.lT=td; e.tL.Text=td end; e.tL.TextColor3=ST.teamCol
    end
    if sD then
        local ds=math.floor(dist).."m"
        if e.lD~=ds then e.lD=ds; e.dL.Text=ds end; e.dL.TextColor3=ST.distCol
    end
    if sH then
        local cur,max=getHPUniversal(e.ch,e.hum)
        local ratio=cur/max
        if math.abs((e.lR or -1)-ratio)>0.005 then
            e.lR=ratio
            e.hpFill_L.Size=UDim2.new(1,0,ratio,0)
            e.hpFill_T.Size=UDim2.new(ratio,0,1,0)
            local r2=math.floor(math.clamp(2*(1-ratio),0,1)*255)
            local g2=math.floor(math.clamp(2*ratio,0,1)*255)
            local hpColor=Color3.fromRGB(r2,g2,0)
            e.hpFill_L.BackgroundColor3=hpColor; e.hpFill_T.BackgroundColor3=hpColor
        end
    end
    local sB=S.box and not mate
    
    if sB and e.boxLines and #e.boxLines==12 and e.r and e.r.Parent then
        local cam=workspace.CurrentCamera
        local rootPos=e.r.Position
                local size=Vector3.new(2,3,2)
        local corners={
            rootPos+Vector3.new(-size.X/2,size.Y/2,-size.Z/2),
            rootPos+Vector3.new(size.X/2,size.Y/2,-size.Z/2),
            rootPos+Vector3.new(size.X/2,size.Y/2,size.Z/2),
            rootPos+Vector3.new(-size.X/2,size.Y/2,size.Z/2),
            rootPos+Vector3.new(-size.X/2,-size.Y/2,-size.Z/2),
            rootPos+Vector3.new(size.X/2,-size.Y/2,-size.Z/2),
            rootPos+Vector3.new(size.X/2,-size.Y/2,size.Z/2),
            rootPos+Vector3.new(-size.X/2,-size.Y/2,size.Z/2)
        }
        local screenCorners={}
        local onScreenCount=0
        for i,corner in ipairs(corners) do
            local screenPos,onScreen,depth=cam:WorldToViewportPoint(corner)
            screenCorners[i]=Vector2.new(screenPos.X,screenPos.Y)
            if onScreen then onScreenCount=onScreenCount+1 end
        end
        if onScreenCount>=1 then
            local edges={{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
            for i,edge in ipairs(edges) do
                e.boxLines[i].From=screenCorners[edge[1]]
                e.boxLines[i].To=screenCorners[edge[2]]
                e.boxLines[i].Color=ST.boxCol
                e.boxLines[i].Visible=true
            end
        else
            for _,line in ipairs(e.boxLines) do line.Visible=false end
        end
    elseif e.boxLines then
        for _,line in ipairs(e.boxLines) do line.Visible=false end
    end



















end

local function ensureESPLoop()
    if ST.espConn then return end
    ST.espConn=RunService.Heartbeat:Connect(function()
        pcall(function()
            frameCount+=1
            local myR; pcall(function() local c=LocalPlayer.Character; myR=c and c:FindFirstChild("HumanoidRootPart") end)
            if wantsESP() then
                for _,p in pairs(Players:GetPlayers()) do
                    if p~=LocalPlayer then
                        local pChar=p.Character
                        if pChar then
                            local found=false
                            for _,e in pairs(ST.espEntries) do if e.ch==pChar then found=true; break end end
                            if not found then
                                local root=findRoot(pChar)
                                if root then
                                    local ok,entry=pcall(buildESP,pChar,false)
                                    if ok and entry then table.insert(ST.espEntries,entry) end
                                end
                            end
                        end
                        if not p.Character then
                            for i=#ST.espEntries,1,-1 do if ST.espEntries[i].plr==p then destroyESP(i) end end
                        end
                    end
                end
            end
            if S.npc and os.clock()-ST.lastNpcScan>2 then
                ST.lastNpcScan=os.clock()
                for _,d in pairs(workspace:GetDescendants()) do
                    if d:IsA("Model") and not d:GetAttribute("ForumXChamsProxy") and not isPlayerChar(d) then
                        local h=d:FindFirstChildOfClass("Humanoid"); local r=findRoot(d)
                        if h and r then
                            local found=false
                            for _,e in pairs(ST.espEntries) do if e.ch==d then found=true; break end end
                            if not found then local ok,entry=pcall(buildESP,d,true); if ok and entry then table.insert(ST.espEntries,entry) end end
                        end
                    end
                end
            end
            for i=#ST.espEntries,1,-1 do
                local e=ST.espEntries[i]
                local valid=e.ch and e.ch.Parent and e.holder and e.holder.Parent and e.r and e.r.Parent and (e.isNPC or (e.plr and e.plr.Character==e.ch))
                if not valid then destroyESP(i)
                elseif e.isNPC and not S.npc then destroyESP(i)
                elseif not e.isNPC and not wantsESP() then
                    destroyESP(i)
                else
                    if not e.isNPC or frameCount%3==0 then pcall(applyESP,e,myR) end
                end
            end
        end)
    end)
end

local function onESPChange()
    playerChams.start()
    ensureESPLoop()
    if S.npc then ST.lastNpcScan=0 end
end

local R15_BONES={
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local R6_BONES={
    {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},
    {"Torso","Left Leg"},{"Torso","Right Leg"},
}

local function getSkelLine(i)
    if not skelLinePool[i] then
        local ok,l=pcall(function() return Drawing.new("Line") end)
        if not ok or not l then return nil end
        l.Thickness=1.5; l.Color=ST.skelCol; l.Transparency=0; l.Visible=false
        skelLinePool[i]=l
    end
    return skelLinePool[i]
end

local function resolveSkeletonBones(ch)
    local resolved={}
    local bones=nil
    if ch:FindFirstChild("UpperTorso") then bones=R15_BONES
    elseif ch:FindFirstChild("Torso") then bones=R6_BONES end
    if not bones then return resolved end
    for _,pair in ipairs(bones) do
        local p0=ch:FindFirstChild(pair[1])
        local p1=ch:FindFirstChild(pair[2])
        if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
            table.insert(resolved,{p0,p1})
        end
    end
    return resolved
end

local function addSkelTarget(ch)
    for _,t in pairs(skelTargets) do if t.ch==ch then return end end
    local r=findRoot(ch); if not r then return end
    table.insert(skelTargets,{ch=ch,r=r,bones=resolveSkeletonBones(ch),lastScan=os.clock()})
end

local function startSkeletonLoop()
    if skeletonConn then return end
    skeletonConn=RunService.RenderStepped:Connect(function()
        local idx=0
        if not S.skeleton then
            for i=1,#skelLinePool do skelLinePool[i].Visible=false end
            return
        end
        local myR
        pcall(function() local c=LocalPlayer.Character; myR=c and c:FindFirstChild("HumanoidRootPart") end)
        for _,p in pairs(Players:GetPlayers()) do
            if p~=LocalPlayer and p.Character then addSkelTarget(p.Character) end
        end
        if S.npc and os.clock()-ST.skelLastScan>1.5 then
            ST.skelLastScan=os.clock()
            for _,d in pairs(workspace:GetDescendants()) do
                if d:IsA("Model") and not d:GetAttribute("ForumXChamsProxy") and not isPlayerChar(d) and d:FindFirstChildOfClass("Humanoid") and findRoot(d) then
                    addSkelTarget(d)
                end
            end
        end
        local cam=workspace.CurrentCamera
        for i=#skelTargets,1,-1 do
            local t=skelTargets[i]
            if not t.ch or not t.ch.Parent or not t.r or not t.r.Parent then
                table.remove(skelTargets,i)
            else
                pcall(function()
                    local inRange=true
                    if myR then
                        local ok,d=pcall(function() return (t.r.Position-myR.Position).Magnitude end)
                        if ok and d>ST.espMax then inRange=false end
                    end
                    if inRange then
                        if os.clock()-t.lastScan>2 then t.bones=resolveSkeletonBones(t.ch); t.lastScan=os.clock() end
                        for _,pair in ipairs(t.bones) do
                            local p0,p1=pair[1],pair[2]
                            if p0 and p0.Parent and p1 and p1.Parent then
                                local ok1,a,aOn=pcall(function() return cam:WorldToViewportPoint(p0.Position) end)
                                local ok2,b,bOn=pcall(function() return cam:WorldToViewportPoint(p1.Position) end)
                                if ok1 and ok2 and aOn and bOn and a.Z>0 and b.Z>0 then
                                    idx+=1
                                    local line=getSkelLine(idx)
                                    if line then
                                        line.Color=ST.skelCol
                                        line.From=Vector2.new(a.X,a.Y)
                                        line.To=Vector2.new(b.X,b.Y)
                                        line.Visible=true
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
        for i=idx+1,#skelLinePool do
            if skelLinePool[i] then skelLinePool[i].Visible=false end
        end
    end)
end

startSkeletonLoop()

local function loadPlayer()
    clearContent(); setActiveTab("player")
    local W=INNER_W; local VW=36

    layoutCtr+=1; contentH+=ROW_H+ROW_PAD
    local r1=Instance.new("Frame"); r1.Parent=ContentFrame; r1.BackgroundTransparency=1
    r1.BorderSizePixel=0; r1.Size=UDim2.new(1,-6,0,ROW_H); r1.LayoutOrder=layoutCtr
    do
        local L=Instance.new("Frame"); L.Parent=r1
        L.BackgroundColor3=Color3.fromRGB(255,255,255); L.BackgroundTransparency=0.93; L.BorderSizePixel=0
        L.Position=UDim2.new(0,0,0,0); L.Size=UDim2.new(0.5,-3,1,0)
        uic(8).Parent=L; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=L
        mkLabel(L,"Noclip",10,54,11)
        local tog=mkToggle(L,ST.noclipEnabled,function(s) ST.noclipEnabled=s; if s then enableNoclip() else disableNoclip() end end)
        mkKeybindBtn(L,66,68,ST.noclipKey,"noclip",function(kb) ST.noclipKey=kb end)
        local ncVL=mkValLabel(L,(W/2)-VW-72,VW,ST.noclipSpeed,5,300,function(v) ST.noclipSpeed=v; return v end)
    end
    do
        local R=Instance.new("Frame"); R.Parent=r1
        R.BackgroundColor3=Color3.fromRGB(255,255,255); R.BackgroundTransparency=0.93; R.BorderSizePixel=0
        R.Position=UDim2.new(0.5,3,0,0); R.Size=UDim2.new(0.5,-3,1,0)
        uic(8).Parent=R; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=R
        mkLabel(R,"CFrame TP",10,78,11)
        mkKeybindBtn(R,94,72,ST.cfTpKey,"cframetp",function(kb) ST.cfTpKey=kb end)
        local cfVL=mkValLabel(R,(W/2)-VW-12,VW,ST.cfTpDist,1,100,function(v) ST.cfTpDist=v; return v end)
    end

    layoutCtr+=1; contentH+=ROW_H+ROW_PAD
    local r2=Instance.new("Frame"); r2.Parent=ContentFrame; r2.BackgroundTransparency=1
    r2.BorderSizePixel=0; r2.Size=UDim2.new(1,-6,0,ROW_H); r2.LayoutOrder=layoutCtr
    do
        local L=Instance.new("Frame"); L.Parent=r2
        L.BackgroundColor3=Color3.fromRGB(255,255,255); L.BackgroundTransparency=0.93; L.BorderSizePixel=0
        L.Position=UDim2.new(0,0,0,0); L.Size=UDim2.new(0.5,-3,1,0)
        uic(8).Parent=L; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=L
        mkLabel(L,"Speed",10,90,11)
        local tog=mkToggle(L,ST.wsEnabled,function(s)
            ST.wsEnabled=s
            if s then
                if ST.savedWS==nil then
                    local ws,jp,jh,ujp=getDefaultSpeeds()
                    ST.savedWS=ws; ST.savedJP=jp; ST.savedJH=jh; ST.savedUJP=ujp
                end
                ensureSpeedLoop()
            else
                if not ST.jumpEnabled then
                    stopSpeedLoop(); restoreSpeeds()
                    ST.savedWS=nil; ST.savedJP=nil; ST.savedJH=nil; ST.savedUJP=nil
                end
            end
        end)
        local wsVL=mkValLabel(L,(W/2)-VW-72,VW,ST.wsValue,1,500,function(v)
            ST.wsValue=v; if ST.wsEnabled then applySpeedPhysics() end; return v
        end)
    end
    do
        local R=Instance.new("Frame"); R.Parent=r2
        R.BackgroundColor3=Color3.fromRGB(255,255,255); R.BackgroundTransparency=0.93; R.BorderSizePixel=0
        R.Position=UDim2.new(0.5,3,0,0); R.Size=UDim2.new(0.5,-3,1,0)
        uic(8).Parent=R; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=R
        mkLabel(R,"Jump",10,90,11)
        local tog=mkToggle(R,ST.jumpEnabled,function(s)
            ST.jumpEnabled=s
            if s then
                if ST.savedJP==nil then
                    local ws,jp,jh,ujp=getDefaultSpeeds()
                    ST.savedWS=ws; ST.savedJP=jp; ST.savedJH=jh; ST.savedUJP=ujp
                end
                ensureSpeedLoop()
            else
                if not ST.wsEnabled then
                    stopSpeedLoop(); restoreSpeeds()
                    ST.savedWS=nil; ST.savedJP=nil; ST.savedJH=nil; ST.savedUJP=nil
                end
            end
        end)
        local jpVL=mkValLabel(R,(W/2)-VW-72,VW,ST.jumpValue,1,500,function(v)
            ST.jumpValue=v; if ST.jumpEnabled then applySpeedPhysics() end; return v
        end)
    end

    layoutCtr+=1; contentH+=ROW_H+ROW_PAD
    local r3=Instance.new("Frame"); r3.Parent=ContentFrame; r3.BackgroundTransparency=1
    r3.BorderSizePixel=0; r3.Size=UDim2.new(1,-6,0,ROW_H); r3.LayoutOrder=layoutCtr
    do
        local L=Instance.new("Frame"); L.Parent=r3
        L.BackgroundColor3=Color3.fromRGB(255,255,255); L.BackgroundTransparency=0.93; L.BorderSizePixel=0
        L.Position=UDim2.new(0,0,0,0); L.Size=UDim2.new(0.5,-3,1,0)
        uic(8).Parent=L; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=L
        mkLabel(L,"Fling",10,56,11)
        local tog=mkToggle(L,ST.nearFling,function(s) if s then enableNearFling() else disableNearFling() end end)
        mkKeybindBtn(L,70,78,ST.nearFlingKey,"nearfling",function(kb) ST.nearFlingKey=kb end)
    end
    do
        local R=Instance.new("Frame"); R.Parent=r3
        R.BackgroundColor3=Color3.fromRGB(255,255,255); R.BackgroundTransparency=0.93; R.BorderSizePixel=0
        R.Position=UDim2.new(0.5,3,0,0); R.Size=UDim2.new(0.5,-3,1,0)
        uic(8).Parent=R; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=R
        mkLabel(R,"Camera FOV",10,110,11)
        local tog=mkToggle(R,ST.cameraFOV,function(s)
            if s then enableCameraFOV() else disableCameraFOV() end
        end)
        local czVL=mkValLabel(R,(W/2)-VW-72,VW,ST.cameraFOVValue,70,120,function(v)
            ST.cameraFOVValue=v
            if ST.cameraFOV then workspace.CurrentCamera.FieldOfView=v end
            return v
        end)
    end

    for _,control in ipairs(ContentFrame:GetDescendants()) do
        if control:IsA("TextLabel") or control:IsA("TextButton") then
            control.TextSize=math.min(control.TextSize,11)
        end
    end
    finalize()
end

local BODY_CX=272
local AIMBOT_PARTS={
    {name="Head",x=BODY_CX,y=28,r=12},{name="UpperTorso",x=BODY_CX,y=62,r=9},
    {name="LowerTorso",x=BODY_CX,y=90,r=9},{name="LeftUpperArm",x=BODY_CX-34,y=64,r=7},
    {name="LeftLowerArm",x=BODY_CX-52,y=84,r=6},{name="LeftHand",x=BODY_CX-64,y=101,r=5},
    {name="RightUpperArm",x=BODY_CX+34,y=64,r=7},{name="RightLowerArm",x=BODY_CX+52,y=84,r=6},
    {name="RightHand",x=BODY_CX+64,y=101,r=5},{name="LeftUpperLeg",x=BODY_CX-18,y=116,r=7},
    {name="LeftLowerLeg",x=BODY_CX-20,y=148,r=6},{name="LeftFoot",x=BODY_CX-22,y=174,r=5},
    {name="RightUpperLeg",x=BODY_CX+18,y=116,r=7},{name="RightLowerLeg",x=BODY_CX+20,y=148,r=6},
    {name="RightFoot",x=BODY_CX+22,y=174,r=5},
}

local function mkChoiceDropdown(parent,label,options,getValue,onSelect,layoutRow,x,width,compact)
    if label~="" then
        local title=mkLabel(parent,label,10,88,11)
        title.Size=UDim2.new(0,88,0,44)
    end
    local position=x and UDim2.new(0,x,0,10) or UDim2.new(1,-142,0,10)
    width=width or 132
    local select=Instance.new("TextButton"); select.Parent=parent
    select.Position=position; select.Size=UDim2.new(0,width,0,24)
    select.BackgroundColor3=Color3.fromRGB(255,255,255); select.BackgroundTransparency=0.92
    select.BorderSizePixel=0; select.Font=Enum.Font.GothamBold; select.TextSize=10
    select.TextColor3=Color3.fromRGB(225,225,230); select.TextXAlignment=Enum.TextXAlignment.Left
    select.Text=compact and "" or ("   "..getValue()); uic(4).Parent=select
    uis(Color3.fromRGB(255,255,255),0.8,1).Parent=select
    local arrow=Instance.new("Frame"); arrow.Parent=select
    arrow.BackgroundTransparency=1; arrow.AnchorPoint=Vector2.new(0.5,0.5)
    arrow.Position=compact and UDim2.new(0.5,0,0.5,0) or UDim2.new(1,-13,0.5,0); arrow.Size=UDim2.new(0,12,0,12)
    for i=1,2 do
        local line=Instance.new("Frame"); line.Parent=arrow; line.BorderSizePixel=0
        line.BackgroundColor3=Color3.fromRGB(255,255,255); line.AnchorPoint=Vector2.new(0.5,0.5)
        line.Size=UDim2.new(0,7,0,2); line.Position=UDim2.new(0,i==1 and 3.5 or 8.5,0,6)
        line.Rotation=i==1 and 45 or -45
    end
    local panel=Instance.new("Frame"); panel.Parent=parent
    panel.Position=UDim2.new(position.X.Scale,position.X.Offset,0,38); panel.Size=UDim2.new(0,compact and 166 or width,0,#options*28+8)
    themeSurface(panel); panel.BorderSizePixel=0; panel.Visible=false
    panel.ZIndex=30; uic(4).Parent=panel
    local rows={}
    local function paint()
        select.Text=compact and "" or ("   "..getValue())
        for value,button in pairs(rows) do
            local active=value==getValue()
            button.Text="   "..value
            button.TextColor3=active and Color3.fromRGB(255,255,255) or Color3.fromRGB(155,155,165)
            button.BackgroundTransparency=active and 0.92 or 1
        end
    end
    local function setOpen(open)
        panel.Visible=open; arrow.Rotation=open and 180 or 0
        layoutRow.ZIndex=open and 20 or 1
        parent.ZIndex=open and 20 or 1
        paint()
    end
    for i,value in ipairs(options) do
        local button=Instance.new("TextButton"); button.Parent=panel
        button.Position=UDim2.new(0,4,0,4+(i-1)*28); button.Size=UDim2.new(1,-8,0,26)
        button.BackgroundColor3=Color3.fromRGB(255,255,255); button.BorderSizePixel=0
        button.Font=Enum.Font.GothamBold; button.TextSize=10; button.TextXAlignment=Enum.TextXAlignment.Left
        button.ZIndex=31; rows[value]=button; uic(3).Parent=button
        button.MouseButton1Click:Connect(function() onSelect(value); setOpen(false) end)
    end
    select.MouseButton1Click:Connect(function() setOpen(not panel.Visible) end)
    paint()
    return function() setOpen(not panel.Visible) end
end

local function loadAimbot()
    clearContent(); setActiveTab("aimbot")
    local W=INNER_W

    local r1=createRow()
    local title=mkLabel(r1,"Aimbot",10,52,11); title.Size=UDim2.new(0,52,0,44)
    local key=mkKeybindBtn(r1,66,64,ST.aimbotKey,"aimbot",function(kb)
        ST.aimbotKey=kb; if ST.aimbotEnabled then startAimbotLoop() end
    end)
    key.Position=UDim2.new(0,66,0,10)
    local methodLabel=mkLabel(r1,"Method",138,62,11); methodLabel.Size=UDim2.new(0,62,0,44)
    mkChoiceDropdown(r1,"",{"Mouse","Camera"},function() return ST.aimbotMethod end,function(value)
        ST.aimbotMethod=value
    end,r1,204,94)
    openAimMode=mkChoiceDropdown(r1,"",{"Hold","Toggle"},function() return ST.aimbotMode end,function(value)
        ST.aimbotMode=value; ST.aimbotActive=false; aimbotLastTarget=nil
    end,r1,308,94)
    local tog=mkToggle(r1,ST.aimbotEnabled,function(value)
        if value then enableAimbot() else disableAimbot() end
    end)
    tog.Position=UDim2.new(1,-54,0,10)
    layoutCtr+=1; contentH+=ROW_H+ROW_PAD
    local r2=Instance.new("Frame"); r2.Parent=ContentFrame; r2.BackgroundTransparency=1
    r2.BorderSizePixel=0; r2.Size=UDim2.new(1,-6,0,ROW_H); r2.LayoutOrder=layoutCtr
    do
        local L=Instance.new("Frame"); L.Parent=r2
        L.BackgroundColor3=Color3.fromRGB(255,255,255); L.BackgroundTransparency=0.93; L.BorderSizePixel=0
        L.Position=UDim2.new(0,0,0,0); L.Size=UDim2.new(0.5,-3,1,0)
        uic(8).Parent=L; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=L
        mkLabel(L,"FOV",10,36)
        local fovVL=mkValLabel(L,(W/2)-50,42,ST.aimbotFOV,10,500,function(v) ST.aimbotFOV=v; refreshFOVRing(); return v end)
        mkSlider(L,48,(W/2)-48-56,10,500,ST.aimbotFOV,function(v) ST.aimbotFOV=math.floor(v+0.5); fovVL.Text=tostring(ST.aimbotFOV); refreshFOVRing() end)
    end
    do
        local L=Instance.new("Frame"); L.Parent=r2
        L.BackgroundColor3=Color3.fromRGB(255,255,255); L.BackgroundTransparency=0.93; L.BorderSizePixel=0
        L.Position=UDim2.new(0.5,3,0,0); L.Size=UDim2.new(0.5,-3,1,0)
        uic(8).Parent=L; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=L
        mkLabel(L,"Team Check",10,130,11)
        local tog=mkToggle(L,ST.aimbotTeamCheck,function(s) ST.aimbotTeamCheck=s end)
        tog.Position=UDim2.new(1,-54,0.5,-12)
    end
    layoutCtr+=1; contentH+=ROW_H+ROW_PAD
    local r3=Instance.new("Frame"); r3.Parent=ContentFrame; r3.BackgroundTransparency=1
    r3.BorderSizePixel=0; r3.Size=UDim2.new(1,-6,0,ROW_H); r3.LayoutOrder=layoutCtr
    do
        local R=Instance.new("Frame"); R.Parent=r3
        R.BackgroundColor3=Color3.fromRGB(255,255,255); R.BackgroundTransparency=0.93; R.BorderSizePixel=0
        R.Position=UDim2.new(0,0,0,0); R.Size=UDim2.new(0.5,-3,1,0)
        uic(8).Parent=R; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=R
        mkLabel(R,"Smooth",10,60)
        local smVL=mkValLabel(R,(W/2)-50,42,math.floor(ST.aimbotSmooth*100),0,99,function(v) ST.aimbotSmooth=v/100; return v end)
        mkSlider(R,72,(W/2)-72-56,0,99,ST.aimbotSmooth*100,function(v) local vv=math.floor(v+0.5); ST.aimbotSmooth=vv/100; smVL.Text=tostring(vv) end)
    end
    do
        local R=Instance.new("Frame"); R.Parent=r3
        R.BackgroundColor3=Color3.fromRGB(255,255,255); R.BackgroundTransparency=0.93; R.BorderSizePixel=0
        R.Position=UDim2.new(0.5,3,0,0); R.Size=UDim2.new(0.5,-3,1,0)
        uic(8).Parent=R; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=R
        mkLabel(R,"Wall Check",10,130,11)
        local tog=mkToggle(R,ST.aimbotWallCheck,function(s) ST.aimbotWallCheck=s end)
        tog.Position=UDim2.new(1,-54,0.5,-12)
    end

    layoutCtr+=1; contentH+=ROW_H+ROW_PAD
    local r5=Instance.new("Frame"); r5.Parent=ContentFrame; r5.BackgroundTransparency=1
    r5.BorderSizePixel=0; r5.Size=UDim2.new(1,-6,0,ROW_H); r5.LayoutOrder=layoutCtr
    do
        local R=Instance.new("Frame"); R.Parent=r5
        R.BackgroundColor3=Color3.fromRGB(255,255,255); R.BackgroundTransparency=0.93; R.BorderSizePixel=0
        R.Position=UDim2.new(0.5,3,0,0); R.Size=UDim2.new(0.5,-3,1,0)
        uic(8).Parent=R; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=R
        mkLabel(R,"Hide FOV",10,70)
        local tog=mkToggle(R,ST.aimbotFovHidden,function(s) ST.aimbotFovHidden=s; refreshFOVRing() end)
        tog.Position=UDim2.new(1,-54,0.5,-12)
    end



    do
    local colorButton=Instance.new("TextButton"); colorButton.Parent=r5
    colorButton.Size=UDim2.new(0.5,-3,1,0); colorButton.Position=UDim2.new(0,0,0,0)
    colorButton.BackgroundColor3=Color3.fromRGB(255,255,255); colorButton.BackgroundTransparency=0.93
    colorButton.BorderSizePixel=0; colorButton.Text=""; colorButton.AutoButtonColor=false
    uic(8).Parent=colorButton; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=colorButton
    mkLabel(colorButton,"FOV Color",10,130,11)
    local sw=Instance.new("Frame"); sw.Parent=colorButton; sw.BackgroundColor3=ST.aimbotFovColor
    sw.BorderSizePixel=0; sw.Position=UDim2.new(1,-36,0.5,-10); sw.Size=UDim2.new(0,26,0,20)
    uic(4).Parent=sw; uis(Color3.fromRGB(255,255,255),0.5,1).Parent=sw
    colorButton.MouseButton1Click:Connect(function()
        openColorPicker("FOV Color",ST.aimbotFovColor,function(col)
            ST.aimbotFovColor=col; sw.BackgroundColor3=col; refreshFOVRing()
        end,loadAimbot)
    end)

    end

    local bodyH=215
    layoutCtr+=1; contentH+=bodyH+ROW_PAD
    local bf=Instance.new("Frame"); bf.Parent=ContentFrame
    bf.BackgroundColor3=Color3.fromRGB(255,255,255); bf.BackgroundTransparency=0.93
    bf.BorderSizePixel=0; bf.Size=UDim2.new(1,-6,0,bodyH); bf.LayoutOrder=layoutCtr
    uic(8).Parent=bf; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=bf

    local selLbl=Instance.new("TextLabel"); selLbl.Parent=bf; selLbl.BackgroundTransparency=1
    selLbl.Position=UDim2.new(0,0,0,0); selLbl.Size=UDim2.new(1,0,0,18)
    selLbl.Font=Enum.Font.GothamBold; selLbl.Text="Selected: "..ST.aimbotTargetPart
    selLbl.TextColor3=Color3.fromRGB(255,255,255); selLbl.TextSize=11; selLbl.TextXAlignment=Enum.TextXAlignment.Center

    aimbotPartBtns={}
    local SEL=Color3.fromRGB(255,255,255); local IDL=Color3.fromRGB(200,210,240)
    for _,p in ipairs(AIMBOT_PARTS) do
        local sel=p.name==ST.aimbotTargetPart
        local sz=sel and p.r*2+4 or p.r*2
        local ox=sel and p.r+2 or p.r
        local oy=sel and p.r+2 or p.r
        local dot=Instance.new("TextButton"); dot.Parent=bf
        dot.Text=""; dot.AutoButtonColor=false; dot.BorderSizePixel=0; dot.ZIndex=3
        dot.BackgroundColor3=sel and SEL or IDL; dot.BackgroundTransparency=sel and 0.1 or 0.55
        dot.Size=UDim2.new(0,sz,0,sz); dot.Position=UDim2.new(0,p.x-ox,0,p.y+18-oy)
        uic(1000).Parent=dot
        local stroke=Instance.new("UIStroke")
        stroke.Color=sel and Color3.fromRGB(255,255,255) or Color3.fromRGB(120,130,160)
        stroke.Transparency=0.3; stroke.Thickness=1.5; stroke.Parent=dot
        dot.MouseEnter:Connect(function()
            if ST.aimbotTargetPart~=p.name then TweenService:Create(dot,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=0.3}):Play() end
        end)
        dot.MouseLeave:Connect(function()
            if ST.aimbotTargetPart~=p.name then TweenService:Create(dot,TweenInfo.new(0.1),{BackgroundColor3=IDL,BackgroundTransparency=0.55}):Play() end
        end)
        table.insert(aimbotPartBtns,{dot=dot,stroke=stroke,part=p.name,r=p.r,x=p.x,y=p.y})
    end

    task.defer(function()
        local fw=bf.AbsoluteSize.X
        if fw<10 then bf:GetPropertyChangedSignal("AbsoluteSize"):Wait(); fw=bf.AbsoluteSize.X end
        local cx=fw/2
        local function refreshDots()
            selLbl.Text="Selected: "..ST.aimbotTargetPart
            for _,info in pairs(aimbotPartBtns) do
                local sel=info.part==ST.aimbotTargetPart
                local sz=sel and info.r*2+4 or info.r*2
                local ox=sel and info.r+2 or info.r
                local oy=sel and info.r+2 or info.r
                local dx=info.x-BODY_CX; local realX=cx+dx
                TweenService:Create(info.dot,TweenInfo.new(0.15),{
                    BackgroundColor3=sel and SEL or IDL,BackgroundTransparency=sel and 0.1 or 0.55,
                    Size=UDim2.new(0,sz,0,sz),Position=UDim2.new(0,realX-ox,0,info.y+18-oy),
                }):Play()
                info.stroke.Color=sel and Color3.fromRGB(255,255,255) or Color3.fromRGB(120,130,160)
            end
        end
        for _,info in pairs(aimbotPartBtns) do
            local dx=info.x-BODY_CX; local realX=cx+dx
            local sel=info.part==ST.aimbotTargetPart
            local sz=sel and info.r*2+4 or info.r*2
            local ox=sel and info.r+2 or info.r
            local oy=sel and info.r+2 or info.r
            info.dot.Position=UDim2.new(0,realX-ox,0,info.y+18-oy)
            info.dot.MouseButton1Click:Connect(function()
                ST.aimbotTargetPart=info.part; refreshDots()
            end)
        end
    end)
    finalize()
end

local loadVisuals
loadVisuals=function()
    clearContent(); setActiveTab("visuals")
    local S=ST.espFlags
    local W=INNER_W
    local function halfPair(lA,fA,gA,sA,lB,fB,gB,sB)
        layoutCtr+=1; contentH+=ROW_H+ROW_PAD
        local wr=Instance.new("Frame"); wr.Parent=ContentFrame; wr.BackgroundTransparency=1
        wr.BorderSizePixel=0; wr.Size=UDim2.new(1,-6,0,ROW_H); wr.LayoutOrder=layoutCtr
        local function mH(left)
            local f=Instance.new("Frame"); f.Parent=wr
            f.BackgroundColor3=Color3.fromRGB(255,255,255); f.BackgroundTransparency=0.93; f.BorderSizePixel=0
            f.Position=left and UDim2.new(0,0,0,0) or UDim2.new(0.5,3,0,0); f.Size=UDim2.new(0.5,-3,1,0)
            uic(8).Parent=f; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=f; return f
        end
        local L=mH(true); local R=mH(false)
        mkLabel(L,lA,10,120,11)
        if gA then
            local swA=Instance.new("TextButton"); swA.Parent=L; swA.BackgroundColor3=gA(); swA.BorderSizePixel=0
            swA.Position=UDim2.new(1,-100,0.5,-10); swA.Size=UDim2.new(0,26,0,20); swA.Text=""; swA.AutoButtonColor=false
            uic(4).Parent=swA; uis(Color3.fromRGB(255,255,255),0.5,1).Parent=swA
            swA.MouseButton1Click:Connect(function() openColorPicker(lA,gA(),function(col) sA(col); swA.BackgroundColor3=col end,loadVisuals) end)
        end
        local togA=Instance.new("TextButton"); togA.Parent=L; togA.Text=""; togA.AutoButtonColor=false
        togA.BackgroundColor3=Color3.fromRGB(255,255,255); togA.BackgroundTransparency=0.78; togA.BorderSizePixel=0
        togA.Position=UDim2.new(1,-54,0.5,-12); togA.Size=UDim2.new(0,44,0,24); togA.ClipsDescendants=true
        uic(1000).Parent=togA; uis(Color3.fromRGB(255,255,255),0.55,1).Parent=togA
        local fillA=Instance.new("Frame"); fillA.Parent=togA; fillA.BackgroundColor3=Color3.fromRGB(255,255,255); fillA.BackgroundTransparency=0.5
        fillA.BorderSizePixel=0; fillA.Size=UDim2.new(0,0,1,0); fillA.ZIndex=2; uic(1000).Parent=fillA
        local knobA=Instance.new("Frame"); knobA.Parent=togA; knobA.BackgroundColor3=Color3.fromRGB(255,255,255)
        knobA.BorderSizePixel=0; knobA.Size=UDim2.new(0,18,0,18); knobA.Position=UDim2.new(0,3,0,3); knobA.ZIndex=3; uic(1000).Parent=knobA
        local stateA=S[fA]
        local function refA(s2)
            local ti=TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
            TweenService:Create(fillA,ti,{Size=s2 and UDim2.new(1,0,1,0) or UDim2.new(0,0,1,0),BackgroundTransparency=s2 and 0.3 or 0.5}):Play()
            TweenService:Create(knobA,ti,{Position=s2 and UDim2.new(1,-21,0,3) or UDim2.new(0,3,0,3)}):Play()
            TweenService:Create(togA,TweenInfo.new(0.18),{BackgroundTransparency=s2 and 0.6 or 0.78}):Play()
        end
        refA(stateA)
        togA.MouseButton1Click:Connect(function() stateA=not stateA; S[fA]=stateA; refA(stateA); onESPChange() end)
        mkLabel(R,lB,10,120,11)
        if gB then
            local swB=Instance.new("TextButton"); swB.Parent=R; swB.BackgroundColor3=gB(); swB.BorderSizePixel=0
            swB.Position=UDim2.new(1,-100,0.5,-10); swB.Size=UDim2.new(0,26,0,20); swB.Text=""; swB.AutoButtonColor=false
            uic(4).Parent=swB; uis(Color3.fromRGB(255,255,255),0.5,1).Parent=swB
            swB.MouseButton1Click:Connect(function() openColorPicker(lB,gB(),function(col) sB(col); swB.BackgroundColor3=col end,loadVisuals) end)
        end
        local togB=Instance.new("TextButton"); togB.Parent=R; togB.Text=""; togB.AutoButtonColor=false
        togB.BackgroundColor3=Color3.fromRGB(255,255,255); togB.BackgroundTransparency=0.78; togB.BorderSizePixel=0
        togB.Position=UDim2.new(1,-54,0.5,-12); togB.Size=UDim2.new(0,44,0,24); togB.ClipsDescendants=true
        uic(1000).Parent=togB; uis(Color3.fromRGB(255,255,255),0.55,1).Parent=togB
        local fillB=Instance.new("Frame"); fillB.Parent=togB; fillB.BackgroundColor3=Color3.fromRGB(255,255,255); fillB.BackgroundTransparency=0.5
        fillB.BorderSizePixel=0; fillB.Size=UDim2.new(0,0,1,0); fillB.ZIndex=2; uic(1000).Parent=fillB
        local knobB=Instance.new("Frame"); knobB.Parent=togB; knobB.BackgroundColor3=Color3.fromRGB(255,255,255)
        knobB.BorderSizePixel=0; knobB.Size=UDim2.new(0,18,0,18); knobB.Position=UDim2.new(0,3,0,3); knobB.ZIndex=3; uic(1000).Parent=knobB
        local stateB=S[fB]
        local function refB(s2)
            local ti=TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
            TweenService:Create(fillB,ti,{Size=s2 and UDim2.new(1,0,1,0) or UDim2.new(0,0,1,0),BackgroundTransparency=s2 and 0.3 or 0.5}):Play()
            TweenService:Create(knobB,ti,{Position=s2 and UDim2.new(1,-21,0,3) or UDim2.new(0,3,0,3)}):Play()
            TweenService:Create(togB,TweenInfo.new(0.18),{BackgroundTransparency=s2 and 0.6 or 0.78}):Play()
        end
        refB(stateB)
        togB.MouseButton1Click:Connect(function() stateB=not stateB; S[fB]=stateB; refB(stateB); onESPChange() end)
    end
    halfPair("Name","name",function() return ST.nameCol end,function(c) ST.nameCol=c end,
             "Distance","distance",function() return ST.distCol end,function(c) ST.distCol=c end)
    do
        layoutCtr+=1; contentH+=ROW_H+ROW_PAD
        local wr=Instance.new("Frame"); wr.Parent=ContentFrame; wr.BackgroundTransparency=1
        wr.BorderSizePixel=0; wr.Size=UDim2.new(1,-6,0,ROW_H); wr.LayoutOrder=layoutCtr
        local hL=Instance.new("Frame"); hL.Parent=wr
        hL.BackgroundColor3=Color3.fromRGB(255,255,255); hL.BackgroundTransparency=0.93; hL.BorderSizePixel=0
        hL.Position=UDim2.new(0,0,0,0); hL.Size=UDim2.new(0.5,-3,1,0); uic(8).Parent=hL; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=hL
        mkLabel(hL,"HP Bar",10,58,11)
        local hpIconBtn,hpIconRefresh=mkHpModeIcon(hL,76)
        local swH=Instance.new("TextButton"); swH.Parent=hL; swH.BorderSizePixel=0
        swH.Position=UDim2.new(1,-100,0.5,-10); swH.Size=UDim2.new(0,26,0,22); swH.Text=""; swH.AutoButtonColor=false
        uic(4).Parent=swH; uis(Color3.fromRGB(255,255,255),0.5,1).Parent=swH
        local function hpCol() return S.healthBarMode=="left" and ST.hpColL or ST.hpColT end
        local function refreshHp() swH.BackgroundColor3=hpCol(); hpIconRefresh(S.healthBarMode,hpCol()) end
        refreshHp()
        swH.MouseButton1Click:Connect(function()
            if S.healthBarMode=="left" then openColorPicker("Left HP Color",ST.hpColL,function(col) ST.hpColL=col; refreshHp() end,loadVisuals)
            else openColorPicker("Top HP Color",ST.hpColT,function(col) ST.hpColT=col; refreshHp() end,loadVisuals) end
        end)
        hpIconBtn.MouseButton1Click:Connect(function() S.healthBarMode=S.healthBarMode=="left" and "top" or "left"; refreshHp() end)
        mkToggle(hL,S.healthBar,function(s) S.healthBar=s; onESPChange() end)
        local hR=Instance.new("Frame"); hR.Parent=wr
        hR.BackgroundColor3=Color3.fromRGB(255,255,255); hR.BackgroundTransparency=0.93; hR.BorderSizePixel=0
        hR.Position=UDim2.new(0.5,3,0,0); hR.Size=UDim2.new(0.5,-3,1,0); uic(8).Parent=hR; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=hR
        local chTitle=mkLabel(hR,"Chams",10,48,11); chTitle.Size=UDim2.new(0,48,0,44)
        local refreshChams
        mkChoiceDropdown(hR,"",{"Normal","Whitelist Players","Team"},function()
            return ST.chamsColorGroup
        end,function(value)
            ST.chamsColorGroup=value
            if refreshChams then refreshChams() end
        end,wr,62,24,true)
        local chIconBtn,chIconRefresh=mkChamsModeIcon(hR,94)
        chIconBtn.Position=UDim2.new(0,94,0,10)
        local swC=Instance.new("TextButton"); swC.Parent=hR; swC.BorderSizePixel=0
        swC.Position=UDim2.new(1,-100,0,11); swC.Size=UDim2.new(0,26,0,22); swC.Text=""; swC.AutoButtonColor=false
        uic(4).Parent=swC; uis(Color3.fromRGB(255,255,255),0.5,1).Parent=swC
        local function colorKey()
            if ST.chamsColorGroup=="Whitelist Players" then return "chamsWhitelistCol" end
            if ST.chamsColorGroup=="Team" then return "chamsTeamCol" end
            return ST.chamsMode=="outline" and "chamsCol2" or "chamsCol"
        end
        refreshChams=function() local col=ST[colorKey()]; swC.BackgroundColor3=col; chIconRefresh(ST.chamsMode,col) end
        refreshChams()
        swC.MouseButton1Click:Connect(function()
            local key=colorKey()
            openColorPicker(ST.chamsColorGroup.." Chams Color",ST[key],function(col)
                ST[key]=col; refreshChams(); playerChams.sync()
            end,loadVisuals)
        end)
        chIconBtn.MouseButton1Click:Connect(function() ST.chamsMode=ST.chamsMode=="fill" and "outline" or "fill"; refreshChams() end)
        local chToggle=mkToggle(hR,S.chams,function(s) S.chams=s; onESPChange() end)
        chToggle.Position=UDim2.new(1,-54,0,10)
    end
    halfPair("Npc Esp","npc",function() return ST.npcCol end,function(c) ST.npcCol=c end,
             "ESP Box","box",function() return ST.boxCol end,function(c) ST.boxCol=c end)
    halfPair("Team Name","teamName",function() return ST.teamCol end,function(c) ST.teamCol=c end,
             "Team Check","teamCheck",nil,nil)
    local rD=createRow(); mkLabel(rD,"Max Distance",12,100,11)
    local dvl=mkValLabel(rD,W-52,42,ST.espMax,10,10000,function(v) ST.espMax=v; return v end)
    mkSlider(rD,116,W-116-62,10,10000,ST.espMax,function(v) ST.espMax=math.floor(v+0.5); dvl.Text=tostring(ST.espMax) end)
    finalize()
end

local function mkTogglePairRow(labelA,stateA,cbA,labelB,stateB,cbB)
    layoutCtr+=1; contentH+=ROW_H+ROW_PAD
    local wr=Instance.new("Frame"); wr.Parent=ContentFrame; wr.BackgroundTransparency=1
    wr.BorderSizePixel=0; wr.Size=UDim2.new(1,-6,0,ROW_H); wr.LayoutOrder=layoutCtr
    local function mkHalf(left)
        local f=Instance.new("Frame"); f.Parent=wr
        f.BackgroundColor3=Color3.fromRGB(255,255,255); f.BackgroundTransparency=0.93; f.BorderSizePixel=0
        f.Position=left and UDim2.new(0,0,0,0) or UDim2.new(0.5,3,0,0); f.Size=UDim2.new(0.5,-3,1,0)
        uic(8).Parent=f; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=f; return f
    end
    local L=mkHalf(true); local R=mkHalf(false)
    mkLabel(L,labelA,10,140,11); mkToggle(L,stateA,cbA)
    mkLabel(R,labelB,10,140,11); mkToggle(R,stateB,cbB)
    return L,R
end

local function loadOther()
    clearContent(); setActiveTab("other")
    local W=INNER_W; local VW=36
    mkTogglePairRow(
        "Anti-AFK",ST.antiAfk,function(s) if s then enableAntiAfk() else disableAntiAfk() end end,
        "(E) Bypass",ST.promptBypass,function(s) if s then enablePromptBypass() else disablePromptBypass() end end
    )
    layoutCtr+=1; contentH+=ROW_H+ROW_PAD
    local r2=Instance.new("Frame"); r2.Parent=ContentFrame; r2.BackgroundTransparency=1
    r2.BorderSizePixel=0; r2.Size=UDim2.new(1,-6,0,ROW_H); r2.LayoutOrder=layoutCtr
    do
        local L=Instance.new("Frame"); L.Parent=r2
        L.BackgroundColor3=Color3.fromRGB(255,255,255); L.BackgroundTransparency=0.93; L.BorderSizePixel=0
        L.Position=UDim2.new(0,0,0,0); L.Size=UDim2.new(0.5,-3,1,0)
        uic(8).Parent=L; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=L
        mkLabel(L,"Prompt Range",10,104,11)
        local tog=mkToggle(L,ST.promptRange,function(s) if s then enablePR() else disablePR() end end)
        local prVL=mkValLabel(L,(W/2)-VW-72,VW,ST.promptRangeVal,5,300,function(v) ST.promptRangeVal=v; return v end)
    end
    do
        local R=Instance.new("Frame"); R.Parent=r2
        R.BackgroundColor3=Color3.fromRGB(255,255,255); R.BackgroundTransparency=0.93; R.BorderSizePixel=0
        R.Position=UDim2.new(0.5,3,0,0); R.Size=UDim2.new(0.5,-3,1,0)
        uic(8).Parent=R; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=R
        mkLabel(R,"Auto Interact",10,104,11)
        local tog=mkToggle(R,ST.autoInteract,function(s) if s then enableAutoInteract() else disableAutoInteract() end end)
        local aiVL=mkValLabel(R,(W/2)-VW-72,VW,ST.autoInteractDist,3,200,function(v)
            ST.autoInteractDist=v
            if ST.autoInteract then destroyAutoInteractESP(); createAutoInteractESP() end
            return v
        end)
    end
    finalize()
end

local function createPlayerCard(parent,player,col)
    local card=Instance.new("Frame"); card.Parent=parent
    card.BackgroundColor3=Color3.fromRGB(255,255,255); card.BackgroundTransparency=0.93
    card.BorderSizePixel=0
    card.Position=col==0 and UDim2.new(0,0,0,0) or UDim2.new(0.5,3,0,0)
    card.Size=UDim2.new(0.5,-3,0,96)
    uic(6).Parent=card; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=card
    
    local nl=Instance.new("TextLabel"); nl.Parent=card; nl.BackgroundTransparency=1
    nl.Position=UDim2.new(0,6,0,3); nl.Size=UDim2.new(1,-12,0,14)
    nl.Font=Enum.Font.GothamBold; nl.Text=player.Name
    nl.TextColor3=Color3.fromRGB(220,220,235); nl.TextSize=10
    nl.TextXAlignment=Enum.TextXAlignment.Left; nl.TextTruncate=Enum.TextTruncate.None; nl.TextScaled=true
    local nameLimit=Instance.new("UITextSizeConstraint"); nameLimit.MaxTextSize=10; nameLimit.MinTextSize=6; nameLimit.Parent=nl
    
    local function mBtn(xPos,y,w,txt,isActive)
        local b=Instance.new("TextButton"); b.Parent=card
        b.BackgroundColor3=isActive and Color3.fromRGB(100,255,150) or Color3.fromRGB(255,255,255)
        b.BackgroundTransparency=isActive and 0.3 or 0.92
        b.BorderSizePixel=0
        b.Position=UDim2.new(0,xPos,0,y); b.Size=UDim2.new(0,w,0,18)
        b.Font=Enum.Font.GothamBold; b.Text=txt
        b.TextColor3=isActive and Color3.fromRGB(255,255,255) or Color3.fromRGB(190,200,220)
        b.TextSize=9; uic(5).Parent=b
        return b
    end
    
    local wlPlayer=ST.whitelistPlayers[player.Name] or false
    local wlpBtn=mBtn(4,22,card.AbsoluteSize.X/2-6,wlPlayer and "WL Player ✓" or "WL Player",wlPlayer)
    wlpBtn.MouseButton1Click:Connect(function()
        ST.whitelistPlayers[player.Name]=not ST.whitelistPlayers[player.Name]
        local isActive=ST.whitelistPlayers[player.Name]
        wlpBtn.Text=isActive and "WL Player ✓" or "WL Player"
        wlpBtn.BackgroundColor3=isActive and Color3.fromRGB(100,255,150) or Color3.fromRGB(255,255,255)
        wlpBtn.BackgroundTransparency=isActive and 0.3 or 0.92
        wlpBtn.TextColor3=isActive and Color3.fromRGB(255,255,255) or Color3.fromRGB(190,200,220)
    end)
    
    if player.Team then
        local wlTeam=ST.whitelistTeams[player.Team.Name] or false
        local wltBtn=mBtn(card.AbsoluteSize.X/2+2,22,card.AbsoluteSize.X/2-6,wlTeam and "WL Team ✓" or "WL Team",wlTeam)
        wltBtn.MouseButton1Click:Connect(function()
            local team = player.Team
            if not team then return end
            local teamName = team.Name
            ST.whitelistTeams[teamName]=not ST.whitelistTeams[teamName]
            local isActive=ST.whitelistTeams[teamName]
            wltBtn.Text=isActive and "WL Team ✓" or "WL Team"
            wltBtn.BackgroundColor3=isActive and Color3.fromRGB(100,255,150) or Color3.fromRGB(255,255,255)
            wltBtn.BackgroundTransparency=isActive and 0.3 or 0.92
            wltBtn.TextColor3=isActive and Color3.fromRGB(255,255,255) or Color3.fromRGB(190,200,220)
        end)
    end
    
    local v1Active=ST.v1Targets[player.Name]~=nil
    local v1B=mBtn(4,42,card.AbsoluteSize.X/2-6,v1Active and "V1 +" or "V1 Fling",v1Active)
    v1B.MouseButton1Click:Connect(function()
        if ST.v1Targets[player.Name] then
            ST.v1Targets[player.Name]=nil; v1B.Text="V1 Fling"
            v1B.BackgroundColor3=Color3.fromRGB(255,255,255); v1B.BackgroundTransparency=0.92
            v1B.TextColor3=Color3.fromRGB(190,200,220)
        else
            ST.v1Targets[player.Name]=player; v1B.Text="V1 +"
            v1B.BackgroundColor3=Color3.fromRGB(100,255,150); v1B.BackgroundTransparency=0.3
            v1B.TextColor3=Color3.fromRGB(255,255,255); v1Loop()
        end
    end)
    
    local tpB=mBtn(card.AbsoluteSize.X/2+2,42,card.AbsoluteSize.X/2-6,"Teleport",false)
    tpB.MouseButton1Click:Connect(function() tpToPlayer(player) end)
    
    local spActive=ST.spectating==player
    local spB=mBtn(4,64,card.AbsoluteSize.X-8,spActive and "Spectate +" or "Spectate",spActive)
    spB.MouseButton1Click:Connect(function()
        if ST.spectating==player then
            stopSpectate(); spB.Text="Spectate"
            spB.BackgroundColor3=Color3.fromRGB(255,255,255); spB.BackgroundTransparency=0.92
            spB.TextColor3=Color3.fromRGB(190,200,220)
        else
            if ST.activeSpecBtn then
                ST.activeSpecBtn.Text="Spectate"
                ST.activeSpecBtn.BackgroundColor3=Color3.fromRGB(255,255,255)
                ST.activeSpecBtn.BackgroundTransparency=0.92
                ST.activeSpecBtn.TextColor3=Color3.fromRGB(190,200,220)
            end
            ST.spectating=player; ST.activeSpecBtn=spB; spB.Text="Spectate +"
            spB.BackgroundColor3=Color3.fromRGB(100,255,150); spB.BackgroundTransparency=0.3
            spB.TextColor3=Color3.fromRGB(255,255,255); startSpectate(player)
        end
    end)
    if spActive then ST.activeSpecBtn=spB end
    
    return card
end


local function loadPlayers()
    clearContent(); setActiveTab("players")
    local topR=createRow()
    local countL=mkLabel(topR,"Players: "..#Players:GetPlayers(),12,200,nil,true)
    local searchR=createRow()
    do
        local sBox=Instance.new("TextBox"); sBox.Parent=searchR
        sBox.BackgroundColor3=Color3.fromRGB(255,255,255); sBox.BackgroundTransparency=0.87
        sBox.BorderSizePixel=0; sBox.Position=UDim2.new(0,10,0.5,-11); sBox.Size=UDim2.new(1,-20,0,22)
        sBox.Font=Enum.Font.Gotham; sBox.PlaceholderText="Search player..."; sBox.Text=""
        sBox.TextColor3=Color3.fromRGB(255,255,255); sBox.PlaceholderColor3=Color3.fromRGB(150,150,150)
        sBox.TextSize=12; sBox.ClearTextOnFocus=false; uic(5).Parent=sBox
        layoutCtr+=1; contentH+=290+ROW_PAD
        local lf=Instance.new("ScrollingFrame"); lf.Parent=ContentFrame
        lf.BackgroundColor3=Color3.fromRGB(255,255,255); lf.BackgroundTransparency=0.96
        lf.BorderSizePixel=0; lf.Size=UDim2.new(1,-6,0,290); lf.LayoutOrder=layoutCtr
        lf.CanvasSize=UDim2.new(0,0,0,0); lf.ScrollBarThickness=6
        lf.ScrollBarImageColor3=Color3.fromRGB(255,255,255); lf.VerticalScrollBarInset=Enum.ScrollBarInset.ScrollBar; uic(8).Parent=lf
        local ft=""
        local function refresh()
            for _,ch in pairs(lf:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
            local y=0; local cnt=0; local rowFrame=nil
            for _,plr in pairs(Players:GetPlayers()) do
                if plr~=LocalPlayer then
                    if ft=="" or plr.Name:lower():find(ft,1,true) then
                        if cnt%2==0 then
                            rowFrame=Instance.new("Frame"); rowFrame.Parent=lf
                            rowFrame.BackgroundTransparency=1; rowFrame.BorderSizePixel=0
                            rowFrame.Position=UDim2.new(0,4,0,y); rowFrame.Size=UDim2.new(1,-8,0,100)
                            y=y+104
                        end
                        if rowFrame then createPlayerCard(rowFrame,plr,cnt%2) end
                        cnt=cnt+1
                    end
                end
            end
            lf.CanvasSize=UDim2.new(0,0,0,y+4)
            countL.Text="Players: "..#Players:GetPlayers().." ("..cnt.." shown)"
        end
        sBox:GetPropertyChangedSignal("Text"):Connect(function() ft=sBox.Text:lower(); refresh() end)
        refresh()
        table.insert(ST.plConns,Players.PlayerAdded:Connect(refresh))
        table.insert(ST.plConns,Players.PlayerRemoving:Connect(function() task.defer(refresh) end))
    end
    finalize()
end

local Config = {
    folder="ForumX_Configs", version=1,
    editing=nil, selected=nil, loaded=nil, draft="", notice=nil,
    booleans={"noclipEnabled","wsEnabled","jumpEnabled","promptBypass","promptRange","antiAfk","autoInteract","nearFling","cameraFOV","aimbotEnabled","aimbotTeamCheck","aimbotWallCheck","aimbotFovHidden"},
    numbers={noclipSpeed={5,300},cfTpDist={1,100},wsValue={1,500},jumpValue={1,500},promptRangeVal={5,300},autoInteractDist={3,200},cameraFOVValue={70,120},espMax={10,10000},aimbotFOV={10,500},aimbotSmooth={0,0.99}},
    colors={"menuColor","nameCol","distCol","hpColL","hpColT","chamsCol","chamsCol2","chamsWhitelistCol","chamsTeamCol","npcCol","boxCol","teamCol","aimbotFovColor"},
    keys={"menuKey","noclipKey","cfTpKey","nearFlingKey","aimbotKey"},
    choices={aimbotMode={Hold=true,Toggle=true},aimbotMethod={Mouse=true,Camera=true},chamsMode={outline=true,fill=true},chamsColorGroup={["Normal"]=true,["Whitelist Players"]=true,["Team"]=true}},
    flags={"name","distance","healthBar","chams","teamCheck","teamName","box","npc"},
}
function Config.snapshot()
    local out={}
    for _,k in ipairs(Config.booleans) do out[k]=ST[k] end
    for k in pairs(Config.numbers) do out[k]=ST[k] end
    for k in pairs(Config.choices) do out[k]=ST[k] end
    out.aimbotTargetPart=ST.aimbotTargetPart
    for _,k in ipairs(Config.colors) do local c=ST[k]; out[k]={c.R,c.G,c.B} end
    for _,k in ipairs(Config.keys) do
        local kb=ST[k]
        local btn=kb and rawget(kb,"btn") or nil
         out[k]=kb and {type=kb.type,name=kb.type=="key" and kb.keyCode.Name or (btn and btn.Name or "MouseButton1")} or false
    end
    out.espFlags={healthBarMode=S.healthBarMode}
    for _,k in ipairs(Config.flags) do out.espFlags[k]=S[k] end
    for _,k in ipairs({"whitelistPlayers","whitelistTeams"}) do
        out[k]={}; for name,enabled in pairs(ST[k]) do if enabled then out[k][name]=true end end
    end
    return {format="ForumX.Config",version=Config.version,settings=out}
end
function Config.validate(doc)
    assert(type(doc)=="table" and doc.format=="ForumX.Config","Not a Forum X config")
    assert(doc.version==Config.version,"Unsupported config version")
    local data=doc.settings
    assert(type(data)=="table","Missing settings")
    local result={}
    local function number(value,lo,hi,label)
        assert(type(value)=="number" and value==value and value>=lo and value<=hi,"Invalid value: "..label)
        return value
    end
    for _,k in ipairs(Config.booleans) do
        local value=data[k]
        assert(type(value)=="boolean","Invalid toggle: "..k); result[k]=value
    end
    for k,range in pairs(Config.numbers) do result[k]=number(data[k],range[1],range[2],k) end
    for k,values in pairs(Config.choices) do
        local value=data[k]
        if k=="chamsColorGroup" and value==nil then
            value=({["Whitelist Chams"]="Whitelist Players",["Team Chams"]="Team"})[data.chamsFilter] or "Normal"
        end
        assert(type(value)=="string" and values[value],"Invalid option: "..k)
        result[k]=value
    end
    local validPart=false
    for _,part in ipairs(AIMBOT_PARTS) do if part.name==data.aimbotTargetPart then validPart=true end end
    assert(validPart,"Invalid target part"); result.aimbotTargetPart=data.aimbotTargetPart
    for _,k in ipairs(Config.colors) do
        local c=data[k]
        if k=="menuColor" and c==nil then c={1,1,1} end
        if c==nil and (k=="chamsWhitelistCol" or k=="chamsTeamCol") then
            c=data.chamsCol2 or data.chamsCol
        end
        assert(type(c)=="table","Invalid color: "..k)
        result[k]=Color3.new(number(c[1],0,1,k),number(c[2],0,1,k),number(c[3],0,1,k))
    end
    for _,k in ipairs(Config.keys) do
        local kb=data[k]
        if kb==false then result[k]=false
        else
            assert(type(kb)=="table" and type(kb.name)=="string","Invalid keybind: "..k)
            if kb.type=="key" then
                local ok,key=pcall(function() return Enum.KeyCode[kb.name] end)
                assert(ok and key and key~=Enum.KeyCode.Unknown,"Invalid keyboard key")
                result[k]={type="key",keyCode=key}
            else
                assert(kb.type=="mouse" and (kb.name=="MouseButton1" or kb.name=="MouseButton2" or kb.name=="MouseButton3"),"Invalid mouse button")
                result[k]={type="mouse",btn=Enum.UserInputType[kb.name]}
            end
        end
    end
    assert(type(data.espFlags)=="table","Missing visual settings")
    result.espFlags={}
    for _,k in ipairs(Config.flags) do assert(type(data.espFlags[k])=="boolean","Invalid visual toggle: "..k); result.espFlags[k]=data.espFlags[k] end
    assert(data.espFlags.healthBarMode=="top" or data.espFlags.healthBarMode=="left","Invalid health bar mode")
    result.espFlags.healthBarMode=data.espFlags.healthBarMode
    for _,k in ipairs({"whitelistPlayers","whitelistTeams"}) do
        assert(type(data[k])=="table","Invalid whitelist")
        result[k]={}; local count=0
        for name,enabled in pairs(data[k]) do
            count+=1
            assert(count<=1000 and type(name)=="string" and #name<=100 and type(enabled)=="boolean","Invalid whitelist entry")
            if enabled then result[k][name]=true end
        end
    end
    return result
end
function Config.apply(data)
    stopCFTPLoop()
    if ST.noclipEnabled then disableNoclip() end
    stopSpeedLoop(); restoreSpeeds()
    disablePromptBypass(); disablePR(); disableAntiAfk(); disableAutoInteract()
    disableNearFling(); disableCameraFOV(); disableAimbot()
    for k,v in pairs(data) do
        if k=="espFlags" then for flag,value in pairs(v) do S[flag]=value end
        else ST[k]=v end
    end
    for _,k in ipairs(Config.keys) do if ST[k]==false then ST[k]=nil end end
    if ST.noclipEnabled then enableNoclip() end
    if ST.wsEnabled or ST.jumpEnabled then ensureSpeedLoop() end
    if ST.promptBypass then enablePromptBypass() end
    if ST.promptRange then enablePR() end
    if ST.antiAfk then enableAntiAfk() end
    if ST.autoInteract then enableAutoInteract() end
    if ST.nearFling then enableNearFling() end
    if ST.cameraFOV then enableCameraFOV() end
    if ST.aimbotEnabled then enableAimbot() end
    ST.aimbotActive=false
    onESPChange(); refreshFOVRing(); updateModeButtons(); refreshMenuColor()
end
function Config.export()
    return game:GetService("HttpService"):JSONEncode(Config.snapshot())
end
function Config.import(text)
    assert(type(text)=="string" and #text>0 and #text<=262144,"Config must be 1-262144 bytes")
    local parsed=Config.validate(game:GetService("HttpService"):JSONDecode(text))
    local previous=Config.validate(Config.snapshot())
    local ok,err=pcall(Config.apply,parsed)
    if not ok then
        local restored=pcall(Config.apply,previous)
        error("Could not apply config: "..tostring(err)..(restored and " (previous settings restored)" or " (restore failed)"),0)
    end
end
function Config.path(name)
    name=name:match("^%s*(.-)%s*$"):gsub("%.json$","")
    assert(#name>=1 and #name<=64 and name:match("^[%w_-]+$"),"Use a file name with letters, numbers, - or _")
    local upper=name:upper()
    assert(not ({CON=true,PRN=true,AUX=true,NUL=true})[upper] and not upper:match("^COM%d$") and not upper:match("^LPT%d$"),"Reserved file name")
    return Config.folder.."/"..name..".json"
end
function Config.prepareFolder()
    assert(type(isfolder)=="function" and type(makefolder)=="function","File saving is not supported in this environment")
    if not isfolder(Config.folder) then makefolder(Config.folder) end
end

function Config.saveFile(name)
    assert(type(writefile)=="function" and type(readfile)=="function","File saving/reading is not supported in this environment")
    local path=Config.path(name)
    local text=Config.export()
    Config.prepareFolder()
    writefile(path,text)
    local saved=readfile(path)
    assert(saved==text,"File saved but verification failed")
    Config.validate(game:GetService("HttpService"):JSONDecode(saved))
    return path
end
function Config.loadFile(name)
    assert(type(readfile)=="function","File reading is not supported in this environment")
    local path=Config.path(name)
    Config.import(readfile(path))
    Config.loaded=name
    return path
end
function Config.fileNames()
    assert(type(listfiles)=="function","File listing is not supported in this environment")
    Config.prepareFolder()
    local names,seen={},{}
    for _,path in ipairs(listfiles(Config.folder)) do
        local name=path:gsub("\\","/"):match("([^/]+)%.json$")
        if name and not seen[name] and pcall(Config.path,name) then
            seen[name]=true; table.insert(names,name)
        end
    end
    table.sort(names,function(a,b) return a:lower()<b:lower() end)
    return names
end

function Config.deleteFile(name)
    assert(type(delfile)=="function" and type(isfile)=="function","File deletion is not supported in this environment")
    local path=Config.path(name)
    assert(isfile(path),"File not found")
    delfile(path)
    assert(not isfile(path),"Could not delete file")
    if Config.editing==name then Config.editing=nil end
    if Config.selected==name then Config.selected=nil end
    if Config.loaded==name then Config.loaded=nil end
    return name
end
function Config.beginEdit(name)
    Config.path(name)
    Config.editing=name
    Config.selected=name
end
function Config.saveCurrent(name)
    local target=Config.editing or name
    local path=Config.saveFile(target)
    target=path:match("([^/]+)%.json$")
    Config.editing=target; Config.selected=target
    return target
end

function Config.newFile(name)
    local used={}
    for _,existing in ipairs(Config.fileNames()) do used[existing:lower()]=true end
    name=(name or ""):match("^%s*(.-)%s*$"):gsub("%.json$","")
    if name=="" then
        local index=1
        repeat name="Config_"..index; index+=1 until not used[name:lower()]
    end
    Config.path(name)
    assert(not used[name:lower()],"File already exists; use Edit or choose another name")
    local path=Config.saveFile(name)
    local saved=path:match("([^/]+)%.json$")
    Config.editing=saved; Config.selected=saved; Config.draft=""
    return saved
end

local loadSettings
loadSettings=function()
    clearContent(); setActiveTab("settings")
    layoutCtr+=1; contentH+=ROW_H+ROW_PAD
    local r=Instance.new("Frame"); r.Parent=ContentFrame
    r.BackgroundTransparency=1; r.BorderSizePixel=0
    r.Size=UDim2.new(1,-6,0,ROW_H); r.LayoutOrder=layoutCtr
    local function settingsCard(right)
        local card=Instance.new("Frame"); card.Parent=r
        card.BackgroundColor3=Color3.fromRGB(255,255,255); card.BackgroundTransparency=0.93
        card.BorderSizePixel=0; card.Size=UDim2.new(0.5,-3,1,0)
        card.Position=right and UDim2.new(0.5,3,0,0) or UDim2.new(0,0,0,0)
        uic(8).Parent=card; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=card
        return card
    end
    local keyCard=settingsCard(false)
    local colorCard=settingsCard(true)
    mkLabel(keyCard,"Menu Key",10,80,11)
    local keyButton=mkKeybindBtn(keyCard,0,90,ST.menuKey,"menu",function(kb) ST.menuKey=kb end)
    keyButton.Position=UDim2.new(1,-100,0.5,-12)
    mkLabel(colorCard,"Color",10,90,11)
    local menuSwatch=Instance.new("TextButton"); menuSwatch.Parent=colorCard
    menuSwatch.Position=UDim2.new(1,-38,0.5,-10); menuSwatch.Size=UDim2.new(0,26,0,20)
    menuSwatch.BackgroundColor3=ST.menuColor; menuSwatch.BorderSizePixel=0; menuSwatch.Text=""
    uic(4).Parent=menuSwatch; uis(Color3.fromRGB(255,255,255),0.5,1).Parent=menuSwatch
    menuSwatch.MouseButton1Click:Connect(function()
        openColorPicker("Color",ST.menuColor,function(color)
            ST.menuColor=color; menuSwatch.BackgroundColor3=color; refreshMenuColor()
        end,loadSettings)
    end)
    local row=createRow(40)
    local nameBox=Instance.new("TextBox"); nameBox.Parent=row
    nameBox.Position=UDim2.new(0,10,0.5,-12); nameBox.Size=UDim2.new(1,-242,0,24)
    nameBox.BackgroundColor3=Color3.fromRGB(255,255,255); nameBox.BackgroundTransparency=0.92
    nameBox.BorderSizePixel=0; nameBox.Font=Enum.Font.Gotham; nameBox.TextSize=11
    nameBox.TextColor3=Color3.fromRGB(220,220,235); nameBox.ClearTextOnFocus=false
    nameBox.Text=Config.editing or Config.draft or ""; nameBox.PlaceholderText="File name"
    nameBox.TextEditable=true
    nameBox:GetPropertyChangedSignal("Text"):Connect(function()
        if not Config.editing then Config.draft=nameBox.Text end
    end)
    uic(5).Parent=nameBox
    local listRow=createRow(200)
    local status=mkLabel(listRow,Config.notice or "",8,INNER_W-26,10,true)
    status.Position=UDim2.new(0,8,1,-22); status.Size=UDim2.new(1,-16,0,18)
    Config.notice=nil
    local list=Instance.new("ScrollingFrame"); list.Parent=listRow
    list.BackgroundTransparency=1; list.BorderSizePixel=0
    list.Position=UDim2.new(0,8,0,8); list.Size=UDim2.new(1,-16,1,-34)
    list.ScrollBarThickness=3; list.ScrollBarImageColor3=Color3.fromRGB(200,200,210)
    list.CanvasSize=UDim2.new(); list.ScrollingDirection=Enum.ScrollingDirection.Y
    local function report(ok,message)
        if status.Parent then
            status.Text=(ok and "" or "Error: ")..tostring(message or "")
            status.TextColor3=Color3.fromRGB(220,220,235)
        end
        if not ok then warn("[Forum X] "..tostring(message)) end
    end
    local refresh
    local function button(parent,label,x,width,callback)
        local btn=Instance.new("TextButton"); btn.Parent=parent
        btn.Position=UDim2.new(1,x,0.5,-12); btn.Size=UDim2.new(0,width,0,24)
        btn.BackgroundColor3=Color3.fromRGB(255,255,255); btn.BackgroundTransparency=0.92
        btn.BorderSizePixel=0; btn.Font=Enum.Font.GothamBold; btn.TextSize=10
        btn.TextColor3=Color3.fromRGB(190,200,220); btn.Text=label
        uic(5).Parent=btn; uis(Color3.fromRGB(255,255,255),0.9,1).Parent=btn
        btn.MouseButton1Click:Connect(function()
            local ok,message=pcall(callback); report(ok,message)
        end)
        return btn
    end
    local function iconButton(parent,kind,x,callback)
        local btn=button(parent,"",x,24,callback)
        btn.Name=kind
        btn.BackgroundTransparency=1
        for _,child in ipairs(btn:GetChildren()) do
            if child:IsA("UIStroke") then child:Destroy() end
        end
        local icon=Instance.new("Frame"); icon.Parent=btn
        icon.BackgroundTransparency=1; icon.AnchorPoint=Vector2.new(0.5,0.5)
        icon.Position=UDim2.new(0.5,0,0.5,0); icon.Size=UDim2.new(0,16,0,16)
        local function line(xp,yp,w,h)
            local f=Instance.new("Frame"); f.Parent=icon; f.BorderSizePixel=0
            f.BackgroundColor3=Color3.fromRGB(255,255,255)
            f.Position=UDim2.new(0,xp,0,yp); f.Size=UDim2.new(0,w,0,h)
            return f
        end
        if kind=="Edit" then
            local function segment(x1,y1,x2,y2)
                local dx,dy=x2-x1,y2-y1
                local stroke=Instance.new("Frame"); stroke.Parent=icon
                stroke.AnchorPoint=Vector2.new(0.5,0.5)
                stroke.Position=UDim2.new(0,(x1+x2)/2,0,(y1+y2)/2)
                stroke.Size=UDim2.new(0,math.sqrt(dx*dx+dy*dy),0,1.5)
                stroke.Rotation=math.deg(math.atan2(dy,dx))
                stroke.BackgroundColor3=Color3.fromRGB(255,255,255); stroke.BorderSizePixel=0
                uic(1).Parent=stroke
            end
            segment(6,3,2,3); segment(2,3,2,14)
            segment(2,14,13,14); segment(13,14,13,10)
            segment(6,7,12,1); segment(12,1,15,4)
            segment(15,4,9,10); segment(9,10,5,11); segment(5,11,6,7)
            segment(10,3,13,6)
        else
            line(3,3,10,2); line(6,0,4,2)
            line(4,6,1,8); line(11,6,1,8); line(4,13,8,1)
            line(6,6,1,5); line(9,6,1,5)
        end
        btn.MouseEnter:Connect(function() btn.BackgroundTransparency=0.9 end)
        btn.MouseLeave:Connect(function() btn.BackgroundTransparency=1 end)
        return btn
    end
    refresh=function()
        local names=Config.fileNames()
        for _,child in ipairs(list:GetChildren()) do child:Destroy() end
        for i,name in ipairs(names) do
            local item=Instance.new("Frame"); item.Parent=list
            item.Position=UDim2.new(0,0,0,(i-1)*34); item.Size=UDim2.new(1,-6,0,30)
            item.BackgroundColor3=Color3.fromRGB(255,255,255)
            item.BackgroundTransparency=Config.editing==name and 0.82 or 0.96
            item.BorderSizePixel=0; uic(4).Parent=item
            local label=mkLabel(item,(Config.editing==name and "• " or "")..name,8,INNER_W-190,11,true)
            label.Size=UDim2.new(1,-148,1,0)
            button(item,"Load",-132,60,function()
                Config.loadFile(name)
                Config.beginEdit(name)
                Config.notice="Loaded: "..name
                loadSettings()
            end)
            iconButton(item,"Edit",-64,function()
                Config.beginEdit(name)
                Config.notice="Selected: "..name
                loadSettings()
            end)
            iconButton(item,"Delete",-32,function()
                Config.deleteFile(name)
                nameBox.Text=Config.editing or Config.draft or ""
                nameBox.TextEditable=true
                refresh()
                return "Deleted: "..name
            end)
        end
        list.CanvasSize=UDim2.new(0,0,0,#names*34)
        return ""
    end
    button(row,"Save",-222,64,function()
        local name=Config.saveCurrent(nameBox.Text)
        nameBox.Text=name; nameBox.TextEditable=true
        local ok,err=pcall(refresh)
        if not ok then return "Saved; could not refresh list: "..tostring(err) end
        return "Saved: "..name
    end)
    button(row,"New",-150,56,function()
        local requested=nameBox.Text
        if Config.editing and requested==Config.editing then requested="" end
        local name=Config.newFile(requested)
        nameBox.Text=name; nameBox.TextEditable=true
        local ok,err=pcall(refresh)
        if not ok then return "Saved; could not refresh list: "..tostring(err) end
        return "Saved: "..name
    end)
    button(row,"Copy Path",-86,76,function()
        assert(type(setclipboard)=="function","Clipboard unavailable")
        setclipboard("C:/Users/TECHORA/AppData/Local/Wave/workspace/ForumX_Configs")
        return "Folder path copied"
    end)
    local ok,message=pcall(refresh)
    if not ok then report(false,message) end
    local timer,lastNames=0,""
    table.insert(ST.plConns,RunService.Heartbeat:Connect(function(dt)
        timer+=dt
        if timer<1 then return end
        timer=0
        local scanOK,names=pcall(Config.fileNames)
        if scanOK then
            local signature=table.concat(names,"\n")
            if signature~=lastNames then
                lastNames=signature
                local refreshed,err=pcall(refresh)
                if not refreshed then report(false,err) end
            end
        end
    end))
    finalize()
end


do
    local t1=createTabBtn("player","Player",1);   t1.MouseButton1Click:Connect(loadPlayer)
    local t2=createTabBtn("aimbot","Aimbot",2);   t2.MouseButton1Click:Connect(loadAimbot)
    local t3=createTabBtn("visuals","Visuals",3); t3.MouseButton1Click:Connect(loadVisuals)
    local t4=createTabBtn("other","Other",4);     t4.MouseButton1Click:Connect(loadOther)
    local t5=createTabBtn("players","Players",5); t5.MouseButton1Click:Connect(loadPlayers)
    local t6=createTabBtn("settings","Settings",6); t6.MouseButton1Click:Connect(loadSettings)
end

local function killAll()
    playerChams.clear()
    G.ForumX_Running=false; cancelKeybindCapture(); clearSliders(); closePicker()
    if ST.noclipEnabled then disableNoclip() end
    ST.wsEnabled=false; ST.jumpEnabled=false
    stopSpeedLoop(); restoreSpeeds()
    stopCFTPLoop()
    disablePromptBypass(); disablePR(); disableAntiAfk()
    disableAutoInteract(); disableNearFling(); stopSpectate(); disableAimbot()
    ST.v1Targets={}
    for _,c in pairs(ST.plConns) do pcall(function() c:Disconnect() end) end
    for k in pairs(S) do if type(S[k])=="boolean" then S[k]=false end end
    for i=#ST.espEntries,1,-1 do destroyESP(i) end
    ST.espEntries={}; skelTargets={}
    if ST.espConn then ST.espConn:Disconnect(); ST.espConn=nil end
    if skeletonConn then skeletonConn:Disconnect(); skeletonConn=nil end
    for _,l in pairs(skelLinePool) do pcall(function() l:Remove() end) end
    G.ForumX_Drawings=nil
    if inputConn then inputConn:Disconnect() end
    if inputEndedConn then inputEndedConn:Disconnect() end
    if charConn then charConn:Disconnect() end
    if dragMoveConn then dragMoveConn:Disconnect() end
    if dragEndConn then dragEndConn:Disconnect() end
    for _,d in pairs(workspace:GetDescendants()) do
        if d:IsA("Folder") and (d.Name=="ForumXESP" or d.Name==FOLDER) then pcall(function() d:Destroy() end) end
    end
    FovGui:Destroy(); ScreenGui:Destroy(); G.ForumX_Kill=nil
end
G.ForumX_Kill=killAll
CloseBtn.MouseButton1Click:Connect(killAll)

local minimized=false
MinBtn.MouseButton1Click:Connect(function()
    minimized=not minimized
    if minimized then
        BodyFrame.Visible=false
        TweenService:Create(MainFrame,TweenInfo.new(0.25,Enum.EasingStyle.Quart),{Size=UDim2.new(0,MENU_W,0,48)}):Play()
        MinBtn.Text="+"
    else
        TweenService:Create(MainFrame,TweenInfo.new(0.25,Enum.EasingStyle.Quart),{Size=UDim2.new(0,MENU_W,0,MENU_H)}):Play()
        task.delay(0.25,function() BodyFrame.Visible=true end); MinBtn.Text="-"
    end
end)

inputConn=UserInputService.InputBegan:Connect(function(input,gameProcessed)
    if waitKey then
        local utype=input.UserInputType
        if utype==Enum.UserInputType.MouseMovement or utype==Enum.UserInputType.MouseWheel then return end
        if utype==Enum.UserInputType.MouseButton1 then return end
        local kc=input.KeyCode
        if utype==Enum.UserInputType.Keyboard and kc==Enum.KeyCode.Escape then cancelKeybindCapture(); return end
        local clearBind=(utype==Enum.UserInputType.Keyboard and (kc==Enum.KeyCode.Backspace or kc==Enum.KeyCode.Delete))
        local kb
        if clearBind then kb=nil
        elseif utype==Enum.UserInputType.Keyboard then
            if kc==Enum.KeyCode.Unknown then return end
            kb={type="key",keyCode=kc}
        elseif utype==Enum.UserInputType.MouseButton2 then
            kb={type="mouse",btn=utype}
        elseif utype==Enum.UserInputType.MouseButton3 then
            kb={type="mouse",btn=utype}
        else
            return
        end
        local tgt,btn2,onSet2=keyTarget,keyBtn,keyOnSet
        waitKey=false; keyTarget=nil; keyBtn=nil; keyOnSet=nil
        if keyTimeout then pcall(task.cancel,keyTimeout); keyTimeout=nil end
        if onSet2 then onSet2(kb) end
        if btn2 then btn2.Text=keybindLabel(kb); TweenService:Create(btn2,TweenInfo.new(0.15),{BackgroundTransparency=0.82}):Play() end
        if tgt=="noclip" then ST.noclipKey=kb
        elseif tgt=="cframetp" then ST.cfTpKey=kb
        elseif tgt=="nearfling" then ST.nearFlingKey=kb
        elseif tgt=="aimbot" then ST.aimbotKey=kb; if ST.aimbotEnabled then startAimbotLoop() end
        elseif tgt=="menu" then ST.menuKey=kb
        end
        return
    end
    if gameProcessed or UserInputService:GetFocusedTextBox() then return end
    if input.UserInputType==Enum.UserInputType.Keyboard then
        local kc=input.KeyCode
        if ST.menuKey and ST.menuKey.type=="key" and kc==ST.menuKey.keyCode then MainFrame.Visible=not MainFrame.Visible; return end
        if kc==Enum.KeyCode.Insert and (not ST.menuKey or ST.menuKey.type~="key" or ST.menuKey.keyCode~=Enum.KeyCode.Insert) then MainFrame.Visible=not MainFrame.Visible; return end
        if ST.noclipKey and ST.noclipKey.type=="key" and kc==ST.noclipKey.keyCode then toggleNoclip(); return end
        if ST.cfTpKey and ST.cfTpKey.type=="key" and kc==ST.cfTpKey.keyCode then startCFTPLoop(); return end
        if ST.nearFlingKey and ST.nearFlingKey.type=="key" and kc==ST.nearFlingKey.keyCode then toggleNearFling(); return end
    else
        if keybindMatches(ST.menuKey, input) then MainFrame.Visible=not MainFrame.Visible; return end
        if keybindMatches(ST.noclipKey, input) then toggleNoclip(); return end
        if keybindMatches(ST.cfTpKey, input) then startCFTPLoop(); return end
        if keybindMatches(ST.nearFlingKey, input) then toggleNearFling(); return end
    end
    aimbotKeyPressed(input)
end)
inputEndedConn=UserInputService.InputEnded:Connect(function(input)
    aimbotKeyReleased(input)
    
    if input.UserInputType == Enum.UserInputType.Keyboard then
        local kc = input.KeyCode
        if ST.cfTpKey and ST.cfTpKey.type=="key" and kc==ST.cfTpKey.keyCode then stopCFTPLoop() end
    else
        if keybindMatches(ST.cfTpKey, input) then stopCFTPLoop() end
    end
end)


charConn=LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if not G.ForumX_Running then return end
    ST.savedWS=nil; ST.savedJP=nil; ST.savedJH=nil; ST.savedUJP=nil
    spoofedHumanoid=nil; spoofActive_flag=false
    skelTargets={}
    if ST.noclipEnabled then enableNoclip() end
    if ST.wsEnabled or ST.jumpEnabled then
        stopSpeedLoop()
        ensureSpeedLoop()
    end
    if ST.autoInteract then
        disableAutoInteract()
        task.wait(0.2)
        if not G.ForumX_Running then return end
        enableAutoInteract()
    end
end)

loadPlayer()

