--[[
	MusicUI — জায়গা: StarterPlayer > StarterPlayerScripts > DJSystem > Music > MusicUI (LocalScript)

	নতুন মিউজিক প্যানেল (ISSUES.md #6)। পুরো UI এই স্ক্রিপ্টই বানায়,
	Studio-তে আলাদা করে কোনো ScreenGui বানাতে হয় না।
	  - "MusicPrompt" ProximityPrompt চাপলে প্যানেল খোলে/বন্ধ হয় (আগের মতো),
	    উপরের ডান কোণের X বাটনেও বন্ধ হয়
	  - বাম পাশে: এখন কোন গান বাজছে, সময়, ভলিউম, স্কিপ
	  - ডান পাশে ট্যাব: DJ, PHONK, QUEUE, আর শুধু অ্যাডমিনের জন্য EQ
	  - গানের লিস্ট আসে ReplicatedStorage > DJSystem > Modules > MusicPlaylist থেকে
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local djSystem = ReplicatedStorage:WaitForChild("DJSystem")
local modules = djSystem:WaitForChild("Modules")
local AdminModule = require(modules:WaitForChild("AdminModule"))
local Playlist = require(modules:WaitForChild("MusicPlaylist"))
local Settings = Playlist.Settings or {}

local musicRemotes = djSystem:WaitForChild("Remotes"):WaitForChild("Music")
local GetState = musicRemotes:WaitForChild("GetState")
local RequestSong = musicRemotes:WaitForChild("RequestSong")
local SkipSong = musicRemotes:WaitForChild("SkipSong")
local SetVolume = musicRemotes:WaitForChild("SetVolume")
local SetEqualizer = musicRemotes:WaitForChild("SetEqualizer")
local StateChanged = musicRemotes:WaitForChild("StateChanged")
local Notify = musicRemotes:WaitForChild("Notify")

local isAdmin = AdminModule.isAdmin(player)

---------------------------------------------------------------------
-- রং আর ফন্ট
---------------------------------------------------------------------
local COLORS = {
	Background = Color3.fromRGB(13, 13, 20),
	Panel = Color3.fromRGB(22, 22, 33),
	PanelLight = Color3.fromRGB(32, 32, 46),
	Stroke = Color3.fromRGB(58, 58, 82),
	Text = Color3.fromRGB(240, 240, 248),
	SubText = Color3.fromRGB(150, 150, 172),
	Danger = Color3.fromRGB(235, 64, 85),
	Success = Color3.fromRGB(70, 210, 130),
	DJ = Color3.fromRGB(0, 200, 255),
	Phonk = Color3.fromRGB(255, 60, 120),
	Queue = Color3.fromRGB(255, 190, 60),
	EQ = Color3.fromRGB(150, 110, 255),
}
local FONT_BOLD = Enum.Font.GothamBold
local FONT = Enum.Font.GothamMedium
local DISC_IMAGE = "rbxassetid://93391259236497"

local CATEGORY_LABEL = { DJ = "DJ", Phonk = "PHONK" }

---------------------------------------------------------------------
-- ছোট helper
---------------------------------------------------------------------
local function create(className, props, children)
	local object = Instance.new(className)
	for key, value in pairs(props or {}) do
		object[key] = value
	end
	for _, child in ipairs(children or {}) do
		child.Parent = object
	end
	return object
end

local function corner(radius)
	return create("UICorner", { CornerRadius = radius or UDim.new(0, 10) })
end

local function stroke(color, thickness, transparency)
	return create("UIStroke", {
		Color = color or COLORS.Stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function textLimit(maxSize)
	return create("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 8 })
end

local function label(props)
	local object = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = props.Font or FONT,
		TextColor3 = props.TextColor3 or COLORS.Text,
		TextScaled = true,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		Text = props.Text or "",
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Name = props.Name,
		ZIndex = props.ZIndex or 1,
		TextTruncate = props.TextTruncate or Enum.TextTruncate.None,
	}, { textLimit(props.MaxTextSize or 18) })
	return object
end

local function button(props)
	local object = create("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = props.Color or COLORS.PanelLight,
		BackgroundTransparency = props.BackgroundTransparency or 0,
		Font = props.Font or FONT_BOLD,
		TextColor3 = props.TextColor3 or COLORS.Text,
		TextScaled = true,
		Text = props.Text or "",
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Name = props.Name,
		ZIndex = props.ZIndex or 1,
	}, {
		corner(props.Radius),
		textLimit(props.MaxTextSize or 18),
		create("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 3),
			PaddingBottom = UDim.new(0, 3),
		}),
	})
	-- মাউস রাখলে হালকা উজ্জ্বল
	local baseTransparency = object.BackgroundTransparency
	object.MouseEnter:Connect(function()
		object.BackgroundTransparency = math.max(0, baseTransparency - 0.15)
	end)
	object.MouseLeave:Connect(function()
		object.BackgroundTransparency = baseTransparency
	end)
	return object
end

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function categoryColor(category)
	return COLORS[category] or COLORS.DJ
end

---------------------------------------------------------------------
-- ScreenGui আর মূল প্যানেল (সাইজ আগের প্যানেলের মতো)
---------------------------------------------------------------------
local oldGui = playerGui:FindFirstChild("DJMusicGui")
if oldGui then
	oldGui:Destroy()
end

local screenGui = create("ScreenGui", {
	Name = "DJMusicGui",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 5,
	Parent = playerGui,
})

local panelScale = create("UIScale", { Scale = 1 })
local panel = create("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.472),
	Size = UDim2.fromScale(0.6, 0.655),
	BackgroundColor3 = COLORS.Background,
	BackgroundTransparency = 0.04,
	Visible = false,
	Parent = screenGui,
}, {
	corner(UDim.new(0, 16)),
	stroke(COLORS.DJ, 2, 0.2),
	panelScale,
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 215)),
	}),
})
local panelStroke = panel:FindFirstChildOfClass("UIStroke")

