-- Monsters. All of them are billboard sprites using Pixel Dungeon art; stats scale with level.
local rnd = dbl.rnd

dbl.mob_types = {}

-- hp/dmg are {base, per level}. kind: "melee" | "bomber". ghost: ignores walls.
local TYPES = {
	rat      = {name = "Marsupial Rat", tex = "voxeldungeon_icon_mob_rat.png",     hp = {14, 6},  dmg = {3, 2},   speed = 2.6, size = 1.2},
	albino   = {name = "Albino Rat",    tex = "voxeldungeon_icon_mob_albino.png",  hp = {20, 7},  dmg = {4, 2},   speed = 2.7, size = 1.3},
	crab     = {name = "Sewer Crab",    tex = "voxeldungeon_icon_mob_crab.png",    hp = {28, 10}, dmg = {4, 2},   speed = 1.8, size = 1.4},
	scout    = {name = "Gnoll Scout",   tex = "voxeldungeon_icon_mob_scout.png",   hp = {18, 8},  dmg = {4, 2},   speed = 2.3, size = 1.6},
	skeleton = {name = "Skeleton",      tex = "voxeldungeon_icon_mob_skeleton.png",hp = {24, 9},  dmg = {5, 2.4}, speed = 2.2, size = 1.7},
	thief    = {name = "Crazy Thief",   tex = "voxeldungeon_icon_mob_thief.png",   hp = {14, 5},  dmg = {5, 2.2}, speed = 3.5, size = 1.6},
	bandit   = {name = "Bandit",        tex = "voxeldungeon_icon_mob_bandit.png",  hp = {22, 8},  dmg = {6, 2.4}, speed = 3.1, size = 1.6},
	wraith   = {name = "Wraith",        tex = "voxeldungeon_icon_mob_wraith.png",  hp = {20, 8},  dmg = {6, 2.6}, speed = 2.9, size = 1.6, ghost = true},
	mimic    = {name = "Mimic",         tex = "voxeldungeon_icon_mob_mimic.png",   hp = {40, 14}, dmg = {6, 3},   speed = 2.0, size = 1.6},
	statue   = {name = "Animated Statue", tex = "voxeldungeon_icon_mob_statue.png", hp = {50, 18}, dmg = {8, 3},  speed = 1.5, size = 1.8},
	bomb     = {name = "Bomb Rat",      tex = "voxeldungeon_icon_mob_rat.png^[colorize:#ff2a1a:110", hp = {12, 5}, dmg = {4, 2}, speed = 2.7, size = 1.3, kind = "bomber"},
}

-- spawn weights per zone (1 sewers .. 5 halls)
local SPAWN = {
	{{"rat", 4}, {"albino", 1}, {"crab", 2}, {"bomb", 2}},
	{{"scout", 3}, {"skeleton", 3}, {"thief", 2}, {"bomb", 2}},
	{{"skeleton", 2}, {"thief", 2}, {"wraith", 3}, {"bandit", 2}, {"bomb", 2}},
	{{"wraith", 3}, {"mimic", 2}, {"skeleton", 2}, {"bandit", 2}, {"bomb", 2}},
	{{"statue", 3}, {"mimic", 2}, {"wraith", 3}, {"bomb", 3}},
}

local function stat(s, lvl) return s[1] + s[2] * lvl end

local function nametag(self)
	local frac = dbl.clamp(self.hp / self.max_hp, 0, 1)
	local filled = math.ceil(frac * 8)
	local bar = string.rep("#", filled) .. string.rep("-", 8 - filled)
	self.object:set_properties({
		nametag = string.format("%s Lv%d [%s]", self.def.name, self.lvl, bar),
		nametag_color = frac > 0.5 and "#d9e6b8" or (frac > 0.25 and "#ffcc66" or "#ff6655"),
		nametag_bgcolor = "#00000000",
	})
end

function dbl.damage_mob(self, dmg, crit, player)
	if self.dead then return end
	self.hp = self.hp - dmg
	self.flash = 0.12
	local pos = self.object:get_pos()
	dbl.float_text({x = pos.x, y = pos.y + self.half + 0.5, z = pos.z}, math.floor(dmg + 0.5) .. (crit and "!" or ""),
		crit and "#ffd23f" or "#ffffff")
	if player then
		local st = dbl.players[player:get_player_name()]
		if st and st.stats.vamp > 0 then
			st.hp = math.min(st.max_hp, st.hp + dmg * st.stats.vamp / 100)
		end
	end
	if self.hp <= 0 then
		self.dead = true
		dbl.mobs[self] = nil
		dbl.burst(pos, self.def.kind == "bomber" and "#ff5a3a" or "#9bb27a", 12)
		if player and dbl.on_mob_kill then dbl.on_mob_kill(self, player, pos) end
		self.object:remove()
	else
		nametag(self)
	end
end

local function set_tex(self, tex)
	if self.cur_tex ~= tex then
		self.cur_tex = tex
		self.object:set_properties({textures = {tex}})
	end
end

local function boom(self, pos, hero)
	self.dead = true
	dbl.mobs[self] = nil
	local d = dbl.hdist(pos, hero.object:get_pos())
	if d < 3.4 then dbl.hurt_hero(hero, self.dmg * 3, self.def.name) end
	dbl.explode({x = pos.x, y = 1.5, z = pos.z}, 2.3)
	self.object:remove()
end

