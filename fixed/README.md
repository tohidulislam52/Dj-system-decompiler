# DJ সিস্টেম — ফিক্স আর সাজানো সংস্করণ

ডাউনলোড: রিপোজিটরির মূল ফোল্ডারে **`Dj system FIXED.zip`**। ভেতরে
`Dj system FIXED.rbxmx`। আপনার পাঠানো ফাইলের মতোই এর ভেতরে
`Dj System by tajim Backup` ফোল্ডার, যাতে Ws / RS / SSS / SGUI / SPS আছে।
এর মধ্যে সব ফিক্স বসানো, আর স্ক্রিপ্টগুলো ফোল্ডারে সাজানো।

## নতুন সাজানো

```
ReplicatedStorage
└─ DJSystem
   ├─ Modules
   │  ├─ AdminModule          ← অ্যাডমিনদের নাম এখানে
   │  ├─ NotificationModule
   │  └─ Icon
   └─ Remotes
      ├─ GLightsRemote
      ├─ QPyroRemote
      ├─ PyroSyncRemote
      └─ MusicRemotes (ফোল্ডার, ভেতরের সব remote আগের মতো)

ServerScriptService
└─ DJSystem
   ├─ DJAuthority             (ModuleScript)
   ├─ Lights › GLightSyncServer
   ├─ Pyro   › QPyroSyncServer
   └─ Music  › MusicServer

StarterPlayer › StarterPlayerScripts
└─ DJSystem
   ├─ Controls › TopBar, QPyroControlPanel, DJControlLock
   ├─ Music    › NotifHandler
   └─ Visuals  › DisplayVisualizer, GifAnimator
```

- StarterGui-র ScreenGui-গুলো (GLightsControlPanel, MusikGui,
  QPyroControlPanel) আগের মতোই সরাসরি StarterGui-তে থাকবে।
  ScreenGui ফোল্ডারের ভেতরে রাখলে স্ক্রিপ্টগুলো সেগুলো খুঁজে পায় না।
- Workspace-এর জিনিসগুলো (GLights, QPyro, Stage, Visuals, MusicFolder)
  যেখানে ছিল সেখানেই থাকবে।
- নাম বদলেছে: `GlightSyncServer vvvvv` → `GLightSyncServer`,
  `QPyroSyncServer VVVVVV` → `QPyroSyncServer`,
  `Music Server by me` → `MusicServer`।
- জিনিসগুলো ফোল্ডারে যাওয়ায় যে ১৪টা স্ক্রিপ্ট এগুলো খোঁজে, তাদের সবার
  পাথ নতুন জায়গা অনুযায়ী বদলে দেওয়া হয়েছে। এই ফোল্ডারে সেই ১৪টা
  স্ক্রিপ্টের কপি আছে।

## Studio-তে বসানোর নিয়ম

1. **ব্যাকআপ:** File → Save to File As দিয়ে বর্তমান গেমের একটা কপি রাখুন।
2. **পুরনো DJ সিস্টেম মুছুন।** নিচের সবকিছু মুছে ফেলুন, নাহলে দুটো কপি
   একসাথে চলবে আর সব দুইবার হবে:
   - ReplicatedStorage: `MusicModule`, `MusicRemotes`, `GLightsRemote`,
     `QPyroRemote`, `PyroSyncRemote`, `Icon`
   - ServerScriptService: `GlightSyncServer vvvvv`,
     `QPyroSyncServer VVVVVV`, `Music Server by me` (আর আগে বসিয়ে থাকলে
     `DJAuthority`)
   - StarterPlayerScripts: `DisplayVisualizer`, `GifAnimator`,
     `NotifHandler`, `QPyroControlPanel`, `TopBar` (আর আগে বসিয়ে থাকলে
     `DJControlLock`)
   - StarterGui: `GLightsControlPanel`, `MusikGui`, `QPyroControlPanel`
   - Workspace: `GLights`, `QPyro`, `Stage`, `Visuals`, `MusicFolder`, `Display`
3. **নতুনটা আনুন:** Workspace-এ রাইট-ক্লিক → **Insert from File...** →
   `Dj system FIXED.rbxmx` বেছে নিন। `Dj System by tajim Backup` ফোল্ডার আসবে।
4. **জায়গামতো সরান**, ড্র্যাগ করে:
   - `RS` ফোল্ডারের ভেতরের **DJSystem** → ReplicatedStorage
   - `SSS`-এর ভেতরের **DJSystem** → ServerScriptService
   - `SPS`-এর ভেতরের **DJSystem** → StarterPlayer › StarterPlayerScripts
   - `SGUI`-এর ভেতরের ৩টা ScreenGui → StarterGui
   - `Ws`-এর ভেতরের সবকিছু → Workspace
5. খালি হয়ে যাওয়া `Dj System by tajim Backup` ফোল্ডারটা মুছে দিন।
6. গেম সেভ করুন।

## অ্যাডমিনের নাম

ReplicatedStorage › DJSystem › Modules › **AdminModule**

```lua
AdminModule.ADMIN_LIST = {
	"Rojin00110",
	"Tajim_294",
}
```

- নাম হবে Roblox username, Display Name না। বড়/ছোট হাতের অক্ষরে সমস্যা নেই।
- `ADMIN_USER_IDS`-এ UserId দিলে কেউ নাম বদলালেও কাজ করবে।
- `ALLOW_OWNER = true` থাকলে গেমের মালিক সবসময় অ্যাডমিন।

## টেস্ট

1. Test → Clients and Servers → 3 Players → Start। Studio-র টেস্ট
   প্লেয়াররা (Player1, Player2...) অ্যাডমিন না।
2. গান চালান। ৩ জন থাকলেও আগুন একজনের সময়ের মতো থাকা উচিত।
3. Shift+F3-এ Recv দেখুন। প্লেয়ার বাড়লেও গুণ হারে বাড়া উচিত না।
4. টেস্ট প্লেয়ার দিয়ে টিভির বাটন চাপুন, কিছু হবে না।
5. নিজের অ্যাকাউন্টে Play দিয়ে ঢুকলে টিভি আর প্যানেল কাজ করবে।

Output-এ লাল error এলে কপি করে পাঠান।
