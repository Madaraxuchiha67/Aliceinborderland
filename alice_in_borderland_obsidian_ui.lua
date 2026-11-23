-- ================================================================
--   ALICE IN BORDERLAND — GAME OF TAG
--   Script ÚNICO — Cole em ServerScriptService como "Script"
-- ================================================================

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local Debris         = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

-- ================================================================
-- CONFIG
-- ================================================================
local BX, BY, BZ   = 705, 3, 429
local FLOORS       = 8
local ROOMS_PER    = 10          -- 10 quartos × 8 andares = 80 + 20 extras = 100
local RW           = 14          -- largura do quarto
local RD           = 12          -- profundidade do quarto
local FH           = 9           -- altura do andar
local BUTTON_ROOM  = 73
local TIMER_DUR    = 3600

-- ================================================================
-- REMOTES
-- ================================================================
local RF = Instance.new("Folder")
RF.Name  = "AIBRemotes"
RF.Parent = ReplicatedStorage

local function RE(n)
	local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = RF; return r
end
local REM_Timer    = RE("Timer")
local REM_GameOver = RE("GameOver")
local REM_Win      = RE("Win")
local REM_Enter    = RE("Enter")
local REM_Minigame = RE("Minigame")
local REM_MResult  = RE("MResult")
local REM_OpenDoor = RE("OpenDoor")

-- ================================================================
-- ESTADO
-- ================================================================
local gameActive   = false
local gameEnded    = false
local timerValue   = TIMER_DUR
local inBuilding   = {}
local openedRooms  = {}
local doorPanels   = {}  -- [roomNum] = {panel, light}
local npcAlive     = true

-- ================================================================
-- HELPERS
-- ================================================================
local bModel = Instance.new("Model")
bModel.Name  = "AIB_Building"
bModel.Parent = workspace

local function Part(sz, cf, col, mat, tr, noCol)
	local p = Instance.new("Part")
	p.Size        = sz
	p.CFrame      = cf
	p.Color       = col or Color3.fromRGB(180,180,185)
	p.Material    = mat or Enum.Material.SmoothPlastic
	p.Anchored    = true
	p.CastShadow  = true
	p.Transparency = tr or 0
	p.CanCollide  = (noCol ~= true)
	p.Parent      = bModel
	return p
end

local function Weld(a,b,c0)
	local w = Instance.new("Weld")
	w.Part0 = a; w.Part1 = b
	w.C0    = c0 or CFrame.new()
	w.Parent = a
	return w
end

-- ================================================================
-- CONSTRUÇÃO DO PRÉDIO (forma de L, vista de cima, como nas fotos)
-- Asa principal: 10 quartos × 8 andares (direção Z)
-- Asa lateral:   5 quartos × 8 andares (direção X) saindo da ponta
-- ================================================================

-- Asa A: largura = RW*10, profundidade = RD
local AW = RW * ROOMS_PER   -- 140
local BW = RW * 5            -- 70 (asa do L)

