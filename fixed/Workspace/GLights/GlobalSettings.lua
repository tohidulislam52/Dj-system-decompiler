-- ===================== Reset বাটনের অ্যাডমিন =====================
-- GLights ফোল্ডারে Sandbox চালু থাকলে এটা ReplicatedStorage-এর
-- AdminModule পড়তে পারে না, তাই এখানেও নাম/UserId লেখা যায়।
local ADMIN_USER_IDS = {
	-- 12345678,
}
local ADMIN_NAMES = {
	"Rojin00110",
	"Tajim_294",
}

-- এখানকার লিস্ট + (পড়া গেলে) AdminModule-এর লিস্ট + গেমের মালিক
local function getAdminWhitelist()
	local list = {}
	for _, name in ipairs(ADMIN_NAMES) do
		table.insert(list, name)
	end
	for _, userId in ipairs(ADMIN_USER_IDS) do
		table.insert(list, userId)
	end

	pcall(function()
		local djSystem = game:GetService("ReplicatedStorage"):FindFirstChild("DJSystem")
		local modules = djSystem and djSystem:FindFirstChild("Modules")
		local module = modules and modules:FindFirstChild("AdminModule")
		if not module then
			return
		end
		local AdminModule = require(module)
		for _, name in ipairs(AdminModule.ADMIN_LIST or {}) do
			table.insert(list, name)
		end
		for _, userId in ipairs(AdminModule.ADMIN_USER_IDS or {}) do
			table.insert(list, userId)
		end
	end)

	pcall(function()
		if game.CreatorType == Enum.CreatorType.User then
			table.insert(list, game.CreatorId)
		end
	end)
	return list
end

return {
	-- A list of who should be able to control the lights
	-- You can use:
	-- - usernames, for example: "gabys2005"
	-- - user ids, for example: 147274250
	-- - group ranks, for example: { Group = 32780278, Ranks = { "Staff", "Owner" } }
	-- - gamepasses, for example: { Gamepass = 14143793 }
	-- - teams, for example: game.Teams.controllers
	-- - to allow private server owners, use "PrivateServerOwner"
	-- - to allow private server players, use "PrivateServerPlayer"
	-- The whitelist is disabled by default, set `Enabled = true,` to enable the whitelist
	-- Each entry should be separated by a comma (,)
	-- For example, a whitelist could look like this:
	-- 		Whitelist = {
	--			Enabled = true,
	--			List = { "gabys2005", "idezye", { Group = 32780278, Ranks = { "Staff", "Owner" } }
	--		},
	-- ফিক্স (ISSUES.md #2): Reset বাটন শুধু অ্যাডমিনদের জন্য।
	-- নাম/আইডি এই ফাইলের একদম উপরের ADMIN_NAMES / ADMIN_USER_IDS-এ লিখুন।
	Whitelist = {
		Enabled = true,
		List = getAdminWhitelist(),
	},

	-- Whether or not the lights should check for possible updates
	-- You need to enable HTTP requests for the lights to be able to check for updates
	CheckForUpdates = true,

	-- Whether lights should fade off or turn off when they're being reset
	FadeReset = false,
}
