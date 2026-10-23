--[[
	MusicServer — জায়গা: ServerScriptService > DJSystem > Music > MusicServer (Script)

	নতুন মিউজিক সিস্টেম (ISSUES.md #6)
	  - গান আসে ReplicatedStorage > DJSystem > Modules > MusicPlaylist থেকে
	    (DJ আর Phonk দুটো সেকশন)। DataStore-এ গান যোগ করার ব্যবস্থা নেই।
	  - কিউ: কিছু না বাজলে গান সাথে সাথে বাজে, নাহলে কিউতে যায়।
	    একজন সর্বোচ্চ Settings.MaxSongsPerPlayer-টা গান রাখতে পারে।
	  - ভলিউম আর ইকুয়ালাইজার শুধু অ্যাডমিন (AdminModule)।
	  - স্কিপ: অ্যাডমিন চাপলে সাথে সাথে, অন্যরা ভোট দিয়ে (Settings.AllowVoteSkip)।
	  - গান বাজে workspace.MusicFolder-এর "DJSound"-এ, আগের মতোই। লাইট আর
	    আগুনের সিঙ্ক এই সাউন্ড থেকেই বিট ধরে।
	  - দরকারি RemoteEvent-গুলো এই স্ক্রিপ্ট নিজেই বানায়
	    (ReplicatedStorage > DJSystem > Remotes > Music), হাতে বানাতে হয় না।
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local djSystem = ReplicatedStorage:WaitForChild("DJSystem")
local modules = djSystem:WaitForChild("Modules")
local AdminModule = require(modules:WaitForChild("AdminModule"))
local Playlist = require(modules:WaitForChild("MusicPlaylist"))
local Settings = Playlist.Settings or {}

local CATEGORIES = { "DJ", "Phonk" }
local MAX_SONGS_PER_PLAYER = Settings.MaxSongsPerPlayer or 2
local ALLOW_VOTE_SKIP = Settings.AllowVoteSkip ~= false
local VOTE_SKIP_PERCENT = Settings.VoteSkipPercent or 0.5
local LOAD_TIMEOUT = 10 -- এত সেকেন্ডে গান লোড না হলে পরের গান
local REQUEST_COOLDOWN = 0.5
local EQ_MIN, EQ_MAX = -60, 10

---------------------------------------------------------------------
-- RemoteEvent / RemoteFunction (না থাকলে বানানো হয়)
---------------------------------------------------------------------
local remotesFolder = djSystem:WaitForChild("Remotes")
local musicRemotes = remotesFolder:FindFirstChild("Music")
if not musicRemotes then
	musicRemotes = Instance.new("Folder")
	musicRemotes.Name = "Music"
	musicRemotes.Parent = remotesFolder
end

local function getRemote(className, name)
	local remote = musicRemotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = musicRemotes
	end
	return remote
end

local GetState = getRemote("RemoteFunction", "GetState")
local RequestSong = getRemote("RemoteEvent", "RequestSong")
local SkipSong = getRemote("RemoteEvent", "SkipSong")
local SetVolume = getRemote("RemoteEvent", "SetVolume")
local SetEqualizer = getRemote("RemoteEvent", "SetEqualizer")
local StateChanged = getRemote("RemoteEvent", "StateChanged")
local Notify = getRemote("RemoteEvent", "Notify")

---------------------------------------------------------------------
-- গানের লিস্ট: songs[category][id] = { Name, Id }
---------------------------------------------------------------------
local songs = {}
for _, category in ipairs(CATEGORIES) do
	songs[category] = {}
	for index, song in ipairs(Playlist[category] or {}) do
		if type(song) == "table" and type(song.Id) == "number" and type(song.Name) == "string" then
			songs[category][song.Id] = { Name = song.Name, Id = song.Id }
		else
			warn(`[Music] MusicPlaylist.{category}[{index}] ঠিকমতো লেখা হয়নি, বাদ দেওয়া হলো`)
		end
	end
end

---------------------------------------------------------------------
-- DJSound (আগের মতো MusicFolder-এর ভেতরে, 3D সাউন্ড)
---------------------------------------------------------------------
local musicFolder = Workspace:WaitForChild("MusicFolder")
local sound = musicFolder:FindFirstChild("DJSound")
if not sound then
	sound = Instance.new("Sound")
	sound.Name = "DJSound"
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 150
	sound.RollOffMode = Enum.RollOffMode.Inverse
	sound.Parent = musicFolder
end
sound.Looped = false

local equalizerEffect = sound:FindFirstChildOfClass("EqualizerSoundEffect")
if not equalizerEffect then
	equalizerEffect = Instance.new("EqualizerSoundEffect")
	equalizerEffect.Name = "EqualizerEffect"
	equalizerEffect.Parent = sound
end

---------------------------------------------------------------------
-- অবস্থা
---------------------------------------------------------------------
local current = nil -- { Name, Id, Category, RequestedBy, UserId }
local queue = {}
local volume = math.clamp(Settings.DefaultVolume or 0.5, 0, 1)
local equalizer = { Low = 0, Mid = 0, High = 0 }
local skipVotes = {} -- [userId] = true
local playToken = 0
local lastRequest = {} -- [player] = os.clock()

sound.Volume = volume

local function applyEqualizer()
	equalizerEffect.LowGain = equalizer.Low
	equalizerEffect.MidGain = equalizer.Mid
	equalizerEffect.HighGain = equalizer.High
end
applyEqualizer()

local function isAdmin(player)
	local ok, result = pcall(AdminModule.isAdmin, player)
	return ok and result == true
end

local function countVotes()
	local count = 0
	for userId in pairs(skipVotes) do
		if Players:GetPlayerByUserId(userId) then
			count += 1
		end
	end
	return count
end

local function votesNeeded()
	return math.max(1, math.ceil(#Players:GetPlayers() * VOTE_SKIP_PERCENT))
end

local function buildState()
	local queueList = {}
	for _, entry in ipairs(queue) do
		table.insert(queueList, { Name = entry.Name, Category = entry.Category, RequestedBy = entry.RequestedBy })
	end
	return {
		Current = current and {
			Name = current.Name,
			Category = current.Category,
			RequestedBy = current.RequestedBy,
			PlayId = playToken, -- প্রতিবার নতুন গান শুরু হলে বদলায়
		} or nil,
		Queue = queueList,
		Volume = volume,
		Equalizer = equalizer,
		Votes = countVotes(),
		VotesNeeded = votesNeeded(),
		AllowVoteSkip = ALLOW_VOTE_SKIP,
		MaxSongsPerPlayer = MAX_SONGS_PER_PLAYER,
	}
end

local function broadcast()
	StateChanged:FireAllClients(buildState())
end

local function notify(target, message, kind)
	if target then
		Notify:FireClient(target, message, kind)
	else
		Notify:FireAllClients(message, kind)
	end
end

---------------------------------------------------------------------
-- বাজানো
---------------------------------------------------------------------
local playNext

local function playSong(entry)
	playToken += 1
	local token = playToken

	current = entry
	table.clear(skipVotes)
	sound:Stop()
	sound.SoundId = "rbxassetid://" .. entry.Id
	sound.TimePosition = 0
	sound.Volume = volume
	broadcast()

	local waited = 0
	while not sound.IsLoaded and waited < LOAD_TIMEOUT do
		waited += task.wait(0.2)
		if token ~= playToken then
			return -- এর মধ্যে অন্য গান শুরু হয়ে গেছে
		end
	end

	if not sound.IsLoaded then
		warn(`[Music] গান লোড হয়নি: {entry.Name} ({entry.Id})`)
		notify(nil, `Could not load "{entry.Name}", skipping`, "error")
		playNext()
		return
	end

	sound:Play()
	notify(nil, `Now playing: {entry.Name}`, entry.Category)
end

playNext = function()
	local nextEntry = table.remove(queue, 1)
	if nextEntry then
		task.spawn(playSong, nextEntry)
	else
		playToken += 1
		current = nil
		table.clear(skipVotes)
		sound:Stop()
		sound.SoundId = ""
		broadcast()
	end
end

sound.Ended:Connect(function()
	if current then
		playNext()
	end
end)

---------------------------------------------------------------------
-- ক্লায়েন্টের অনুরোধ
---------------------------------------------------------------------
local function onCooldown(player)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
		return true
	end
	lastRequest[player] = now
	return false
end

-- RequestSong:FireServer(category, songId)
RequestSong.OnServerEvent:Connect(function(player, category, songId)
	if onCooldown(player) then
		return
	end
	if type(category) ~= "string" or not songs[category] or type(songId) ~= "number" then
		return
	end
	local song = songs[category][songId]
	if not song then
		return
	end

	local entry = {
		Name = song.Name,
		Id = song.Id,
		Category = category,
		RequestedBy = player.DisplayName,
		UserId = player.UserId,
	}

	if not current then
		task.spawn(playSong, entry)
		return
	end

	local mine = 0
	for _, queued in ipairs(queue) do
		if queued.UserId == player.UserId then
			mine += 1
		end
	end
	if mine >= MAX_SONGS_PER_PLAYER then
		notify(player, `You can only add up to {MAX_SONGS_PER_PLAYER} songs to the queue`, "error")
		return
	end

	table.insert(queue, entry)
	notify(player, `Added to queue (#{#queue}): {song.Name}`, category)
	broadcast()
end)

SkipSong.OnServerEvent:Connect(function(player)
	if onCooldown(player) or not current then
		return
	end

	if isAdmin(player) then
		notify(nil, `{player.DisplayName} skipped the song`, "info")
		playNext()
		return
	end

	if not ALLOW_VOTE_SKIP then
		notify(player, "Only admins can skip songs", "error")
		return
	end

	skipVotes[player.UserId] = true
	if countVotes() >= votesNeeded() then
		notify(nil, "Vote skip passed", "info")
		playNext()
	else
		broadcast()
	end
end)

-- SetVolume:FireServer(0..1)
SetVolume.OnServerEvent:Connect(function(player, newVolume)
	if not isAdmin(player) or type(newVolume) ~= "number" or newVolume ~= newVolume then
		return
	end
	volume = math.clamp(newVolume, 0, 1)
	sound.Volume = volume
	broadcast()
end)

-- SetEqualizer:FireServer("Low" | "Mid" | "High", dB)
SetEqualizer.OnServerEvent:Connect(function(player, band, value)
	if not isAdmin(player) or equalizer[band] == nil or type(value) ~= "number" or value ~= value then
		return
	end
	equalizer[band] = math.clamp(value, EQ_MIN, EQ_MAX)
	applyEqualizer()
	broadcast()
end)

GetState.OnServerInvoke = function()
	return buildState()
end

Players.PlayerAdded:Connect(broadcast)

Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
	skipVotes[player.UserId] = nil
	for index = #queue, 1, -1 do
		if queue[index].UserId == player.UserId then
			table.remove(queue, index)
		end
	end

	task.defer(function()
		if current and ALLOW_VOTE_SKIP and countVotes() > 0 and countVotes() >= votesNeeded() then
			playNext()
		else
			broadcast()
		end
	end)
end)
