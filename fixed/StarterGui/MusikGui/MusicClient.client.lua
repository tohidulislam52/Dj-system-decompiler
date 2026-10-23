local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")

local AdminModule = require(ReplicatedStorage:WaitForChild("DJSystem"):WaitForChild("Modules"):WaitForChild("AdminModule"))
local NotificationModule = require(ReplicatedStorage:WaitForChild("DJSystem"):WaitForChild("Modules"):WaitForChild("NotificationModule"))

local musicRemotes = ReplicatedStorage:WaitForChild("DJSystem"):WaitForChild("Remotes"):WaitForChild("MusicRemotes")
local playMusicRemote = musicRemotes:WaitForChild("PlayMusic")
local stopMusicRemote = musicRemotes:WaitForChild("StopMusic")
local setVolumeRemote = musicRemotes:WaitForChild("SetVolume")
local getMusicStateRemote = musicRemotes:WaitForChild("GetMusicState")
local skipVoteRemote = musicRemotes:WaitForChild("SkipVote")
local skipVoteUpdateRemote = musicRemotes:WaitForChild("SkipVoteUpdate")
local addCustomMusicRemote = musicRemotes:WaitForChild("AddCustomMusic")
local setEqualizerRemote = musicRemotes:WaitForChild("SetEqualizer")
local getEqualizerStateRemote = musicRemotes:WaitForChild("GetEqualizerState")
local starRemote = musicRemotes:WaitForChild("StarMusic")

local musikGui = script.Parent
local frame = musikGui:WaitForChild("Frame")
local scrollingFrame = frame:WaitForChild("PlayListFrame"):WaitForChild("ScrollingFrame")
local template = scrollingFrame:WaitForChild("Template")
local musicFolder = Workspace:WaitForChild("MusicFolder")

local mainFrame = frame:WaitForChild("MainFrame")
local imageLabel = mainFrame:WaitForChild("ImageLabel")
local timeFrame = mainFrame:WaitForChild("Time")
local tickFrame = timeFrame:WaitForChild("Tick")
local volMinus = mainFrame:WaitForChild("Vol -")
local volPlus = mainFrame:WaitForChild("Vol +")
local indikator = mainFrame:WaitForChild("Indikator")
local titleLabel = mainFrame:WaitForChild("Title")
local skipButton = mainFrame:WaitForChild("Skip")
local countButton = mainFrame:WaitForChild("Count")

