local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local MessagingService = game:GetService("MessagingService")

-- Remote Folder & Events Setup
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

local musicModule = ReplicatedStorage:WaitForChild("DJSystem"):WaitForChild("Modules", 10)
local AdminModule = musicModule and musicModule:FindFirstChild("AdminModule") and require(musicModule.AdminModule)
local NotificationModule = musicModule and musicModule:FindFirstChild("NotificationModule") and require(musicModule.NotificationModule)

local musicFolder = Workspace:WaitForChild("MusicFolder")

-- Dynamic DJ Sound Object Setup
local currentSoundObject = musicFolder:FindFirstChild("DJSound")
if not currentSoundObject then
	currentSoundObject = Instance.new("Sound")
	currentSoundObject.Name = "DJSound"
	currentSoundObject.RollOffMinDistance = 10
	currentSoundObject.RollOffMaxDistance = 150
	currentSoundObject.RollOffMode = Enum.RollOffMode.Inverse
	currentSoundObject.Parent = musicFolder
end

-- Equalizer Sound Effect Setup (ইকুয়ালাইজার কাজ করার জন্য)
local equalizerEffect = currentSoundObject:FindFirstChild("EqualizerEffect")
if not equalizerEffect then
	equalizerEffect = Instance.new("EqualizerSoundEffect")
	equalizerEffect.Name = "EqualizerEffect"
	equalizerEffect.Parent = currentSoundObject
end

local currentSoundName = nil
local globalVolume = 0.5
local isPlaying = false
local songQueue = {}
local skipVotes = {}
local MAX_SONGS_PER_PLAYER = 2

-- ============================================================
-- CUSTOM SONG SYSTEM (শুধু Player-এর add করা ID এখানে থাকে)
-- ============================================================
local CUSTOM_STORE_NAME = "CustomSongs_v1"
local CUSTOM_STORE_KEY = "GlobalPlaylist"
local MESSAGE_TOPIC = "CustomSongAdded_v1"
local MAX_CUSTOM_SONGS = 500
local ADD_COOLDOWN = 3
local NAME_LENGTH = 8

local customStore = DataStoreService:GetDataStore(CUSTOM_STORE_NAME)

local customSongs = {}      -- [idString] = { id = number, name = string }
local customLoaded = false
local pendingAdds = {}      -- [idString] = true (একই server-এ double add ঠেকাতে)
local lastAddTime = {}      -- [userId] = os.clock()
local lastRefresh = 0

local function notify(player, message)
	if NotificationModule and player and player.Parent and player:FindFirstChild("PlayerGui") then
		NotificationModule.showNotification(player.PlayerGui, message)
	end
end

-- Music Folder-এর existing/default sound কিনা চেক (এগুলো DataStore-এ কখনোই save হবে না)
local function isBuiltInSound(instance)
	return instance:IsA("Sound") and instance ~= currentSoundObject
end

local function isBuiltInId(idString)
	for _, child in ipairs(musicFolder:GetChildren()) do
		if isBuiltInSound(child) and string.match(child.SoundId, "%d+") == idString then
			return true
		end
	end
	return false
end

local function shortName(name)
	name = tostring(name or "")
	name = name:gsub("^%s+", ""):gsub("%s+$", "")

	local len = utf8.len(name)
	if len and len > NAME_LENGTH then
		name = string.sub(name, 1, utf8.offset(name, NAME_LENGTH + 1) - 1)
	elseif not len then
		name = string.sub(name, 1, NAME_LENGTH)
	end

	if name == "" then
		name = "Unknown"
	end
	return name
end

local function formatCustomName(entry)
	return entry.name .. " - " .. tostring(entry.id)
end

local function toClientEntry(entry)
	return { id = tostring(entry.id), display = formatCustomName(entry) }
end

local function getCustomListForClients()
	local list = {}
	for _, entry in pairs(customSongs) do
		table.insert(list, toClientEntry(entry))
	end
	table.sort(list, function(a, b) return a.display < b.display end)
	return list
end

