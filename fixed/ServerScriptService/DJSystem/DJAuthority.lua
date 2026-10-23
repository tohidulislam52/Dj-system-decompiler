--[[
	DJAuthority — অনুমতি আর "কন্ডাক্টর" ব্যবস্থা
	জায়গা: ServerScriptService > DJSystem > DJAuthority (ModuleScript)
	QPyroSyncServer আর GlightSyncServer দুটোই এটা require করে।

	কন্ডাক্টর কী?
	  গানের বিট (PlaybackLoudness) শুধু ক্লায়েন্টে পড়া যায়, সার্ভারে না।
	  আগে সার্ভারের প্রত্যেক প্লেয়ারের ক্লায়েন্ট বিট ধরে কমান্ড পাঠাত,
	  তাই ১০ জন থাকলে প্রতিটা আগুন/লাইট কমান্ড ১০ বার আসত।
	  এখন সার্ভার একজন প্লেয়ারকে "কন্ডাক্টর" বানায়। শুধু তার ক্লায়েন্ট
	  অটো-শো চালায়, বাকিদের অটো-কমান্ড বাদ।

	কে কন্ডাক্টর হয়?
	  স্পিকারের (workspace.MusicFolder Part) সবচেয়ে কাছের প্লেয়ার। গানটা 3D,
	  তাই দূরে গেলে আওয়াজ কমে যায় আর বিট ধরা যায় না, আর কাছের জনই
	  সবচেয়ে ভালো শোনে। দূরত্ব সমান হলে আগে অ্যাডমিন, তারপর যে আগে
	  ঢুকেছে। কেউ একটু বেশি কাছে এলেই যেন বারবার বদল না হয়, তাই নতুন
	  জন SWITCH_MARGIN স্টাড বেশি কাছে হলে তবেই বদলায়।

	ক্লায়েন্টরা ReplicatedStorage-এর এই attribute-গুলো পড়ে:
	  DJConductor  : কন্ডাক্টরের UserId (0 = কেউ না)
	  DJAutoPyro   : অটো আগুন চালু/বন্ধ
	  DJAutoLights : অটো লাইট সিঙ্ক চালু/বন্ধ
	  DJAutoCue    : অটো কিউ চালু/বন্ধ
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminModule = require(ReplicatedStorage:WaitForChild("DJSystem"):WaitForChild("Modules"):WaitForChild("AdminModule"))
local PyroSyncRemote = ReplicatedStorage:WaitForChild("DJSystem"):WaitForChild("Remotes"):WaitForChild("PyroSyncRemote")

local DJAuthority = {}

local CONDUCTOR_ATTRIBUTE = "DJConductor"
local FLAG_ATTRIBUTES = {
	AutoPyro = "DJAutoPyro",
	AutoLights = "DJAutoLights",
	AutoCue = "DJAutoCue",
}

-- অ্যাডমিন প্যানেলের বাটন থেকে আসা কমান্ড → কোন flag বদলাবে
local FLAG_COMMANDS = {
	SET_AUTO_MODE = "AutoPyro",
	SET_AUTO_LIGHTS = "AutoLights",
	SET_AUTO_CUE = "AutoCue",
}

-- গান বাজছে অথচ কন্ডাক্টর এত সেকেন্ড কিছু পাঠায়নি → পরের জনকে দেওয়া হয়
-- (তার গেম আটকে গেলে বা ল্যাগ করলে শো যেন বন্ধ না থাকে)
local SILENT_TIMEOUT = 15

-- নতুন কেউ বর্তমান কন্ডাক্টরের চেয়ে এত স্টাড বেশি কাছে হলে তবেই বদল
local SWITCH_MARGIN = 20

local joinOrder = {} -- [player] = কত নম্বরে ঢুকেছে
local joinCounter = 0
local skipped = {} -- [player] = true, যারা কন্ডাক্টর হয়ে চুপ ছিল
local conductor = nil
local lastAutoTime = os.clock()
local buckets = {} -- [player] = { [name] = { tokens, last } }

for _, attribute in pairs(FLAG_ATTRIBUTES) do
	if ReplicatedStorage:GetAttribute(attribute) == nil then
		ReplicatedStorage:SetAttribute(attribute, true)
	end
end

---------------------------------------------------------------------
-- অনুমতি
---------------------------------------------------------------------
function DJAuthority.isAdmin(player)
	return AdminModule.isAdmin(player)
end

function DJAuthority.isConductor(player)
	return player ~= nil and player == conductor
end

function DJAuthority.getFlag(name)
	return ReplicatedStorage:GetAttribute(FLAG_ATTRIBUTES[name]) ~= false
end

function DJAuthority.getFlagChangedSignal(name)
	return ReplicatedStorage:GetAttributeChangedSignal(FLAG_ATTRIBUTES[name])
end

-- কন্ডাক্টরের অটো-কমান্ড গ্রহণ করা হলে ডাকতে হবে (watchdog-এর জন্য)
function DJAuthority.noteAuto(player)
	if player == conductor then
		lastAutoTime = os.clock()
	end
end

-- Rate limit (token bucket): প্রতি সেকেন্ডে rate-টা, একসাথে সর্বোচ্চ burst-টা
function DJAuthority.allow(player, name, rate, burst)
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end

	local now = os.clock()
	local bucket = playerBuckets[name]
	if not bucket then
		bucket = { tokens = burst, last = now }
		playerBuckets[name] = bucket
	end

	bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.last) * rate)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

