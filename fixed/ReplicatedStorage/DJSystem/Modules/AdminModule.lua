--[[
	AdminModule — DJ সিস্টেমের Config (কে কন্ট্রোল করতে পারবে)
	জায়গা: ReplicatedStorage > DJSystem > Modules > AdminModule (ModuleScript)

	এখানে যাদের নাম/UserId দেবেন, শুধু তারাই পারবে:
	  - GLights আর QPyro কন্ট্রোল প্যানেল (TopBar আইকন)
	  - Q-Tech টিভির বাটন আর পাওয়ার বাটন
	  - GLights-এর Reset বাটন
	  - গানের ভলিউম আর ইকুয়ালাইজার
	বাকিরা বাটন চাপলেও সার্ভার কমান্ড বাদ দিয়ে দেবে।
]]

local AdminModule = {}

-- ===================== ADMIN LIST =====================
-- Roblox username (Display Name না)। বড়/ছোট হাতের অক্ষরে সমস্যা নেই।
AdminModule.ADMIN_LIST = {
	"Rojin00110",
	"Tajim_294",
}

-- (ঐচ্ছিক) UserId — কেউ username বদলালেও এটা কাজ করে
-- উদাহরণ: AdminModule.ADMIN_USER_IDS = { 12345678, 87654321 }
AdminModule.ADMIN_USER_IDS = {}

-- true হলে গেমের মালিক সবসময় অ্যাডমিন (গেমটা নিজের অ্যাকাউন্টে হলে)
AdminModule.ALLOW_OWNER = true

function AdminModule.isAdmin(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end

	if AdminModule.ALLOW_OWNER and game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end

	if table.find(AdminModule.ADMIN_USER_IDS, player.UserId) then
		return true
	end

	local playerName = string.lower(player.Name)
	for _, adminName in ipairs(AdminModule.ADMIN_LIST) do
		if playerName == string.lower(adminName) then
			return true
		end
	end
	return false
end

return AdminModule
