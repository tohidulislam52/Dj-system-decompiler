# ফিক্স করা স্ক্রিপ্ট — Studio-তে বসানোর নিয়ম

এই ফোল্ডারের প্রতিটা ফাইল Studio-র একটা Script/LocalScript/ModuleScript।
ফোল্ডারের নামই বলে দেয় Studio-তে ওটা কোথায় যাবে। ফাইলের নামের শেষের
`.server.lua` মানে **Script**, `.client.lua` মানে **LocalScript**, আর শুধু
`.lua` মানে **ModuleScript**।

> শুরুর আগে Studio-তে **File → Save to File As** দিয়ে গেমের একটা ব্যাকআপ রাখুন।

## ধাপে ধাপে

প্রতিটা ক্ষেত্রে: Studio-তে স্ক্রিপ্টটা খুলুন → ভেতরের সব লেখা মুছে দিন →
এই ফাইলের পুরো লেখা কপি করে পেস্ট করুন।

| # | এই ফাইল | Studio-তে কোথায় | কী করবেন |
|---|---|---|---|
| 1 | `ReplicatedStorage/MusicModule/AdminModule.lua` | ReplicatedStorage › MusicModule › **AdminModule** | বদলে দিন, তারপর **নিজের নামগুলো লিখুন** |
| 2 | `ServerScriptService/DJAuthority.lua` | ServerScriptService › **DJAuthority** | **নতুন ModuleScript** বানান, নাম ঠিক `DJAuthority` |
| 3 | `ServerScriptService/QPyroSyncServer.server.lua` | ServerScriptService › **QPyroSyncServer VVVVVV** | বদলে দিন |
| 4 | `ServerScriptService/GlightSyncServer.server.lua` | ServerScriptService › **GlightSyncServer vvvvv** | বদলে দিন |
| 5 | `StarterPlayerScripts/QPyroControlPanel.client.lua` | StarterPlayer › StarterPlayerScripts › **QPyroControlPanel** | বদলে দিন |
| 6 | `StarterPlayerScripts/DJControlLock.client.lua` | StarterPlayer › StarterPlayerScripts › **DJControlLock** | **নতুন LocalScript** বানান |
| 7 | `StarterGui/GLightsControlPanel/GLightsControlScript.client.lua` | StarterGui › GLightsControlPanel › **GLightsControlScript** | বদলে দিন |
| 8 | `Workspace/QPyro/Q-Tech Premium/MainFolder/MainScript.server.lua` | Workspace › QPyro › Q-Tech Premium › MainFolder › **MainScript** | বদলে দিন |
| 9 | `Workspace/GLights/GlobalSettings.lua` | Workspace › GLights › **GlobalSettings** | বদলে দিন |

নতুন কোনো RemoteEvent বানাতে হবে না। আগের `PyroSyncRemote`-টাই ব্যবহার হয়।

## অ্যাডমিনের নাম কোথায় লিখবেন

শুধু **একটা** জায়গায়: ReplicatedStorage › MusicModule › AdminModule

```lua
AdminModule.ADMIN_LIST = {
	"Rojin00110",
	"Tajim_294",
	-- এখানে আরও নাম যোগ করুন, প্রতিটার শেষে কমা
}
```

- নাম হবে Roblox **username**, Display Name না।
- `ADMIN_USER_IDS`-এ UserId দিলে নাম বদলালেও কাজ করবে।
- `ALLOW_OWNER = true` থাকলে গেমের মালিক সবসময় অ্যাডমিন।

এই লিস্টটাই এখন সব জায়গায় ব্যবহার হয়: TopBar-এর GLights/QPyro প্যানেল,
Q-Tech টিভি, GLights Reset বাটন, আর গানের ভলিউম/ইকুয়ালাইজার।

## কীভাবে টেস্ট করবেন

1. **Test → Clients and Servers → 3 Players → Start।** Studio-র টেস্ট
   প্লেয়ারদের নাম Player1, Player2..., তাই এরা অ্যাডমিন না।
2. গান চালান। আগুন আর লাইট একজন খেলার সময় যেমন ছিল, ৩ জনেও তেমনই
   থাকা উচিত, বেশি না।
3. যেকোনো প্লেয়ারের উইন্ডোতে **Shift+F3** চাপলে Recv দেখা যায়। প্লেয়ার
   বাড়লেও এটা আর আগের মতো গুণ হারে বাড়া উচিত না।
4. টেস্ট প্লেয়ার দিয়ে Q-Tech টিভির বাটন চাপুন। কিছু হবে না।
5. নিজের অ্যাকাউন্টে (Play বাটন) ঢুকে টিভি আর প্যানেল চালান। সব কাজ করবে।

Output-এ লাল error এলে সেটা কপি করে আমাকে পাঠান।

## কী বদলেছে, সংক্ষেপে

- **কন্ডাক্টর:** গানের বিট শুধু একজনের কম্পিউটার ধরে কমান্ড পাঠায় (প্রথমে
  অ্যাডমিন, না থাকলে যে সবচেয়ে আগে ঢুকেছে)। সে চলে গেলে বা ১৫ সেকেন্ড চুপ
  থাকলে পরের জন দায়িত্ব নেয়।
- **আগুন বন্ধ করে সার্ভার:** অটো-আগুন 0.25 সেকেন্ড পর সার্ভার নিজেই বন্ধ
  করে, তাই কারো ল্যাগ হলেও আগুন জ্বলে থাকে না।
- **Pan/Tilt:** আগে প্রতি বিটে ~১৬০টা লাইট কমান্ড সবার কাছে যেত, এখন ~১২টা।
- **অনুমতি:** অ্যাডমিন ছাড়া কেউ প্যানেল বা টিভির কমান্ড চালাতে পারে না।
  অটো-কমান্ডও শুধু নিরাপদ কয়েকটা কমান্ড আর মানের সীমার ভেতরে নেওয়া হয়।
- **Auto বাটন:** অ্যাডমিন প্যানেল থেকে AutoSync/Auto/Auto Pyro বন্ধ করলে
  এখন সবার জন্য একসাথে বন্ধ হয়। আগে শুধু নিজের কম্পিউটারে বন্ধ হতো।