---------------------------------------------------------------------
-- কন্ডাক্টর বাছাই
---------------------------------------------------------------------
-- স্পিকার কোথায় (MusicFolder একটা Part, গান ওটার ভেতরে বাজে)
local function getSpeakerPosition()
	local musicFolder = workspace:FindFirstChild("MusicFolder")
	if musicFolder and musicFolder:IsA("BasePart") then
		return musicFolder.Position
	end
	return nil
end

-- চরিত্র না থাকলে (মারা গেছে / এখনো লোড হয়নি) অসীম দূরত্ব
local function distanceToSpeaker(player, speakerPosition)
	if not speakerPosition then
		return math.huge
	end
	local character = player.Character
	local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
	if not root then
		return math.huge
	end
	return (root.Position - speakerPosition).Magnitude
end

local function pickConductor()
	local speakerPosition = getSpeakerPosition()
	local best, bestDistance, bestIsAdmin, bestOrder
	for _, player in ipairs(Players:GetPlayers()) do
		if not skipped[player] then
			local distance = distanceToSpeaker(player, speakerPosition)
			local isAdmin = AdminModule.isAdmin(player)
			local order = joinOrder[player] or math.huge
			local isBetter = best == nil
				or distance < bestDistance
				or (distance == bestDistance and isAdmin and not bestIsAdmin)
				or (distance == bestDistance and isAdmin == bestIsAdmin and order < bestOrder)
			if isBetter then
				best, bestDistance, bestIsAdmin, bestOrder = player, distance, isAdmin, order
			end
		end
	end
	return best
end

local function setConductor(player)
	if player ~= conductor then
		conductor = player
		lastAutoTime = os.clock()
		ReplicatedStorage:SetAttribute(CONDUCTOR_ATTRIBUTE, conductor and conductor.UserId or 0)
	end
end

local function refreshConductor()
	local nextConductor = pickConductor()
	if not nextConductor and next(skipped) then
		table.clear(skipped)
		nextConductor = pickConductor()
	end
	setConductor(nextConductor)
end

-- কেউ স্পিকারের অনেক বেশি কাছে থাকলে কন্ডাক্টর তাকে দেওয়া
local function moveConductorCloser()
	if not conductor then
		refreshConductor()
		return
	end
	local best = pickConductor()
	if best and best ~= conductor then
		local speakerPosition = getSpeakerPosition()
		if distanceToSpeaker(best, speakerPosition) + SWITCH_MARGIN < distanceToSpeaker(conductor, speakerPosition) then
			setConductor(best)
		end
	end
end

local function isMusicPlaying()
	local musicFolder = workspace:FindFirstChild("MusicFolder")
	if not musicFolder then
		return false
	end
	for _, child in ipairs(musicFolder:GetChildren()) do
		if child:IsA("Sound") and child.IsPlaying then
			return true
		end
	end
	return false
end

local function onPlayerAdded(player)
	if joinOrder[player] then
		return
	end
	joinCounter += 1
	joinOrder[player] = joinCounter
	refreshConductor()
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	joinOrder[player] = nil
	skipped[player] = nil
	buckets[player] = nil
	if player == conductor then
		conductor = nil
		ReplicatedStorage:SetAttribute(CONDUCTOR_ATTRIBUTE, 0)
	end
	task.defer(refreshConductor)
end)

-- Watchdog: প্রতি ২ সেকেন্ডে কাছের জনকে কন্ডাক্টর বানানো, আর কন্ডাক্টর
-- চুপ থাকলে পরের জনকে দেওয়া
task.spawn(function()
	while true do
		task.wait(2)
		moveConductorCloser()
		if not isMusicPlaying() then
			lastAutoTime = os.clock()
		elseif conductor and os.clock() - lastAutoTime > SILENT_TIMEOUT then
			skipped[conductor] = true
			refreshConductor()
			lastAutoTime = os.clock()
		end
	end
end)

---------------------------------------------------------------------
-- অ্যাডমিন প্যানেল থেকে অটো-মোড চালু/বন্ধ (সবার জন্য একসাথে)
-- ক্লায়েন্ট থেকে আসে: PyroSyncRemote:FireServer("SET_AUTO_MODE", true/false)
---------------------------------------------------------------------
PyroSyncRemote.OnServerEvent:Connect(function(player, command, enabled)
	local flagName = FLAG_COMMANDS[command]
	if not flagName or type(enabled) ~= "boolean" then
		return
	end
	if not AdminModule.isAdmin(player) then
		return
	end
	ReplicatedStorage:SetAttribute(FLAG_ATTRIBUTES[flagName], enabled)
end)

return DJAuthority
