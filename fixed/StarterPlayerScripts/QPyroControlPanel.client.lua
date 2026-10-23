--[[
	QPyroControlPanel — জায়গা: StarterPlayer > StarterPlayerScripts (LocalScript)

	ফিক্স (ISSUES.md #1):
	  আগে এই স্ক্রিপ্ট সার্ভারের প্রত্যেক প্লেয়ারের কাছে বাসের বিট ধরে আগুন
	  চালাত, তাই প্লেয়ার যত বেশি, আগুনও তত বেশি। এখন শুধু সার্ভারের বাছাই
	  করা "কন্ডাক্টর" (ReplicatedStorage-এর DJConductor attribute) বিট পাঠায়।
	  আগুন বন্ধ করার কাজ সার্ভার নিজে করে।
	  Auto বাটন এখন সবার জন্য একসাথে অটো-মোড চালু/বন্ধ করে (শুধু অ্যাডমিন)।
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local QPyroRemote = ReplicatedStorage:WaitForChild("QPyroRemote")
local PyroSyncRemote = ReplicatedStorage:WaitForChild("PyroSyncRemote")

local playerGui = player:WaitForChild("PlayerGui")
local screenGui = playerGui:WaitForChild("QPyroControlPanel")
local mainFrame = screenGui:WaitForChild("Frame")
local scrollingFrame = mainFrame:WaitForChild("ScrollingFrame")

local effectContainer = scrollingFrame:WaitForChild("Effect")
local specialEffectContainer = scrollingFrame:WaitForChild("SpesialEffect")

local lastBassTime = 0

local autoPool = {"FPA", "FPB", "FPC"}

-- Setting Sensitivitas Bass
local bassCooldown = 0.34
local minLoudness = 250
local spikeMultiplier = 1.4 --Harus 1.4 kali lebih kuat dari rata" volume
local volumeHistory = {}
local maxHistorySize = 10

-- এই ক্লায়েন্ট কি এখন অটো-শো চালাবে?
local function isConductor()
	return ReplicatedStorage:GetAttribute("DJConductor") == player.UserId
end

local function isAutoPyroOn()
	return ReplicatedStorage:GetAttribute("DJAutoPyro") ~= false
end


local function connectEffectButton(button, effectKey)
	local stroke = button:FindFirstChild("IndicatorStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = "IndicatorStroke"
		stroke.Color = Color3.fromRGB(0, 0, 0)
		stroke.Thickness = 2
		stroke.Parent = button
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end

	button.MouseButton1Down:Connect(function()
		QPyroRemote:FireServer(effectKey, true)
		stroke.Color = Color3.fromRGB(0, 255, 0)
	end)

	button.MouseButton1Up:Connect(function()
		QPyroRemote:FireServer(effectKey, false)
		stroke.Color = Color3.fromRGB(0, 0, 0)
	end)
end


-- শুধু "চালু" পাঠানো হয়; সার্ভার 0.25 সেকেন্ড পরে নিজেই বন্ধ করে
local function triggerAutoEffect()
	if not isConductor() or not isAutoPyroOn() then return end

	local randomEffect = autoPool[math.random(1, #autoPool)]
	QPyroRemote:FireServer(randomEffect, true, "AUTO")
end


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


local function isBassSpike(sound)
	if not sound then return false end

	local loudness = sound.PlaybackLoudness
	local currentTime = tick()


	table.insert(volumeHistory, loudness)
	if #volumeHistory > maxHistorySize then
		table.remove(volumeHistory, 1)
	end


	local avg = 0
	for _, v in ipairs(volumeHistory) do
		avg = avg + v
	end
	avg = avg / #volumeHistory

	-- Logika Deteksi:
	-- 1. Suara harus cukup keras (minLoudness)
	-- 2. Suara saat ini harus jauh lebih tinggi dari rata-rata (Spike)
	-- 3. Harus melewati cooldown (Anti-spam)
	if loudness > minLoudness and (loudness > avg * spikeMultiplier) and (currentTime - lastBassTime) > bassCooldown then
		lastBassTime = currentTime
		return true
	end

	return false
end

-- বিট ধরার লুপ: সবসময় চলে, কিন্তু কাজ করে শুধু কন্ডাক্টরের কাছে
RunService.RenderStepped:Connect(function()
	if not isConductor() or not isAutoPyroOn() then
		return
	end
	local sound = findCurrentPlayingSound()
	if sound and isBassSpike(sound) then
		triggerAutoEffect()
	end
end)


local function setupAutoButton(button)

	local stroke = button:FindFirstChild("IndicatorStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = "IndicatorStroke"
		stroke.Color = Color3.fromRGB(0, 0, 0)
		stroke.Thickness = 2
		stroke.Parent = button
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end

	-- বাটনের রং সার্ভারের অবস্থা দেখে বদলায়
	local function updateStroke()
		stroke.Color = isAutoPyroOn() and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(0, 0, 0)
	end
	updateStroke()
	ReplicatedStorage:GetAttributeChangedSignal("DJAutoPyro"):Connect(function()
		updateStroke()
		print("[QPyro] Auto Mode " .. (isAutoPyroOn() and "Enabled" or "Disabled") .. " (FPA/B/C Only)")
	end)

	button.MouseButton1Click:Connect(function()
		PyroSyncRemote:FireServer("SET_AUTO_MODE", not isAutoPyroOn())
	end)
end

PyroSyncRemote.OnClientEvent:Connect(function(eventType)
	if eventType == "BASS_DETECTED" or eventType == "SONG_CHANGED" then
		volumeHistory = {}
		triggerAutoEffect()
	end
end)

-- কন্ডাক্টর বদলালে পুরনো ইতিহাস মুছে নতুন করে শুরু
ReplicatedStorage:GetAttributeChangedSignal("DJConductor"):Connect(function()
	volumeHistory = {}
end)

connectEffectButton(effectContainer:WaitForChild("Fire"), "FIRE")
connectEffectButton(effectContainer:WaitForChild("Co2"), "CO2")
connectEffectButton(effectContainer:WaitForChild("Spark"), "SPARK")
connectEffectButton(effectContainer:WaitForChild("Confetti"), "CONFETTI")
connectEffectButton(effectContainer:WaitForChild("Co2Two"), "CO2_TWO")
setupAutoButton(effectContainer:WaitForChild("Auto"))

connectEffectButton(specialEffectContainer:WaitForChild("MovingFireA"), "MOVING_FIRE_A")
connectEffectButton(specialEffectContainer:WaitForChild("TripelCo2"), "TRIPLE_CO2")
connectEffectButton(specialEffectContainer:WaitForChild("TopFire"), "TOP_FIRE")
connectEffectButton(specialEffectContainer:WaitForChild("FireProjector"), "FIRE_PROJECTOR")

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
