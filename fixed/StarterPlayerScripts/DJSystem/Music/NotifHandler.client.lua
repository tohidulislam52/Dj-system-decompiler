local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")

local NotificationModule = require(ReplicatedStorage:WaitForChild("DJSystem"):WaitForChild("Modules"):WaitForChild("NotificationModule"))

local musicRemotes = ReplicatedStorage:WaitForChild("DJSystem"):WaitForChild("Remotes"):WaitForChild("MusicRemotes")
local queueNotificationRemote = musicRemotes:WaitForChild("QueueNotification")
local skipNotificationRemote = musicRemotes:WaitForChild("SkipNotification")

queueNotificationRemote.OnClientEvent:Connect(function(playerName, songName, queuePosition)

	if queuePosition == -1 then

		NotificationModule.showNotification(playerGui, songName, Color3.fromRGB(255, 100, 100))
	else
		local message = playerName .. " menambahkan " .. songName .. " ke antrian, No " .. queuePosition
		NotificationModule.showNotification(playerGui, message)
	end
end)

skipNotificationRemote.OnClientEvent:Connect(function(songName)
	local message = "Skip terpenuhi, sekarang memainkan lagu: " .. songName
	NotificationModule.showNotification(playerGui, message)
end)

print("NotifHandler loaded successfully")
