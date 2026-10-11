-- The hero and the camera rig.
--
-- Luanti has no free mouse cursor, so (like Extra Ordinance) the real player object is only a
-- camera: it is attached to an invisible entity that hovers above and behind the hero. The mouse
-- turns the camera around the hero (yaw) and slides the aim point nearer/farther (pitch); the
-- hero aims at wherever the screen-centre ray hits the floor. The hero itself is a sprite entity.
local H = {}
dbl.hero = H
local mp = core.get_modpath("dbl_hero")

H.CAM_H, H.CAM_D = 15, 10        -- camera height / distance behind the hero
H.PITCH_MIN, H.PITCH_MAX = 0.55, 1.15
H.PITCH_DEFAULT = 0.75   -- aim point ~6 nodes ahead of the hero
H.HERO_H = 1.5                   -- sprite size
H.BASE_SPEED = 6

local T = function(n) return "voxeldungeon_tool_" .. n .. ".png" end

-- inventory items (the hotbar is the 3-slot weapon / pickaxe / barricade selector) -------
local noop = function(stack) return stack end
core.register_craftitem("dbl_hero:weapon", {
	description = "Weapon", inventory_image = T"weapon_shortsword", stack_max = 1, range = 0, on_drop = noop,
})
core.register_craftitem("dbl_hero:pickaxe", {
	description = "Pickaxe", inventory_image = T"pickaxe_demonite", stack_max = 1, range = 0, on_drop = noop,
})
core.override_item("", {range = 0, tool_capabilities = {full_punch_interval = 1, groupcaps = {}, damage_groups = {}}})

-- player state -----------------------------------------------------------------------
local function new_state()
	return {
		hp = 100, max_hp = 100, lvl = 1, xp = 0, kills = 0, gold = 0, blocks = 12,
		eq = {weapon = {slot = "weapon", rar = 1, lvl = 1, aff = {}, dmg = 6, name = "Shortsword", plus = 0, tex = T"weapon_shortsword"}},
		stats = {dmg = 8, armor = 0, crit = 5, haste = 0, vamp = 0},
		cd = {nova = 0, fire = 0}, atk_cd = 0, mine_cd = 0, place_cd = 0,
		log = {}, aim = {x = 0, z = 1}, aim_dist = 5, fwd = {x = 0, z = 1}, right = {x = 1, z = 0},
		dead_t = 0, last = {}, hud = {}, hud_cache = {}, age = 0,
	}
end

function dbl.recompute(st)
	local function a(k)
		local s = 0
		for _, it in pairs(st.eq) do s = s + (it.aff[k] or 0) end
		return s
	end
	local S = st.stats
	S.dmg = ((st.eq.weapon and st.eq.weapon.dmg) or 3) + st.lvl * 2
	S.armor = st.eq.armor and st.eq.armor.armor or 0
	S.crit, S.haste, S.vamp = 5 + a("crit"), a("haste"), a("vamp")
	st.max_hp = 100 + (st.lvl - 1) * 12 + a("life")
	st.hp = math.min(st.hp, st.max_hp)
	st.sync_inv = true
end

function dbl.haste(st) return 1 + st.stats.haste / 100 end

function dbl.nearest_hero(pos, maxd)
	local best, bd = nil, maxd or 1e9
	for _, h in pairs(dbl.heroes) do
		local p = h.object:get_pos()
		if p then
			local d = dbl.hdist(p, pos)
			if d < bd then best, bd = h, d end
		end
	end
	return best
end

-- entities ----------------------------------------------------------------------------
local half = H.HERO_H / 2
core.register_entity("dbl_hero:hero", {
	initial_properties = {
		visual = "sprite", textures = {"dbl_hero.png"}, visual_size = {x = H.HERO_H, y = H.HERO_H},
		collisionbox = {-0.3, -half, -0.3, 0.3, half, 0.3},
		physical = true, collide_with_objects = false, pointable = false, static_save = false,
		show_on_minimap = false,
	},
	on_activate = function(self)
		self.object:set_acceleration({x = 0, y = -24, z = 0})
	end,
	on_step = function(self)
		if not self.player_name or not core.get_player_by_name(self.player_name) then self.object:remove() end
	end,
})

core.register_entity("dbl_hero:cam", {
	initial_properties = {
		visual = "sprite", textures = {"dbl_blank.png"}, visual_size = {x = 0.01, y = 0.01},
		physical = false, pointable = false, static_save = false, collisionbox = {0, 0, 0, 0, 0, 0},
		show_on_minimap = false,
	},
	on_step = function(self)
		if not self.player_name or not core.get_player_by_name(self.player_name) then self.object:remove() end
	end,
})

-- spawning ------------------------------------------------------------------------------
function H.spawn_hero(player)
	local name = player:get_player_name()
	local st = dbl.players[name]
	if not st then return end
	local old = dbl.heroes[name]
	if old and old.object:get_pos() then old.object:remove() end
	local sp = dbl.dungeon.start_pos
	local obj = core.add_entity({x = sp.x, y = dbl.FLOOR + half + 0.05, z = sp.z}, "dbl_hero:hero")
	if not obj then return end
	local ent = obj:get_luaentity()
	ent.player_name = name
	dbl.heroes[name] = ent
	st.hp = st.max_hp
	if not (st.cam and st.cam:get_pos()) then
		st.cam = core.add_entity({x = sp.x, y = sp.y + H.CAM_H, z = sp.z - H.CAM_D}, "dbl_hero:cam")
		st.cam:get_luaentity().player_name = name
		player:set_attach(st.cam, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
		player:set_look_vertical(math.atan(H.CAM_H / H.CAM_D))
		player:set_look_horizontal(0)
	end
end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local st = new_state()
	dbl.players[name] = st

	player:set_properties({
		is_visible = false, pointable = false, eye_height = 0, collisionbox = {0, 0, 0, 0, 0, 0},
		nametag = "", nametag_color = "#00000000", show_on_minimap = false,
	})
	player:set_physics_override({speed = 0, jump = 0, gravity = 0, sneak = false})
	player:set_fov(45, false, 0)
	player:set_pos({x = 0, y = 30, z = 0})
	player:set_sky({type = "plain", base_color = "#0b0810", clouds = false})
	player:set_sun({visible = false, sunrise_visible = false})
	player:set_moon({visible = false})
	player:set_stars({visible = false})
	player:override_day_night_ratio(0.85)
	player:set_inventory_formspec("")
	player:hud_set_flags({crosshair = false, wielditem = false, healthbar = false, breathbar = false, minimap = false, minimap_radar = false})
	player:hud_set_hotbar_itemcount(3)
	local inv = player:get_inventory()
	inv:set_size("main", 3)
	dbl.recompute(st)
	st.hp = st.max_hp
	H.build_hud(player, st)
	dbl.log(player, "Welcome to the dungeon. Kill something.", "#e8dcc0")
	dbl.when_ready(function()
		if core.get_player_by_name(name) then H.spawn_hero(player) end
	end)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local st = dbl.players[name]
	if st and st.cam and st.cam:get_pos() then st.cam:remove() end
	local h = dbl.heroes[name]
	if h and h.object:get_pos() then h.object:remove() end
	dbl.heroes[name], dbl.players[name] = nil, nil
end)
core.register_on_respawnplayer(function() return true end)
core.register_allow_player_inventory_action(function() return 0 end)

dofile(mp .. "/combat.lua")
dofile(mp .. "/hud.lua")
dofile(mp .. "/loop.lua")