-- হেডার
local header = create("Frame", {
	Name = "Header",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0.11),
	Parent = panel,
})
local titleLabel = label({
	Name = "Title",
	Text = "♪  " .. (Settings.Title or "DJ MUSIC"),
	Font = FONT_BOLD,
	Size = UDim2.fromScale(0.6, 0.62),
	Position = UDim2.fromScale(0.025, 0.22),
	MaxTextSize = 24,
})
titleLabel.Parent = header

local closeButton = button({
	Name = "Close",
	Text = "X",
	Color = COLORS.Danger,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(0.985, 0, 0.55, 0),
	Size = UDim2.fromScale(0.07, 0.7),
	MaxTextSize = 20,
	Radius = UDim.new(0, 8),
})
create("UIAspectRatioConstraint", { AspectRatio = 1.25, Parent = closeButton })
closeButton.Parent = header

create("Frame", {
	Name = "Divider",
	BackgroundColor3 = COLORS.Stroke,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.02, 0.115),
	Size = UDim2.new(0.96, 0, 0, 1),
	Parent = panel,
})

---------------------------------------------------------------------
-- বাম পাশ: এখন বাজছে
---------------------------------------------------------------------
local nowCard = create("Frame", {
	Name = "NowPlaying",
	BackgroundColor3 = COLORS.Panel,
	Position = UDim2.fromScale(0.02, 0.14),
	Size = UDim2.fromScale(0.32, 0.83),
	Parent = panel,
}, { corner(UDim.new(0, 12)), stroke() })

local discHolder = create("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.04),
	Size = UDim2.fromScale(0.9, 0.38),
	Parent = nowCard,
})
local disc = create("ImageLabel", {
	Name = "Disc",
	Image = DISC_IMAGE,
	BackgroundColor3 = COLORS.PanelLight,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	ScaleType = Enum.ScaleType.Crop,
	Parent = discHolder,
}, {
	create("UIAspectRatioConstraint", { AspectRatio = 1 }),
	corner(UDim.new(1, 0)),
	stroke(COLORS.DJ, 2, 0.1),
})
local discStroke = disc:FindFirstChildOfClass("UIStroke")

local badge = create("TextLabel", {
	Name = "Badge",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.445),
	Size = UDim2.fromScale(0.36, 0.055),
	BackgroundColor3 = COLORS.DJ,
	Font = FONT_BOLD,
	Text = "DJ",
	TextColor3 = COLORS.Background,
	TextScaled = true,
	Visible = false,
	Parent = nowCard,
}, { corner(UDim.new(1, 0)), textLimit(14) })

