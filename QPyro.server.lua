--[[
	QPyro — Script By A Studio
	এটা আসল obfuscated স্ক্রিপ্টের পড়ার মতো (deobfuscated) সংস্করণ।
	আচরণ হুবহু একই রাখা হয়েছে; শুধু obfuscator-এর নিজের anti-tamper
	কোড বাদ দেওয়া হয়েছে, কারণ ওটা স্ক্রিপ্টের কাজের অংশ না।

	ধরন: Server Script (OnServerEvent ব্যবহার করে)
]]

local HttpService = game:GetService("HttpService")

---------------------------------------------------------------------
-- ১) লাইসেন্স চেক (GLightSync-এর মতোই)
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
print("Sistem QPyro Berhasil Dijalankan!")                  -- "QPyro সিস্টেম সফলভাবে চালু হয়েছে!"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remote = ReplicatedStorage:WaitForChild("QPyroRemote")

---------------------------------------------------------------------
-- ২) Helper-গুলো
-- প্রতিটা ইফেক্ট workspace.QPyro-র ভেতরের একটা ফোল্ডারে থাকে।
-- ফোল্ডারটা প্রতিবার কল করার সময় খোঁজা হয় (আসল কোডেও তাই)।
---------------------------------------------------------------------

-- folder-এর ভেতরে যেসব child-এর নাম names-এর কোনো একটার সাথে মেলে,
-- তাদের প্রত্যেকের উপর apply(child) চালায়।
-- names না দিলে সব child-এর উপর চালায়।
local function forEachNamed(folder, names, apply)
	for _, child in ipairs(folder:GetChildren()) do
		local matches = names == nil
		if names then
			for _, name in ipairs(names) do
				if child.Name == name then
					matches = true
					break
				end
			end
		end
		if matches then
			apply(child)
		end
	end
end

-- কোনো object থাকলে তবেই Enabled সেট করে (না থাকলে চুপচাপ বাদ দেয়)
local function setEnabledIfExists(object, on)
	if object then
		object.Enabled = on
	end
end

-- on/off ফাংশন থেকে { activate, deactivate } টেবিল বানায়
local function makeEffect(setState)
	return {
		activate = function()
			setState(true)
		end,
		deactivate = function()
			setState(false)
		end,
	}
end

---------------------------------------------------------------------
-- ৩) ইফেক্টগুলো
---------------------------------------------------------------------

-- Main_Pyro.Fire_Machine → "Fire" নামের মেশিন
local function setFire(on)
	local folder = game.Workspace.QPyro.Main_Pyro.Fire_Machine
	forEachNamed(folder, { "Fire" }, function(machine)
		machine.Shot.F1.Enabled = on
		machine.Shot.Light.Enabled = on
	end)
end

-- Main_Pyro.Co2_Machine → "Co2" নামের মেশিন (LED, শব্দ, আলো সহ)
local function setCo2(on)
	local folder = game.Workspace.QPyro.Main_Pyro.Co2_Machine
	forEachNamed(folder, { "Co2" }, function(machine)
		local shot = machine.Co2_Shot
		shot.Shot.Shot.Enabled = on
		shot.Led.Transparency = on and 1 or 0
		shot.MainLed.Transparency = on and 0 or 1
		shot.Shot.Sound.Playing = on
		shot.Shot.Light.Brightness = on and 5 or 1
	end)
end

-- Main_Pyro.Spark_Machine → "Spark" নামের মেশিন
local function setSpark(on)
	local folder = game.Workspace.QPyro.Main_Pyro.Spark_Machine
	forEachNamed(folder, { "Spark" }, function(machine)
		machine.S1.S1.Enabled = on
		machine.S1.S2.Enabled = on
		machine.S1.S3.Enabled = on
		machine.S1.Sound.Playing = on
	end)
end

-- Main_Pyro.Confetti_Machine → "Confetti_Cannon" নামের কামান
local function setConfetti(on)
	local folder = game.Workspace.QPyro.Main_Pyro.Confetti_Machine
	forEachNamed(folder, { "Confetti_Cannon" }, function(cannon)
		local confetti = cannon.Confetti
		for i = 1, 5 do
			confetti["P" .. i].Enabled = on
		end
		confetti.Smoke.Enabled = on
		confetti.Sound1.Playing = on
		confetti.Sound2.Playing = on
	end)
end

-- Main_Pyro.Co2_Two → "TCo2" নামের মেশিন
local function setCo2Two(on)
	local folder = game.Workspace.QPyro.Main_Pyro.Co2_Two
	forEachNamed(folder, { "TCo2" }, function(machine)
		machine.Co2_Shot.Shot.Enabled = on
		machine.Co2_Shot.Sound.Playing = on
	end)
end