local function buildFloor(floor, wingAX, wingAZ, wingBX, wingBZ, wingBDir)
	local y0 = BY + floor * FH

	-- === ASA PRINCIPAL (A) ===
	-- Chão
	Part(Vector3.new(AW+2, 0.7, RD+6),
		CFrame.new(wingAX + AW/2, y0+0.35, wingAZ + RD/2),
		Color3.fromRGB(55,57,62), Enum.Material.Concrete)
	-- Parede traseira
	Part(Vector3.new(AW+2, FH, 0.55),
		CFrame.new(wingAX + AW/2, y0+FH/2, wingAZ - 0.28),
		Color3.fromRGB(50,52,58), Enum.Material.Concrete)
	-- Teto neon
	Part(Vector3.new(AW+2, 0.35, RD+6),
		CFrame.new(wingAX + AW/2, y0+FH, wingAZ + RD/2),
		Color3.fromRGB(215,225,235), Enum.Material.Neon).Transparency = 0.3
	-- Parapeito (frente)
	Part(Vector3.new(AW+2, FH*0.22, 0.38),
		CFrame.new(wingAX + AW/2, y0 + FH*0.11, wingAZ + RD + 3),
		Color3.fromRGB(62,64,70), Enum.Material.Concrete)
	-- Corrimão metálico
	Part(Vector3.new(AW+2, 0.18, 0.18),
		CFrame.new(wingAX + AW/2, y0+1.3, wingAZ + RD + 2.9),
		Color3.fromRGB(150,150,155), Enum.Material.Metal)
	-- Parede lateral esquerda
	Part(Vector3.new(0.5, FH, RD+6),
		CFrame.new(wingAX - 0.25, y0+FH/2, wingAZ + RD/2),
		Color3.fromRGB(50,52,58), Enum.Material.Concrete)

	-- Quartos da asa A
	for d = 0, ROOMS_PER-1 do
		local roomNum = floor * ROOMS_PER + d + 1
		local rx = wingAX + d * RW
		local rcx = rx + RW/2
		local rz0 = wingAZ
		-- Parede divisória
		if d > 0 then
			Part(Vector3.new(0.38, FH-0.7, RD),
				CFrame.new(rx, y0+FH/2+0.35, rz0 + RD/2),
				Color3.fromRGB(60,62,68), Enum.Material.SmoothPlastic)
		end
		-- Parede fundo quarto
		Part(Vector3.new(RW-0.38, FH-0.7, 0.38),
			CFrame.new(rcx, y0+FH/2+0.35, rz0),
			Color3.fromRGB(62,64,70), Enum.Material.SmoothPlastic)
		-- Chão interno quarto
		Part(Vector3.new(RW-0.38, 0.25, RD-0.38),
			CFrame.new(rcx, y0+0.72, rz0 + RD/2),
			Color3.fromRGB(72,74,80), Enum.Material.SmoothPlastic)

		-- Mobília simples: cama
		Part(Vector3.new(RW*0.55, 0.55, RD*0.45),
			CFrame.new(rcx - RW*0.1, y0+1.0, rz0 + RD*0.3),
			Color3.fromRGB(100,80,60), Enum.Material.SmoothPlastic)
		-- Travesseiro
		Part(Vector3.new(RW*0.25, 0.2, RD*0.12),
			CFrame.new(rcx - RW*0.1, y0+1.32, rz0 + RD*0.13),
			Color3.fromRGB(220,220,225), Enum.Material.SmoothPlastic)

		-- PORTA: Moldura
		local pz = rz0 + RD - 0.1
		-- moldura esq
		Part(Vector3.new(0.22, FH*0.73, 0.22),
			CFrame.new(rcx - 1.25, y0 + FH*0.365+0.35, pz),
			Color3.fromRGB(85,65,45), Enum.Material.WoodPlanks)
		-- moldura dir
		Part(Vector3.new(0.22, FH*0.73, 0.22),
			CFrame.new(rcx + 1.25, y0 + FH*0.365+0.35, pz),
			Color3.fromRGB(85,65,45), Enum.Material.WoodPlanks)
		-- moldura topo
		Part(Vector3.new(2.72, 0.22, 0.22),
			CFrame.new(rcx, y0 + FH*0.73+0.35, pz),
			Color3.fromRGB(85,65,45), Enum.Material.WoodPlanks)
		-- painel da porta
		local panel = Part(Vector3.new(2.28, FH*0.71, 0.16),
			CFrame.new(rcx, y0 + FH*0.355+0.35, pz),
			Color3.fromRGB(55,42,30), Enum.Material.Wood)
		panel.Name = "DoorPanel_"..roomNum
		-- painel superior (pequena janela de vidro na porta)
		Part(Vector3.new(1.6, FH*0.18, 0.1),
			CFrame.new(rcx, y0 + FH*0.61+0.35, pz-0.04),
			Color3.fromRGB(140,175,210), Enum.Material.Glass).Transparency = 0.4
		-- maçaneta
		Part(Vector3.new(0.24,0.24,0.24),
			CFrame.new(rcx + 0.85, y0 + FH*0.35+0.35, pz - 0.18),
			Color3.fromRGB(195,165,75), Enum.Material.Metal).Shape = Enum.PartType.Ball
		-- luz de status
		local sl = Part(Vector3.new(0.3,0.3,0.16),
			CFrame.new(rcx - 0.9, y0 + FH*0.62+0.35, pz - 0.1),
			Color3.fromRGB(255,50,50), Enum.Material.Neon)
		sl.Shape = Enum.PartType.Ball
		sl.Name  = "StatusLight_"..roomNum

		-- Número da porta (SurfaceGui)
		local numPart = Part(Vector3.new(1.1, 0.55, 0.06),
			CFrame.new(rcx, y0 + FH*0.83+0.35, pz - 0.02),
			Color3.fromRGB(10,10,10), Enum.Material.SmoothPlastic)
		numPart.Name = "NumPlate_"..roomNum
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Back
		sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sg.CanvasSize = Vector2.new(110,55)
		sg.Parent = numPart
		local nl = Instance.new("TextLabel")
		nl.Size = UDim2.new(1,0,1,0)
		nl.BackgroundTransparency = 1
		nl.Text = tostring(roomNum)
		nl.TextColor3 = (roomNum == BUTTON_ROOM) and Color3.fromRGB(255,220,0) or Color3.fromRGB(230,230,230)
		nl.TextScaled = true
		nl.Font = Enum.Font.GothamBold
		nl.Parent = sg

		-- ClickDetector
		local cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 8
		cd.Parent = panel

		doorPanels[roomNum] = {panel=panel, light=sl, click=cd}

		-- Quarto 73: botão
		if roomNum == BUTTON_ROOM then
			local ped = Part(Vector3.new(1.0, 0.9, 1.0),
				CFrame.new(rcx, y0+1.35, rz0 + RD*0.5),
				Color3.fromRGB(30,30,30), Enum.Material.Metal)
			local btn = Part(Vector3.new(0.8,0.28,0.8),
				CFrame.new(rcx, y0+1.94, rz0 + RD*0.5),
				Color3.fromRGB(255,25,25), Enum.Material.Neon)
			btn.Name = "WinButton"
			local pl = Instance.new("PointLight")
			pl.Color = Color3.fromRGB(255,30,30); pl.Brightness=3; pl.Range=14; pl.Parent=btn
			local bsg = Instance.new("SurfaceGui")
			bsg.Face = Enum.NormalId.Top
			bsg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
			bsg.CanvasSize = Vector2.new(160,80)
			bsg.Parent = btn
			local bl = Instance.new("TextLabel")
			bl.Size=UDim2.new(1,0,1,0); bl.BackgroundTransparency=1
			bl.Text="PRESSIONE"; bl.TextColor3=Color3.new(1,1,1)
			bl.TextScaled=true; bl.Font=Enum.Font.GothamBold; bl.Parent=bsg
			local bcd = Instance.new("ClickDetector")
			bcd.MaxActivationDistance=10; bcd.Parent=btn
			bcd.MouseClick:Connect(function(p)
				if gameActive and not gameEnded then
					gameEnded=true; gameActive=false
					REM_Win:FireAllClients()
					TweenService:Create(btn,TweenInfo.new(1),{Color=Color3.fromRGB(0,255,80)}):Play()
					pl.Color=Color3.fromRGB(0,255,80)
				end
			end)
		end

		-- Click handler
		local cn = roomNum
		cd.MouseClick:Connect(function(plr)
			if not gameActive then return end
			if openedRooms[cn] then return end
			REM_Minigame:FireClient(plr, cn)
		end)
	end
