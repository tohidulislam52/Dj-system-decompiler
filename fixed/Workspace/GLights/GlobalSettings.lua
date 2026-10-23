-- AdminModule-এর নাম আর UserId থেকে GLights-এর whitelist বানানো
local function getAdminWhitelist()
	local AdminModule = require(game:GetService("ReplicatedStorage"):WaitForChild("MusicModule"):WaitForChild("AdminModule"))
	local list = {}
	for _, name in ipairs(AdminModule.ADMIN_LIST) do
		table.insert(list, name)
	end
	for _, userId in ipairs(AdminModule.ADMIN_USER_IDS or {}) do
		table.insert(list, userId)
	end
	if AdminModule.ALLOW_OWNER and game.CreatorType == Enum.CreatorType.User then
		table.insert(list, game.CreatorId)
	end
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
	-- ফিক্স (ISSUES.md #2): Reset বাটন শুধু AdminModule-এর অ্যাডমিনদের জন্য।
	-- নাম এখানে না, ReplicatedStorage > MusicModule > AdminModule-এ লিখুন।
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