local songTitle = label({
	Name = "SongTitle",
	Text = "No music playing",
	Font = FONT_BOLD,
	TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromScale(0.05, 0.515),
	Size = UDim2.fromScale(0.9, 0.085),
	TextTruncate = Enum.TextTruncate.AtEnd,
	MaxTextSize = 20,
})
songTitle.Parent = nowCard

local requestedBy = label({
	Name = "RequestedBy",
	Text = "",
	TextColor3 = COLORS.SubText,
	TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromScale(0.05, 0.6),
	Size = UDim2.fromScale(0.9, 0.05),
	TextTruncate = Enum.TextTruncate.AtEnd,
	MaxTextSize = 14,
})
requestedBy.Parent = nowCard

local progressBack = create("Frame", {
	Name = "Progress",
	BackgroundColor3 = COLORS.PanelLight,
	Position = UDim2.fromScale(0.07, 0.675),
	Size = UDim2.fromScale(0.86, 0.018),
	Parent = nowCard,
}, { corner(UDim.new(1, 0)) })
local progressFill = create("Frame", {
	BackgroundColor3 = COLORS.DJ,
	Size = UDim2.fromScale(0, 1),
	Parent = progressBack,
}, { corner(UDim.new(1, 0)) })

local timeNow = label({
	Text = "0:00",
	TextColor3 = COLORS.SubText,
	Position = UDim2.fromScale(0.07, 0.7),
	Size = UDim2.fromScale(0.4, 0.045),
	MaxTextSize = 13,
})
timeNow.Parent = nowCard
local timeEnd = label({
	Text = "0:00",
	TextColor3 = COLORS.SubText,
	TextXAlignment = Enum.TextXAlignment.Right,
	Position = UDim2.fromScale(0.53, 0.7),
	Size = UDim2.fromScale(0.4, 0.045),
	MaxTextSize = 13,
})
timeEnd.Parent = nowCard

local volumeMinus = button({
	Name = "VolumeMinus",
	Text = "−",
	Position = UDim2.fromScale(0.07, 0.775),
	Size = UDim2.fromScale(0.22, 0.085),
	MaxTextSize = 22,
})
volumeMinus.Parent = nowCard
local volumeLabel = label({
	Name = "Volume",
	Text = "VOL 5",
	Font = FONT_BOLD,
	TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromScale(0.3, 0.785),
	Size = UDim2.fromScale(0.4, 0.065),
	MaxTextSize = 16,
})
volumeLabel.Parent = nowCard
local volumePlus = button({
	Name = "VolumePlus",
	Text = "+",
	Position = UDim2.fromScale(0.71, 0.775),
	Size = UDim2.fromScale(0.22, 0.085),
	MaxTextSize = 22,
})
volumePlus.Parent = nowCard

local skipButton = button({
	Name = "Skip",
	Text = "SKIP",
	Color = COLORS.DJ,
	TextColor3 = COLORS.Background,
	Position = UDim2.fromScale(0.07, 0.88),
	Size = UDim2.fromScale(0.86, 0.09),
	MaxTextSize = 18,
})
skipButton.Parent = nowCard

---------------------------------------------------------------------
-- ডান পাশ: ট্যাব, সার্চ, লিস্ট
---------------------------------------------------------------------
local right = create("Frame", {
	Name = "Right",
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(0.36, 0.14),
	Size = UDim2.fromScale(0.62, 0.83),
	Parent = panel,
})