-- Cache-এ entry ঢোকায়। নতুন হলে true দেয়। Music Folder-এর ID হলে কখনো ঢোকে না।
local function registerCustomSong(entry, broadcast)
	if type(entry) ~= "table" or type(entry.id) ~= "number" or type(entry.name) ~= "string" then
		return false
	end

	local key = tostring(entry.id)
	if customSongs[key] or isBuiltInId(key) then
		return false
	end

	customSongs[key] = { id = entry.id, name = entry.name }
	if broadcast then
		playMusicRemote:FireAllClients("SongAdded", toClientEntry(customSongs[key]))
	end
	return true
end

local function loadCustomSongs(broadcast)
	local data
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return customStore:GetAsync(CUSTOM_STORE_KEY)
		end)
		if ok then
			data = result
			break
		end
		warn("[Music] DataStore load failed (attempt " .. attempt .. "):", result)
		task.wait(1)
	end

	if type(data) == "table" then
		for _, entry in ipairs(data) do
			registerCustomSong(entry, broadcast)
		end
	end
end

-- UpdateAsync = server-to-server safe, একই ID দুইবার save হবে না
local function saveCustomSong(song)
	local existingEntry, addedEntry, limitReached

	for attempt = 1, 3 do
		existingEntry, addedEntry, limitReached = nil, nil, false

		local ok, err = pcall(function()
			customStore:UpdateAsync(CUSTOM_STORE_KEY, function(old)
				existingEntry, addedEntry, limitReached = nil, nil, false
				old = type(old) == "table" and old or {}

				for _, entry in ipairs(old) do
					if entry.id == song.id then
						existingEntry = entry
						return nil -- আগে থেকেই আছে, নতুন write নেই
					end
				end

				if #old >= MAX_CUSTOM_SONGS then
					limitReached = true
					return nil
				end

				table.insert(old, { id = song.id, name = song.name })
				addedEntry = song
				return old
			end)
		end)

		if ok then
			return true, existingEntry, addedEntry, limitReached
		end
		warn("[Music] DataStore save failed (attempt " .. attempt .. "):", err)
		task.wait(1)
	end

	return false
end

local function parseAssetId(raw)
	if typeof(raw) ~= "string" and typeof(raw) ~= "number" then
		return nil
	end
	local s = tostring(raw)
	s = s:gsub("rbxassetid://", "")
	s = s:gsub("%s", "")
	if not string.match(s, "^%d+$") or #s > 15 then
		return nil
	end
	local id = tonumber(s)
	if not id or id <= 0 then
		return nil
	end
	return id
end

-- Startup load
task.spawn(function()
	loadCustomSongs(false)
	customLoaded = true
end)

-- অন্য server-এ কেউ add করলে এখানে live আসবে
task.spawn(function()
	local ok, err = pcall(function()
		MessagingService:SubscribeAsync(MESSAGE_TOPIC, function(message)
			registerCustomSong(message.Data, true)
		end)
	end)
	if not ok then
		warn("[Music] MessagingService subscribe failed:", err)
	end
end)

addCustomMusicRemote.OnServerEvent:Connect(function(player, rawId)
	local now = os.clock()
	if lastAddTime[player.UserId] and now - lastAddTime[player.UserId] < ADD_COOLDOWN then
		notify(player, "Please wait a few seconds before adding another song")
		return
	end
	lastAddTime[player.UserId] = now

	local id = parseAssetId(rawId)
	if not id then
		notify(player, "Invalid Sound ID")
		return
	end

	local key = tostring(id)

	-- Default/Music Folder song হলে কখনো save হবে না
	if isBuiltInId(key) then
		notify(player, "This song is already in the default playlist")
		return
	end

	if customSongs[key] then
		notify(player, "This song is already in the playlist")
		return
	end

	if pendingAdds[key] then
		return
	end
	pendingAdds[key] = true

	-- Roblox থেকে real Name আনা
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, Enum.InfoType.Asset)
	end)

	if not ok or type(info) ~= "table" or info.AssetTypeId ~= 3 then
		pendingAdds[key] = nil
		notify(player, "Invalid or unavailable audio ID")
		return
	end

	local song = { id = id, name = shortName(info.Name) }
	local saved, existingEntry, addedEntry, limitReached = saveCustomSong(song)
	pendingAdds[key] = nil

	if not saved then
		notify(player, "Could not save the song, try again later")
		return
	end

	if limitReached then
		notify(player, "Custom playlist is full")
		return
	end

	if existingEntry then
		-- অন্য server/player আগে save করেছে: existing entry-ই ব্যবহার হবে
		registerCustomSong(existingEntry, true)
		notify(player, "This song is already in the playlist")
	elseif addedEntry then
		registerCustomSong(addedEntry, true)
		notify(player, "Song added: " .. formatCustomName(addedEntry))

		pcall(function()
			MessagingService:PublishAsync(MESSAGE_TOPIC, { id = addedEntry.id, name = addedEntry.name })
		end)
	end
