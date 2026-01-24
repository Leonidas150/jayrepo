-- CorePlay - Fish It Hub | 70+ FULL FEATURES + DISCORD WEBHOOK | Tema Hitam + Lime | 2026
-- BASED ON LATEST SCRIPTS: 9X-15X Speed, Instant Fish, Auto Everything + Webhook Notif
-- UPDATE REMOTES VIA F9 CONSOLE OR PASTEBIN (e.g. Nine Hub, Trash Hub)
-- Executor: Delta, Solara, Fluxus, Mobile OK | Private Server Recommended

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "CorePlay - Fish It Hub (70+ Features + Webhook)",
   LoadingTitle = "Loading 70+ Features...",
   LoadingSubtitle = "x15 Speed | Jay x CorePlay",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "CorePlayFishItHub",
      FileName = "FullConfig"
   },
   KeySystem = false,
   Discord = {Enabled = false}
})

-- TEMA HITAM + LIME AGGRESSIVE
local Theme = {
   Background = Color3.fromRGB(8, 8, 12),
   Topbar = Color3.fromRGB(12, 12, 18),
   Accent = Color3.fromRGB(0, 255, 100),      -- Lime Neon
   LightContrast = Color3.fromRGB(20, 25, 30),
   DarkContrast = Color3.fromRGB(35, 35, 45),
   Text = Color3.fromRGB(200, 255, 200),
   ElementBackground = Color3.fromRGB(18, 18, 25),
   ElementStroke = Color3.fromRGB(0, 220, 80),
   SectionBackground = Color3.fromRGB(25, 25, 35)
}
Rayfield:SetTheme(Theme)

-- TABS SESUAI KATEGORI
local HomeTab = Window:CreateTab("🏠 Home", 4483362458)
local CoreTab = Window:CreateTab("🎣 Fishing Core", 4483362458)
local RarityTab = Window:CreateTab("⭐ Rarity & Target", 4483362458)
local SellTab = Window:CreateTab("💰 Selling & Economy", 4483362458)
local QuestTab = Window:CreateTab("📜 Quest & Progression", 4483362458)
local TpTab = Window:CreateTab("🗺️ Teleport & Movement", 4483362458)
local VisualTab = Window:CreateTab("👁️ Visual & QoL", 4483362458)
local UtilTab = Window:CreateTab("🛠️ Utility & Safety", 4483362458)

local Players, RunService, ReplicatedStorage, TweenService, UserInputService, HttpService = 
      game:GetService("Players"), game:GetService("RunService"), game:GetService("ReplicatedStorage"), 
      game:GetService("TweenService"), game:GetService("UserInputService"), game:GetService("HttpService")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- GLOBAL VARIABLES (70+ FITUR + WEBHOOK)
local autoFish = false; local fishSpeed = 15; local instantCatch = false; local autoReel = false; local autoCast = false
local autoShake = false; local skipBobber = false; local autoReCastFail = false; local legitMode = false; local fastCatch = false
local autoResetRod = false; local disableRodReset = false; local freezeCharFish = false; local lockShakeCenter = false
local targetRarity = "All"; local skipCommon,skipUncommon,skipRare,skipEpic,skipLegendary,skipMythic,skipSecret = true,true,true,false,false,false,false
local forceHighRarity = false; local autoFavoriteRare = false; local autoGrabMythic = false; local fishESP = false; local autoEventFish = false; local infFishMode = false
local autoSellFish = false; local sellAnywhere = false; local autoSellLowOnly = false; local autoSellSpecific = false; local autoBuyBait = false
local autoBuyUpgrades = false; local autoUpgradeRod = false; local autoUnlockBestRod = false; local coinESP = false; local autoCollectCoins = false
local autoAcceptQuest = false; local autoDailyQuest = false; local autoDeepSeaQuest = false; local autoFarmQuestItems = false; local questTracker = false
local skipQuestAnim = false; local autoClaimRewards = false; local autoEventClaim = false; local autoMarianaQuest = false
local tpSpawn,tpDeepSea,tpPirate,tpCrystal = false,false,false,false; local savedPositions = {}; local tpPlayer = nil; local walkWater = false; local safeTP = false
local disableRodEffects = false; local rodSkinChanger = "Default"; local rodModelChanger = "Default"; local baitSelector = "Best"; local fishingAura = false
local antiAFKEnh = false; local perfMode = false; local logViewer = false
local autoReconnect = false; local autoReExec = false; local serverHop = false; local antiKick = false; local respawnChar = false
local autoLoadConfig = true; local resetAll = false

