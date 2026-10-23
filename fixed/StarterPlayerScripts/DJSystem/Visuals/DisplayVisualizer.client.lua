--[[
	DisplayVisualizer — জায়গা: StarterPlayer > StarterPlayerScripts > DJSystem > Visuals (LocalScript)

	ফিক্স: workspace.Display আর workspace.MusicFolder স্পন থেকে দূরের Part।
	StreamingEnabled চালু থাকায় প্লেয়ার কাছে না যাওয়া পর্যন্ত এগুলো তার
	কম্পিউটারে থাকে না, আর দূরে গেলে আবার সরে যায়। আগে স্ক্রিপ্ট শুরুতেই
	WaitForChild করে আটকে থাকত, আর একবার সরে গিয়ে ফিরে এলে পুরনো জিনিস ধরে
	রাখত। এখন প্রতিবার খুঁজে নেয়: না থাকলে চুপচাপ অপেক্ষা, ফিরে এলে আবার চালু।
]]

local RunService = game:GetService("RunService")

-- Konfigurasi animasi
local config = {
	minHeight = 0.05,      -- Tinggi minimum (saat senyap) - dalam scale (0-1)
	maxHeight = 0.9,       -- Tinggi maksimum (saat bass kuat)
	smoothing = 0.25,      -- Smoothing factor (0-1, lebih tinggi = lebih responsif)
	fallSpeed = 0.08,     -- Kecepatan turun saat tidak ada beat
}

local RESCAN_INTERVAL = 1 -- Display না পেলে কত সেকেন্ড পরপর আবার খুঁজবে

local ticks = {}
local tickFrameOwner = nil -- যে Frame থেকে ticks নেওয়া হয়েছে
local previousHeights = {}
local lastScan = -math.huge

-- Display-এর Tick_0..Tick_32 খুঁজে আনা (না পেলে খালি লিস্ট)
local function refreshTicks()
	if tickFrameOwner and tickFrameOwner.Parent then
		return
	end
	if os.clock() - lastScan < RESCAN_INTERVAL then
		return
	end
	lastScan = os.clock()

	table.clear(ticks)
	tickFrameOwner = nil

	local display = workspace:FindFirstChild("Display")
	local surfaceGui = display and display:FindFirstChild("SurfaceGui")
	local frame = surfaceGui and surfaceGui:FindFirstChild("Frame")
	if not frame then
		return
	end

	for i = 0, 32 do
		local tickFrame = frame:FindFirstChild("Tick_" .. i)
		if tickFrame then
			table.insert(ticks, tickFrame)
		end
	end
	tickFrameOwner = frame
	for i = 1, #ticks do
		previousHeights[i] = config.minHeight
	end
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

local function getEqualizerHeight(tickIndex, totalTicks, loudness)
	local normalizedLoudness = math.clamp(loudness / 700, 0, 1)
	local seed = tickIndex * 12345
	local randomVariation = (math.sin(seed) + 1) / 2  -- 0 to 1
	local timeOffset = math.sin(tick() * (3 + tickIndex * 0.5) + tickIndex) * 0.15
	local height = normalizedLoudness * (0.7 + randomVariation * 0.3) + timeOffset * normalizedLoudness

	height = math.clamp(height, config.minHeight, config.maxHeight)

	return height
end

RunService.RenderStepped:Connect(function()
	refreshTicks()
	if #ticks == 0 then
		return -- Display এখনো লোড হয়নি (প্লেয়ার দূরে)
	end

	local currentMusic = findCurrentPlayingSound()

	if currentMusic and currentMusic.IsPlaying then
		local loudness = currentMusic.PlaybackLoudness

		for i, tickFrame in ipairs(ticks) do

			local targetHeight = getEqualizerHeight(i, #ticks, loudness)

			local smoothedHeight = previousHeights[i] + (targetHeight - previousHeights[i]) * config.smoothing
			previousHeights[i] = smoothedHeight

			tickFrame.Size = UDim2.new(0.01, 0, smoothedHeight, 0)

			tickFrame.Position = UDim2.new(tickFrame.Position.X.Scale, 0, 0.5, 0)
		end
	else

		for i, tickFrame in ipairs(ticks) do
			local targetHeight = config.minHeight
			local smoothedHeight = previousHeights[i] + (targetHeight - previousHeights[i]) * config.fallSpeed
			previousHeights[i] = smoothedHeight

			tickFrame.Size = UDim2.new(0.01, 0, smoothedHeight, 0)
			tickFrame.Position = UDim2.new(tickFrame.Position.X.Scale, 0, 0.5, 0)
		end
	end
end)

print("[DisplayVisualizer] Initialized (waits for Display to stream in)")
