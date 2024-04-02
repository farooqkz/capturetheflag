ctf_modebase.bounty_algo = {kd = {}}

function ctf_modebase.bounty_algo.kd.get_next_bounty(team_members)
	local sum = 0
	local kd_list = {}
	local recent = ctf_modebase:get_current_mode().recent_rankings.players()

	for _, pname in ipairs(team_members) do
		if recent[pname] then
			local kd = (recent[pname].kills or 0) / (recent[pname].deaths or 1)
			if kd >= 0.8 then
				table.insert(kd_list, kd)
				sum = sum + kd
			end
		end
	end

	local random = math.random() * sum

	for i, kd in ipairs(kd_list) do
		if random <= kd then
			return team_members[i]
		end
		random = random - kd
	end

	return team_members[#team_members]
end

function ctf_modebase.bounty_algo.kd.bounty_reward_func(pname)
	local recent = ctf_modebase:get_current_mode().recent_rankings.players()[pname] or {}
	local kd = (recent.kills or 1) / (recent.deaths or 1)

	return {bounty_kills = 1, score = math.pow(kd * 1.5, 2.3)}
end