local function register(id, def)
	dbl.mob_types[id] = def
	local half = def.size / 2
	local r = def.size * 0.25
	core.register_entity("dbl_mobs:" .. id, {
		initial_properties = {
			visual = "sprite",
			textures = {def.tex},
			visual_size = {x = def.size, y = def.size},
			collisionbox = {-r, -half, -r, r, half, r},
			physical = not def.ghost,
			collide_with_objects = false,
			pointable = false,
			static_save = false,
			glow = def.ghost and 6 or 0,
			show_on_minimap = false,
		},
		on_activate = function(self, staticdata)
			local d = staticdata ~= "" and core.deserialize(staticdata) or {}
			self.def, self.half = def, half
			self.lvl = d.lvl or 1
			self.max_hp = stat(def.hp, self.lvl)
			self.hp = self.max_hp
			self.dmg = stat(def.dmg, self.lvl)
			self.cd, self.flash, self.fuse, self.stuck_t, self.side_t = rnd(0.2, 1), 0, 0, 0, 0
			self.cur_tex = def.tex
			if not def.ghost then self.object:set_acceleration({x = 0, y = -24, z = 0}) end
			dbl.mobs[self] = true
			nametag(self)
		end,
		on_deactivate = function(self) dbl.mobs[self] = nil end,
		on_step = function(self, dtime)
			if self.dead then return end
			local pos = self.object:get_pos()
			if not pos then return end
			local hero = dbl.nearest_hero(pos, 60)
			if not hero then
				dbl.mobs[self] = nil
				self.object:remove()
				return
			end
			local hp = hero.object:get_pos()
			local dx, dz = hp.x - pos.x, hp.z - pos.z
			local d = math.hypot(dx, dz)
			self.cd = self.cd - dtime

			local vel = self.object:get_velocity()
			local move = 0
			if d < 22 then
				local reach = def.kind == "bomber" and 1.6 or 1.2
				local speed = def.speed
				if def.kind == "bomber" then
					if d < 2.4 then self.fuse = self.fuse + dtime else self.fuse = math.max(0, self.fuse - dtime) end
					if self.fuse > 0 then speed = speed * 0.3 end
					if self.fuse > 1.4 then return boom(self, pos, hero) end
				elseif d <= reach and self.cd <= 0 then
					self.cd = 1
					dbl.hurt_hero(hero, self.dmg, def.name)
				end
				if d > reach then
					move = speed
					local ux, uz = dx / d, dz / d
					-- cheap unstick: if we're not making progress, sidestep for a moment
					self.stuck_t = self.stuck_t + dtime
					if self.stuck_t > 0.5 then
						self.stuck_t = 0
						if self.last_pos and not def.ghost and dbl.hdist(self.last_pos, pos) < speed * 0.5 * 0.3 then
							self.side_t = 0.7
							self.side = math.random() < 0.5 and 1 or -1
						end
						self.last_pos = pos
					end
					if self.side_t > 0 then
						self.side_t = self.side_t - dtime
						local a = self.side * 1.2
						ux, uz = ux * math.cos(a) - uz * math.sin(a), ux * math.sin(a) + uz * math.cos(a)
					end
					self.object:set_velocity({x = ux * move, y = def.ghost and 0 or vel.y, z = uz * move})
					if dbl.cam_right then self.flip = (ux * dbl.cam_right.x + uz * dbl.cam_right.z) > 0 end
				else
					self.object:set_velocity({x = 0, y = def.ghost and 0 or vel.y, z = 0})
				end
			end

			if def.ghost and math.abs(pos.y - (dbl.FLOOR + 0.8 + half * 0.5)) > 0.05 then
				self.object:set_pos({x = pos.x, y = dbl.FLOOR + 0.8 + half * 0.5, z = pos.z})
			end

			-- hit flash / fuse pulse
			self.flash = self.flash - dtime
			local pulse = def.kind == "bomber" and self.fuse > 0 and math.sin(self.fuse * 25) > 0
			local tex = def.tex .. (self.flip and "^[transformFX" or "")
			if self.flash > 0 or pulse then tex = tex .. "^[colorize:#ffffff:170" end
			set_tex(self, tex)
		end,
	})
end

for id, def in pairs(TYPES) do register(id, def) end

-- spawner ----------------------------------------------------------------------
local MAX_MOBS = 14
local timer = 0
function dbl.count_mobs()
	local n = 0
	for _ in pairs(dbl.mobs) do n = n + 1 end
	return n
end

function dbl.spawn_mob(id, pos, lvl)
	local def = dbl.mob_types[id]
	local o = core.add_entity({x = pos.x, y = dbl.FLOOR + def.size / 2 + 0.05, z = pos.z}, "dbl_mobs:" .. id,
		core.serialize({lvl = lvl}))
	return o
end

core.register_globalstep(function(dtime)
	timer = timer - dtime
	if timer > 0 or not dbl.world_ready then return end
	timer = 2.2
	if dbl.count_mobs() >= MAX_MOBS then return end
	local heroes = {}
	for _, h in pairs(dbl.heroes) do heroes[#heroes + 1] = h end
	if #heroes == 0 then return end
	local hero = dbl.pick(heroes)
	local hp = hero.object:get_pos()
	if not hp then return end
	for _ = 1, 12 do
		local a, dist = rnd(0, math.pi * 2), rnd(14, 24)
		local x, z = hp.x + math.cos(a) * dist, hp.z + math.sin(a) * dist
		if dbl.dungeon.is_floor(x, z) and dbl.dungeon.is_floor(x + 0.6, z) and dbl.dungeon.is_floor(x - 0.6, z)
				and dbl.dungeon.is_floor(x, z + 0.6) and dbl.dungeon.is_floor(x, z - 0.6) then
			local zone = dbl.dungeon.zone_at(x, z)
			local id = dbl.wpick(SPAWN[zone])
			local st = dbl.players[hero.player_name]
			local lvl = (st and st.lvl or 1) + (zone - 1)
			dbl.spawn_mob(id, {x = x, z = z}, lvl)
			return
		end
	end
end)