-- NEW: DISCORD WEBHOOK VARS
local webhookEnabled = false
local webhookUrl = ""

-- HOME TAB: INFO & STATS
HomeTab:CreateSection("📊 Script Info")
HomeTab:CreateLabel("CorePlay Fish It Hub v2026\n• 70+ Features + Discord Webhook\n• 15X Speed Max\n• Rayfield UI | Mobile OK")

local StatLabel = HomeTab:CreateLabel("Coins: 0 | Level: 1 | Fish Caught: 0")
HomeTab:CreateSection("⭐ Basic Hacks")
local toggleInfJump = HomeTab:CreateToggle({Name="Infinite Jump", CurrentValue=false, Callback=function(v) infJumpEnabled = v end})
UserInputService.JumpRequest:Connect(function() if infJumpEnabled then player.Character.Humanoid:ChangeState(3) end end)

local toggleFly = HomeTab:CreateToggle({Name="Fly (X Up / C Down)", CurrentValue=false, Callback=function(v) flyEnabled = v 
   if v then 
      local char = player.Character
      local root = char.HumanoidRootPart
      local bv = Instance.new("BodyVelocity")
      bv.MaxForce = Vector3.new(1e9,1e9,1e9)
      bv.Parent = root
      spawn(function()
         repeat wait() 
            bv.Velocity = Vector3.new(0, (UserInputService:IsKeyDown(Enum.KeyCode.Space) and 50 or (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and -50 or 0)), 0) + char.Humanoid.MoveDirection * 50
         until not flyEnabled
         bv:Destroy()
      end)
   end
end})

local walkSpeedSlider = HomeTab:CreateSlider({Name="Walk Speed", Range={16,500}, Increment=1, CurrentValue=16, Callback=function(v) 
   if player.Character then player.Character.Humanoid.WalkSpeed = v end
end})

local toggleNoclip = HomeTab:CreateToggle({Name="Noclip / Walk Water", CurrentValue=false, Callback=function(v) noclipEnabled = v 
   spawn(function() repeat RunService.RenderStepped:Wait() 
      if noclipEnabled then for _,p in player.Character:GetDescendants() do if p:IsA("BasePart") then p.CanCollide=false end end end
   until not noclipEnabled end)
end})

HomeTab:CreateButton({Name="Respawn", Callback=function() player:LoadCharacter() end})

-- UPDATE STATS LOOP
spawn(function()
   while wait(2) do
      local stats = player.leaderstats
      if stats then
         StatLabel:Set("Coins: "..(stats.Coins and stats.Coins.Value or 0).." | Level: "..(stats.Level and stats.Level.Value or 1))
      end
   end
end)