starRemote.OnClientEvent:Connect(function()
	print("[Client Debug] DJ System Loaded via StarRemote!")

	template.Visible = false

	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA("TextButton") and child.Name ~= "Template" then
			child:Destroy()
		end
	end

	local currentSoundName = nil
	local volume = 5
	local isPlaying = false
	local rotationSpeed = 100
	local connection = nil
	local hasVotedSkip = false

	local queue = {}
	local queueFrame = frame:FindFirstChild("QueueFrame")
	local queueScrollingFrame = queueFrame and queueFrame:FindFirstChild("ScrollingFrame")
	local queueTemplate = queueScrollingFrame and queueScrollingFrame:FindFirstChild("Title")

	if queueTemplate then
		queueTemplate.Visible = false
	end

	local playListFrame = frame:FindFirstChild("PlayListFrame")
	local addFrame = frame:FindFirstChild("AddFrame")
	local equalizerFrame = frame:FindFirstChild("EqualizerFrame")

	local searchBox = playListFrame and playListFrame:FindFirstChild("Search")
	if searchBox then searchBox.Text = "Search" end

	local assetIdBox = addFrame and addFrame:FindFirstChild("AssetId")
	local addIdButton = addFrame and addFrame:FindFirstChild("AddID")

	local buttonFrame = frame:FindFirstChild("ButtonFrame")
	local playListBtn = buttonFrame and buttonFrame:FindFirstChild("PlayList")
	local queueBtn = buttonFrame and buttonFrame:FindFirstChild("Queue")
	local addBtn = buttonFrame and buttonFrame:FindFirstChild("Add")
	local equalizerBtn = buttonFrame and buttonFrame:FindFirstChild("Equalizer")

	local function hideAllFrames()
		if playListFrame then playListFrame.Visible = false end
		if queueFrame then queueFrame.Visible = false end
		if addFrame then addFrame.Visible = false end
		if equalizerFrame then equalizerFrame.Visible = false end
	end

	local function showFrame(frameToShow)
		hideAllFrames()
		if frameToShow then
			frameToShow.Visible = true
		end
	end

	if playListBtn then
		playListBtn.MouseButton1Click:Connect(function()
			showFrame(playListFrame)
		end)
	end

	if queueBtn then
		queueBtn.MouseButton1Click:Connect(function()
			showFrame(queueFrame)
		end)
	end

	if addBtn then
		addBtn.MouseButton1Click:Connect(function()
			showFrame(addFrame)
		end)
	end

	if equalizerBtn then
		equalizerBtn.MouseButton1Click:Connect(function()
			if not AdminModule.isAdmin(player) then
				NotificationModule.showNotification(playerGui, "Hanya admin yang bisa mengakses equalizer")
				return
			end
			showFrame(equalizerFrame)
		end)
	end

	showFrame(playListFrame)

	local function updateVolumeDisplay()
		if indikator then
			indikator.Text = tostring(volume)
		end
	end

	local function updateTitle(soundName)
		if titleLabel then
			titleLabel.Text = soundName or "No Music Playing"
		end
	end

	local function updateQueueDisplay()
		if not queueScrollingFrame or not queueTemplate then return end

		for _, child in ipairs(queueScrollingFrame:GetChildren()) do
			if child:IsA("TextLabel") and child.Name ~= "Title" then
				child:Destroy()
			end
		end

		if #queue > 0 then
			for i, item in ipairs(queue) do
				local songName = type(item) == "table" and item.soundName or item
				local newItem = queueTemplate:Clone()
				newItem.Name = "QueueItem_" .. i
				newItem.Text = i .. ". " .. songName
				newItem.Visible = true
				newItem.Parent = queueScrollingFrame
			end
		else
			local emptyLabel = queueTemplate:Clone()
			emptyLabel.Name = "EmptyQueue"
			emptyLabel.Text = "Queue: Empty"
			emptyLabel.Visible = true
			emptyLabel.Parent = queueScrollingFrame
		end
	end

	local function addToQueueDisplay(soundName)
		table.insert(queue, soundName)
		updateQueueDisplay()
	end

	local function playSound(soundName)
		print("[Client Debug] Requesting Server to play sound:", soundName)
		playMusicRemote:FireServer(soundName)
	end

	-- identifier = Music Folder sound name অথবা Custom ID (string)
	-- displayText = Playlist-এ যা দেখাবে ("SoundName - CustomID")
	local function addSongButton(identifier, displayText, isCustom)
		displayText = displayText or identifier
		local buttonName = isCustom and ("Custom_" .. identifier) or identifier

		if scrollingFrame:FindFirstChild(buttonName) then
			return
		end

		local newButton = template:Clone()
		newButton.Name = buttonName
		newButton.Text = displayText
		newButton.Visible = true
		newButton.Parent = scrollingFrame

		newButton:SetAttribute("SoundName", displayText)

		newButton.MouseButton1Click:Connect(function()
			playSound(identifier)
		end)
	end

	playMusicRemote.OnClientEvent:Connect(function(action, data)
		if action == "NowPlaying" then
			print("[Client Debug] Server sent NowPlaying:", data)
			currentSoundName = data
			isPlaying = true
			hasVotedSkip = false -- নতুন গান শুরু হলে ভোট রিসেট
			updateTitle(data)
		elseif action == "QueueUpdate" then
			queue = data or {}
			updateQueueDisplay()
		elseif action == "SongAdded" then
			if type(data) == "table" and data.id then
				addSongButton(data.id, data.display, true)
			end
		end
	end)

	stopMusicRemote.OnClientEvent:Connect(function()
		print("[Client Debug] Server sent StopMusic")
		isPlaying = false
		currentSoundName = nil
		hasVotedSkip = false
		updateTitle(nil)
		if tickFrame then
			tickFrame.Size = UDim2.new(0, 0, 1, 0)
		end
	end)

	setVolumeRemote.OnClientEvent:Connect(function(newVolume)
		volume = math.floor(newVolume * 10 + 0.5)
		updateVolumeDisplay()
	end)

	skipVoteUpdateRemote.OnClientEvent:Connect(function(voteCount, requiredVotes)
		print("[Client Debug] Vote update received:", voteCount, "/", requiredVotes)
		if countButton then
			countButton.Text = voteCount .. "/" .. requiredVotes
		end

		if voteCount == 0 then
			hasVotedSkip = false
		end
	end)

	if volMinus then
		volMinus.MouseButton1Click:Connect(function()
			if not AdminModule.isAdmin(player) then
				NotificationModule.showNotification(playerGui, "Only admins can adjust the volume.   ")
				return
			end
			if volume > 0 then
				local newVolume = (volume - 1) / 10
				setVolumeRemote:FireServer(newVolume)
			end
		end)
	end

	if volPlus then
		volPlus.MouseButton1Click:Connect(function()
			if not AdminModule.isAdmin(player) then
				NotificationModule.showNotification(playerGui, "Only admins can adjust the volume.   ")
				return
			end
			if volume < 10 then
				local newVolume = (volume + 1) / 10
				setVolumeRemote:FireServer(newVolume)
			end
		end)
	end

	-- Skip Button Fixed Logic
	if skipButton then
		skipButton.MouseButton1Click:Connect(function()
			print("[Client Debug] Skip Button Clicked! isPlaying =", isPlaying, "hasVotedSkip =", hasVotedSkip)
			if not hasVotedSkip then
				print("[Client Debug] Sending Skip Request to Server...")
				skipVoteRemote:FireServer()
				hasVotedSkip = true
			else
				warn("[Client Debug] You already voted to skip this song!")
			end
		end)
	end

	-- 🔥 Rotation Fix: আসল গান বাজে "DJSound"-এ (server-এর তৈরি), Music Folder-এর original sound-এ না।
	-- আগে original sound খোঁজা হচ্ছিল, যেটা কখনো IsPlaying হয় না -> rotation/tick কাজ করত না।
	local lastRotation = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		local djSound = musicFolder:FindFirstChild("DJSound")

		if isPlaying and djSound and djSound.IsPlaying then
			lastRotation = (lastRotation + (rotationSpeed * deltaTime)) % 360
			if imageLabel then
				imageLabel.Rotation = lastRotation
			end

			if tickFrame and djSound.TimeLength > 0 then
				local progress = math.clamp(djSound.TimePosition / djSound.TimeLength, 0, 1)
				tickFrame.Size = UDim2.new(progress, 0, 1, 0)
			end
		else
			-- sound stopped / loading / no music
			if tickFrame then
				tickFrame.Size = UDim2.new(0, 0, 1, 0)
			end
			if lastRotation ~= 0 then
				lastRotation = 0
				if imageLabel then
					imageLabel.Rotation = 0
				end
			end
		end
	end)

	updateVolumeDisplay()
	updateQueueDisplay()

	local function requestInitialState()
		task.wait(0.5)

		local maxRetries = 5
		local retryCount = 0
		local success, state

		while retryCount < maxRetries do
			success, state = pcall(function()
				return getMusicStateRemote:InvokeServer()
			end)

			if success and state then
				break
			end

			retryCount = retryCount + 1
			task.wait(0.5)
		end

		if success and state then
			if state.currentSoundName then
				currentSoundName = state.currentSoundName
				isPlaying = state.isPlaying
				updateTitle(state.currentSoundName)
			end
			if state.volume then
				volume = math.floor(state.volume * 10 + 0.5)
				updateVolumeDisplay()
			end
			if state.queue then
				queue = state.queue
				updateQueueDisplay()
			end

			-- DataStore থেকে load হওয়া Custom Songs -> Playlist ("SoundName - CustomID")
			if state.customSongs then
				for _, song in ipairs(state.customSongs) do
					addSongButton(song.id, song.display, true)
				end
			end

			if countButton then
				local voteCount = state.skipVoteCount or 0
				local requiredVotes = state.requiredVotes or 1
				countButton.Text = voteCount .. "/" .. requiredVotes
			end
		end
	end

	task.spawn(requestInitialState)

	for _, sound in ipairs(musicFolder:GetChildren()) do
		-- DJSound হলো playback object, playlist song না
		if sound:IsA("Sound") and sound.Name ~= "DJSound" then
			local newButton = template:Clone()
			newButton.Name = sound.Name
			newButton.Text = sound.Name
			newButton.Visible = true
			newButton.Parent = scrollingFrame

			newButton:SetAttribute("SoundName", sound.Name)

			newButton.MouseButton1Click:Connect(function()
				playSound(sound.Name)
			end)
		end
	end

	local function filterSongs(searchText)
		searchText = string.lower(searchText or "")
		for _, child in ipairs(scrollingFrame:GetChildren()) do
			if child:IsA("TextButton") and child.Name ~= "Template" then
				local songName = child:GetAttribute("SoundName") or child.Name
				if searchText == "" then
					child.Visible = true
				else
					child.Visible = string.find(string.lower(songName), searchText) ~= nil
				end
			end
		end
	end

	if searchBox then
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			filterSongs(searchBox.Text)
		end)
	end

	-- Add Custom ID -> Server validate + name fetch + DataStore save + playlist-এ add
	if addIdButton and assetIdBox then
		addIdButton.MouseButton1Click:Connect(function()
			local assetId = assetIdBox.Text
			if assetId and assetId ~= "" then
				addCustomMusicRemote:FireServer(assetId)
				assetIdBox.Text = "" -- Clear the text box
			end
		end)
	end

	local equalizerChannels = {
		{ Name = "SubBass", Min = -60, Max = 10, Default = 0, Unit = "dB" },    -- 50-60 Hz
		{ Name = "Bass", Min = -60, Max = 10, Default = 0, Unit = "dB" },        -- 125-150 Hz
		{ Name = "LowMid", Min = -60, Max = 10, Default = 0, Unit = "dB" },      -- 320-420 Hz
		{ Name = "Mid", Min = -60, Max = 10, Default = 0, Unit = "dB" },        -- 750-1kHz
		{ Name = "HighMid", Min = -60, Max = 10, Default = 0, Unit = "dB" },    -- 2.2-2.5kHz
		{ Name = "Treble", Min = -60, Max = 10, Default = 0, Unit = "dB" },     -- 6-7 kHz
		{ Name = "HighTreble", Min = -60, Max = 10, Default = 0, Unit = "dB" } -- 15-16.5kHz
	}

	local equalizerValues = {}
	local sliderDragging = {}

	for _, channel in ipairs(equalizerChannels) do
		equalizerValues[channel.Name] = channel.Default
	end

	local function updateSliderPosition(channelName, value)
		local container = equalizerFrame:FindFirstChild(channelName .. "Container")
		if not container then return end

		local sliderFrame = container:FindFirstChild("SliderFrame")
		local slider = sliderFrame and sliderFrame:FindFirstChild(channelName .. "Slider")
		local valueLabel = container:FindFirstChild("Value")

		if not slider or not sliderFrame then return end

		local channelConfig = nil
		for _, ch in ipairs(equalizerChannels) do
			if ch.Name == channelName then
				channelConfig = ch
				break
			end
		end
		if not channelConfig then return end

		local normalizedValue
		if value <= 0 then
			normalizedValue = 0.5 * (value - channelConfig.Min) / (0 - channelConfig.Min)
		else
			normalizedValue = 0.5 + 0.5 * value / channelConfig.Max
		end

		local sliderWidth = slider.AbsoluteSize.X
		local frameWidth = sliderFrame.AbsoluteSize.X
		local sliderHalfWidth = sliderWidth / 2

		local minCenter = sliderHalfWidth
		local maxCenter = frameWidth - sliderHalfWidth
		local range = maxCenter - minCenter
		local newCenterX = minCenter + normalizedValue * range

		slider.Position = UDim2.new(0, newCenterX, 0, 0)

		if valueLabel then
			valueLabel.Text = tostring(math.floor(value + 0.5)) .. channelConfig.Unit
		end
	end

	local function setupSliderDrag(channelName)
		local container = equalizerFrame:FindFirstChild(channelName .. "Container")
		if not container then return end

		local sliderFrame = container:FindFirstChild("SliderFrame")
		local slider = sliderFrame and sliderFrame:FindFirstChild(channelName .. "Slider")

		if not slider or not sliderFrame then return end

		local channelConfig = nil
		for _, ch in ipairs(equalizerChannels) do
			if ch.Name == channelName then
				channelConfig = ch
				break
			end
		end
		if not channelConfig then return end

		local UserInputService = game:GetService("UserInputService")

		local function updateValue()
			local mousePos = UserInputService:GetMouseLocation()
			local sliderWidth = slider.AbsoluteSize.X
			local frameWidth = sliderFrame.AbsoluteSize.X
			local sliderHalfWidth = sliderWidth / 2
			local relativeX = mousePos.X - sliderFrame.AbsolutePosition.X

			local minCenter = sliderHalfWidth
			local maxCenter = frameWidth - sliderHalfWidth
			local range = maxCenter - minCenter

			relativeX = math.clamp(relativeX, minCenter, maxCenter)

			local normalizedPos = (relativeX - minCenter) / range

			local value
			if normalizedPos <= 0.5 then
				value = channelConfig.Min + (normalizedPos * 2) * (0 - channelConfig.Min)
			else
				value = (normalizedPos - 0.5) * 2 * channelConfig.Max
			end
			value = math.clamp(value, channelConfig.Min, channelConfig.Max)

			equalizerValues[channelName] = value
			updateSliderPosition(channelName, value)
			setEqualizerRemote:FireServer(channelName, value)
		end

		slider.MouseButton1Down:Connect(function()
			sliderDragging[channelName] = true
			updateValue()
		end)

		slider.MouseButton1Up:Connect(function()
			sliderDragging[channelName] = false
		end)

		sliderFrame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				sliderDragging[channelName] = true
				updateValue()
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if sliderDragging[channelName] and input.UserInputType == Enum.UserInputType.MouseMovement then
				updateValue()
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				sliderDragging[channelName] = false
			end
		end)
	end

	for _, channel in ipairs(equalizerChannels) do
		setupSliderDrag(channel.Name)
	end

	setEqualizerRemote.OnClientEvent:Connect(function(channel, value)
		equalizerValues[channel] = value
		updateSliderPosition(channel, value)
	end)

	task.spawn(function()
		local success, state = pcall(function()
			return getEqualizerStateRemote:InvokeServer()
		end)
		if success and state then
			for channel, value in pairs(state) do
				equalizerValues[channel] = value
				updateSliderPosition(channel, value)
			end
		end
	end)

	return "Playlist populated with " .. #musicFolder:GetChildren() .. " sounds"
end)
