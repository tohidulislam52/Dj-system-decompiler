--[[
	GLightsControlScript — জায়গা: StarterGui > GLightsControlPanel (LocalScript)

	ফিক্স (ISSUES.md #1):
	  AutoSync আর AutoCue আগে সার্ভারের প্রত্যেক প্লেয়ারের কাছে চলত, তাই
	  প্লেয়ার যত বেশি, লাইটের কমান্ডও তত গুণ। এখন শুধু সার্ভারের বাছাই করা
	  "কন্ডাক্টর" (ReplicatedStorage-এর DJConductor attribute) এগুলো পাঠায়,
	  target = "Auto" দিয়ে। AutoSync/Auto বাটন এখন সবার জন্য একসাথে চালু/বন্ধ
	  করে (শুধু অ্যাডমিন)।
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = script.Parent
local mainFrame = screenGui:WaitForChild("MainFrame")
local titleBar = mainFrame:WaitForChild("TitleBar")
local tabContainer = mainFrame:WaitForChild("TabContainer")
local contentContainer = mainFrame:WaitForChild("ContentContainer")
local scrollFrame = contentContainer:WaitForChild("ContentScroll")

local Remote = ReplicatedStorage:WaitForChild("DJSystem"):WaitForChild("Remotes"):WaitForChild("GLightsRemote")
-- MusicFolder দূরের Part, StreamingEnabled-এ শুরুতে না-ও থাকতে পারে;
-- তাই এখানে WaitForChild না করে findCurrentPlayingSound প্রতিবার খুঁজে নেয়।

local function findCurrentPlayingSound()
	local musicHandler = workspace:FindFirstChild("MusicFolder")
	if not musicHandler then return nil end

	for _, child in ipairs(musicHandler:GetChildren()) do
		if child:IsA("Sound") and child.IsPlaying then
			return child
		end
	end
	return nil
end


local selectedLightType = "All"
local isDragging = false
local lastBeat = 0.10
local threshold = 200 -- Atur sensitivitas bass di sini
local dragStartPos = Vector2.new()
local frameStartPos = UDim2.new()

local currentAutoCue = nil
local autoCueInterval = 5 -- detik pergantian antar cue

-- PyroSyncRemote-ই অটো-মোডের সব flag বদলায় (DJAuthority দেখুন)
local AutoModeRemote = ReplicatedStorage:WaitForChild("DJSystem"):WaitForChild("Remotes"):WaitForChild("PyroSyncRemote")

-- এই ক্লায়েন্ট কি এখন অটো-শো চালাবে?
local function isConductor()
	return ReplicatedStorage:GetAttribute("DJConductor") == player.UserId
end

local function isAutoSyncOn()
	return ReplicatedStorage:GetAttribute("DJAutoLights") ~= false
end

local function isAutoCueOn()
	return ReplicatedStorage:GetAttribute("DJAutoCue") ~= false
end

local lightFolderNames = {
	["All"] = true,
	["Bars"] = "Bars",
	["Heads"] = "Heads",
	["LEDs"] = "LEDs",
	["LineBars"] = "LineBars",
	["Strobes"] = "Strobes",
	["Washes"] = "Washes",
}

-- ==================== CLOSE BUTTON ====================
local closeBtn = titleBar:WaitForChild("CloseBtn")
closeBtn.MouseButton1Click:Connect(function()
	screenGui.MainFrame.Visible = false
end)

-- ==================== TAB SYSTEM ====================
local tabNames = {"All Lights", "Colors", "Movement", "Beam/Gobo", "Effects", "Settings"}

for i, tabName in ipairs(tabNames) do
	local tabBtn = tabContainer:FindFirstChild(tabName .. "Tab")
	if tabBtn then
		tabBtn.MouseButton1Click:Connect(function()
			for _, otherTab in ipairs(tabContainer:GetChildren()) do
				if otherTab:IsA("TextButton") then
					otherTab.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
					otherTab.TextColor3 = Color3.fromRGB(180, 180, 200)
				end
			end
			tabBtn.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
			tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end)
	end
end

-- ==================== LIGHT TYPE SELECTION ====================
local allLightsSection = scrollFrame:FindFirstChild("Power Control")
if allLightsSection then
	for lightType, _ in pairs(lightFolderNames) do
		local btn = allLightsSection:FindFirstChild(lightType .. "Btn")
		if btn then
			btn.MouseButton1Click:Connect(function()
				for lt, _ in pairs(lightFolderNames) do
					local otherBtn = allLightsSection:FindFirstChild(lt .. "Btn")
					if otherBtn then
						otherBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 160)
					end
				end
				btn.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
				selectedLightType = lightType
				print("Selected light type: " .. lightType)
			end)
		end
	end
end

-- ==================== HELPER FUNCTION TO SEND COMMAND (CLIENT) ====================
local Remote = ReplicatedStorage:WaitForChild("DJSystem"):WaitForChild("Remotes"):WaitForChild("GLightsRemote")

local function sendCommand(action, ...)
	local args = {...}
	Remote:FireServer(selectedLightType, action, table.unpack(args))
end

-- অটো-সিঙ্ক/অটো-কিউর কমান্ড: সব গ্রুপে যায়, সার্ভার শুধু কন্ডাক্টরেরটা নেয়
local function sendAutoCommand(action, ...)
	Remote:FireServer("Auto", action, ...)
end



-- ==================== AUTOSYNC LOGIC ====================
local advancedSettings = scrollFrame:WaitForChild("Advanced Settings")
local autoSyncBtn = advancedSettings:WaitForChild("AutoSync")

-- বাটনের রং সার্ভারের অবস্থা দেখে বদলায়
local function updateAutoSyncBtn()
	if isAutoSyncOn() then
		autoSyncBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
	else
		autoSyncBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
	end
end
updateAutoSyncBtn()
ReplicatedStorage:GetAttributeChangedSignal("DJAutoLights"):Connect(updateAutoSyncBtn)

autoSyncBtn.MouseButton1Click:Connect(function()
	AutoModeRemote:FireServer("SET_AUTO_LIGHTS", not isAutoSyncOn())
end)

RunService.RenderStepped:Connect(function()
	if not isConductor() or not isAutoSyncOn() then
		return
	end
	local currentMusic = findCurrentPlayingSound()
	if currentMusic and currentMusic.IsPlaying then
		local loudness = currentMusic.PlaybackLoudness

		if loudness > threshold and (tick() - lastBeat) > 0.12 then
			lastBeat = tick()

			local randomColor = Color3.fromHSV(math.random(), 0.7, 1)
			sendAutoCommand("Color", randomColor)
			sendAutoCommand("Dimness", 1)

			task.delay(0.08, function()
				if isConductor() and isAutoSyncOn() then sendAutoCommand("Dimness", 0.3) end
			end)

			if loudness > 200 then -- Nilai ini diturunkan sedikit agar lebih responsif

				local maxLoudness = 1000
				local minSpeed = 0.01
				local maxSpeed = 0.1

				local speedPercent = math.clamp((loudness - 300) / (maxLoudness - 300), 0, 1)
				local dynamicSpeed = minSpeed + (speedPercent * (maxSpeed - minSpeed))

				sendAutoCommand("MotorSpeed", dynamicSpeed)

				local randomPan = math.random(-180, 180)
				local randomTilt = math.random(0, 90)

				sendAutoCommand("Pan", randomPan)
				sendAutoCommand("Tilt", randomTilt)
			end
		end
	end
end)

-- ==================== POWER CONTROL ====================
if allLightsSection then
	local onBtn = allLightsSection:FindFirstChild("OnBtn")
	local offBtn = allLightsSection:FindFirstChild("OffBtn")
	local fadeOnBtn = allLightsSection:FindFirstChild("FadeOnBtn")
	local fadeOffBtn = allLightsSection:FindFirstChild("FadeOffBtn")
	
	if onBtn then
		onBtn.MouseButton1Click:Connect(function()
			sendCommand("On")
		end)
	end
	
	if offBtn then
		offBtn.MouseButton1Click:Connect(function()
			sendCommand("Off")
		end)
	end
	
	if fadeOnBtn then
		fadeOnBtn.MouseButton1Click:Connect(function()
			sendCommand("FadeOn")
		end)
	end
	
	if fadeOffBtn then
		fadeOffBtn.MouseButton1Click:Connect(function()
			sendCommand("FadeOff")
		end)
	end
end

-- ==================== DIMNESS CONTROL ====================
local brightnessSection = scrollFrame:FindFirstChild("Brightness / Dimness")
if brightnessSection then
	local dimnessContainer = brightnessSection:FindFirstChild("DimnessContainer")
	if dimnessContainer then
		local slider = dimnessContainer:FindFirstChild("Slider")
		local fill = slider:FindFirstChild("Fill")
		local label = dimnessContainer:FindFirstChild("Label")
		
		local function updateDimness(x)
			local relX = math.clamp(x, 0, slider.AbsoluteSize.X)
			local percent = relX / slider.AbsoluteSize.X
			fill.Size = UDim2.new(percent, 0, 1, 0)
			local value = percent
			label.Text = "Dimness: " .. string.format("%.2f", value)
			sendCommand("Dimness", value)
		end
		
		slider.MouseButton1Down:Connect(function(x)
			updateDimness(x - slider.AbsolutePosition.X)
			local conn
			conn = slider.MouseMoved:Connect(function(x)
				updateDimness(x - slider.AbsolutePosition.X)
			end)
			slider.MouseButton1Up:Once(function()
				conn:Disconnect()
			end)
		end)
	end
end

-- ==================== COLOR CONTROL ====================
local colorSection = scrollFrame:FindFirstChild("Color Control")
if colorSection then
	local colorPresets = {
		{ name = "White", color = Color3.fromRGB(255, 255, 255) },
		{ name = "Red", color = Color3.fromRGB(255, 50, 50) },
		{ name = "Green", color = Color3.fromRGB(50, 255, 50) },
		{ name = "Blue", color = Color3.fromRGB(50, 100, 255) },
		{ name = "Yellow", color = Color3.fromRGB(255, 255, 50) },
		{ name = "Purple", color = Color3.fromRGB(200, 50, 255) },
		{ name = "Cyan", color = Color3.fromRGB(50, 255, 255) },
		{ name = "Orange", color = Color3.fromRGB(255, 150, 50) },
		{ name = "Pink", color = Color3.fromRGB(255, 100, 200) },
		{ name = "Gold", color = Color3.fromRGB(255, 200, 50) },
	}
	
	for _, preset in ipairs(colorPresets) do
		local btn = colorSection:FindFirstChild(preset.name .. "Btn")
		if btn then
			btn.MouseButton1Click:Connect(function()
				sendCommand("Color", preset.color)
			end)
		end
	end
end

-- ==================== MOVEMENT CONTROL ====================
local movementSection = scrollFrame:FindFirstChild("Motor Movement (Tilt/Pan)")
if movementSection then
	local tiltContainer = movementSection:FindFirstChild("TiltContainer")
	if tiltContainer then
		local slider = tiltContainer:FindFirstChild("Slider")
		local fill = slider:FindFirstChild("Fill")
		local label = tiltContainer:FindFirstChild("Label")
		
		local function updateTilt(x)
			local relX = math.clamp(x, 0, slider.AbsoluteSize.X)
			local percent = relX / slider.AbsoluteSize.X
			fill.Size = UDim2.new(percent, 0, 1, 0)
			local value = -180 + (percent * 360)
			label.Text = "Tilt: " .. string.format("%.1f", value) .. "°"
			sendCommand("Tilt", value)
		end
		
		slider.MouseButton1Down:Connect(function(x)
			updateTilt(x - slider.AbsolutePosition.X)
			local conn
			conn = slider.MouseMoved:Connect(function(x)
				updateTilt(x - slider.AbsolutePosition.X)
			end)
			slider.MouseButton1Up:Once(function()
				conn:Disconnect()
			end)
		end)
	end
	
	local panContainer = movementSection:FindFirstChild("PanContainer")
	if panContainer then
		local slider = panContainer:FindFirstChild("Slider")
		local fill = slider:FindFirstChild("Fill")
		local label = panContainer:FindFirstChild("Label")
		
		local function updatePan(x)
			local relX = math.clamp(x, 0, slider.AbsoluteSize.X)
			local percent = relX / slider.AbsoluteSize.X
			fill.Size = UDim2.new(percent, 0, 1, 0)
			local value = -180 + (percent * 360)
			label.Text = "Pan: " .. string.format("%.1f", value) .. "°"
			sendCommand("Pan", value)
		end
		
		slider.MouseButton1Down:Connect(function(x)
			updatePan(x - slider.AbsolutePosition.X)
			local conn
			conn = slider.MouseMoved:Connect(function(x)
				updatePan(x - slider.AbsolutePosition.X)
			end)
			slider.MouseButton1Up:Once(function()
				conn:Disconnect()
			end)
		end)
	end
	
	local motorSpeedContainer = movementSection:FindFirstChild("Motor SpeedContainer")
	if motorSpeedContainer then
		local slider = motorSpeedContainer:FindFirstChild("Slider")
		local fill = slider:FindFirstChild("Fill")
		local label = motorSpeedContainer:FindFirstChild("Label")
		
		local function updateMotorSpeed(x)
			local relX = math.clamp(x, 0, slider.AbsoluteSize.X)
			local percent = relX / slider.AbsoluteSize.X
			fill.Size = UDim2.new(percent, 0, 1, 0)
			local value = 0.001 + (percent * 0.099)
			label.Text = "Motor Speed: " .. string.format("%.3f", value)
			sendCommand("MotorSpeed", value)
		end
		
		slider.MouseButton1Down:Connect(function(x)
			updateMotorSpeed(x - slider.AbsolutePosition.X)
			local conn
			conn = slider.MouseMoved:Connect(function(x)
				updateMotorSpeed(x - slider.AbsolutePosition.X)
			end)
			slider.MouseButton1Up:Once(function()
				conn:Disconnect()
			end)
		end)
	end
end

-- ==================== BEAM/GOBO CONTROL ====================
local beamGoboSection = scrollFrame:FindFirstChild("Beam & Gobo Control")
if beamGoboSection then
	local beamModes = {"NoBeam", "Beam", "Gobo"}
	for _, mode in ipairs(beamModes) do
		local btn = beamGoboSection:FindFirstChild(mode .. "Btn")
		if btn then
			btn.MouseButton1Click:Connect(function()
				sendCommand("BeamMode", mode)
			end)
		end
	end
	
	local beamThicknessContainer = beamGoboSection:FindFirstChild("Beam ThicknessContainer")
	if beamThicknessContainer then
		local slider = beamThicknessContainer:FindFirstChild("Slider")
		local fill = slider:FindFirstChild("Fill")
		local label = beamThicknessContainer:FindFirstChild("Label")
		
		local function updateBeamThickness(x)
			local relX = math.clamp(x, 0, slider.AbsoluteSize.X)
			local percent = relX / slider.AbsoluteSize.X
			fill.Size = UDim2.new(percent, 0, 1, 0)
			local value = 0.1 + (percent * 2.9)
			label.Text = "Beam Thickness: " .. string.format("%.2f", value)
			sendCommand("BeamThickness", value)
		end
		
		slider.MouseButton1Down:Connect(function(x)
			updateBeamThickness(x - slider.AbsolutePosition.X)
			local conn
			conn = slider.MouseMoved:Connect(function(x)
				updateBeamThickness(x - slider.AbsolutePosition.X)
			end)
			slider.MouseButton1Up:Once(function()
				conn:Disconnect()
			end)
		end)
	end
	
	local goboSpreadContainer = beamGoboSection:FindFirstChild("Gobo SpreadContainer")
	if goboSpreadContainer then
		local slider = goboSpreadContainer:FindFirstChild("Slider")
		local fill = slider:FindFirstChild("Fill")
		local label = goboSpreadContainer:FindFirstChild("Label")
		
		local function updateGoboSpread(x)
			local relX = math.clamp(x, 0, slider.AbsoluteSize.X)
			local percent = relX / slider.AbsoluteSize.X
			fill.Size = UDim2.new(percent, 0, 1, 0)
			local value = 0.1 + (percent * 2.9)
			label.Text = "Gobo Spread: " .. string.format("%.2f", value)
			sendCommand("GoboSpread", value)
		end
		
		slider.MouseButton1Down:Connect(function(x)
			updateGoboSpread(x - slider.AbsolutePosition.X)
			local conn
			conn = slider.MouseMoved:Connect(function(x)
				updateGoboSpread(x - slider.AbsolutePosition.X)
			end)
			slider.MouseButton1Up:Once(function()
				conn:Disconnect()
			end)
		end)
	end
end

-- ==================== EFFECTS CONTROL ====================
local effectsSection = scrollFrame:FindFirstChild("Effects & Cues")
if effectsSection then
	local cueMappings = {
		["Cue1Btn"] = "State.Cue1",
		["Cue2Btn"] = "State.Cue2",
		["Cue3Btn"] = "State.Cue3",
		["Cue4Btn"] = "State.Cue4",
		["Cue5Btn"] = "State.Cue5",
		["Cue6Btn"] = "State.Cue9",
		["Cue7Btn"] = "State.Cue7",
		["ChaseBtn"] = "BumpRandom", 
	}
	
	for btnName, cueName in pairs(cueMappings) do
		local btn = effectsSection:FindFirstChild(btnName)
		if btn then
			btn.MouseButton1Click:Connect(function()
				local isActive = btn.BackgroundColor3 == Color3.fromRGB(100, 200, 100)
				if isActive then
					btn.BackgroundColor3 = Color3.fromRGB(120, 80, 160)
					sendCommand("Cue", cueName, false)
				else
					btn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
					sendCommand("Cue", cueName, true)
				end
			end)
		end
	end
	
	local fadeSpeedContainer = effectsSection:FindFirstChild("Fade SpeedContainer")
	if fadeSpeedContainer then
		local slider = fadeSpeedContainer:FindFirstChild("Slider")
		local fill = slider:FindFirstChild("Fill")
		local label = fadeSpeedContainer:FindFirstChild("Label")
		
		local function updateFadeSpeed(x)
			local relX = math.clamp(x, 0, slider.AbsoluteSize.X)
			local percent = relX / slider.AbsoluteSize.X
			fill.Size = UDim2.new(percent, 0, 1, 0)
			local value = 0.1 + (percent * 4.9)
			label.Text = "Fade Speed: " .. string.format("%.2f", value)
			sendCommand("FadeSpeed", value)
		end
		
		slider.MouseButton1Down:Connect(function(x)
			updateFadeSpeed(x - slider.AbsolutePosition.X)
			local conn
			conn = slider.MouseMoved:Connect(function(x)
				updateFadeSpeed(x - slider.AbsolutePosition.X)
			end)
			slider.MouseButton1Up:Once(function()
				conn:Disconnect()
			end)
		end)
	end
	
	local cueSpeedContainer = effectsSection:FindFirstChild("Cue SpeedContainer")
	if cueSpeedContainer then
		local slider = cueSpeedContainer:FindFirstChild("Slider")
		local fill = slider:FindFirstChild("Fill")
		local label = cueSpeedContainer:FindFirstChild("Label")
		
		local function updateCueSpeed(x)
			local relX = math.clamp(x, 0, slider.AbsoluteSize.X)
			local percent = relX / slider.AbsoluteSize.X
			fill.Size = UDim2.new(percent, 0, 1, 0)
			local value = 0.1 + (percent * 4.9)
			label.Text = "Cue Speed: " .. string.format("%.2f", value)
			sendCommand("CueSpeed", value)
		end
		
		slider.MouseButton1Down:Connect(function(x)
			updateCueSpeed(x - slider.AbsolutePosition.X)
			local conn
			conn = slider.MouseMoved:Connect(function(x)
				updateCueSpeed(x - slider.AbsolutePosition.X)
			end)
			slider.MouseButton1Up:Once(function()
				conn:Disconnect()
			end)
		end)
	end
	
	-- ==================== AUTO CUE LOGIC ====================
	local autoBtn = effectsSection:FindFirstChild("AutoBtn")
	if autoBtn then
		local availableCues = {
			"State.Cue1",
			"State.Cue2",
			"State.Cue3",
			"State.Cue4",
			"State.Cue5",
			"State.Cue9",
			"State.Cue7",
			"BumpRandom",
		}

		local function getCueButtonFromName(cueName)
			for btnName, cName in pairs(cueMappings) do
				if cName == cueName then
					return effectsSection:FindFirstChild(btnName)
				end
			end
			return nil
		end

		local function clearAutoCueButton()
			if currentAutoCue then
				local cueBtn = getCueButtonFromName(currentAutoCue)
				if cueBtn then
					cueBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 160)
				end
				currentAutoCue = nil
			end
		end

		-- আগের কিউ বন্ধ করার কাজ সার্ভার করে (একসাথে একটাই অটো-কিউ রাখে)
		local function runRandomCue()
			local previousCue = currentAutoCue
			clearAutoCueButton()

			local newCue
			repeat
				newCue = availableCues[math.random(1, #availableCues)]
			until newCue ~= previousCue or #availableCues == 1

			currentAutoCue = newCue
			sendAutoCommand("Cue", currentAutoCue, true)

			local cueBtn = getCueButtonFromName(currentAutoCue)
			if cueBtn then
				cueBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
			end
		end

		-- লুপ সবসময় চলে, কিন্তু কিউ বদলায় শুধু কন্ডাক্টরের কাছে
		task.spawn(function()
			while true do
				if isConductor() and isAutoCueOn() then
					runRandomCue()
				else
					clearAutoCueButton()
				end
				task.wait(autoCueInterval)
			end
		end)

		-- বাটনের রং সার্ভারের অবস্থা দেখে বদলায়
		local function updateAutoBtn()
			if isAutoCueOn() then
				autoBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
			else
				autoBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 160)
			end
		end
		updateAutoBtn()
		ReplicatedStorage:GetAttributeChangedSignal("DJAutoCue"):Connect(updateAutoBtn)

		autoBtn.MouseButton1Click:Connect(function()
			AutoModeRemote:FireServer("SET_AUTO_CUE", not isAutoCueOn())
		end)
	end
end

-- ==================== SETTINGS TOGGLES ====================
local settingsSection = scrollFrame:FindFirstChild("Advanced Settings")
if settingsSection then
	-- Toggle yang bisa dipanggil langsung
	local directToggles = {
		"SmoothColor",
		"AnimatedGradients",
		"LoopCues",
	}
	
	-- Toggle yang perlu via SetGlobalCueSetting
	local globalCueToggles = {
		"Overshoot",
		"GroupRandom",
		"KillCues",
	}

	for _, toggleName in ipairs(directToggles) do
		local btn = settingsSection:FindFirstChild(toggleName .. "Toggle")
		if btn then
			btn.MouseButton1Click:Connect(function()
				local isActive = btn.BackgroundColor3 == Color3.fromRGB(60, 160, 80)
				if isActive then
					btn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
					sendCommand(toggleName, false)
				else
					btn.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
					sendCommand(toggleName, true)
				end
			end)
		end
	end

	for _, toggleName in ipairs(globalCueToggles) do
		local btn = settingsSection:FindFirstChild(toggleName .. "Toggle")
		if btn then
			btn.MouseButton1Click:Connect(function()
				local isActive = btn.BackgroundColor3 == Color3.fromRGB(60, 160, 80)
				if isActive then
					btn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
					sendCommand("SetGlobalCueSetting", toggleName, false)
				else
					btn.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
					sendCommand("SetGlobalCueSetting", toggleName, true)
				end
			end)
		end
	end
	
	local resetBtn = settingsSection:FindFirstChild("ResetBtn")
	if resetBtn then
		resetBtn.MouseButton1Click:Connect(function()
			sendCommand("HardReset")
		end)
	end
end

print("GLights Control Panel initialized successfully!")
print("[Asset] Sync Glights by A Studio")

local UserInputService = game:GetService("UserInputService")
local dragging, dragStart, startPos
mainFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position
	end
end)

mainFrame.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)