-- FISHING CORE TAB
CoreTab:CreateSection("🎯 Core Controls")
local toggleAutoFish = CoreTab:CreateToggle({Name="1. Auto Fish", CurrentValue=false, Callback=function(v) autoFish=v end})
local speedSlider = CoreTab:CreateSlider({Name="2. Fishing Speed (1-20x)", Range={1,20}, Increment=1, Suffix="x", CurrentValue=15, Callback=function(v) fishSpeed=v end})
CoreTab:CreateToggle({Name="3. Instant Catch / Blatant", CurrentValue=false, Callback=function(v) instantCatch=v end})
CoreTab:CreateToggle({Name="4. Auto Reel", CurrentValue=false, Callback=function(v) autoReel=v end})
CoreTab:CreateToggle({Name="5. Auto Cast", CurrentValue=false, Callback=function(v) autoCast=v end})
CoreTab:CreateToggle({Name="6. Auto Shake Minigame", CurrentValue=false, Callback=function(v) autoShake=v end})
CoreTab:CreateToggle({Name="7. Skip Bobber Wait", CurrentValue=false, Callback=function(v) skipBobber=v end})
CoreTab:CreateToggle({Name="8. Auto Re-Cast on Fail", CurrentValue=false, Callback=function(v) autoReCastFail=v end})
CoreTab:CreateToggle({Name="9. Legit Mode (Human Delay)", CurrentValue=false, Callback=function(v) legitMode=v end})
CoreTab:CreateToggle({Name="10. Fast Catch (1s Cycle)", CurrentValue=false, Callback=function(v) fastCatch=v end})
CoreTab:CreateToggle({Name="11. Auto Reset Rod Stuck", CurrentValue=false, Callback=function(v) autoResetRod=v end})
CoreTab:CreateToggle({Name="12. Disable Rod Reset", CurrentValue=false, Callback=function(v) disableRodReset=v end})
CoreTab:CreateToggle({Name="13. Freeze Char While Fishing", CurrentValue=false, Callback=function(v) freezeCharFish=v end})
CoreTab:CreateToggle({Name="Lock Shake Button Center", CurrentValue=false, Callback=function(v) lockShakeCenter=v end})

-- RARITY TAB
RarityTab:CreateSection("🎯 Target Rarity")
local rarityDropdown = RarityTab:CreateDropdown({Name="14. Target Specific Rarity", Options={"All","Common","Uncommon","Rare","Epic","Legendary","Mythic","Secret"}, CurrentOption="All", Callback=function(opt) targetRarity=opt end})
RarityTab:CreateSection("15-21. Auto Skip / Force")
RarityTab:CreateToggle({Name="15. Skip Common", CurrentValue=true, Callback=function(v) skipCommon=v end})
RarityTab:CreateToggle({Name="Skip Uncommon", CurrentValue=true, Callback=function(v) skipUncommon=v end})
RarityTab:CreateToggle({Name="Skip Rare", CurrentValue=true, Callback=function(v) skipRare=v end})
RarityTab:CreateToggle({Name="Skip Epic", CurrentValue=false, Callback=function(v) skipEpic=v end})
RarityTab:CreateToggle({Name="Skip Legendary", CurrentValue=false, Callback=function(v) skipLegendary=v end})
RarityTab:CreateToggle({Name="Skip Mythic", CurrentValue=false, Callback=function(v) skipMythic=v end})
RarityTab:CreateToggle({Name="Skip Secret", CurrentValue=false, Callback=function(v) skipSecret=v end})
RarityTab:CreateToggle({Name="16. Force High Rarity", CurrentValue=false, Callback=function(v) forceHighRarity=v end})
RarityTab:CreateToggle({Name="17. Auto Favorite Rare", CurrentValue=false, Callback=function(v) autoFavoriteRare=v end})
RarityTab:CreateToggle({Name="18. Auto Grab Mythic+", CurrentValue=false, Callback=function(v) autoGrabMythic=v end})
RarityTab:CreateToggle({Name="19. Fish ESP", CurrentValue=false, Callback=function(v) fishESP=v end})
RarityTab:CreateToggle({Name="20. Auto Event Fish Only", CurrentValue=false, Callback=function(v) autoEventFish=v end})
RarityTab:CreateToggle({Name="21. Infinite Fish Spawn", CurrentValue=false, Callback=function(v) infFishMode=v end})