end

-- Constrói andares
for f = 0, FLOORS-1 do
	buildFloor(f, BX, BZ, 0, 0, false)
end

-- Parede lateral direita da asa A
Part(Vector3.new(0.5, FH*FLOORS, RD+6),
	CFrame.new(BX + AW + 0.25, BY + FH*FLOORS/2, BZ + RD/2),
	Color3.fromRGB(50,52,58), Enum.Material.Concrete)

-- Laje do topo
Part(Vector3.new(AW+2, 0.8, RD+6),
	CFrame.new(BX + AW/2, BY + FLOORS*FH + 0.4, BZ + RD/2),
	Color3.fromRGB(48,50,56), Enum.Material.Concrete)

-- ================================================================
-- ESCADAS (nas extremidades, 2 lados)
-- ================================================================
for f = 0, FLOORS-2 do
	local y0 = BY + f*FH
	for _, sx in ipairs({BX - 2, BX + AW - RW + 2}) do
		Part(Vector3.new(3, 0.4, 7),
			CFrame.new(sx, y0 + FH*0.52, BZ + RD + 1)
				* CFrame.Angles(math.rad(-28),0,0),
			Color3.fromRGB(80,82,88), Enum.Material.Metal)
		-- Degraus
		for s=0,4 do
			Part(Vector3.new(3,0.25,1.2),
				CFrame.new(sx, y0+0.9+s*FH*0.18, BZ+RD+2.1-s*0.7),
				Color3.fromRGB(90,92,98), Enum.Material.Metal)
		end
	end
end

print("[AIB] Prédio construído! ".. (FLOORS*ROOMS_PER) .." quartos.")

-- ================================================================
-- ÂNCORA DO TIMER (invisível, no centro do prédio)
-- ================================================================
local timerAnchor = Part(Vector3.new(0.1,0.1,0.1),
	CFrame.new(BX + AW/2, BY + FLOORS*FH + 5, BZ + RD/2),
	Color3.new(0,0,0), Enum.Material.SmoothPlastic, 1, true)
timerAnchor.Name = "TimerAnchor"
timerAnchor.CanCollide = false

-- ================================================================
-- ÁUDIO
-- ================================================================
local audioAnchor = Part(Vector3.new(0.1,0.1,0.1),
	CFrame.new(BX + AW/2, BY + FLOORS*FH/2, BZ + RD/2),
	Color3.new(0,0,0), Enum.Material.SmoothPlastic, 1, true)
audioAnchor.Name = "AudioAnchor"
audioAnchor.CanCollide = false

local audioIDs = {"rbxassetid://111781039353417","rbxassetid://136585544296968"}
local audioList = {}
for _, id in ipairs(audioIDs) do
	local s = Instance.new("Sound")
	s.SoundId = id; s.Volume = 0.65; s.Looped = true
	s.RollOffMaxDistance = 400; s.Parent = audioAnchor
	table.insert(audioList, s)
end

-- ================================================================
-- NPC — MÁSCARA DE CAVALO
-- ================================================================
local npcModel = Instance.new("Model")
npcModel.Name  = "HorseMaskKiller"
npcModel.Parent = workspace

-- Root (HumanoidRootPart)
local npcRoot = Instance.new("Part")
npcRoot.Name = "HumanoidRootPart"
npcRoot.Size = Vector3.new(2,2,1)
npcRoot.Color = Color3.fromRGB(15,15,15)
npcRoot.Material = Enum.Material.SmoothPlastic
npcRoot.Anchored = false
npcRoot.CanCollide = true
npcRoot.CFrame = CFrame.new(BX + RW*2, BY + FH*0 + 4, BZ + RD + 1)
npcRoot.Parent = npcModel

-- Torso
local npcTorso = Instance.new("Part")
npcTorso.Name="Torso"; npcTorso.Size=Vector3.new(2,2,1)
npcTorso.Color=Color3.fromRGB(15,15,15); npcTorso.Material=Enum.Material.SmoothPlastic
npcTorso.Anchored=false; npcTorso.CanCollide=false; npcTorso.Parent=npcModel
Weld(npcRoot, npcTorso)

