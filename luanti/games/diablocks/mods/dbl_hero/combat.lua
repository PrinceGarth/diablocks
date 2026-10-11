-- Combat, mining, building and skills. Called from loop.lua once per server step.
local H = dbl.hero
local rnd = dbl.rnd

local function player_damage(st, mult)
	local crit = math.random() * 100 < st.stats.crit
	return st.stats.dmg * mult * rnd(0.9, 1.1) * (crit and 2 or 1), crit
end
H.player_damage = player_damage

local function each_mob(fn)
	for mob in pairs(dbl.mobs) do
		local p = not mob.dead and mob.object:get_pos()
		if p then fn(mob, p) end
	end
end
H.each_mob = each_mob

-- taking damage / dying -------------------------------------------------------------------
function H.kill_hero(player, st, hero)
	local name = player:get_player_name()
	local pos = hero.object:get_pos()
	if pos then dbl.burst(pos, "#ff4040", 16) end
	hero.object:remove()
	dbl.heroes[name] = nil
	st.dead_t = 2.5
	dbl.log(player, "You died. Oran wakes at the entrance.", "#ff5252")
end

function dbl.hurt_hero(hero, raw, source)
	local name = hero.player_name
	local st, player = dbl.players[name], core.get_player_by_name(name)
	if not st or not player then return end
	local d = math.max(1, raw * 100 / (100 + st.stats.armor * 3))
	st.hp = st.hp - d
	local pos = hero.object:get_pos()
	dbl.float_text({x = pos.x, y = pos.y + 1.2, z = pos.z}, "-" .. math.floor(d + 0.5), "#ff5252")
	if st.hp <= 0 then H.kill_hero(player, st, hero) end
end

function dbl.on_mob_kill(mob, player, pos)
	local st = dbl.players[player:get_player_name()]
	if not st then return end
	st.kills = st.kills + 1
	st.xp = st.xp + 10 + mob.lvl * 4
	while st.xp >= st.lvl * 40 do
		st.xp = st.xp - st.lvl * 40
		st.lvl = st.lvl + 1
		dbl.recompute(st)
		st.hp = st.max_hp
		dbl.log(player, "Level " .. st.lvl .. "!", "#ffd23f")
		dbl.ring({x = pos.x, y = dbl.FLOOR + 0.2, z = pos.z}, 3, "#ffd23f")
	end
	if math.random() < 0.45 then dbl.drop_item(pos, dbl.roll_item(mob.lvl)) end
	if math.random() < 0.25 then st.blocks = st.blocks + 2; st.sync_inv = true end
	if math.random() < 0.30 then
		local g = math.random(1, 2)
		st.gold = st.gold + g
		dbl.float_text({x = pos.x, y = pos.y + 1, z = pos.z}, "+" .. g .. " gold", "#e0b440")
	end
end

-- raycast helpers --------------------------------------------------------------------------
function H.pointed_node(player, st)
	local eye = st.cam and st.cam:get_pos()
	if not eye then return end
	local dir = player:get_look_dir()
	local to = vector.add(eye, vector.multiply(dir, 70))
	for pt in core.raycast(eye, to, false, false) do
		if pt.type == "node" then return pt end
	end
end