local tabBar = create("Frame", {
	Name = "Tabs",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0.1),
	Parent = right,
}, {
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0.015, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local TABS = { "DJ", "Phonk", "Queue" }
if isAdmin then
	table.insert(TABS, "EQ")
end
local TAB_TEXT = { DJ = "DJ", Phonk = "PHONK", Queue = "QUEUE", EQ = "EQ" }
local tabWidth = (1 - 0.015 * (#TABS - 1)) / #TABS
local tabButtons = {}
for index, tabName in ipairs(TABS) do
	local tab = button({
		Name = tabName,
		Text = TAB_TEXT[tabName],
		Size = UDim2.fromScale(tabWidth, 1),
		MaxTextSize = 16,
	})
	tab.LayoutOrder = index
	tab.Parent = tabBar
	tabButtons[tabName] = tab
end

local searchBox = create("TextBox", {
	Name = "Search",
	BackgroundColor3 = COLORS.Panel,
	ClearTextOnFocus = false,
	Font = FONT,
	PlaceholderText = "Search songs...",
	PlaceholderColor3 = COLORS.SubText,
	Text = "",
	TextColor3 = COLORS.Text,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromScale(0, 0.12),
	Size = UDim2.fromScale(1, 0.09),
	Parent = right,
}, {
	corner(UDim.new(0, 8)),
	stroke(),
	textLimit(16),
	create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
})

local function makeList(name)
	return create("ScrollingFrame", {
		Name = name,
		BackgroundColor3 = COLORS.Panel,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0.23),
		Size = UDim2.fromScale(1, 0.77),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = COLORS.SubText,
		Visible = false,
		Parent = right,
	}, {
		corner(UDim.new(0, 10)),
		stroke(),
		create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 8),
		}),
	})
end

local songLists = { DJ = makeList("DJList"), Phonk = makeList("PhonkList") }
local queueList = makeList("QueueList")
queueList.Position = UDim2.fromScale(0, 0.12)
queueList.Size = UDim2.fromScale(1, 0.88)

local ROW_HEIGHT = 36

local function emptyRow(parent, text)
	local row = label({
		Name = "Empty",
		Text = text,
		TextColor3 = COLORS.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		MaxTextSize = 15,
	})
	row.Parent = parent
	return row
end

-- গানের সারি (পুরো সারি চাপলেই গান বাজে / কিউতে যায়)
local lastRequestTime = -math.huge
for _, category in ipairs({ "DJ", "Phonk" }) do
	local list = songLists[category]
	local accent = categoryColor(category)
	local categorySongs = Playlist[category] or {}

	if #categorySongs == 0 then
		emptyRow(list, "No songs yet — add them in MusicPlaylist")
	end

	for index, song in ipairs(categorySongs) do
		if type(song) == "table" and type(song.Id) == "number" and type(song.Name) == "string" then
			local row = create("TextButton", {
				Name = "Song",
				AutoButtonColor = false,
				BackgroundColor3 = COLORS.PanelLight,
				Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
				Text = "",
				LayoutOrder = index,
				Parent = list,
			}, { corner(UDim.new(0, 8)) })
			row:SetAttribute("SongName", string.lower(song.Name))

			label({
				Text = tostring(index),
				TextColor3 = accent,
				Font = FONT_BOLD,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.new(0, 4, 0.2, 0),
				Size = UDim2.new(0, 26, 0.6, 0),
				MaxTextSize = 14,
			}).Parent = row
			label({
				Text = song.Name,
				Position = UDim2.new(0, 34, 0.18, 0),
				Size = UDim2.new(1, -84, 0.64, 0),
				TextTruncate = Enum.TextTruncate.AtEnd,
				MaxTextSize = 15,
			}).Parent = row
			create("TextLabel", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6, 0.5, 0),
				Size = UDim2.new(0, 40, 0.7, 0),
				BackgroundColor3 = accent,
				Font = FONT_BOLD,
				Text = "▶",
				TextColor3 = COLORS.Background,
				TextScaled = true,
				Parent = row,
			}, { corner(UDim.new(0, 6)), textLimit(14) })

			row.MouseEnter:Connect(function()
				row.BackgroundColor3 = COLORS.Stroke
			end)
			row.MouseLeave:Connect(function()
				row.BackgroundColor3 = COLORS.PanelLight
			end)
			row.Activated:Connect(function()
				if os.clock() - lastRequestTime < 0.6 then
					return
				end
				lastRequestTime = os.clock()
				RequestSong:FireServer(category, song.Id)
			end)
		end
	end
end

-- সার্চ (plain খোঁজা, তাই বিশেষ চিহ্ন দিলেও error হয় না)
local function applySearch()
	local query = string.lower(searchBox.Text)
	for _, list in pairs(songLists) do
		for _, row in ipairs(list:GetChildren()) do
			if row:IsA("TextButton") then
				local name = row:GetAttribute("SongName") or ""
				row.Visible = query == "" or string.find(name, query, 1, true) ~= nil
			end
		end
	end