-- Head
local npcHead = Instance.new("Part")
npcHead.Name="Head"; npcHead.Size=Vector3.new(1.8,1.8,1.8)
npcHead.Color=Color3.fromRGB(190,160,110); npcHead.Material=Enum.Material.SmoothPlastic
npcHead.Anchored=false; npcHead.CanCollide=false; npcHead.Parent=npcModel
Weld(npcRoot, npcHead, CFrame.new(0,2.1,0))

-- Focinho
local snout = Instance.new("Part")
snout.Name="Snout"; snout.Size=Vector3.new(0.85,0.82,2.3)
snout.Color=Color3.fromRGB(180,152,102); snout.Material=Enum.Material.SmoothPlastic
snout.Anchored=false; snout.CanCollide=false; snout.Parent=npcModel
Weld(npcRoot, snout, CFrame.new(0,1.72,-1.55))

-- Orelhas
for _, side in ipairs({-1,1}) do
	local ear = Instance.new("Part")
	ear.Size=Vector3.new(0.32,0.92,0.26); ear.Color=Color3.fromRGB(180,152,102)
	ear.Material=Enum.Material.SmoothPlastic; ear.Anchored=false; ear.CanCollide=false
	ear.Parent=npcModel
	Weld(npcRoot, ear, CFrame.new(side*0.58, 3.1, 0))
end

-- Braços
for _, side in ipairs({-1,1}) do
	local arm = Instance.new("Part")
	arm.Size=Vector3.new(0.7,2,0.7); arm.Color=Color3.fromRGB(15,15,15)
	arm.Material=Enum.Material.SmoothPlastic; arm.Anchored=false; arm.CanCollide=false
	arm.Parent=npcModel
	Weld(npcRoot, arm, CFrame.new(side*1.45, 0, 0))
end

-- Pernas
for _, side in ipairs({-1,1}) do
	local leg = Instance.new("Part")
	leg.Size=Vector3.new(0.7,2,0.7); leg.Color=Color3.fromRGB(15,15,15)
	leg.Material=Enum.Material.SmoothPlastic; leg.Anchored=false; leg.CanCollide=false
	leg.Parent=npcModel
	Weld(npcRoot, leg, CFrame.new(side*0.55, -2.1, 0))
end

-- Casaco (detalhe)
local coat = Instance.new("Part")
coat.Size=Vector3.new(2.1,1.1,1.05); coat.Color=Color3.fromRGB(35,35,35)
coat.Material=Enum.Material.SmoothPlastic; coat.Anchored=false; coat.CanCollide=false
coat.Parent=npcModel
Weld(npcRoot, coat, CFrame.new(0,-0.6,0))

-- Arma (rifle)
local gun = Instance.new("Part")
gun.Name="Gun"; gun.Size=Vector3.new(0.24,0.24,3.8)
gun.Color=Color3.fromRGB(25,25,25); gun.Material=Enum.Material.Metal
gun.Anchored=false; gun.CanCollide=false; gun.Parent=npcModel
Weld(npcRoot, gun, CFrame.new(1.2, 0.15, -2.0))

-- Flash do tiro
local gunFlash = Instance.new("PointLight")
gunFlash.Brightness=0; gunFlash.Color=Color3.fromRGB(255,200,100); gunFlash.Range=16
gunFlash.Parent=gun

-- Som de tiro
local gunSound = Instance.new("Sound")
gunSound.SoundId="rbxassetid://111026285687215"; gunSound.Volume=1.6
gunSound.RollOffMaxDistance=220; gunSound.Parent=npcRoot

-- Humanoid
local npcHum = Instance.new("Humanoid")
npcHum.MaxHealth=math.huge; npcHum.Health=math.huge
npcHum.WalkSpeed=13; npcHum.JumpPower=0
npcHum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
npcHum.Parent=npcModel
npcModel.PrimaryPart=npcRoot

-- IA do NPC
local npcFloor  = 0
local npcDir    = 1
local npcPX     = BX + RW*2
local lastShot  = 0

local function shootAt(plr)
	if not plr.Character then return end
	local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
	local hum = plr.Character:FindFirstChild("Humanoid")
	if not hrp or not hum then return end
	gunSound:Play()
	gunFlash.Brightness = 14
	task.delay(0.11, function() gunFlash.Brightness=0 end)
	local miss = math.random(100) <= 35
	local s = gun.Position + gun.CFrame.LookVector * (-1.9)
	local e = miss and (hrp.Position + Vector3.new(math.random(-5,5),math.random(-2,4),math.random(-5,5))) or hrp.Position
	local bul = Instance.new("Part")
	bul.Size=Vector3.new(0.1,0.1,(s-e).Magnitude)
	bul.CFrame=CFrame.lookAt((s+e)/2, e)
	bul.Color=Color3.fromRGB(255,235,80); bul.Material=Enum.Material.Neon
	bul.Anchored=true; bul.CanCollide=false; bul.Parent=workspace
	Debris:AddItem(bul, 0.13)
	if not miss then hum:TakeDamage(math.random(18,28)) end
end