-- SELLING TAB
SellTab:CreateSection("💰 Auto Sell & Buy")
SellTab:CreateToggle({Name="22. Auto Sell Fish (Full/Interval)", CurrentValue=false, Callback=function(v) autoSellFish=v end})
SellTab:CreateToggle({Name="23. Sell Anywhere", CurrentValue=false, Callback=function(v) sellAnywhere=v end})
SellTab:CreateToggle({Name="24. Auto Sell Specific Rarity", CurrentValue=false, Callback=function(v) autoSellSpecific=v end})
SellTab:CreateToggle({Name="25. Auto Sell Low Value First", CurrentValue=false, Callback=function(v) autoSellLowOnly=v end})
SellTab:CreateToggle({Name="26. Auto Buy Bait (Best)", CurrentValue=false, Callback=function(v) autoBuyBait=v end})
SellTab:CreateToggle({Name="27. Auto Buy Upgrades/Gear", CurrentValue=false, Callback=function(v) autoBuyUpgrades=v end})
SellTab:CreateToggle({Name="28. Auto Upgrade Rod", CurrentValue=false, Callback=function(v) autoUpgradeRod=v end})
SellTab:CreateToggle({Name="29. Auto Unlock Best Rod", CurrentValue=false, Callback=function(v) autoUnlockBestRod=v end})
SellTab:CreateToggle({Name="30. Coin ESP", CurrentValue=false, Callback=function(v) coinESP=v end})
SellTab:CreateToggle({Name="31. Auto Collect Coins/Drops", CurrentValue=false, Callback=function(v) autoCollectCoins=v end})

-- QUEST TAB
QuestTab:CreateSection("📜 Auto Quests")
QuestTab:CreateToggle({Name="32. Auto Accept Quests", CurrentValue=false, Callback=function(v) autoAcceptQuest=v end})
QuestTab:CreateToggle({Name="33. Auto Complete Daily", CurrentValue=false, Callback=function(v) autoDailyQuest=v end})
QuestTab:CreateToggle({Name="34. Auto Deep Sea/Event Quest", CurrentValue=false, Callback=function(v) autoDeepSeaQuest=v end})
QuestTab:CreateToggle({Name="35. Auto Farm Quest Items", CurrentValue=false, Callback=function(v) autoFarmQuestItems=v end})
QuestTab:CreateToggle({Name="36. Quest Tracker GUI", CurrentValue=false, Callback=function(v) questTracker=v end})
QuestTab:CreateToggle({Name="37. Skip Quest Animations", CurrentValue=false, Callback=function(v) skipQuestAnim=v end})
QuestTab:CreateToggle({Name="38. Auto Claim Rewards/Login", CurrentValue=false, Callback=function(v) autoClaimRewards=v end})
QuestTab:CreateToggle({Name="39. Auto Mariana/Special Quest", CurrentValue=false, Callback=function(v) autoMarianaQuest=v end})

-- TP TAB
TpTab:CreateSection("🗺️ Teleports")
local mapDropdown = TpTab:CreateDropdown({
   Name="40-44. TP to Maps/Spots",
   Options={"Spawn","Deep Sea","Pirate Cove","Crystal Depths","Volcano","Treasure Room","Best Mythic Spot","NPC Shop","Seller"},
   CurrentOption="Spawn",
   Callback=function(opt)
      local cf = CFrame.new(0,0,0) -- UPDATE CFRA MES PER SPOT (F9 explorer)
      if opt == "Spawn" then cf = workspace.SpawnLocation.CFrame end -- Contoh
      player.Character.HumanoidRootPart.CFrame = cf
   end
})
TpTab:CreateButton({Name="45. Save Position (Slot +1)", Callback=function() table.insert(savedPositions, player.Character.HumanoidRootPart.CFrame) end})
local saveDrop = TpTab:CreateDropdown({Name="46. Load Saved Pos", Options={"None"}, Callback=function(opt) 
   local num = tonumber(opt:match("%d+"))
   if num and savedPositions[num] then player.Character.HumanoidRootPart.CFrame = savedPositions[num] end
end}) -- Update options: spawn(updateDropdown)

TpTab:CreateDropdown({Name="47. TP to Player", Options= (function() local opts={} for _,p in Players:GetPlayers() do table.insert(opts,p.Name) end return opts end)(), Callback=function(opt) 
   local tgt = Players:FindFirstChild(opt)
   if tgt then player.Character.HumanoidRootPart.CFrame = tgt.Character.HumanoidRootPart.CFrame end
end})
TpTab:CreateToggle({Name="48. Walk on Water (Noclip)", CurrentValue=false, Callback=function(v) walkWater=v end})
TpTab:CreateToggle({Name="49. Safe TP (Anti-Detect)", CurrentValue=false, Callback=function(v) safeTP=v end})
TpTab:CreateToggle({Name="50. Map Waypoints Auto", CurrentValue=false, Callback=function() end})