end
searchBox:GetPropertyChangedSignal("Text"):Connect(applySearch)

---------------------------------------------------------------------
-- EQ (শুধু অ্যাডমিন): Low / Mid / High, মাউস আর টাচ দুটোতেই চলে
---------------------------------------------------------------------
local EQ_MIN, EQ_MAX = -60, 10
local eqPanel = create("Frame", {
	Name = "EQ",
	BackgroundColor3 = COLORS.Panel,
	Position = UDim2.fromScale(0, 0.12),
	Size = UDim2.fromScale(1, 0.88),
	Visible = false,
	Parent = right,
}, { corner(UDim.new(0, 10)), stroke() })

local eqSliders = {}
local draggingBand = nil
local lastEqSend = -math.huge

local function valueToScale(value)
	return (value - EQ_MIN) / (EQ_MAX - EQ_MIN)
end

local function setSliderVisual(band, value)
	local slider = eqSliders[band]
	if not slider then
		return
	end
	local scale = valueToScale(value)
	slider.Fill.Size = UDim2.fromScale(scale, 1)
	slider.Knob.Position = UDim2.fromScale(scale, 0.5)
	slider.Value.Text = string.format("%+d dB", math.floor(value + 0.5))
end

for index, band in ipairs({ "Low", "Mid", "High" }) do
	local rowTop = 0.08 + (index - 1) * 0.3
	label({
		Text = band:upper(),
		Font = FONT_BOLD,
		Position = UDim2.fromScale(0.05, rowTop),
		Size = UDim2.fromScale(0.4, 0.1),
		MaxTextSize = 16,
	}).Parent = eqPanel
	local valueLabel = label({
		Text = "+0 dB",
		TextColor3 = COLORS.EQ,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromScale(0.55, rowTop),
		Size = UDim2.fromScale(0.4, 0.1),
		MaxTextSize = 16,
	})
	valueLabel.Parent = eqPanel

	local track = create("Frame", {
		BackgroundColor3 = COLORS.PanelLight,
		Position = UDim2.fromScale(0.05, rowTop + 0.13),
		Size = UDim2.fromScale(0.9, 0.05),
		Active = true,
		Parent = eqPanel,
	}, { corner(UDim.new(1, 0)) })
	local fill = create("Frame", {
		BackgroundColor3 = COLORS.EQ,
		Size = UDim2.fromScale(valueToScale(0), 1),
		Parent = track,
	}, { corner(UDim.new(1, 0)) })
	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = COLORS.Text,
		Position = UDim2.fromScale(valueToScale(0), 0.5),
		Size = UDim2.fromScale(2.4, 2.4),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Parent = track,
	}, { corner(UDim.new(1, 0)) })

	eqSliders[band] = { Track = track, Fill = fill, Knob = knob, Value = valueLabel }

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingBand = band
		end
	end)
end