RunService.Heartbeat:Connect(function(dt)
	if not gameActive or not npcAlive then return end
	if not npcRoot or not npcRoot.Parent then return end
	local spd = 11
	npcPX = npcPX + npcDir * spd * dt
	local minX = BX + 0.5
	local maxX = BX + AW - RW - 0.5
	if npcPX > maxX then npcPX=maxX; npcDir=-1; npcFloor=(npcFloor+1)%FLOORS
	elseif npcPX < minX then npcPX=minX; npcDir=1; npcFloor=(npcFloor+1)%FLOORS end
	local ty = BY + npcFloor*FH + 3.6
	local tp = Vector3.new(npcPX, ty, BZ + RD + 1)
	npcRoot.CFrame = CFrame.new(tp, tp + Vector3.new(npcDir,0,0))
	local now = tick()
	if now - lastShot >= 2.5 then
		local best, bestD = nil, math.huge
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character then
				local hrp = p.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local d = (hrp.Position - npcRoot.Position).Magnitude
					if d >= 7 and d <= 52 and d < bestD then
						local rp = RaycastParams.new()
						rp.FilterDescendantsInstances={npcModel}
						rp.FilterType=Enum.RaycastFilterType.Exclude
						local res = workspace:Raycast(npcRoot.Position, hrp.Position - npcRoot.Position, rp)
						if res and res.Instance and res.Instance:IsDescendantOf(p.Character) then
							bestD=d; best=p
						end
					end
				end
			end
		end
		if best then lastShot=now; shootAt(best) end
	end
end)

-- ================================================================
-- TRIGGER DE ENTRADA
-- ================================================================
local entryTrigger = Part(
	Vector3.new(AW+4, FLOORS*FH, RD+8),
	CFrame.new(BX+AW/2, BY+FLOORS*FH/2, BZ+RD/2),
	Color3.fromRGB(0,255,0), Enum.Material.Neon, 1, false)
entryTrigger.Name = "EntryTrigger"
entryTrigger.CanCollide = false

local alreadyEntered = {}

entryTrigger.Touched:Connect(function(hit)
	local plr = Players:GetPlayerFromCharacter(hit.Parent)
	if not plr or alreadyEntered[plr] then return end
	alreadyEntered[plr] = true
	for _,s in ipairs(audioList) do if not s.IsPlaying then s:Play() end end
	REM_Enter:FireClient(plr)
	if not gameActive and not gameEnded then
		gameActive = true
		task.spawn(function()
			while timerValue > 0 and gameActive and not gameEnded do
				task.wait(1)
				timerValue -= 1
				REM_Timer:FireAllClients(timerValue)
			end
			if not gameEnded and timerValue <= 0 then
				gameEnded=true; gameActive=false
				REM_GameOver:FireAllClients()
				for _,p in ipairs(Players:GetPlayers()) do
					if p.Character then
						local h=p.Character:FindFirstChild("Humanoid")
						if h then h.Health=0 end
					end
				end
				for f=0,FLOORS-1 do
					task.delay(f*0.22, function()
						for _=1,4 do
							local ex=Instance.new("Explosion")
							ex.Position=Vector3.new(BX+math.random(0,AW), BY+f*FH+2, BZ+math.random(0,RD))
							ex.BlastPressure=850000; ex.BlastRadius=22
							ex.ExplosionType=Enum.ExplosionType.CratersAndDebris
							ex.Parent=workspace
						end
					end)
				end
				task.delay(FLOORS*0.22+3, function()
					bModel:Destroy(); npcModel:Destroy()
				end)
			end
		end)
	end
end)

-- ================================================================
-- RESULTADO DO MINIGAME
-- ================================================================
REM_MResult.OnServerEvent:Connect(function(plr, roomNum, success)
	if openedRooms[roomNum] then return end
	if success then
		openedRooms[roomNum] = true
		local d = doorPanels[roomNum]
		if d then
			d.light.Color = Color3.fromRGB(0,255,80)
			TweenService:Create(d.panel, TweenInfo.new(0.65, Enum.EasingStyle.Sine),{
				CFrame = d.panel.CFrame * CFrame.new(-2.2,0,0) * CFrame.Angles(0,math.rad(85),0)
			}):Play()
		end
		REM_OpenDoor:FireAllClients(roomNum, true)
	else
		REM_OpenDoor:FireAllClients(roomNum, false)
	end
end)

Players.PlayerRemoving:Connect(function(p) alreadyEntered[p]=nil end)

