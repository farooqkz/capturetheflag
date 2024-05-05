ctf_core = {
	settings = {
		-- server_mode = minetest.settings:get("ctf_server_mode") or "play",
		server_mode = minetest.settings:get_bool("creative_mode", false) and "mapedit" or "play",
<<<<<<< HEAD
		eliminate_team_flag_captures = tonumber(minetest.settings:get("ctf_eliminate_team_flag_captures")) or 1,
		low_ram_mode = minetest.settings:get("ctf_low_ram_mode") or false,
=======
		low_ram_mode = minetest.settings:get("ctf_low_ram_mode") == "true" or false,
>>>>>>> 18d0b00fc1620a4da2d2d7927323873c9284f6bb
	}
}

---@param files table
-- Returns dofile() return values in order that files are given
--
-- Example: local f1, f2 = ctf_core.include_files("file1", "file2")
function ctf_core.include_files(...)
	local PATH = minetest.get_modpath(minetest.get_current_modname()) .. "/"
	local returns = {}

	for _, file in pairs({...}) do
		for _, value in pairs{dofile(PATH .. file)} do
			table.insert(returns, value)
		end
	end

	return unpack(returns)
end

ctf_core.include_files(
	"helpers.lua",
	"privileges.lua",
	"cooldowns.lua"
)