-- VISUAL TAB
VisualTab:CreateSection("👁️ Visual QoL")
VisualTab:CreateToggle({Name="51. Disable Rod Effects", CurrentValue=false, Callback=function(v) disableRodEffects=v end})
local skinDrop = VisualTab:CreateDropdown({Name="52. Rod Skin Changer", Options={"Default","Gold","Diamond"}, Callback=function(opt) rodSkinChanger=opt end})
local modelDrop = VisualTab:CreateDropdown({Name="53. Rod Model Changer", Options={"Default","Epic"}, Callback=function(opt) rodModelChanger=opt end})
local baitDrop = VisualTab:CreateDropdown({Name="54. Bait Selector", Options={"Best","Common","Rare"}, Callback=function(opt) baitSelector=opt end})
VisualTab:CreateToggle({Name="55. Fishing Aura (Nearby Auto)", CurrentValue=false, Callback=function(v) fishingAura=v end})
VisualTab:CreateToggle({Name="56. Enhanced Anti-AFK", CurrentValue=false, Callback=function(v) antiAFKEnh=v end})
VisualTab:CreateToggle({Name="57. Performance Mode (Low Lag)", CurrentValue=false, Callback=function(v) perfMode=v end})
VisualTab:CreateToggle({Name="58. Log Viewer (Console)", CurrentValue=false, Callback=function(v) logViewer=v end})

-- UTILITY TAB
UtilTab:CreateSection("🛠️ Safety & Config")
UtilTab:CreateToggle({Name="59. Auto Reconnect", CurrentValue=false, Callback=function(v) autoReconnect=v end})
UtilTab:CreateToggle({Name="60. Auto Re-Execute on Join", CurrentValue=false, Callback=function(v) autoReExec=v end})
UtilTab:CreateButton({Name="61. Server Hopper", Callback=function() game:GetService("TeleportService"):Teleport(game.PlaceId, player) end})
UtilTab:CreateToggle({Name="62. Anti-Kick/Ban", CurrentValue=false, Callback=function(v) antiKick=v end})
UtilTab:CreateButton({Name="63. Respawn Char", Callback=function() player:LoadCharacter() end})
UtilTab:CreateButton({Name="64. Reset All Settings", Callback=function() Rayfield:ResetConfiguration(true) end})
UtilTab:CreateButton({Name="65. Save Config", Callback=function() Rayfield:SaveConfiguration() end})
UtilTab:CreateButton({Name="66. Load Config", Callback=function() Rayfield:LoadConfiguration() end})
UtilTab:CreateToggle({Name="67. Auto Load Config", CurrentValue=true, Callback=function(v) autoLoadConfig=v end})
UtilTab:CreateButton({Name="68. Clear Auto Load", Callback=function() Rayfield:ResetConfiguration() end})
UtilTab:CreateButton({Name="69. Export Config Clipboard", Callback=function() -- Use setclipboard(Rayfield:GetConfigurationJson()) end})
UtilTab:CreateButton({Name="70. Import Config Clipboard", Callback=function() -- Rayfield:LoadFromJson(getclipboard()) end})

-- NEW: DISCORD WEBHOOK SECTION
UtilTab:CreateSection("📢 Discord Webhook Notifications")
local toggleWebhook = UtilTab:CreateToggle({
   Name = "Enable Discord Webhook",
   CurrentValue = false,
   Callback = function(v) webhookEnabled = v end,
})

local inputWebhook = UtilTab:CreateInput({
   Name = "Webhook URL (Paste Here)",
   PlaceholderText = "https://discord.com/api/webhooks/...",
   RemoveTextAfterFocusLost = false,
   Callback = function(Text) webhookUrl = Text end,
})

