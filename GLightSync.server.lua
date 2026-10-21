--[[
	GLightSync — Script By A Studio
	এটা আসল obfuscated স্ক্রিপ্টের পড়ার মতো (deobfuscated) সংস্করণ।
	আচরণ হুবহু একই রাখা হয়েছে; শুধু obfuscator-এর নিজের anti-tamper
	কোড ("Tamper Detected!" চেক) বাদ দেওয়া হয়েছে, কারণ ওটা স্ক্রিপ্টের কাজের অংশ না।

	ধরন: Server Script (OnServerEvent ব্যবহার করে)
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
local Remote = ReplicatedStorage:WaitForChild("GLightsRemote")
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
-- ৪) RemoteEvent হ্যান্ডলার
-- ক্লায়েন্ট থেকে আসে: Remote:FireServer(target, action, ...)
--   target : "All" অথবা Lights ফোল্ডারের ভেতরের কোনো গ্রুপের নাম
--   action : "Pan", "Tilt", অথবা Panel মডিউলের যেকোনো কমান্ড
--   ...    : কমান্ডের মান (যেমন Pan/Tilt-এর জন্য ডিগ্রি)
---------------------------------------------------------------------
Remote.OnServerEvent:Connect(function(player, target, action, ...)
	local args = { ... }
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
		for _, side in ipairs(group:GetChildren()) do
			if side.Name == "A" or side.Name == "B" then
				local degrees = value
				if action == "Pan" and side.Name == "B" then
					degrees = -value
				end

				for _, fixture in ipairs(side:GetChildren()) do
					if not setMotorAngle(fixture, action, degrees) then
						-- মোটর না থাকলে Panel মডিউলকে কাজটা দেওয়া হয়
						forwardToPanel(groupName)
					end
				end
			end
		end
	end

	if target == "All" then
		for _, groupName in ipairs(ALL_GROUPS) do
			applyToGroup(groupName)
		end
	else
		applyToGroup(target)
	end
end)

print("[ Asset By A Studio ] GLightSync Loaded")
print("Pastikan Anda membeli dari discord A Studio") -- "নিশ্চিত করুন আপনি A Studio-র discord থেকে কিনেছেন"