-- Special_Effects.Moving_Fire.FPA → ভেতরের সব মেশিন (নাম দেখে না)
local function setMovingFireA(on)
	local folder = game.Workspace.QPyro.Special_Effects.Moving_Fire.FPA
	forEachNamed(folder, nil, function(machine)
		machine.Shot.F.Enabled = on
		machine.Shot.Light.Enabled = on
	end)
end

-- Special_Effects.Triple_Co2 → "T_Co2" মেশিনের A, B, C তিনটা নল
local function setTripleCo2(on)
	local folder = game.Workspace.QPyro.Special_Effects.Triple_Co2
	forEachNamed(folder, { "T_Co2" }, function(machine)
		for _, side in ipairs({ "A", "B", "C" }) do
			local nozzle = machine.Co2_Shot[side]["Co2_" .. side]
			nozzle.Shot.Enabled = on
			nozzle.Sound.Playing = on
		end
	end)
end

-- Special_Effects.TopFire → "TFire" নামের মেশিন
local function setTopFire(on)
	local folder = game.Workspace.QPyro.Special_Effects.TopFire
	forEachNamed(folder, { "TFire" }, function(machine)
		machine.ShotFire.TF.Enabled = on
		machine.ShotFire.TL.Enabled = on
	end)
end

-- Special_Effects.Moving_Fire.FPB → "MFireA"/"MFireB" মেশিনের দুই দিকের আগুন
local function setFireProjectorB(on)
	local folder = game.Workspace.QPyro.Special_Effects.Moving_Fire.FPB
	forEachNamed(folder, { "MFireA", "MFireB" }, function(machine)
		local shotA = machine.Main.FSA.ShotA
		local fireA = shotA:FindFirstChild("FA")
		local lightA = shotA:FindFirstChild("LA")
		setEnabledIfExists(fireA, on)
		setEnabledIfExists(lightA, on)

		local shotB = machine.Main.FSB.ShotB
		local fireB = shotB:FindFirstChild("FB")
		local lightB = shotB:FindFirstChild("LB")
		setEnabledIfExists(fireB, on)
		setEnabledIfExists(lightB, on)
	end)
end

-- Special_Effects.Moving_Fire.FPC → "FireProjectorA"/"FireProjectorB"-এর ৭টা নল (F1..F7)
local function setFireProjectorC(on)
	local folder = game.Workspace.QPyro.Special_Effects.Moving_Fire.FPC
	forEachNamed(folder, { "FireProjectorA", "FireProjectorB" }, function(projector)
		local fireShot = projector.FireShot
		for i = 1, 7 do
			local nozzle = fireShot:FindFirstChild("F" .. i)
			if nozzle then
				local flame = nozzle:FindFirstChild("F" .. i)
				local light = nozzle:FindFirstChild("Light")
				setEnabledIfExists(flame, on)
				setEnabledIfExists(light, on)
			end
		end
	end)
end

-- ক্লায়েন্ট যে নাম পাঠাবে → কোন ইফেক্ট চলবে।
-- কয়েকটা নাম একই জিনিস চালায় (যেমন MOVING_FIRE_A আর FPA)।
local Effects = {
	FIRE = makeEffect(setFire),
	CO2 = makeEffect(setCo2),
	SPARK = makeEffect(setSpark),
	CONFETTI = makeEffect(setConfetti),
	CO2_TWO = makeEffect(setCo2Two),
	MOVING_FIRE_A = makeEffect(setMovingFireA),
	TRIPLE_CO2 = makeEffect(setTripleCo2),
	TOP_FIRE = makeEffect(setTopFire),
	FIRE_PROJECTOR = makeEffect(setFireProjectorC),
	FPA = makeEffect(setMovingFireA),
	FPB = makeEffect(setFireProjectorB),
	FPC = makeEffect(setFireProjectorC),
}

---------------------------------------------------------------------
-- ৪) RemoteEvent হ্যান্ডলার
-- ক্লায়েন্ট থেকে আসে: Remote:FireServer(effectName, isOn)
--   effectName : উপরের Effects টেবিলের কোনো নাম, যেমন "FIRE"
--   isOn       : true (বা যেকোনো truthy মান) হলে চালু, false/nil হলে বন্ধ
-- অজানা নাম এলে কিছুই হয় না।
---------------------------------------------------------------------
Remote.OnServerEvent:Connect(function(player, effectName, isOn)
	local effect = Effects[effectName]
	if not effect then
		return
	end

	if isOn then
		effect.activate()
	else
		effect.deactivate()
	end
end)

print("Asset By A Studio")
print("Pastikan anda membeli dari discord A Studio") -- "নিশ্চিত করুন আপনি A Studio-র discord থেকে কিনেছেন"
print("QPyro loaded successfully!")