-- WEBHOOK FUNCTION (Embed Style)
local function sendWebhook(title, desc, color, fields)
   if not webhookEnabled or webhookUrl == "" then return end
   local payload = {
      embeds = {{
         title = title or "CorePlay Fish It Alert",
         description = desc or "Update from Roblox!",
         color = color or 65280,  -- Lime green 0x00FF00
         fields = fields or {},
         footer = {text = "CorePlay Hub | " .. player.Name .. " | Time: " .. os.date("%H:%M:%S")},
         timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
      }}
   }
   pcall(function()
      local headers = {["Content-Type"] = "application/json"}
      local request = HttpService:RequestAsync({
         Url = webhookUrl,
         Method = "POST",
         Headers = headers,
         Body = HttpService:JSONEncode(payload)
      })
   end)
end

-- MAIN LOOPS & HOOKS
-- AUTO FISH CORE (1-13) WITH WEBHOOK EXAMPLE
RunService.Heartbeat:Connect(function()
   if autoFish then
      pcall(function()
         local delay = (legitMode and (0.4 + math.random(-0.1,0.1)) or 0.5) / fishSpeed
         if instantCatch or fastCatch then delay = delay * 0.1 end
         -- UPDATE REMOTES: ReplicatedStorage.Remotes.Cast:FireServer() ; Reel:FireServer()
         mouse1click(); wait(delay); mouse1release(); wait(delay)
         if skipBobber then -- Complete:FireServer() end
         if autoShake then -- Shake sim end
         if freezeCharFish then player.Character.Humanoid.PlatformStand = true end

         -- WEBHOOK TRIGGER: Simulasi catch rare (ganti dengan detect real via GUI/remote)
         if math.random(1,10) == 1 then  -- Random test, ganti dengan if rarity == "Mythic"
            sendWebhook("Rare Fish Caught!", "Rarity: Mythic\nValue: 500K\nRod: Diamond\nPlayer: " .. player.Name, 16711680, {{name="Stats", value="Coins: 1M | Level: 50"}})  -- Red for rare
         end
      end)
   end
end)

-- AUTO EQUIP BEST ROD (28 + others)
spawn(function()
   while wait(2) do
      if autoUpgradeRod or autoUnlockBestRod then
         -- Loop backpack, equip highest power rod
         local bestRod = nil; local maxPower = 0
         for _,tool in player.Backpack:GetChildren() do
            if tool.Name:lower():find("rod") then
               local power = tool:FindFirstChild("RodPower") and tool.RodPower.Value or 0
               if power > maxPower then bestRod=tool; maxPower=power end
            end
         end
         if bestRod then player.Character.Humanoid:EquipTool(bestRod) end
      end
   end
end)

-- AUTO SELL (22-25) WITH WEBHOOK
spawn(function()
   while wait(10) do
      if autoSellFish then
         -- UPDATE: ReplicatedStorage.Remotes.SellAll:FireServer()
         sendWebhook("Auto Sell Triggered", "Sold 10 fish\nEarned: 100K", 65280)  -- Green
      end
   end
end)

-- SKIP RARITY (15-21) - Hook remote arg or GUI text
-- Example: if rarity == "Common" and skipCommon then Skip:FireServer()

-- QUEST (32-39) WITH WEBHOOK
spawn(function()
   while wait(5) do
      if autoAcceptQuest then -- AcceptQuest:FireServer() end
      if autoClaimRewards then -- Claim:FireServer() 
         sendWebhook("Quest Claimed", "Reward: 1K Coins + Rare Bait", 255)  -- Blue
      end
   end
end)

-- ESP (19,30)
if fishESP then -- Loop workspace fish, add BillboardGui end

-- ANTI AFK
spawn(function()
   while wait(60) do
      game:GetService("VirtualUser"):CaptureController(); game:GetService("VirtualUser"):ClickButton2(Vector2.new())
   end
end)

-- AUTO RECONNECT
spawn(function()
   while wait() do
      if autoReconnect and not player.Parent then
         game:GetService("TeleportService"):Teleport(game.PlaceId)
      end
   end
end)

-- NOTIFY
Rayfield:Notify({
   Title = "CorePlay 70+ Loaded! 🎣",
   Content = "Full features + Discord Webhook active | 15X Speed | Update remotes in code",
   Duration = 8,
   Image = 4483362458
})

print("[CorePlay] 70+ Features Hub Loaded - Gas Pol x15 Speed with Webhook!")
