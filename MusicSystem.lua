--[[
Author(s): Electra Bree & Aaron Spivey

This script runs the game's music system with the Trello API
]]--

--// Variables
api = require(game.ServerScriptService.TrelloBrain)
music_board = api:GetBoardID("Music")
generic_song_list = api:GetListID("Generic", music_board)
sound = workspace:WaitForChild("Music")

--// Arrays
_G["song_queue"] = {}

--// Chooses song based on queue or random
function choose_song() 
	local song
	if #_G.song_queue == 0 then
		local playlist_table = api:GetCardsInList(generic_song_list)
		local random_index = math.random(1, #playlist_table)
		song = playlist_table[random_index] --// lists the info: song.name, song.desc
	else
		-- choose a song not yet implemented
	end
	return song
end

--// Loads the song into the sound object
function load_song(song)
	local song_name = song.name
	local song_id = string.match(song.desc, "%d+")
	local playback_speed = string.match(song.desc, "%d+ (.+)")
	if playback_speed == nil then print(song.name) end
	sound.SoundId = "rbxassetid://"..song_id
	sound.PlaybackSpeed = tonumber(playback_speed) or 1
	sound.TimePosition = 0
	sound:WaitForChild("SongName").Value = tostring(song_name)
end

--// Plays the songs in a loop
while wait() do
	local song = choose_song() 
	load_song(song)
	if not sound.IsLoaded then 
		sound.Loaded:wait()
	end
	sound:Play()
	sound.Ended:Wait()
end