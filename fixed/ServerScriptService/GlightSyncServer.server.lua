--[[
	GLightSync — Script By A Studio
	এটা আসল obfuscated স্ক্রিপ্টের পড়ার মতো (deobfuscated) সংস্করণ।
	আচরণ হুবহু একই রাখা হয়েছে; শুধু obfuscator-এর নিজের anti-tamper
	কোড ("Tamper Detected!" চেক) বাদ দেওয়া হয়েছে, কারণ ওটা স্ক্রিপ্টের কাজের অংশ না।

	ধরন: Server Script (OnServerEvent ব্যবহার করে)
	জায়গা: ServerScriptService > GlightSyncServer

	ফিক্স (ISSUES.md #1, #2):
	  - প্যানেলের কমান্ড শুধু AdminModule-এর অ্যাডমিনদের কাছ থেকে নেওয়া হয়
	  - অটো-সিঙ্ক (target = "Auto") শুধু কন্ডাক্টরের কাছ থেকে, আর শুধু
	    Color/Dimness/MotorSpeed/Pan/Tilt/Cue কমান্ড
	  - একসাথে একটাই অটো-কিউ চালু থাকে
	  - প্রতি প্লেয়ারের জন্য rate limit
]]

local HttpService = game:GetService("HttpService")

---------------------------------------------------------------------
-- ১) লাইসেন্স চেক
-- গেমের CreatorId একটা Google Apps Script URL-এ পাঠানো হয়।
-- সার্ভার ঠিক "TRUE" লেখা ফেরত দিলে তবেই সিস্টেম চালু হয়।
---------------------------------------------------------------------
local LICENSE_URL = "https://script.google.com/macros/s/AKfycbwOQ-F1Wy3i9DBw_sGxSNIkx77jBifHxkurrRDLBBWPRqYi2TykHX7GPBr_fO56Vrq-/exec"

local ok, response = pcall(function()
	return HttpService:GetAsync(LICENSE_URL .. "?targetID=" .. game.CreatorId)
end)

if not ok or response ~= "TRUE" then
	warn("LISENSI TIDAK VALID! Sistem musik dinonaktifkan.") -- "লাইসেন্স সঠিক নয়! মিউজিক সিস্টেম বন্ধ।"
	return
end

print("Lisensi Terverifikasi untuk ID: " .. game.CreatorId) -- "লাইসেন্স যাচাই হয়েছে, ID: ..."
print("Sistem Glight Berhasil Dijalankan!")                 -- "Glight সিস্টেম সফলভাবে চালু হয়েছে!"

---------------------------------------------------------------------
-- ২) দরকারি অবজেক্টগুলো
---------------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Remote = ReplicatedStorage:WaitForChild("GLightsRemote")
local DJAuthority = require(ServerScriptService:WaitForChild("DJAuthority"))
local GLights = game.Workspace:WaitForChild("GLights")
local Panel = require(GLights.Scripts.Panels.Panel)
local Lights = GLights:WaitForChild("Lights")

-- "All" পাঠালে এই গ্রুপগুলোতে কমান্ড যায় (এই ক্রমেই)
local ALL_GROUPS = { "Bars", "Heads", "LEDs", "LineBars", "Strobes", "Washes" }

---------------------------------------------------------------------
-- ৩) Helper: একটা fixture-এর Motors ফোল্ডারের ভেতরের মোটর ঘোরানো
-- সফল হলে true, মোটর না পেলে false ফেরত দেয়।
---------------------------------------------------------------------
local function setMotorAngle(fixture, motorName, degrees)
	local motors = fixture:FindFirstChild("Motors")
	if not motors then
		return false
	end

	local motor = motors:FindFirstChild(motorName)
	if not motor then
		return false
	end

	motor.DesiredAngle = math.rad(degrees)
	return true
end

---------------------------------------------------------------------
-- ৪) কমান্ড চালানো
--   target : "All" অথবা Lights ফোল্ডারের ভেতরের কোনো গ্রুপের নাম
--   action : "Pan", "Tilt", অথবা Panel মডিউলের যেকোনো কমান্ড
--   args   : কমান্ডের মান (যেমন Pan/Tilt-এর জন্য ডিগ্রি)
---------------------------------------------------------------------
local function runCommand(target, action, args)
	local value = args[1]

	-- বাকি সব কাজ Panel মডিউলকে দিয়ে দেওয়া (error হলেও স্ক্রিপ্ট থামবে না)
	local function forwardToPanel(groupName)
		pcall(function()
			Panel.Run(groupName, action, table.unpack(args))
		end)
	end

	local function applyToGroup(groupName)
		local group = Lights:FindFirstChild(groupName)
		if not group then
			return
		end

		local isMovement = (action == "Pan" or action == "Tilt") and type(value) == "number"

		-- Pan/Tilt ছাড়া অন্য কমান্ড, আর "Bars" গ্রুপ — সরাসরি Panel-এ যায়
		if not isMovement or groupName == "Bars" then
			forwardToPanel(groupName)
			return
		end

		-- Pan/Tilt: গ্রুপের ভেতরের "A" আর "B" সাইডের প্রতিটা fixture-এর মোটর ঘোরানো।
		-- B সাইডে Pan উল্টো দিকে (mirror) হয়, Tilt দুই সাইডে একই।
		local needsPanel = false
		for _, side in ipairs(group:GetChildren()) do
			if side.Name == "A" or side.Name == "B" then
				local degrees = value
				if action == "Pan" and side.Name == "B" then
					degrees = -value
				end

				for _, fixture in ipairs(side:GetChildren()) do
					if not setMotorAngle(fixture, action, degrees) then
						needsPanel = true
					end
				end
			end
		end

		-- মোটর না থাকলে Panel মডিউলকে কাজটা দেওয়া হয়, তবে গ্রুপপ্রতি একবারই।
		-- (আগে প্রতিটা fixture-এর জন্য একবার করে পুরো গ্রুপে পাঠাত। এই গেমের
		-- কোনো fixture-এ Motors ফোল্ডার নেই, তাই প্রতি বিটে ~১৬০টা Pan/Tilt
		-- সব প্লেয়ারের কাছে যেত, যেখানে ~১২টাই যথেষ্ট।)
		if needsPanel then
			forwardToPanel(groupName)
		end
	end

	if target == "All" then
		for _, groupName in ipairs(ALL_GROUPS) do
			applyToGroup(groupName)
		end
	else
		applyToGroup(target)
	end
