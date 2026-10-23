local Icon = require(script:WaitForChild("Icon"))
local rep = game:GetService("ReplicatedStorage")
local modul = rep:WaitForChild("DJSystem"):WaitForChild("Modules")
local admin = require(modul:waitForChild("AdminModule"))
local adminAccess = admin.ADMIN_LIST


local player = game.Players.LocalPlayer

-- Hanya tampilkan icon untuk admin
if admin.isAdmin(player) then
	local icon = Icon.new()
		:setLabel("Glight")
		:bindEvent("selected", function()
			local mainframe = player.PlayerGui.GLightsControlPanel.MainFrame
			mainframe.Visible = true
		end)
		:bindEvent("deselected", function()
			local mainframe = player.PlayerGui.GLightsControlPanel.MainFrame
			mainframe.Visible = false
		end)

	local icon = Icon.new()
		:setLabel("Qpyro")
		:bindEvent("selected", function()
			local mainframe = player.PlayerGui.QPyroControlPanel.Frame
			mainframe.Visible = true
		end)
		:bindEvent("deselected", function() 
			local mainframe = player.PlayerGui.QPyroControlPanel.Frame
			mainframe.Visible = false
		end)
end
