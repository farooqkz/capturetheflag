local CHAT_COLOR = "orange"
local timer = nil
local bounties = {}

ctf_modebase.bounties = {}
-- ^ This is for game's own bounties
ctf_modebase.contributed_bounties = {}
-- ^ This is for user contributed bounties
ctf_modebase.bank = {}
-- ^ This is to keep track of scores pledged by players for user contributed bounties

local function get_contributors(name) 
	local b = ctf_modebase.contributed_bounties[name]
	if b == nil then
		return ""
	else
		count = 0
		list = ""
		for _, contributor in pairs(b["contributors"]) do
			count = count + 1
			list = list .. contributor .. ","
		end
		if count == 1 then
			list = b["contributors"][1]
		end
		return list
	end
end

local function get_reward_str(rewards)
	local ret = ""

	for reward, amount in pairs(rewards) do
		ret = string.format("%s%s%d %s, ", ret, amount >= 0 and "+" or "-", amount, HumanReadable(reward))
	end

	return ret:sub(1, -3)
end

local function set(pname, pteam, rewards)
	-- pname(str) is the player's name
	-- pteam(str) is the player's team(e.g. "red")
	-- rewards(table) has two entries:
	-- -- bounty_kills(int) which is usually 1
	-- -- score(int) which is the amount of score given to the one
	-- -- -- who claims the bounty
	local bounty_message = minetest.colorize(CHAT_COLOR, string.format(
		"[Bounty] %s. Rewards: %s",
		pname, get_reward_str(rewards)
	))

	for _, team in ipairs(ctf_teams.current_team_list) do -- show bounty to all but target's team
		if team ~= pteam then
			ctf_teams.chat_send_team(team, bounty_message)
		end
	end

	bounties[pteam] = {name = pname, rewards = rewards, msg = bounty_message}
end

local function remove(pname, pteam)
	minetest.chat_send_all(minetest.colorize(CHAT_COLOR, string.format("[Bounty] %s is no longer bountied", pname)))
	bounties[pteam] = nil
end

function ctf_modebase.bounties.claim(player, killer)
	local pteam = ctf_teams.get(player)
	local is_bounty = not (pteam and bounties[pteam] and bounties[pteam].name == player)
	if is_bounty and ctf_modebase.contributed_bounties[player] == nil then
		-- checking if there is bounty on this player
		return
	end
	
	local rewards = { bounty_kills = 0, score = 0 }
	if bounties[pteam] and bounties[pteam].rewards then
		rewards = bounties[pteam].rewards
		minetest.chat_send_all(minetest.colorize(CHAT_COLOR,
			string.format("[Bounty] %s killed %s and got %s from the game!", killer, player, get_reward_str(rewards))
		))

		bounties[pteam] = nil
	end
	if ctf_modebase.contributed_bounties[player] then
		local score = ctf_modebase.contributed_bounties[player]["amount"]
		rewards.score = rewards.score + score
		minetest.chat_send_all(minetest.colorize(CHAT_COLOR, string.format("[Player bounty] %s killed %s and got %d from %s!", killer, player, score, get_contributors(player))))
	end	
	return rewards
end

function ctf_modebase.bounties.reassign()
	local teams = {}

	for tname, team in pairs(ctf_teams.online_players) do
		teams[tname] = {}
		for player in pairs(team.players) do
			table.insert(teams[tname], player)
		end
	end

	for tname in pairs(bounties) do
		if not teams[tname] then
			teams[tname] = {}
		end
	end

	for tname, team_members in pairs(teams) do
		local old = nil
		if bounties[tname] then
			old = bounties[tname].name
		end

		local new = nil
		if #team_members > 0 then
			new = ctf_modebase.bounties.get_next_bounty(team_members)
		end

		if old and old ~= new then
			remove(old, tname)
		end

		if new then
			set(new, tname, ctf_modebase.bounties.bounty_reward_func(new))
		end
	end
end

function ctf_modebase.bounties.reassign_timer()
	timer = minetest.after(math.random(180, 360), function()
		ctf_modebase.bounties.reassign()
		ctf_modebase.bounties.reassign_timer()
	end)
end

ctf_api.register_on_match_start(ctf_modebase.bounties.reassign_timer)

ctf_api.register_on_match_end(function()
	bounties = {}
	if timer then
		timer:cancel()
		timer = nil
	end
end)

function ctf_modebase.bounties.bounty_reward_func()
	return {bounty_kills = 1, score = 500}
end