-- melee ------------------------------------------------------------------------------------
function H.sword(player, st, hp)
	if st.atk_cd > 0 then return end
	local aim = st.aim
	local hits = {}
	each_mob(function(mob, p)
		local ex, ez = p.x - hp.x, p.z - hp.z
		local d = math.hypot(ex, ez)
		if d < 2.4 and (d < 0.6 or (ex * aim.x + ez * aim.z) / d > 0.34) then hits[#hits + 1] = mob end
	end)
	local tex = st.eq.weapon and st.eq.weapon.tex or "voxeldungeon_tool_weapon_shortsword.png"
	if #hits > 0 then
		st.atk_cd = 0.6 / dbl.haste(st)
		core.add_particle({
			pos = {x = hp.x + aim.x * 1.1, y = hp.y + 0.3, z = hp.z + aim.z * 1.1},
			velocity = {x = aim.x * 3, y = 0.3, z = aim.z * 3}, expirationtime = 0.2, size = 4, texture = tex, glow = 12,
		})
		for _, mob in ipairs(hits) do
			local dmg, crit = player_damage(st, 1)
			dbl.damage_mob(mob, dmg, crit, player)
		end
	else
		st.atk_cd = 0.12
		H.dig(player, st, hp, 0.5) -- nothing to hit: the sword chips away at stone, slowly
	end
end

-- mining / building ----------------------------------------------------------------------------
function H.dig(player, st, hp, cooldown)
	if st.mine_cd > 0 then return end
	local pt = H.pointed_node(player, st)
	if not pt then return end
	local u = pt.under
	if u.y < 1 then return end
	local name = core.get_node(u).name
	if core.get_item_group(name, "dbl_dig") == 0 then return end
	if math.hypot(u.x - hp.x, u.z - hp.z) > 5.5 then
		if (st.age - (st.far_t or -9)) > 1 then
			st.far_t = st.age
			dbl.float_text({x = hp.x, y = hp.y + 1.3, z = hp.z}, "too far", "#aaaaaa")
		end
		return
	end
	core.remove_node(u)
	st.mine_cd = cooldown
	dbl.burst(u, "#8b7355", 6)
	if core.get_item_group(name, "dbl_ore") > 0 then
		st.gold = st.gold + 1
		dbl.float_text({x = u.x, y = u.y + 1, z = u.z}, "+1 gold", "#e0b440")
	else
		st.blocks = st.blocks + 1
		st.sync_inv = true
	end
end

function H.place(player, st, hp)
	if st.place_cd > 0 or st.blocks < 1 then return end
	local pt = H.pointed_node(player, st)
	if not pt then return end
	local a = pt.above
	if a.y ~= 1 then return end
	if math.hypot(a.x - hp.x, a.z - hp.z) > 7 then return end
	if math.abs(a.x - hp.x) < 0.9 and math.abs(a.z - hp.z) < 0.9 then return end
	if core.get_node(a).name ~= "air" then return end
	core.set_node(a, {name = "dbl_dungeon:barricade"})
	st.blocks = st.blocks - 1
	st.place_cd = 0.2
	st.sync_inv = true
end

-- skills -----------------------------------------------------------------------------------------
function H.nova(player, st, hp)
	if st.cd.nova > 0 then return end
	st.cd.nova = 4 / dbl.haste(st)
	dbl.ring({x = hp.x, y = dbl.FLOOR + 0.2, z = hp.z}, 4.2, "#66ccff")
	each_mob(function(mob, p)
		if dbl.hdist(p, hp) < 4.2 then
			local dmg, crit = player_damage(st, 2)
			dbl.damage_mob(mob, dmg, crit, player)
		end
	end)
end

core.register_entity("dbl_hero:fireball", {
	initial_properties = {
		visual = "sprite", textures = {"dbl_pixel.png^[colorize:#ff7a1a:255"}, visual_size = {x = 0.55, y = 0.55},
		physical = false, pointable = false, static_save = false, glow = 14, collisionbox = {0, 0, 0, 0, 0, 0},
	},
	on_activate = function(self, staticdata)
		local d = core.deserialize(staticdata)
		if not d then self.object:remove() return end
		self.dir, self.owner, self.dist = d.dir, d.owner, 0
		self.object:set_velocity({x = d.dir.x * 15, y = 0, z = d.dir.z * 15})
	end,
	on_step = function(self, dtime)
		local pos = self.object:get_pos()
		if not pos or not self.dir then return end
		self.dist = self.dist + 15 * dtime
		core.add_particle({pos = pos, expirationtime = 0.3, size = 2, glow = 14,
			velocity = {x = rnd(-.5, .5), y = rnd(0, 1), z = rnd(-.5, .5)}, texture = "dbl_pixel.png^[colorize:#ffb04a:255"})
		local boom = self.dist > 20
		local node = core.get_node(pos)
		local def = core.registered_nodes[node.name]
		if node.name == "ignore" or (def and def.walkable) then boom = true end
		if not boom then
			each_mob(function(mob, p)
				if dbl.hdist(p, pos) < 0.9 then boom = true end
			end)
		end
		if boom then
			local player = core.get_player_by_name(self.owner or "")
			local st = player and dbl.players[self.owner]
			if st then
				each_mob(function(mob, p)
					if dbl.hdist(p, pos) < 2.6 then
						local dmg, crit = player_damage(st, 2.5)
						dbl.damage_mob(mob, dmg, crit, player)
					end
				end)
			end
			dbl.explode(pos, 1.7)
			self.object:remove()
		end
	end,
})

-- mode "aim": right click, snaps to mobs close to the aim line; mode "auto": E, wide cone
function H.fireball(player, st, hp, mode)
	if st.cd.fire > 0 then return end
	st.cd.fire = 3 / dbl.haste(st)
	local dx, dz = st.aim.x, st.aim.z
	local min_cos = mode == "aim" and 0.9 or 0.5
	local best, bd = nil, 22
	each_mob(function(mob, p)
		local ex, ez = p.x - hp.x, p.z - hp.z
		local d = math.hypot(ex, ez)
		if d >= 1 and d < bd and (ex * dx + ez * dz) / d >= min_cos then best, bd = {x = ex / d, z = ez / d}, d end
	end)
	if best then dx, dz = best.x, best.z end
	core.add_entity({x = hp.x + dx * 0.8, y = hp.y + 0.1, z = hp.z + dz * 0.8}, "dbl_hero:fireball",
		core.serialize({dir = {x = dx, z = dz}, owner = player:get_player_name()}))
	st.aim = {x = dx, z = dz}
end

-- Scroll of Upgrade: costs 5 gold, +20% weapon damage -------------------------------------------
function H.upgrade(player, st, hp)
	if st.cd_up and st.cd_up > 0 then return end
	local w = st.eq.weapon
	if not w then return end
	if st.gold >= 5 then
		st.gold = st.gold - 5
		st.cd_up = 0.6
		w.dmg = math.ceil(w.dmg * 1.2)
		w.plus = (w.plus or 0) + 1
		dbl.recompute(st)
		dbl.log(player, "Scroll of Upgrade! " .. dbl.item_label(w) .. " is stronger.", "#ffd23f")
		dbl.burst({x = hp.x, y = hp.y + 0.8, z = hp.z}, "#e0b440", 14)
	else
		st.cd_up = 1.5
		dbl.log(player, "A Scroll of Upgrade costs 5 gold (dig the gold veins in the walls).", "#aaaaaa")
	end
end
