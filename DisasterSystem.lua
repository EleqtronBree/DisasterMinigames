--[[
Author(s): Electra Bree & Aaron Spivey

This script runs the disaster minigame
]]--

--// Configuration
map_hit = 3 -- how many times until map regen
map_change = 10 -- how many times until map changes (given maps > 0)
disaster_duration = 40 -- default duration of each disaster (given no duration value added)
intermission_duration = 25 -- seconds
blur_size = 42 -- for announcement messages
_G.disaster_queue = {}
maps = game.ServerStorage.Maps:GetChildren()

--// Variables
map_change_count = 0
map_index = 0

--// Fetches the player data for a given player
function get_data(player_name)
	local data = game.ReplicatedStorage.PlayerData:FindFirstChild(player_name)
	if data then
		return data
	end
	return false
end

--// Upgrades the player's level given they have enough XP
function check_for_level_upgrade(data)
	if data:WaitForChild("LevelData").CurrentXP.Value >= data:WaitForChild("LevelData").NeededXP.Value then
		data:WaitForChild("LevelData").Level.Value = data:WaitForChild("LevelData").Level.Value + 1
		data:WaitForChild("LevelData").NeededXP.Value = data:WaitForChild("LevelData").NeededXP.Value*1.5
		data:WaitForChild("LevelData").CurrentXP.Value = 0
		local multiplier = 1
		if data.Gamepasses.Premium.Value == true then
			multiplier = 2
		end
		data.Currency.Coins.Value = data.Currency.Coins.Value + 400 * multiplier
		local player = game.Players:FindFirstChild(data.Name)
		if player ~= nil then
			game.ReplicatedStorage.RemoteEvents.UpLvl:FireClient(player, 400 * multiplier)
		end
	end
end

--// Awards XP to a given player
function add_xp(player_name)
	local data = get_data(player_name)
	local mul = 1
	if data then
		if data.Gamepasses.Premium.Value == true then
			mul = 2
		end
		data:WaitForChild("LevelData").CurrentXP.Value = data:WaitForChild("LevelData").CurrentXP.Value + 5 * mul
		check_for_level_upgrade(data)
		game.ReplicatedStorage.RemoteEvents.UpXP:FireClient(game.Players:FindFirstChild(player_name), 5 * mul)
	end
end

--// Awards a win to a given player
function add_win(player_name)
	local data = get_data(player_name)
	if data then
		data.Totals.Survivals.Value = data.Totals.Survivals.Value + 1
	end
end

--// Resets all current settings in lighting to default value - called after every disaster
function reset_sky() 
	game.Lighting.Ambient = workspace.Map:FindFirstChildOfClass("Model").Lighting:WaitForChild("Configuration").Ambient.Value
	game.Lighting.Brightness = workspace.Map:FindFirstChildOfClass("Model").Lighting:WaitForChild("Configuration").Brightness.Value
	game.Lighting.ColorShift_Bottom = workspace.Map:FindFirstChildOfClass("Model").Lighting:WaitForChild("Configuration").ColorShift_Bottom.Value
	game.Lighting.ColorShift_Top = workspace.Map:FindFirstChildOfClass("Model").Lighting:WaitForChild("Configuration").ColorShift_Top.Value
	game.Lighting.EnvironmentDiffuseScale = workspace.Map:FindFirstChildOfClass("Model").Lighting:WaitForChild("Configuration").EnvironmentDiffuseScale.Value
	game.Lighting.EnvironmentSpecularScale = workspace.Map:FindFirstChildOfClass("Model").Lighting:WaitForChild("Configuration").EnvironmentSpecularScale.Value
	game.Lighting.OutdoorAmbient = workspace.Map:FindFirstChildOfClass("Model").Lighting:WaitForChild("Configuration").OutdoorAmbient.Value
	game.Lighting.ClockTime = workspace.Map:FindFirstChildOfClass("Model").Lighting:WaitForChild("Configuration").ClockTime.Value
	game.Lighting.GeographicLatitude = workspace.Map:FindFirstChildOfClass("Model").Lighting:WaitForChild("Configuration").GeographicLatitude.Value
	game.Lighting.ExposureCompensation = workspace.Map:FindFirstChildOfClass("Model").Lighting:WaitForChild("Configuration").ExposureCompensation.Value
	game.Lighting.FogColor = workspace.Map:FindFirstChildOfClass("Model").Lighting:WaitForChild("Configuration").FogColor.Value
	game.Lighting.FogEnd = workspace.Map:FindFirstChildOfClass("Model").Lighting:WaitForChild("Configuration").FogEnd.Value
	game.Lighting.FogStart = workspace.Map:FindFirstChildOfClass("Model").Lighting:WaitForChild("Configuration").FogStart.Value
	game.Lighting:ClearAllChildren()
	for index, effect in ipairs(workspace.Map:FindFirstChildOfClass("Model").Lighting:GetChildren()) do
		local lighting_effect = effect:Clone()
		lighting_effect.Parent = game.Lighting
	end