-- ================================================================
-- LOCAL SCRIPT EMBUTIDO (injetado em StarterCharacterScripts)
-- ================================================================
local ls = Instance.new("LocalScript")
ls.Name = "AIB_Client"
ls.Source = [[
local Players       = game:GetService("Players")
local UIS           = game:GetService("UserInputService")
local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")
local player        = Players.LocalPlayer
local gui           = player.PlayerGui
local RF            = game.ReplicatedStorage:WaitForChild("AIBRemotes",20)
if not RF then return end
local REM_Timer    = RF:WaitForChild("Timer")
local REM_GameOver = RF:WaitForChild("GameOver")
local REM_Win      = RF:WaitForChild("Win")
local REM_Enter    = RF:WaitForChild("Enter")
local REM_Minigame = RF:WaitForChild("Minigame")
local REM_MResult  = RF:WaitForChild("MResult")
local REM_OpenDoor = RF:WaitForChild("OpenDoor")

-- ── OBSIDIAN THEME ─────────────────────────────────────────────
local OB = {
    Main    = Color3.fromRGB(25,25,25),
    Back    = Color3.fromRGB(15,15,15),
    Outline = Color3.fromRGB(40,40,40),
    Font    = Color3.fromRGB(255,255,255),
    Dim     = Color3.fromRGB(165,165,165),
    Accent  = Color3.fromRGB(125,85,255),
    Red     = Color3.fromRGB(255,70,70),
    Orange  = Color3.fromRGB(255,150,40),
    Green   = Color3.fromRGB(70,230,130),
    Font1   = Enum.Font.Code,
}

local function stroke(parent, col, th)
    local s = Instance.new("UIStroke")
    s.Color = col or OB.Outline; s.Thickness = th or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function corner(parent, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 4); c.Parent = parent
    return c
end

local function label(parent, txt, size, pos, col, z, xa)
    local l = Instance.new("TextLabel")
    l.Size = size; l.Position = pos; l.BackgroundTransparency = 1
    l.Text = txt; l.TextColor3 = col or OB.Font; l.TextScaled = true
    l.Font = OB.Font1; l.ZIndex = z or 1
    l.TextXAlignment = xa or Enum.TextXAlignment.Center
    l.Parent = parent
    return l
end

-- ── ScreenGui ──────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name="AIB_HUD"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.Parent=gui

-- ── TIMER (janela Obsidian) ────────────────────────────────────
local timerFrame = Instance.new("Frame")
timerFrame.Name="TimerFrame"
timerFrame.Size=UDim2.new(0,300,0,76)
timerFrame.Position=UDim2.new(0.5,-150,0,14)
timerFrame.BackgroundColor3=OB.Main
timerFrame.BorderSizePixel=0
timerFrame.Visible=false
timerFrame.ZIndex=5
timerFrame.Parent=sg
corner(timerFrame, 4)
stroke(timerFrame, OB.Outline, 1)

-- Barra de acento no topo (muda de cor conforme urgência)
local redBar=Instance.new("Frame")
redBar.Size=UDim2.new(1,0,0,2); redBar.Position=UDim2.new(0,0,0,0)
redBar.BackgroundColor3=OB.Accent; redBar.BorderSizePixel=0
redBar.ZIndex=6; redBar.Parent=timerFrame

-- Barra inferior (mantida p/ compatibilidade com a lógica)
local redBarBot=Instance.new("Frame")
redBarBot.Size=UDim2.new(1,0,0,2); redBarBot.Position=UDim2.new(0,0,1,-2)
redBarBot.BackgroundColor3=OB.Accent; redBarBot.BorderSizePixel=0
redBarBot.ZIndex=6; redBarBot.Parent=timerFrame

-- Cabeçalho
local tTopLabel = label(timerFrame, "TEMPO RESTANTE", UDim2.new(1,-20,0,16), UDim2.new(0,10,0,8), OB.Dim, 6, Enum.TextXAlignment.Left)

-- Divisória
local div=Instance.new("Frame")
div.Size=UDim2.new(1,-20,0,1); div.Position=UDim2.new(0,10,0,28)
div.BackgroundColor3=OB.Outline; div.BorderSizePixel=0; div.ZIndex=6; div.Parent=timerFrame

-- Número grande (MM:SS:ms)
local tNumLabel = label(timerFrame, "01:00:000", UDim2.new(1,-20,0,34), UDim2.new(0,10,0,34), OB.Font, 6, Enum.TextXAlignment.Left)

-- milissegundos
local msConn; local msExtra=0
RunService.RenderStepped:Connect(function(dt)
    if timerFrame.Visible then
        msExtra = (msExtra + dt*1000) % 1000
    end
end)

-- ── MINIGAME ───────────────────────────────────────────────────
local mgFrame=Instance.new("Frame")
mgFrame.Name="MinigameFrame"
mgFrame.Size=UDim2.new(1,0,1,0)
mgFrame.BackgroundColor3=OB.Back
mgFrame.BackgroundTransparency=0.35
mgFrame.Visible=false; mgFrame.ZIndex=15; mgFrame.Parent=sg

-- Janela central
local mgWin=Instance.new("Frame")
mgWin.Size=UDim2.new(0,360,0,420); mgWin.Position=UDim2.new(0.5,-180,0.5,-210)
mgWin.BackgroundColor3=OB.Main; mgWin.BorderSizePixel=0; mgWin.ZIndex=16; mgWin.Parent=mgFrame
corner(mgWin, 4); stroke(mgWin, OB.Outline, 1)

local mgAccent=Instance.new("Frame")
mgAccent.Size=UDim2.new(1,0,0,2); mgAccent.BackgroundColor3=OB.Accent
mgAccent.BorderSizePixel=0; mgAccent.ZIndex=17; mgAccent.Parent=mgWin

local mgTitle = label(mgWin, "PRECISÃO DE ABERTURA", UDim2.new(1,-24,0,22), UDim2.new(0,12,0,12), OB.Font, 17, Enum.TextXAlignment.Left)

local mgDiv=Instance.new("Frame")
mgDiv.Size=UDim2.new(1,-24,0,1); mgDiv.Position=UDim2.new(0,12,0,42)
mgDiv.BackgroundColor3=OB.Outline; mgDiv.BorderSizePixel=0; mgDiv.ZIndex=17; mgDiv.Parent=mgWin

-- Contador 0/5
local mgCounter = label(mgWin, "0 / 5", UDim2.new(1,-24,0,22), UDim2.new(0,12,0,52), OB.Accent, 17, Enum.TextXAlignment.Center)

-- Botão circular
local circleBtn=Instance.new("TextButton")
circleBtn.Size=UDim2.new(0,200,0,200)
circleBtn.Position=UDim2.new(0.5,-100,0.5,-40)
circleBtn.BackgroundColor3=OB.Accent
circleBtn.Text=""
circleBtn.AutoButtonColor=false
circleBtn.BorderSizePixel=0
circleBtn.ZIndex=18; circleBtn.Parent=mgFrame
corner(circleBtn, 100)
stroke(circleBtn, OB.Outline, 2)

local circleNum = label(circleBtn, "1", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), OB.Font, 19)

-- Instrução
local mgHint = label(mgWin, "Pressione  [E]  para abrir", UDim2.new(1,-24,0,18), UDim2.new(0,12,1,-30), OB.Dim, 17, Enum.TextXAlignment.Center)

-- ── POPUP DE RESULTADO ─────────────────────────────────────────
local popupFrame=Instance.new("Frame")
popupFrame.Name="PopupFrame"
popupFrame.Size=UDim2.new(0,560,0,150)
popupFrame.Position=UDim2.new(0.5,-280,0.5,-75)
popupFrame.BackgroundColor3=OB.Main
popupFrame.BorderSizePixel=0
popupFrame.Visible=false; popupFrame.ZIndex=20; popupFrame.Parent=sg
corner(popupFrame, 4)

local popupStroke = stroke(popupFrame, OB.Red, 1)

local popupTitle = label(popupFrame, "FALHOU!", UDim2.new(1,-24,0.42,0), UDim2.new(0,12,0.08,0), OB.Red, 21, Enum.TextXAlignment.Left)
local popupSub   = label(popupFrame, "A porta rejeitou sua chave.", UDim2.new(1,-24,0.3,0), UDim2.new(0,12,0.58,0), OB.Dim, 21, Enum.TextXAlignment.Left)

-- ── GAME OVER ──────────────────────────────────────────────────
local goFrame=Instance.new("Frame")
goFrame.Size=UDim2.new(1,0,1,0); goFrame.BackgroundColor3=OB.Back
goFrame.BackgroundTransparency=0.15; goFrame.BorderSizePixel=0
goFrame.Visible=false; goFrame.ZIndex=25; goFrame.Parent=sg

local goBox=Instance.new("Frame")
goBox.Size=UDim2.new(0,520,0,170); goBox.Position=UDim2.new(0.5,-260,0.5,-85)
goBox.BackgroundColor3=OB.Main; goBox.BorderSizePixel=0; goBox.ZIndex=26; goBox.Parent=goFrame
corner(goBox, 4); stroke(goBox, OB.Red, 1)

local goTitle = label(goBox, "TEMPO ESGOTADO", UDim2.new(1,-24,0.5,0), UDim2.new(0,12,0.1,0), OB.Red, 27)
local goSub   = label(goBox, "O prédio explodiu. Todos morreram.", UDim2.new(1,-24,0.22,0), UDim2.new(0,12,0.66,0), OB.Dim, 27)

-- ── WIN ────────────────────────────────────────────────────────
local winFrame=Instance.new("Frame")
winFrame.Size=UDim2.new(1,0,1,0); winFrame.BackgroundColor3=OB.Back
winFrame.BackgroundTransparency=0.15; winFrame.BorderSizePixel=0
winFrame.Visible=false; winFrame.ZIndex=25; winFrame.Parent=sg

local winBox=Instance.new("Frame")
winBox.Size=UDim2.new(0,520,0,170); winBox.Position=UDim2.new(0.5,-260,0.5,-85)
winBox.BackgroundColor3=OB.Main; winBox.BorderSizePixel=0; winBox.ZIndex=26; winBox.Parent=winFrame
corner(winBox, 4); stroke(winBox, OB.Green, 1)

local wTitle = label(winBox, "BOTÃO APERTADO!", UDim2.new(1,-24,0.5,0), UDim2.new(0,12,0.1,0), OB.Green, 27)
local wSub   = label(winBox, "Vocês sobreviveram. Parabéns!", UDim2.new(1,-24,0.22,0), UDim2.new(0,12,0.66,0), OB.Dim, 27)

-- ── LÓGICA MINIGAME ────────────────────────────────────────────
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
local currentRoom = nil
local pressCount  = 0
local PRESSES_NEEDED = 5
local mgActive    = false
local pressCD     = false

if isMobile then
    mgHint.Text = "Toque no botão para abrir"
end

local function showPopup(success)
    mgFrame.Visible = false
    mgActive = false
    pressCount = 0
    mgCounter.Text = "0 / "..PRESSES_NEEDED
    if success then
        popupStroke.Color = OB.Accent
        popupTitle.Text   = "A porta foi aberta com sucesso!"
        popupTitle.TextColor3 = OB.Accent
        popupSub.Text     = "Força, Resistência e Recompensa de Passagem"
        popupSub.TextColor3 = OB.Dim
    else
        popupStroke.Color = OB.Red
        popupTitle.Text   = "FALHOU!"
        popupTitle.TextColor3 = OB.Red
        popupSub.Text     = "A porta rejeitou sua chave."
        popupSub.TextColor3 = OB.Dim
    end
    popupFrame.Visible = true
    task.delay(2.8, function()
        TweenService:Create(popupFrame, TweenInfo.new(0.4), {BackgroundTransparency=1}):Play()
        TweenService:Create(popupTitle, TweenInfo.new(0.4), {TextTransparency=1}):Play()
        TweenService:Create(popupSub,   TweenInfo.new(0.4), {TextTransparency=1}):Play()
        task.delay(0.42, function()
            popupFrame.Visible=false
            popupFrame.BackgroundTransparency=0
            popupTitle.TextTransparency=0
            popupSub.TextTransparency=0
        end)
    end)
end

local function onPress()
    if not mgActive or pressCD then return end
    pressCD = true
    task.delay(0.18, function() pressCD=false end)
    pressCount = pressCount + 1
    mgCounter.Text = pressCount.." / "..PRESSES_NEEDED
    -- Animação do círculo
    TweenService:Create(circleBtn, TweenInfo.new(0.08),{
        Size=UDim2.new(0,175,0,175),
        Position=UDim2.new(0.5,-87.5,0.5,-27.5)
    }):Play()
    task.delay(0.09, function()
        TweenService:Create(circleBtn, TweenInfo.new(0.1),{
            Size=UDim2.new(0,200,0,200),
            Position=UDim2.new(0.5,-100,0.5,-40)
        }):Play()
    end)
    circleNum.Text = tostring(pressCount)
    if pressCount >= PRESSES_NEEDED then
        local cr = currentRoom
        currentRoom = nil
        REM_MResult:FireServer(cr, true)
        showPopup(true)
    end
end

circleBtn.MouseButton1Click:Connect(onPress)

UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.E then onPress() end
    if inp.KeyCode == Enum.KeyCode.Q and mgActive then
        -- Cancela
        local cr = currentRoom; currentRoom=nil
        mgActive=false; mgFrame.Visible=false
        pressCount=0; mgCounter.Text="0 / "..PRESSES_NEEDED
        REM_MResult:FireServer(cr, false)
        showPopup(false)
    end
end)

