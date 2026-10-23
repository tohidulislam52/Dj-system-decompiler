--[[
	DJControlLock — জায়গা: StarterPlayer > StarterPlayerScripts > DJSystem > Controls (LocalScript)

	ফিক্স (ISSUES.md #2):
	  Q-Tech টিভির বাটনগুলো (workspace.QPyro["Q-Tech Premium"]) সার্ভারের
	  Script দিয়ে চলে, আর কে চাপল সেটা ওই Script জানতে পারে না। তাই যারা
	  AdminModule-এ নেই, তাদের নিজের স্ক্রিনে টিভির বাটনগুলো এখানে বন্ধ করে
	  দেওয়া হয়, যাতে চাপলেও কিছু না হয়। টিভি দেখা যাবে, শুধু চাপা যাবে না।

	সতর্কতা: এটা সাধারণ প্লেয়ারদের আটকায়, কিন্তু exploiter নিজের ক্লায়েন্টে
	এটা বন্ধ করতে পারে। পুরোপুরি নিরাপদ করতে টিভির স্ক্রিপ্টগুলো RemoteEvent
	দিয়ে নতুন করে লিখতে হবে (ISSUES.md #2-এ নোট করা আছে)।
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminModule = require(ReplicatedStorage:WaitForChild("DJSystem"):WaitForChild("Modules"):WaitForChild("AdminModule"))

local player = Players.LocalPlayer
if AdminModule.isAdmin(player) then
	return
end

local TV_NAME = "Q-Tech Premium"

local function lock(object)
	if object:IsA("GuiButton") then
		object.Interactable = false
		object.AutoButtonColor = false
	elseif object:IsA("TextBox") then
		object.Interactable = false
		object.TextEditable = false
	elseif object:IsA("ClickDetector") then
		object.MaxActivationDistance = 0
	end
end

local function lockTV(tv)
	for _, object in ipairs(tv:GetDescendants()) do
		lock(object)
	end
	tv.DescendantAdded:Connect(lock)
end

local function findTV()
	local qpyro = workspace:WaitForChild("QPyro")
	local tv = qpyro:FindFirstChild(TV_NAME)
	if tv then
		lockTV(tv)
	end
	-- StreamingEnabled থাকলে টিভি পরে আসতে পারে
	qpyro.ChildAdded:Connect(function(child)
		if child.Name == TV_NAME then
			lockTV(child)
		end
	end)
end

findTV()