function ctf_modebase.bounties.get_next_bounty(team_members)
	return team_members[math.random(1, #team_members)]
end

ctf_teams.register_on_allocplayer(function(player, new_team, old_team)
	local pname = player:get_player_name()

	if old_team and old_team ~= new_team and bounties[old_team] and bounties[old_team].name == pname then
		remove(pname, old_team)
	end

	local output = {}

	for tname, bounty in pairs(bounties) do
		if new_team ~= tname then
			table.insert(output, bounty.msg)
		end
	end

	if #output > 0 then
		minetest.chat_send_player(pname, table.concat(output, "\n"))
	end
end)

ctf_core.register_chatcommand_alias("list_bounties", "lb", {
	description = "List current bounties",
	func = function(name)
		local pteam = ctf_teams.get(name)
		local output = {}
		local x = 0
		for tname, bounty in pairs(bounties) do
			local player = minetest.get_player_by_name(bounty.name)

			if player and pteam ~= tname then
				local label = string.format(
					"label[%d,0.1;%s: %s score]",
					x,
					bounty.name,
					minetest.colorize("cyan", bounty.rewards.score)
				)

				table.insert(output, label)
				local model = "model[%d,1;4,6;player;character.b3d;%s;{0,160};;;]"
				model = string.format(
					model,
					x,
					player:get_properties().textures[1]
				)
				table.insert(output, model)
				x = x + 4.5
			end
		end
		for pname, bounty in pairs(ctf_modebase.contributed_bounties) do
			local label = string.format(
				"label[%d,0.1;%s: %s score]",
				x,
				pname,
				minetest.colorize("cyan", bounty.amount)
			)
			table.insert(output, label)

			model = string.format(
				model,
				x,
				player:get_properties().textures[1]
			)
			table.insert(output, model)
			x = x + 4.5
		end

		if #output <= 0 then
			return false, "There are no bounties you can claim"
		end
		x = x - 1.5
		local formspec = "size[" .. x .. ",6]\n" .. table.concat(output, "\n")
		minetest.show_formspec(name, "ctf_modebase:lb", formspec)
		return true, ""
	end,
})

ctf_core.register_chatcommand_alias("put_bounty", "pb", {
	description = "Put bounty on some player",
	params = "<player> <amount>",
	privs = { ctf_admin = true },
	func = function(name, param)
		local player, amount = string.match(param, "(.*) (.*)")
		local pteam = ctf_teams.get(player)
		local team_colour = ctf_teams.team[pteam].color
		if not (player and pteam and amount) then
			return false, "Incorrect parameters"
		end
		amount = ctf_core.to_number(amount)
		set(
			player,
			pteam,
			{ bounty_kills=1, score=amount }
		)
		return true, "Successfully placed a bounty of " .. amount .. " on " .. minetest.colorize(team_colour, player) .. "!"
	end,
})



ctf_core.register_chatcommand_alias("bounty", "b", {
	description = "Put bounty on someone's head using your score(10% fee)",
	params = "<player> <score>",
	func = function(name, params)
		local bname, amount = string.match(params, "(.*) (.*)")
		if not (amount and bname) then
			return false, "Missing argument(s)"
		end
		amount = tonumber(amount) * 0.9
		local bteam = ctf_teams.get(bname)
		if bteam == nil then
			return false, "This player is either not online or not in any team"
		end
		if bteam == ctf_teams.get(name) then
			return false, "You cannot put bounty on your teammate's head!"
		end
		if amount * 10/9 < 15 then
			return false, "Sorry you must at least donate 15"
		end
		local mode_data = ctf_modebase:get_current_mode()
		if not mode_data or not ctf_modebase.match_started then
			return false, "Match has not started yet."
		end
		local prank = mode_data.rankings:get(name)
		if not prank or prank["score"] <= amount then
			return false, "Sorry you haven't got enough score"
		end
		if ctf_modebase.contributed_bounties[bname] == nil then
			ctf_modebase.contributed_bounties[bname] = { contributors = { name }, amount = amount }
		else
			table.insert(ctf_modebase.contributed_bounties[bname]["contributors"], name)
			ctf_modebase.contributed_bounties[bname]["amount"] = ctf_modebase.contributed_bounties[bname]["amount"] + amount
		end
		prank["score"] = prank["score"] - amount
		mode_data.rankings:set(name, prank)
		if ctf_modebase.bank[name] == nil then
			ctf_modebase.bank[name] = amount
		else
			ctf_modebase.bank[name] = ctf_modebase.bank[name] + amount
		end
		local contributors = ""
		local count = 0
		for _, contributor in pairs(ctf_modebase.contributed_bounties[bname]["contributors"]) do
			contributors = contributors .. ", " .. contributor
			count = count + 1
		end
		if count == 1 then
			contributors = ctf_modebase.contributed_bounties[bname]["contributors"][1]
		end
		amount = ctf_modebase.contributed_bounties[bname]["amount"]
		minetest.chat_send_all(minetest.colorize(CHAT_COLOR, string.format("%s donated %d for %s's head!", get_contributors(bname), amount, bname)))
	end,
})