end

--// Chooses a random or requested disaster and returns a disaster object
function choose_disaster() 
	local disaster
	if #_G.disaster_queue > 0 then
		disaster = _G.disaster_queue[1]
		table.remove(_G.disaster_queue, 1)
	else
		local random_index = math.random(1, #game.ServerStorage.Disasters:GetChildren())
		disaster = game.ServerStorage.Disasters:GetChildren()[random_index]
	end
	return disaster
end

--// Sends an announcement to all players with a given message
function send_announcement(message, blur_size)
	game.ReplicatedStorage.RemoteEvents.SendAnnouncement:FireAllClients(message, blur_size)
end

--// Removes gear from all players that can harm other players
function remove_lethal_gear() 
	for index, player in pairs(game.Players:GetPlayers()) do
		for index, gear in pairs(player.Backpack:GetChildren()) do
			if gear.Name == "Bomb" or gear.Name == "ClassicSword" or gear.Name == "LaserGun" or gear.Name == "RocketLauncher" then
				gear:Destroy()
			end
		end
		pcall(function()
			for index, gear in pairs(player.Character:GetChildren()) do
				if gear.Name == "Bomb" or gear.Name == "ClassicSword" or gear.Name == "LaserGun" or gear.Name == "RocketLauncher" then
					gear:Destroy()
				end
			end
		end)
	end
end

--// Loads a given disaster model into the game's workspace
function load_disaster(model)
	for index, player in ipairs(game.Players:GetPlayers()) do
		pcall(function()
			if player ~= nil and game.ReplicatedStorage.PlayerData:FindFirstChild(player.Name) ~= nil then
				game.ReplicatedStorage.PlayerData:FindFirstChild(player.Name):WaitForChild("InGame").Alive.Value = true
			end
		end)
	end
	local disaster = game.ServerStorage.Disasters[model.Name]:Clone()
	disaster.Parent = workspace.Disasters
end

--// Deletes the disaster from the workspace 
function clear_disaster(model)
	reset_sky()
	remove_lethal_gear()
	workspace.Disasters:ClearAllChildren()
	workspace.Music.Volume = 0.5
	workspace.Gravity = 196.2
	for index, part in pairs(workspace.Map:FindFirstChildOfClass("Model")["Spawn Set"].SpawnBox:GetChildren()) do
		part.Transparency = 1
		part.CanCollide = false
	end
	for index, player in pairs(game.Players:GetPlayers()) do
		pcall(function()
			if player.Character then
				player.Character.Humanoid.WalkSpeed = 16
			end
		end)
		pcall(function()
			if player.Character:FindFirstChild("ExposureTag") then
				player.Character:FindFirstChild("ExposureTag"):Destroy()
				if player.PlayerGui:FindFirstChild("BlizzardGui") then
					player.PlayerGui:FindFirstChild("BlizzardGui"):Destroy()
				end
				if player.PlayerGui:FindFirstChild("SandStormGui") then
					player.PlayerGui:FindFirstChild("SandStormGui"):Destroy()
				end
			end
		end)
	end
end

--// Loads a random map into the game's workspace 
function draw_map()
	send_announcement("Changing Map", blur_size)
	local choices = {}
	for index = 1, #maps do
		if maps[index]:IsA("Model") then
			table.insert(choices, maps[index])
		end
	end
	workspace.Map:ClearAllChildren()
	local picked = math.random(1,#maps)
	for index, player in pairs(game.Players:GetPlayers()) do
		pcall(function()
			if player.Character ~= nil and player.Character:FindFirstChild("HumanoidRootPart") ~= nil then
				player.Character.Humanoid.Jump = true
				player.Character.HumanoidRootPart.CFrame = CFrame.new(0,70,0)
			end
		end)
	end
	local map_clone = game.ServerStorage.Maps:FindFirstChild(choices[picked].Name):Clone()
	map_clone.Parent = workspace.Map
	game.ReplicatedStorage.RemoteEvents.MapGui:FireAllClients(map_clone.Name,map_clone.Info:WaitForChild("ImageId").Value,map_clone.Info:WaitForChild("CreatorId").Value)
	reset_sky()
end

--// Refreshes the map
function regen_map() 
	local map = workspace.Map:FindFirstChildOfClass("Model")
	local map_clone = game.ServerStorage.Maps[map.Name]:Clone()
	workspace.Map:ClearAllChildren()
	for index, player in pairs(game.Players:GetPlayers()) do
		pcall(function()
			if player.Character ~= nil and player.Character:FindFirstChild("HumanoidRootPart") ~= nil then
				player.Character.Humanoid.Jump = true
				player.Character.HumanoidRootPart.CFrame = CFrame.new(0,70,0)
			end
		end)
	end
	map_clone.Parent = workspace.Map
	if map_clone.Name == "Atlantis" then
		map_clone:WaitForChild("Treasure"):Destroy()
	end
	for index, player in pairs(game.Players:GetPlayers()) do
		pcall(function()
			if player.Character ~= nil and player.Character:FindFirstChild("HumanoidRootPart") ~= nil then
				player.Character.Humanoid.Jump = true
				player.Character.HumanoidRootPart.CFrame = CFrame.new(0,70,0)
			end
		end)
	end
end

--// Collects the winners of a disaster they survived and returns a string of all players that won 
function get_winners()
	local winners = "No one survived!" -- default string when no one survived
	local winner_count = 0
	if game.Players.NumPlayers == 0  then return winners end
	for index, player in ipairs(game.Players:GetPlayers()) do
		pcall(function()
			if game.ReplicatedStorage.PlayerData:FindFirstChild(player.Name):WaitForChild("InGame").Alive.Value == true then
				if winner_count == 0 then
					if player.Name == "Eleqtron" then
						winners = "Survivors: ".."DenisDaily"
					else
						winners = "Survivors: "..player.Name
					end
					--winners = "Survivors: "..player.Name
				else 
					if player.Name == "Eleqtron" then
						winners = winners..", ".. "DenisDaily"
					else
						winners = winners..", ".. player.Name
					end
					--winners = winners..", ".. player.Name
				end
				winner_count = winner_count + 1
				if (game.VIPServerId ~= "" and game.VIPServerOwnerId == 0) then return nil else
					local data = get_data(player.Name)
					local mul = 1
					if data.Gamepasses.Premium.Value == true then
						mul = 2
					end
					game.ReplicatedStorage.PlayerData:FindFirstChild(player.Name).Currency.Coins.Value = game.ReplicatedStorage.PlayerData:FindFirstChild(player.Name).Currency.Coins.Value + 10 * mul -- give points
					add_win(player.Name)
					--game.ReplicatedStorage.RemoteEvents.UpLead:FireAllClients()
					add_xp(player.Name)
				end
			end
		end)
	end
	return winners
end

--// Counts down until the disaster ends - the duration is given by the disaster model
function countdown_disaster(model)
	game.ReplicatedStorage.RemoteEvents["UpdateHeader"]:FireAllClients("Event: "..model.Name)
	local duration
	if model:FindFirstChild("Duration") then
		duration = model.Duration.Value
	else
		duration = disaster_duration
	end
	for timer = duration, 0, -1 do
		game.ReplicatedStorage.RemoteEvents["UpdateTime"]:FireAllClients(tostring(timer))
		wait(1)
	end
end

--// Counts down until the next disaster begins
function countdown_intermission()
	game.ReplicatedStorage.RemoteEvents["UpdateHeader"]:FireAllClients("Intermission")
	for timer = intermission_duration, 0, -1 do
		game.ReplicatedStorage.RemoteEvents["UpdateTime"]:FireAllClients(tostring(timer))
		wait(1)
	end
	game.ReplicatedStorage.RemoteEvents["UpdateHeader"]:FireAllClients("Loading Event")
	wait(2)
end

--// Starting the game
if not workspace.Map:FindFirstChildOfClass("Model") then
	draw_map()
end
reset_sky()

--// Runs the game
while true do
	countdown_intermission()
	local disaster = choose_disaster() -- object
	send_announcement("Event: "..disaster.Name, blur_size)
	wait(6)
	load_disaster(disaster)
	countdown_disaster(disaster) -- wait til disaster ends
	clear_disaster(disaster)
	send_announcement(get_winners(), blur_size)
	if map_change_count == map_change then
		draw_map()
		map_change_count = 0
	elseif map_hit_count == map_hit then 
		send_announcement("Regenerating Map", blur_size)
		regen_map()
		map_hit_count = 0
	else
		map_hit_count = map_hit_count + 1
		map_change_count = map_change_count + 1
	end
end