local function updateDrag(position)
	local slider = eqSliders[draggingBand]
	if not slider then
		return
	end
	local track = slider.Track
	local scale = math.clamp((position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
	local value = EQ_MIN + scale * (EQ_MAX - EQ_MIN)
	setSliderVisual(draggingBand, value)
	if os.clock() - lastEqSend > 0.1 then
		lastEqSend = os.clock()
		SetEqualizer:FireServer(draggingBand, value)
	end
end

UserInputService.InputChanged:Connect(function(input)
	if draggingBand and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		updateDrag(input.Position)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if draggingBand and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		updateDrag(input.Position)
		local slider = eqSliders[draggingBand]
		local scale = slider.Fill.Size.X.Scale
		SetEqualizer:FireServer(draggingBand, EQ_MIN + scale * (EQ_MAX - EQ_MIN))
		draggingBand = nil
	end
end)

---------------------------------------------------------------------
-- ট্যাব বদল
---------------------------------------------------------------------
local currentTab = "DJ"
local function selectTab(tabName)
	currentTab = tabName
	for name, tab in pairs(tabButtons) do
		local selected = name == tabName
		local accent = COLORS[name] or COLORS.DJ
		tab.BackgroundColor3 = selected and accent or COLORS.PanelLight
		tab.TextColor3 = selected and COLORS.Background or COLORS.Text
	end
	songLists.DJ.Visible = tabName == "DJ"
	songLists.Phonk.Visible = tabName == "Phonk"
	queueList.Visible = tabName == "Queue"
	eqPanel.Visible = tabName == "EQ"
	searchBox.Visible = tabName == "DJ" or tabName == "Phonk"
end
for name, tab in pairs(tabButtons) do
	tab.Activated:Connect(function()
		selectTab(name)
	end)
end
selectTab("DJ")

---------------------------------------------------------------------
-- নোটিফিকেশন (প্যানেল বন্ধ থাকলেও দেখা যায়)
---------------------------------------------------------------------
local toastHolder = create("Frame", {
	Name = "Toasts",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.03),
	Size = UDim2.fromScale(0.4, 0.2),
	Parent = screenGui,
}, {
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
create("UISizeConstraint", { MinSize = Vector2.new(260, 0), Parent = toastHolder })

local toastCount = 0
local function showToast(message, kind)
	toastCount += 1
	local accent = COLORS[kind] or (kind == "error" and COLORS.Danger) or COLORS.Success
	local toast = create("TextLabel", {
		BackgroundColor3 = COLORS.Background,
		BackgroundTransparency = 0.1,
		Font = FONT_BOLD,
		Text = message,
		TextColor3 = COLORS.Text,
		TextScaled = true,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = toastCount,
		Parent = toastHolder,
	}, {
		corner(UDim.new(0, 8)),
		stroke(accent, 2),
		textLimit(16),
		create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	local children = toastHolder:GetChildren()
	local toasts = {}
	for _, child in ipairs(children) do
		if child:IsA("TextLabel") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 3 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
	task.delay(3.5, function()
		if toast.Parent then
			local fade = TweenService:Create(toast, TweenInfo.new(0.3), { BackgroundTransparency = 1, TextTransparency = 1 })
			local toastStroke = toast:FindFirstChildOfClass("UIStroke")
			if toastStroke then
				TweenService:Create(toastStroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
			fade:Play()
			fade.Completed:Wait()
			toast:Destroy()
		end
	end)
end

Notify.OnClientEvent:Connect(showToast)

---------------------------------------------------------------------
-- সার্ভারের অবস্থা দেখানো
---------------------------------------------------------------------
local state = nil
local hasVoted = false
local lastSongKey = nil

local function renderQueue()
	for _, child in ipairs(queueList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local entries = state and state.Queue or {}
	if #entries == 0 then
		emptyRow(queueList, "Queue is empty — pick a song from DJ or PHONK")
		return
	end
	for index, entry in ipairs(entries) do
		local accent = categoryColor(entry.Category)
		local row = create("Frame", {
			BackgroundColor3 = COLORS.PanelLight,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			LayoutOrder = index,
			Parent = queueList,
		}, { corner(UDim.new(0, 8)) })
		create("Frame", {
			BackgroundColor3 = accent,
			Position = UDim2.new(0, 0, 0.15, 0),
			Size = UDim2.new(0, 4, 0.7, 0),
			Parent = row,
		}, { corner(UDim.new(1, 0)) })
		label({
			Text = `{index}. {entry.Name}`,
			Position = UDim2.new(0, 12, 0.12, 0),
			Size = UDim2.new(0.62, -12, 0.76, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			MaxTextSize = 15,
		}).Parent = row
		label({
			Text = `{CATEGORY_LABEL[entry.Category] or entry.Category} · {entry.RequestedBy}`,
			TextColor3 = COLORS.SubText,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.62, 0, 0.2, 0),
			Size = UDim2.new(0.38, -8, 0.6, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			MaxTextSize = 13,
		}).Parent = row
	end
end

local function render()
	if not state then
		return
	end
	local current = state.Current
	local accent = current and categoryColor(current.Category) or COLORS.DJ

	local songKey = current and current.PlayId or nil
	if songKey ~= lastSongKey then
		lastSongKey = songKey
		hasVoted = false
	end

	songTitle.Text = current and current.Name or "No music playing"
	requestedBy.Text = current and ("Requested by " .. tostring(current.RequestedBy)) or "Pick a song to start the party"
	badge.Visible = current ~= nil
	if current then
		badge.Text = CATEGORY_LABEL[current.Category] or current.Category
		badge.BackgroundColor3 = accent
	end
	panelStroke.Color = accent
	discStroke.Color = accent
	progressFill.BackgroundColor3 = accent

	volumeLabel.Text = "VOL " .. tostring(math.floor((state.Volume or 0) * 10 + 0.5))
	volumeMinus.TextTransparency = isAdmin and 0 or 0.5
	volumePlus.TextTransparency = isAdmin and 0 or 0.5

	if isAdmin then
		skipButton.Text = "SKIP"
	elseif state.AllowVoteSkip then
		skipButton.Text = `VOTE SKIP  {state.Votes or 0}/{state.VotesNeeded or 1}`
	else
		skipButton.Text = "SKIP (ADMIN)"
	end
	skipButton.BackgroundColor3 = current and accent or COLORS.PanelLight
	skipButton.TextColor3 = current and COLORS.Background or COLORS.SubText

	tabButtons.Queue.Text = (#(state.Queue or {}) > 0) and `QUEUE ({#state.Queue})` or "QUEUE"
	renderQueue()

	if state.Equalizer and not draggingBand then
		for band, value in pairs(state.Equalizer) do
			setSliderVisual(band, value)
		end
	end
end

StateChanged.OnClientEvent:Connect(function(newState)
	state = newState
	render()
end)

task.spawn(function()
	for _ = 1, 5 do
		local ok, result = pcall(function()
			return GetState:InvokeServer()
		end)
		if ok and result then
			state = state or result
			render()
			return
		end
		task.wait(1)
	end
end)

---------------------------------------------------------------------
-- বাটনগুলো
---------------------------------------------------------------------
local function changeVolume(delta)
	if not isAdmin then
		showToast("Only admins can change the volume", "error")
		return
	end
	if not state then
		return
	end
	local steps = math.floor((state.Volume or 0) * 10 + 0.5)
	SetVolume:FireServer(math.clamp(steps + delta, 0, 10) / 10)
end
volumeMinus.Activated:Connect(function()
	changeVolume(-1)
end)
volumePlus.Activated:Connect(function()
	changeVolume(1)
end)

skipButton.Activated:Connect(function()
	if not state or not state.Current then
		return
	end
	if not isAdmin then
		if not state.AllowVoteSkip then
			showToast("Only admins can skip songs", "error")
			return
		end
		if hasVoted then
			showToast("You already voted to skip this song", "error")
			return
		end
		hasVoted = true
	end
	SkipSong:FireServer()
end)

---------------------------------------------------------------------
-- খোলা / বন্ধ
---------------------------------------------------------------------
local function setOpen(open)
	if open == panel.Visible then
		return
	end
	if open then
		panel.Visible = true
		panelScale.Scale = 0.92
		TweenService:Create(panelScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	else
		panel.Visible = false
		draggingBand = nil
	end
end

closeButton.Activated:Connect(function()
	setOpen(false)
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "MusicPrompt" then
		setOpen(not panel.Visible)
	end
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
	if prompt.Name == "MusicPrompt" then
		setOpen(false)
	end
end)

---------------------------------------------------------------------
-- ডিস্ক ঘোরানো আর সময়
---------------------------------------------------------------------
local musicFolder = workspace:WaitForChild("MusicFolder")
local rotation = 0
RunService.RenderStepped:Connect(function(deltaTime)
	if not panel.Visible then
		return
	end
	local djSound = musicFolder:FindFirstChild("DJSound")
	local playing = state and state.Current and djSound and djSound.IsPlaying
	if playing then
		rotation = (rotation + 60 * deltaTime) % 360
		disc.Rotation = rotation
		local length = djSound.TimeLength
		local position = djSound.TimePosition
		progressFill.Size = UDim2.fromScale(length > 0 and math.clamp(position / length, 0, 1) or 0, 1)
		timeNow.Text = formatTime(position)
		timeEnd.Text = formatTime(length)
	else
		progressFill.Size = UDim2.fromScale(0, 1)
		timeNow.Text = "0:00"
		timeEnd.Text = "0:00"
	end
end)
