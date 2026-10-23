--[[
	GifAnimator — জায়গা: StarterPlayer > StarterPlayerScripts > DJSystem > Visuals (LocalScript)

	ফিক্স: Visuals.Screens-এর Screen1/Screen2 স্পন থেকে দূরের Part।
	StreamingEnabled চালু থাকায় শুরুতে এগুলো না পেলে আগে স্ক্রিপ্ট "Screen1 or
	Screen2 not found!" বলে চিরতরে থেমে যেত। এখন প্রতি পালায় স্ক্রিন নতুন করে
	খোঁজে: না পেলে ১ সেকেন্ড পর আবার দেখে, আর দূরে গিয়ে ফিরে এলেও আবার চালু হয়।
]]

local visuals = workspace:WaitForChild("Visuals")
local scripts = visuals:WaitForChild("Scripts")
local VisualsPlayer = require(scripts:WaitForChild("VisualsPlayer"))
local GIFs = require(scripts:WaitForChild("GIFs"))

local Screens = visuals:WaitForChild("Screens")
local CHANGE_INTERVAL = 10
local RETRY_INTERVAL = 1

-- দুটো স্ক্রিনের SurfaceGui (না পেলে nil)
local function getSurfaceGuis()
	local screen1 = Screens:FindFirstChild("Screen1")
	local screen2 = Screens:FindFirstChild("Screen2")
	local surfaceGui1 = screen1 and screen1:FindFirstChild("SurfaceGui")
	local surfaceGui2 = screen2 and screen2:FindFirstChild("SurfaceGui")
	if surfaceGui1 and surfaceGui2 then
		return surfaceGui1, surfaceGui2
	end
	return nil
end

local function playGifs()
	local currentGif1 = nil
	local currentGif2 = nil
	local gifIndex = 1

	while true do
		if currentGif1 then currentGif1:Destroy() currentGif1 = nil end
		if currentGif2 then currentGif2:Destroy() currentGif2 = nil end

		local surfaceGui1, surfaceGui2 = getSurfaceGuis()
		if not surfaceGui1 then
			task.wait(RETRY_INTERVAL) -- স্ক্রিন এখনো লোড হয়নি (প্লেয়ার দূরে)
			continue
		end

		local fade1 = surfaceGui1:FindFirstChild("FadeScreen")
		local fade2 = surfaceGui2:FindFirstChild("FadeScreen")
		if fade1 then fade1.BackgroundTransparency = 1 end
		if fade2 then fade2.BackgroundTransparency = 1 end

		local gifData = GIFs[gifIndex]

		currentGif1 = VisualsPlayer.new({
			Screen = surfaceGui1,
			ID = "Screen1GIF",
			FPS = gifData.FPS,
			Image = gifData.Image,
			Frames = gifData.Frames,
			FramesPerRow = gifData.FramesPerRow,
		})
		currentGif1:Play()

		currentGif2 = VisualsPlayer.new({
			Screen = surfaceGui2,
			ID = "Screen2GIF",
			FPS = gifData.FPS,
			Image = gifData.Image,
			Frames = gifData.Frames,
			FramesPerRow = gifData.FramesPerRow,
		})
		currentGif2:Play()

		-- পালা শেষ হওয়া পর্যন্ত অপেক্ষা; মাঝে স্ক্রিন সরে গেলে সাথে সাথে নতুন করে খোঁজা
		local waited = 0
		while waited < CHANGE_INTERVAL and surfaceGui1.Parent and surfaceGui2.Parent do
			waited += task.wait(RETRY_INTERVAL)
		end

		gifIndex = gifIndex + 1
		if gifIndex > #GIFs then
			gifIndex = 1
		end
	end
end

print("[ Script By A Studio ] Gif Animator Loaded")
playGifs()
