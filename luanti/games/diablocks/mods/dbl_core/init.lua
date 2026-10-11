-- Shared helpers for Diablocks. Everything else hangs off the global `dbl` table.
dbl = {}

-- y of the walkable top surface of the floor layer (floor nodes live at y = 0)
dbl.FLOOR = 0.5

dbl.players = {}  -- player name -> state table (see dbl_hero)
dbl.heroes = {}   -- player name -> hero luaentity (only while alive on the map)
dbl.mobs = {}     -- set of mob luaentities

function dbl.rnd(a, b) return a + math.random() * (b - a) end
function dbl.pick(t) return t[math.random(#t)] end
function dbl.clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
function dbl.hdist(a, b) return math.hypot(a.x - b.x, a.z - b.z) end

function dbl.wpick(list)
	local total = 0
	for _, e in ipairs(list) do total = total + e[2] end
	local r = math.random() * total
	for _, e in ipairs(list) do
		r = r - e[2]
		if r <= 0 then return e[1] end
	end
	return list[#list][1]
end

-- run `fn` once the dungeon has been carved into the map (dbl_dungeon sets dbl.world_ready)
local waiting = {}
function dbl.when_ready(fn)
	if dbl.world_ready then fn() else waiting[#waiting + 1] = fn end
end
function dbl.set_ready()
	dbl.world_ready = true
	for _, fn in ipairs(waiting) do fn() end
	waiting = {}
end

-- particles ---------------------------------------------------------------
local function tint(color) return "dbl_pixel.png^[colorize:" .. color .. ":255" end

function dbl.burst(pos, color, n, spread)
	spread = spread or 3
	for _ = 1, n do
		core.add_particle({
			pos = pos,
			velocity = {x = dbl.rnd(-spread, spread), y = dbl.rnd(1, 5), z = dbl.rnd(-spread, spread)},
			acceleration = {x = 0, y = -14, z = 0},
			expirationtime = dbl.rnd(0.4, 0.9),
			size = dbl.rnd(1, 2.2),
			texture = tint(color),
			glow = 10,
		})
	end
end

-- expanding ring of sparks on the floor plane
function dbl.ring(pos, radius, color)
	local n = 28
	for i = 1, n do
		local a = i / n * math.pi * 2
		core.add_particle({
			pos = {x = pos.x, y = pos.y, z = pos.z},
			velocity = {x = math.cos(a) * radius / 0.35, y = 0.2, z = math.sin(a) * radius / 0.35},
			expirationtime = 0.35,
			size = 2.5,
			texture = tint(color),
			glow = 14,
		})
	end
end

-- floating combat text -----------------------------------------------------
-- A nametag on an invisible rising entity: the only world-anchored text Luanti offers.
core.register_entity("dbl_core:float", {
	initial_properties = {
		visual = "sprite",
		textures = {"dbl_blank.png"},
		visual_size = {x = 0.01, y = 0.01},
		physical = false,
		pointable = false,
		static_save = false,
		collisionbox = {0, 0, 0, 0, 0, 0},
	},
	on_activate = function(self)
		self.age = 0
		self.object:set_velocity({x = 0, y = 1.6, z = 0})
	end,
	on_step = function(self, dtime)
		self.age = self.age + dtime
		if self.age > 1.0 then self.object:remove() end
	end,
})

function dbl.float_text(pos, text, color)
	local o = core.add_entity({x = pos.x + dbl.rnd(-0.25, 0.25), y = pos.y, z = pos.z + dbl.rnd(-0.25, 0.25)}, "dbl_core:float")
	if o then
		o:set_properties({nametag = text, nametag_color = color or "#ffffff", nametag_bgcolor = "#00000000"})
	end
end

-- message log (per player, shown by the HUD) ---------------------------------
function dbl.log(player, text, color)
	local st = player and dbl.players[player:get_player_name()]
	if not st then return end
	table.insert(st.log, {text = text, color = color or "#e8dcc0", t = 0})
	while #st.log > 6 do table.remove(st.log, 1) end
	st.log_dirty = true
end

function dbl.log_all(text, color)
	for _, p in ipairs(core.get_connected_players()) do dbl.log(p, text, color) end
end