-- Tempo limite do minigame (15 s para apertar 5x)
local mgTimeLeft = 0
local mgTimerConn

REM_Minigame.OnClientEvent:Connect(function(roomNum)
    currentRoom = roomNum
    pressCount  = 0
    pressCD     = false
    mgActive    = true
    mgCounter.Text = "0 / "..PRESSES_NEEDED
    circleNum.Text = "1"
    circleBtn.BackgroundColor3 = OB.Accent
    mgFrame.Visible = true
    -- Timeout: 12 segundos
    if mgTimerConn then mgTimerConn:Disconnect() end
    mgTimeLeft = 12
    mgTimerConn = RunService.Heartbeat:Connect(function(dt)
        if not mgActive then mgTimerConn:Disconnect(); return end
        mgTimeLeft = mgTimeLeft - dt
        -- Muda cor do círculo conforme urgência
        local t = math.clamp(mgTimeLeft/12, 0, 1)
        circleBtn.BackgroundColor3 = Color3.fromRGB(
            math.floor(155 + (1-t)*80),
            math.floor(80*t),
            math.floor(210*t)
        )
        if mgTimeLeft <= 0 then
            mgTimerConn:Disconnect()
            local cr = currentRoom; currentRoom=nil
            mgActive=false; mgFrame.Visible=false
            pressCount=0; mgCounter.Text="0 / "..PRESSES_NEEDED
            REM_MResult:FireServer(cr, false)
            showPopup(false)
        end
    end)
end)