end

---------------------------------------------------------------------
-- ৫) অটো-সিঙ্ক: কন্ডাক্টর কোন কমান্ড পাঠাতে পারবে আর মানের সীমা
-- (মান NaN হলে তুলনাগুলো false হয়, তাই সেটাও বাদ পড়ে)
---------------------------------------------------------------------
local AUTO_TARGET = "Auto"

local function isNumberBetween(value, low, high)
	return type(value) == "number" and value >= low and value <= high
end

local AUTO_CUES = {
	["State.Cue1"] = true,
	["State.Cue2"] = true,
	["State.Cue3"] = true,
	["State.Cue4"] = true,
	["State.Cue5"] = true,
	["State.Cue9"] = true,
	["State.Cue7"] = true,
	["BumpRandom"] = true,
}

local AUTO_ACTIONS = {
	Color = function(value)
		return typeof(value) == "Color3"
	end,
	Dimness = function(value)
		return isNumberBetween(value, 0, 1)
	end,
	MotorSpeed = function(value)
		return isNumberBetween(value, 0, 0.2)
	end,
	Pan = function(value)
		return isNumberBetween(value, -180, 180)
	end,
	Tilt = function(value)
		return isNumberBetween(value, -180, 180)
	end,
	Cue = function(cueName, enabled)
		return AUTO_CUES[cueName] == true and type(enabled) == "boolean"
	end,
}

-- একসাথে একটাই অটো-কিউ। কন্ডাক্টর বদলালে নতুনজন আগেরটা জানে না,
-- তাই সার্ভার নিজে মনে রাখে আর নতুন কিউ চালুর আগে পুরনোটা বন্ধ করে।
local activeAutoCue = nil

local function runAutoCue(cueName, enabled)
	if enabled then
		if activeAutoCue and activeAutoCue ~= cueName then
			runCommand("All", "Cue", { activeAutoCue, false })
		end
		activeAutoCue = cueName
		runCommand("All", "Cue", { cueName, true })
	elseif activeAutoCue == cueName then
		activeAutoCue = nil
		runCommand("All", "Cue", { cueName, false })
	end
end

-- অ্যাডমিন অটো-কিউ বন্ধ করলে চলতে থাকা অটো-কিউটাও বন্ধ
DJAuthority.getFlagChangedSignal("AutoCue"):Connect(function()
	if not DJAuthority.getFlag("AutoCue") and activeAutoCue then
		runAutoCue(activeAutoCue, false)
	end
end)

---------------------------------------------------------------------
-- ৬) RemoteEvent হ্যান্ডলার
-- ক্লায়েন্ট থেকে আসে: Remote:FireServer(target, action, ...)
--   target = "Auto" হলে অটো-সিঙ্ক (সব গ্রুপে যায়), নাহলে প্যানেলের কমান্ড
---------------------------------------------------------------------
Remote.OnServerEvent:Connect(function(player, target, action, ...)
	if type(target) ~= "string" or type(action) ~= "string" then
		return
	end
	local args = { ... }

	if target == AUTO_TARGET then
		local isValid = AUTO_ACTIONS[action]
		if not isValid or not isValid(table.unpack(args)) then
			return
		end
		if not DJAuthority.isConductor(player) then
			return
		end
		local flagName = if action == "Cue" then "AutoCue" else "AutoLights"
		if not DJAuthority.getFlag(flagName) then
			return
		end
		if not DJAuthority.allow(player, "GLightsAuto", 70, 70) then
			return
		end
		DJAuthority.noteAuto(player)

		if action == "Cue" then
			runAutoCue(args[1], args[2])
		else
			runCommand("All", action, args)
		end
		return
	end

	-- প্যানেলের কমান্ড: শুধু অ্যাডমিন
	if not DJAuthority.isAdmin(player) then
		return
	end
	if not DJAuthority.allow(player, "GLightsManual", 60, 120) then
		return
	end
	runCommand(target, action, args)
end)

print("[ Asset By A Studio ] GLightSync Loaded")
print("Pastikan Anda membeli dari discord A Studio") -- "নিশ্চিত করুন আপনি A Studio-র discord থেকে কিনেছেন"