end)

-- ============================================================

local equalizerState = {
	SubBass = 0,
	Bass = 0,
	LowMid = 0,
	Mid = 0,
	HighMid = 0,
	Treble = 0,
	HighTreble = 0
}

local function applyEqualizerSettings()
	local lowGain = (equalizerState["SubBass"] + equalizerState["Bass"]) / 2
	local midGain = (equalizerState["LowMid"] + equalizerState["Mid"] + equalizerState["HighMid"]) / 3
	local highGain = (equalizerState["Treble"] + equalizerState["HighTreble"]) / 2

	equalizerEffect.LowGain = math.clamp(lowGain, -80, 10)
	equalizerEffect.MidGain = math.clamp(midGain, -80, 10)
	equalizerEffect.HighGain = math.clamp(highGain, -80, 10)
end

local function isAdmin(player)
	if AdminModule and AdminModule.isAdmin then
		return AdminModule.isAdmin(player)
	end
	return true
end

local function getRequiredVotes()
	local totalPlayers = #Players:GetPlayers()
	if totalPlayers <= 1 then
		return 1
	end
	return math.ceil(totalPlayers * 0.5)
end

local function updateSkipVotes()
	local voteCount = 0
	for userId, voted in pairs(skipVotes) do
		if voted then voteCount = voteCount + 1 end
	end

	local req = getRequiredVotes()
	skipVoteUpdateRemote:FireAllClients(voteCount, req)
	return voteCount
end

local function resetSkipVotes()
	skipVotes = {}
	updateSkipVotes()
end

-- Music Folder sound হলে সেটার Name, Custom হলে "Name - ID"
local function getDisplayName(identifier)
	identifier = tostring(identifier)

	local folderSound = musicFolder:FindFirstChild(identifier)
	if folderSound and isBuiltInSound(folderSound) then
		return folderSound.Name
	end

	local entry = customSongs[identifier]
	if entry then
		return formatCustomName(entry)
	end

	return identifier
end

-- Play/queue করা যাবে শুধু Music Folder sound অথবা saved Custom song
local function isValidSongIdentifier(identifier)
	if typeof(identifier) ~= "string" then
		return false
	end

	local folderSound = musicFolder:FindFirstChild(identifier)
	if folderSound and isBuiltInSound(folderSound) then
		return true
	end

	return customSongs[identifier] ~= nil
end

local function getQueueDataForClients()
	local clientQueue = {}
	for _, item in ipairs(songQueue) do
		table.insert(clientQueue, getDisplayName(item.soundName))
	end
	return clientQueue
end

local function countPlayerSongsInQueue(player)
	local count = 0
	for _, item in ipairs(songQueue) do
		if item.sender == player then
			count = count + 1
		end
	end
	return count
end

local playNextInQueue

local function playSong(soundIdentifier)
	currentSoundObject:Stop()
	currentSoundObject.TimePosition = 0

	local soundToPlay = musicFolder:FindFirstChild(soundIdentifier)
	local targetSoundId = nil

	if soundToPlay and isBuiltInSound(soundToPlay) then
		targetSoundId = soundToPlay.SoundId
		currentSoundName = soundToPlay.Name
	elseif customSongs[tostring(soundIdentifier)] then
		local entry = customSongs[tostring(soundIdentifier)]
		targetSoundId = "rbxassetid://" .. tostring(entry.id)
		currentSoundName = formatCustomName(entry)
	end

	if targetSoundId then
		currentSoundObject.SoundId = targetSoundId
		currentSoundObject.Volume = globalVolume

		-- 🔥 গান শুরু হওয়ার সাথে সাথেই বর্তমান Equalizer সেট করে দেওয়া হচ্ছে
		applyEqualizerSettings()

		task.wait(0.1)
		currentSoundObject:Play()
		isPlaying = true

		resetSkipVotes()
		playMusicRemote:FireAllClients("NowPlaying", currentSoundName)
	else
		playNextInQueue()
	end
