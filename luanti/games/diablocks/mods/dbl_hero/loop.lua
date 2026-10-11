-- Per-step driver: camera, aim, movement, actions, HUD.
local H = dbl.hero

local function camera_step(player, st, focus)
	local cam = st.cam
	local cpos = cam and cam:get_pos()
	if not cpos then return end
	local yaw = player:get_look_horizontal()
	local fwd = {x = -math.sin(yaw), z = math.cos(yaw)}
	st.fwd, st.right = fwd, {x = math.cos(yaw), z = math.sin(yaw)}
	dbl.cam_right = st.right
	if st.age < 1.5 then player:set_look_vertical(H.PITCH_DEFAULT) end
	local pitch = player:get_look_vertical()
	local cl = dbl.clamp(pitch, H.PITCH_MIN, H.PITCH_MAX)
	if cl ~= pitch then player:set_look_vertical(cl) end
	local tx, ty, tz = focus.x - fwd.x * H.CAM_D, focus.y + H.CAM_H, focus.z - fwd.z * H.CAM_D
	local k = 14
	cam:set_velocity({x = (tx - cpos.x) * k, y = (ty - cpos.y) * k, z = (tz - cpos.z) * k})
	return cpos
end

-- where does the screen-centre ray hit the floor? that is the aim point
local function aim_step(player, st, hp, cpos)
	local dir = player:get_look_dir()
	if cpos and dir.y < -0.05 then
		local plane = dbl.FLOOR + 0.05
		local t = (plane - cpos.y) / dir.y
		local ax, az = cpos.x + dir.x * t, cpos.z + dir.z * t
		local dx, dz = ax - hp.x, az - hp.z
		local d = math.hypot(dx, dz)
		if d > 1.2 then
			st.aim = {x = dx / d, z = dz / d}
			st.aim_dist = math.min(d, 26)
		end
	end
	local ax, az = hp.x + st.aim.x * st.aim_dist, hp.z + st.aim.z * st.aim_dist
	core.add_particle({pos = {x = ax, y = dbl.FLOOR + 0.06, z = az}, expirationtime = 0.08, size = 2.6,
		texture = "dbl_cursor.png", glow = 14, to_player = player:get_player_name()})
end

local function respawn(player, st)
	H.spawn_hero(player)
	local sp = dbl.dungeon.start_pos
	for mob in pairs(dbl.mobs) do
		local p = mob.object:get_pos()
		if p and dbl.hdist(p, sp) < 16 then
			mob.dead = true
			dbl.mobs[mob] = nil
			mob.object:remove()
		end
	end
end

local function step_player(player, st, dt)
	st.age = st.age + dt
	st.atk_cd, st.mine_cd, st.place_cd = st.atk_cd - dt, st.mine_cd - dt, st.place_cd - dt
	st.cd.nova, st.cd.fire = st.cd.nova - dt, st.cd.fire - dt
	st.cd_up = (st.cd_up or 0) - dt
	for i = #st.log, 1, -1 do
		st.log[i].t = st.log[i].t + dt
		if st.log[i].t > 12 then table.remove(st.log, i) end
	end

	local name = player:get_player_name()
	local hero = dbl.heroes[name]
	local hp = hero and hero.object:get_pos()
	if hero and not hp then dbl.heroes[name], hero = nil, nil end

	if hp then st.last_focus = hp end
	local focus = hp or st.last_focus or dbl.dungeon.start_pos
	local cpos = camera_step(player, st, focus)

	if hero and hp then
		aim_step(player, st, hp, cpos)
		local ctrl = player:get_player_control()
		local mx = (ctrl.up and 1 or 0) - (ctrl.down and 1 or 0)
		local mz = (ctrl.right and 1 or 0) - (ctrl.left and 1 or 0)
		local vx = st.fwd.x * mx + st.right.x * mz
		local vz = st.fwd.z * mx + st.right.z * mz
		local l = math.hypot(vx, vz)
		if l > 1 then vx, vz = vx / l, vz / l end
		local speed = H.BASE_SPEED * dbl.haste(st)
		local cur = hero.object:get_velocity()
		hero.object:set_velocity({x = vx * speed, y = cur.y, z = vz * speed})

		local wi = player:get_wield_index()
		if ctrl.dig then
			if wi == 1 then H.sword(player, st, hp)
			elseif wi == 2 then H.dig(player, st, hp, 0.15)
			else H.dig(player, st, hp, 0.6) end
		end
		if ctrl.place then
			if wi == 1 then H.fireball(player, st, hp, "aim")
			elseif wi == 3 then H.place(player, st, hp) end
		end
		if ctrl.jump then H.nova(player, st, hp) end
		if ctrl.aux1 then H.fireball(player, st, hp, "auto") end
		if ctrl.sneak and not st.last.sneak then H.upgrade(player, st, hp) end
		st.last.sneak = ctrl.sneak

		-- keep the hero on the dungeon floor if something shoves it through the world
		if hp.y < -2 then hero.object:set_pos({x = 0, y = dbl.FLOOR + 1, z = 0}) end
	elseif st.dead_t > 0 then
		st.dead_t = st.dead_t - dt
		if st.dead_t <= 0 then
			st.dead_t = 0
			respawn(player, st)
		end
	end

	st.hud_t = (st.hud_t or 0) - dt
	if st.hud_t <= 0 then
		st.hud_t = 0.1
		if st.sync_inv then H.sync_inv(player, st) end
		H.update_hud(player, st, hp)
	end
end

core.register_globalstep(function(dt)
	if not dbl.world_ready then return end
	for _, player in ipairs(core.get_connected_players()) do
		local st = dbl.players[player:get_player_name()]
		if st then step_player(player, st, dt) end
	end
end)
