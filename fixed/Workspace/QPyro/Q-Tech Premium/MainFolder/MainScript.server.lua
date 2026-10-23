-- জায়গা: workspace > QPyro > Q-Tech Premium > MainFolder > MainScript
-- ফিক্স (ISSUES.md #2): টিভি চালু করতে পারবে শুধু অ্যাডমিন,
-- আর চালু হয়ে গেলে আবার চাপলে কিছু হবে না (আগে Loading মুছে যাওয়ার পর error দিত)।

-- ===================== এই টিভির অ্যাডমিন =====================
-- এই মডেলে Sandbox চালু থাকলে স্ক্রিপ্টটা ReplicatedStorage-এর
-- AdminModule পড়তে পারে না, তাই টিভির অ্যাডমিন এখানে লিখুন।
-- (গেমের মালিক সবসময় অ্যাডমিন।)
local ADMIN_USER_IDS = {
	-- 12345678,
}
local ADMIN_NAMES = {
	"Rojin00110",
	"Tajim_294",
}

-- Sandbox বন্ধ থাকলে AdminModule-এর লিস্টও মানা হবে; চালু থাকলে চুপচাপ বাদ
local AdminModule = nil
pcall(function()
	local djSystem = game:GetService("ReplicatedStorage"):FindFirstChild("DJSystem")
	local modules = djSystem and djSystem:FindFirstChild("Modules")
	local module = modules and modules:FindFirstChild("AdminModule")
	if module then
		AdminModule = require(module)
	end
end)

local function isAdmin(player)
	local ok, isOwner = pcall(function()
		return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
	end)
	if ok and isOwner then
		return true
	end

	if table.find(ADMIN_USER_IDS, player.UserId) then
		return true
	end

	local playerName = string.lower(player.Name)
	for _, adminName in ipairs(ADMIN_NAMES) do
		if playerName == string.lower(adminName) then
			return true
		end
	end

	if AdminModule then
		local moduleOk, result = pcall(AdminModule.isAdmin, player)
		if moduleOk and result then
			return true
		end
	end
	return false
end

local Main_Zone = script.Parent.Screen.Loading.MainZone
local started = false

script.Parent.Button:WaitForChild("ClickDetector").MouseClick:Connect(function(player)
	if started or not isAdmin(player) then
		return
	end
	started = true
	script.Parent.Button.Color = Color3.fromRGB(85, 255, 0)
	script.Parent.Motor.DesiredAngle = -1
	wait(2)
	Main_Zone.A.VideoConnected.Visible = true
	Main_Zone.A.TextLoading.MainText.TextTransparency = 0
	wait(1)
	Main_Zone.A.TextLoading.PointA.TextTransparency = 0
	wait(1.5)
	Main_Zone.A.TextLoading.PointB.TextTransparency = 0
	wait(1.5)
	Main_Zone.A.TextLoading.PointC.TextTransparency = 0
	wait(1)
	Main_Zone.A.TextLoading.MainText.TextColor3 = Color3.fromRGB(85, 255, 0)
	Main_Zone.A.TextLoading.PointA.TextColor3 = Color3.fromRGB(85, 255, 0)
	Main_Zone.A.TextLoading.PointB.TextColor3 = Color3.fromRGB(85, 255, 0)
	Main_Zone.A.TextLoading.PointC.TextColor3 = Color3.fromRGB(85, 255, 0)
	wait(1)
	Main_Zone.A.TextLoading.MainText.TextTransparency = 1
	Main_Zone.A.TextLoading.PointA.TextTransparency = 1
	Main_Zone.A.TextLoading.PointB.TextTransparency = 1
	Main_Zone.A.TextLoading.PointC.TextTransparency = 1
	Main_Zone.A.VideoConnected.Visible = false
	wait(0.5)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0.9
	wait(0.1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0.8
	wait(0.1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0.7
	wait(0.1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0.6
	wait(0.1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0.5
	wait(0.1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0.4
	wait(0.1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0.3
	wait(0.1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0.2
	wait(0.1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0.1
	wait(0.1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0
	wait(1)
	Main_Zone.A.Logo.T.TextTransparency = 0
	wait(0.5)
	Main_Zone.A.Logo.e.TextTransparency = 0
	wait(0.5)
	Main_Zone.A.Logo.c.TextTransparency = 0
	wait(0.5)
	Main_Zone.A.Logo.h.TextTransparency = 0
	wait(1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0.1
	Main_Zone.A.Logo.T.TextTransparency = 0.1
	Main_Zone.A.Logo.e.TextTransparency = 0.1
	Main_Zone.A.Logo.c.TextTransparency = 0.1
	Main_Zone.A.Logo.h.TextTransparency = 0.1
	wait(0.1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0.2
	Main_Zone.A.Logo.T.TextTransparency = 0.2
	Main_Zone.A.Logo.e.TextTransparency = 0.2
	Main_Zone.A.Logo.c.TextTransparency = 0.2
	Main_Zone.A.Logo.h.TextTransparency = 0.2
	wait(0.1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0.3
	Main_Zone.A.Logo.T.TextTransparency = 0.3
	Main_Zone.A.Logo.e.TextTransparency = 0.3
	Main_Zone.A.Logo.c.TextTransparency = 0.3
	Main_Zone.A.Logo.h.TextTransparency = 0.3
	wait(0.1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0.4
	Main_Zone.A.Logo.T.TextTransparency = 0.4
	Main_Zone.A.Logo.e.TextTransparency = 0.4
	Main_Zone.A.Logo.c.TextTransparency = 0.4
	Main_Zone.A.Logo.h.TextTransparency = 0.4
	wait(0.1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0.5
	Main_Zone.A.Logo.T.TextTransparency = 0.5
	Main_Zone.A.Logo.e.TextTransparency = 0.5
	Main_Zone.A.Logo.c.TextTransparency = 0.5
	Main_Zone.A.Logo.h.TextTransparency = 0.5
	wait(0.1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0.6
	Main_Zone.A.Logo.T.TextTransparency = 0.6
	Main_Zone.A.Logo.e.TextTransparency = 0.6
	Main_Zone.A.Logo.c.TextTransparency = 0.6
	Main_Zone.A.Logo.h.TextTransparency = 0.6
	wait(0.1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0.7
	Main_Zone.A.Logo.T.TextTransparency = 0.7
	Main_Zone.A.Logo.e.TextTransparency = 0.7
	Main_Zone.A.Logo.c.TextTransparency = 0.7
	Main_Zone.A.Logo.h.TextTransparency = 0.7
	wait(0.1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0.8
	Main_Zone.A.Logo.T.TextTransparency = 0.8
	Main_Zone.A.Logo.e.TextTransparency = 0.8
	Main_Zone.A.Logo.c.TextTransparency = 0.8
	Main_Zone.A.Logo.h.TextTransparency = 0.8
	wait(0.1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 0.9
	Main_Zone.A.Logo.T.TextTransparency = 0.9
	Main_Zone.A.Logo.e.TextTransparency = 0.9
	Main_Zone.A.Logo.c.TextTransparency = 0.9
	Main_Zone.A.Logo.h.TextTransparency = 0.9
	wait(0.1)
	Main_Zone.A.Logo.Logo.ImageTransparency = 1
	Main_Zone.A.Logo.T.TextTransparency = 1
	Main_Zone.A.Logo.e.TextTransparency = 1
	Main_Zone.A.Logo.c.TextTransparency = 1
	Main_Zone.A.Logo.h.TextTransparency = 1
	wait(0.1)
	script.Parent.Screen.Loading.Enabled = false
	script.Parent.Screen.Loading:Destroy()
	script.Parent.Screen.MainGui.Enabled = true
	wait(0.1)
	script.Parent.Screen.MainGui.Heading.Visible = true
	wait(0.1)
	script.Parent.Screen.MainGui.MainZone.A.Visible = true
	wait(0.1)
	script.Parent.Screen.MainGui.MainZone.B.Visible = true
	wait(0.1)
	script.Parent.Screen.MainGui.MainZone.C.Visible = true
	wait(0.1)
	script.Parent.Screen.MainGui.MainZone.D.Visible = true
end)