end

playNextInQueue = function()
	resetSkipVotes()

	if #songQueue > 0 then
		local nextItem = table.remove(songQueue, 1)
		playMusicRemote:FireAllClients("QueueUpdate", getQueueDataForClients())
		playSong(nextItem.soundName)
	else
		isPlaying = false
		currentSoundName = nil
		currentSoundObject:Stop()
		currentSoundObject.SoundId = ""
		stopMusicRemote:FireAllClients()
	end
end

currentSoundObject.Ended:Connect(function()
	if isPlaying then
		playNextInQueue()
	end
end)

playMusicRemote.OnServerEvent:Connect(function(player, soundIdentifier)
	if not isValidSongIdentifier(soundIdentifier) then
		return
	end

	if isPlaying then
		local songsQueued = countPlayerSongsInQueue(player)
		if songsQueued >= MAX_SONGS_PER_PLAYER then
			if NotificationModule and player:FindFirstChild("PlayerGui") then
				NotificationModule.showNotification(player.PlayerGui, "You can only add up to " .. MAX_SONGS_PER_PLAYER .. " songs!")
			end
			return
		end

		table.insert(songQueue, { soundName = soundIdentifier, sender = player })
		playMusicRemote:FireAllClients("QueueUpdate", getQueueDataForClients())
	else
		playSong(soundIdentifier)
	end
end)

setVolumeRemote.OnServerEvent:Connect(function(player, newVolume)
	if not isAdmin(player) then return end
	globalVolume = math.clamp(newVolume, 0, 1)
	currentSoundObject.Volume = globalVolume
	setVolumeRemote:FireAllClients(globalVolume)
end)

skipVoteRemote.OnServerEvent:Connect(function(player)
	if not isPlaying then return end

	if not skipVotes[player.UserId] then
		skipVotes[player.UserId] = true
	end

	local voteCount = updateSkipVotes()
	local required = getRequiredVotes()

	if voteCount >= required or isAdmin(player) then
		playNextInQueue()
	end
end)

setEqualizerRemote.OnServerEvent:Connect(function(player, channel, value)
	if not isAdmin(player) then return end
	if equalizerState[channel] ~= nil then
		equalizerState[channel] = value
		applyEqualizerSettings() -- ইকুয়ালাইজার ইফেক্ট প্রয়োগ
		setEqualizerRemote:FireAllClients(channel, value)
	end
end)

getMusicStateRemote.OnServerInvoke = function(player)
	-- DataStore load শেষ হওয়া পর্যন্ত অপেক্ষা (max ~10s)
	local waited = 0
	while not customLoaded and waited < 10 do
		task.wait(0.2)
		waited = waited + 0.2
	end

	return {
		currentSoundName = currentSoundName,
		isPlaying = isPlaying,
		volume = globalVolume,
		queue = getQueueDataForClients(),
		skipVoteCount = updateSkipVotes(),
		requiredVotes = getRequiredVotes(),
		customSongs = getCustomListForClients()
	}
end

getEqualizerStateRemote.OnServerInvoke = function(player)
	return equalizerState
end

Players.PlayerAdded:Connect(function(player)
	task.wait(0.5)
	starRemote:FireClient(player)
	updateSkipVotes()

	-- Join-এর সময় DataStore থেকে নতুন Custom Song sync (30s throttle)
	if customLoaded and os.clock() - lastRefresh > 30 then
		lastRefresh = os.clock()
		task.spawn(loadCustomSongs, true)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastAddTime[player.UserId] = nil

	if skipVotes[player.UserId] then
		skipVotes[player.UserId] = nil
	end

	for i = #songQueue, 1, -1 do
		if songQueue[i].sender == player then
			table.remove(songQueue, i)
		end
	end
	playMusicRemote:FireAllClients("QueueUpdate", getQueueDataForClients())

	local voteCount = updateSkipVotes()
	if isPlaying and voteCount >= getRequiredVotes() then
		playNextInQueue()
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	starRemote:FireClient(player)
end


-- গেম স্টার্ট হওয়ার সাথে সাথেই ডিফোল্ট Equalizer এপ্লাই করে রাখা
applyEqualizerSettings()