-- ── TIMER update ───────────────────────────────────────────────
REM_Enter.OnClientEvent:Connect(function()
    timerFrame.Visible = true
end)

REM_Timer.OnClientEvent:Connect(function(secs)
    timerFrame.Visible = true
    local m = math.floor(secs/60)
    local s = secs % 60
    local ms = math.floor(msExtra)
    tNumLabel.Text = string.format("%02d:%02d:%03d", m, s, ms)
    if secs <= 60 then
        tNumLabel.TextColor3 = OB.Red
        redBar.BackgroundColor3 = OB.Red
        redBarBot.BackgroundColor3 = OB.Red
    elseif secs <= 300 then
        tNumLabel.TextColor3 = OB.Orange
    else
        tNumLabel.TextColor3 = OB.Font
    end
end)

-- Atualiza ms em tempo real
RunService.RenderStepped:Connect(function(dt)
    if timerFrame.Visible then
        local txt = tNumLabel.Text
        if #txt >= 9 then
            local prefix = txt:sub(1,6)
            tNumLabel.Text = prefix .. string.format("%03d", math.floor(msExtra))
        end
    end
end)

REM_GameOver.OnClientEvent:Connect(function()
    timerFrame.Visible=false; mgFrame.Visible=false
    goFrame.Visible=true
    task.delay(6, function() goFrame.Visible=false end)
end)

REM_Win.OnClientEvent:Connect(function()
    timerFrame.Visible=false; mgFrame.Visible=false
    winFrame.Visible=true
    task.delay(6, function() winFrame.Visible=false end)
end)

REM_OpenDoor.OnClientEvent:Connect(function(roomNum, success)
    -- feedback sonoro opcional
end)
]]
ls.Parent = game:GetService("StarterPlayer").StarterCharacterScripts

print("[AIB] ✅ Script completo carregado! "..FLOORS*ROOMS_PER.." quartos | Quarto "..BUTTON_ROOM.." = botão de vitória")