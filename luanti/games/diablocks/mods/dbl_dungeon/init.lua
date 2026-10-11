-- Nodes + level generator. One flat floor (y = 0), walls one node high (y = 1),
-- five zones going outward from the entrance room: the five Pixel Dungeon regions.
local rnd, pick = dbl.rnd, dbl.pick

dbl.zones = {
	{id = "sewers",  name = "Sewers"},
	{id = "prisons", name = "Prison"},
	{id = "caves",   name = "Caves"},
	{id = "cities",  name = "Dwarven City"},
	{id = "halls",   name = "Demon Halls"},
}

local function tex(kind, id) return "voxeldungeon_tiles_" .. id .. "_" .. kind .. ".png" end

for i, z in ipairs(dbl.zones) do
	local wall, stone = tex("wall", z.id), tex("stone", z.id)
	core.register_node("dbl_dungeon:floor" .. i, {
		description = z.name .. " floor",
		tiles = {tex("floor", z.id)},
		is_ground_content = false,
	})
	core.register_node("dbl_dungeon:moss" .. i, {
		description = z.name .. " mossy floor",
		tiles = {tex("floor", z.id) .. "^voxeldungeon_tiles_sewers_grass.png"},
		is_ground_content = false,
	})
	core.register_node("dbl_dungeon:wall" .. i, {
		description = z.name .. " wall",
		tiles = {stone, stone, wall},
		groups = {dbl_dig = 1},
		is_ground_content = false,
	})
	core.register_node("dbl_dungeon:ore" .. i, {
		description = z.name .. " gold vein",
		tiles = {"voxeldungeon_ore_" .. z.id .. "_gold.png"},
		groups = {dbl_dig = 1, dbl_ore = 1},
		is_ground_content = false,
	})
	core.register_node("dbl_dungeon:torch" .. i, {
		description = z.name .. " torch wall",
		tiles = {stone, stone, wall .. "^voxeldungeon_item_torch.png"},
		light_source = 13,
		groups = {dbl_dig = 1},
		is_ground_content = false,
	})
end

core.register_node("dbl_dungeon:puddle", {
	description = "Sewer puddle",
	tiles = {"voxeldungeon_tiles_sewers_floor.png^[lowpart:60:voxeldungeon_tiles_sewers_water.png"},
	is_ground_content = false,
})
core.register_node("dbl_dungeon:bedrock", {
	description = "Dungeon edge",
	tiles = {"voxeldungeon_tiles_halls_stone.png^[colorize:#000000:140"},
	is_ground_content = false,
})
-- what the Barricade slot places
core.register_node("dbl_dungeon:barricade", {
	description = "Barricade",
	tiles = {"voxeldungeon_tiles_sewers_stone.png", "voxeldungeon_tiles_sewers_stone.png", "voxeldungeon_tiles_sewers_door.png"},
	inventory_image = "voxeldungeon_tiles_sewers_door.png",
	groups = {dbl_dig = 1, dbl_placed = 1},
	range = 0,
	on_drop = function(stack) return stack end,
})

-- layout --------------------------------------------------------------------
local GRID, CELL = 9, 13
local HALF = math.floor(GRID * CELL / 2) -- 58: playable area is [-58, 58]
local PAD = 4                             -- bedrock margin around it

local D = {tiles = {}, rooms = {}, half = HALF}
dbl.dungeon = D

-- tile kinds: nil/"border" = outside, "rock", "floor", "moss", "puddle"
local function tget(x, z)
	local col = D.tiles[x]
	return col and col[z]
end
local function tset(x, z, v)
	if x < -HALF or x > HALF or z < -HALF or z > HALF then return end
	local col = D.tiles[x]
	if not col then col = {}; D.tiles[x] = col end
	col[z] = v
end

function D.is_floor(x, z)
	local t = tget(math.floor(x + 0.5), math.floor(z + 0.5))
	return t ~= nil and t ~= "rock"
end

-- zone index 1..5 from distance to the entrance: concentric square bands
function D.zone_at(x, z)
	local r = math.max(math.abs(x), math.abs(z)) / CELL
	return math.min(#dbl.zones, math.floor(r + 0.5) + 1)
end

local function carve_rect(x1, z1, x2, z2)
	for x = x1, x2 do for z = z1, z2 do tset(x, z, "floor") end end
end

local function carve_corridor(ax, az, bx, bz)
	-- L-shaped, three tiles wide
	local x1, x2 = math.min(ax, bx), math.max(ax, bx)
	local z1, z2 = math.min(az, bz), math.max(az, bz)
	carve_rect(x1 - 1, az - 1, x2 + 1, az + 1)
	carve_rect(bx - 1, z1 - 1, bx + 1, z2 + 1)
end

function D.generate_layout()
	D.tiles, D.rooms = {}, {}
	for x = -HALF, HALF do
		D.tiles[x] = {}
		for z = -HALF, HALF do D.tiles[x][z] = "rock" end
	end
	local cells = {}
	local mid = (GRID - 1) / 2
	for i = 0, GRID - 1 do
		cells[i] = {}
		for j = 0, GRID - 1 do
			local ox, oz = -HALF + i * CELL, -HALF + j * CELL
			local w, h = math.random(5, 9), math.random(5, 9)
			local x1 = ox + math.random(2, CELL - 1 - w)
			local z1 = oz + math.random(2, CELL - 1 - h)
			if i == mid and j == mid then -- entrance room: big and centred on the origin
				w, h = 9, 9
				x1, z1 = -4, -4
			end
			local r = {x1 = x1, z1 = z1, x2 = x1 + w - 1, z2 = z1 + h - 1, i = i, j = j,
				cx = x1 + math.floor(w / 2), cz = z1 + math.floor(h / 2), start = (i == mid and j == mid)}
			carve_rect(r.x1, r.z1, r.x2, r.z2)
			cells[i][j] = r
			D.rooms[#D.rooms + 1] = r
		end
	end
	-- randomized DFS spanning tree, then a few extra loops
	local seen, stack, edges = {}, {{0, 0}}, {}
	seen["0,0"] = true
	local dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
	while #stack > 0 do
		local cur = stack[#stack]
		local opts = {}
		for _, d in ipairs(dirs) do
			local ni, nj = cur[1] + d[1], cur[2] + d[2]
			if ni >= 0 and nj >= 0 and ni < GRID and nj < GRID and not seen[ni .. "," .. nj] then
				opts[#opts + 1] = {ni, nj}
			end
		end
		if #opts == 0 then
			stack[#stack] = nil
		else
			local n = pick(opts)
			seen[n[1] .. "," .. n[2]] = true
			edges[#edges + 1] = {cells[cur[1]][cur[2]], cells[n[1]][n[2]]}
			stack[#stack + 1] = n
		end
	end
	for i = 0, GRID - 1 do for j = 0, GRID - 1 do
		if i + 1 < GRID and math.random() < 0.2 then edges[#edges + 1] = {cells[i][j], cells[i + 1][j]} end
		if j + 1 < GRID and math.random() < 0.2 then edges[#edges + 1] = {cells[i][j], cells[i][j + 1]} end
	end end
	for _, e in ipairs(edges) do carve_corridor(e[1].cx, e[1].cz, e[2].cx, e[2].cz) end

	-- decoration: pillars in big rooms, moss everywhere, puddles in the sewers
	for _, r in ipairs(D.rooms) do
		if not r.start and (r.x2 - r.x1) >= 7 and (r.z2 - r.z1) >= 7 and math.random() < 0.6 then
			for _, p in ipairs({{r.x1 + 2, r.z1 + 2}, {r.x2 - 2, r.z1 + 2}, {r.x1 + 2, r.z2 - 2}, {r.x2 - 2, r.z2 - 2}}) do
				tset(p[1], p[2], "rock")
			end
		end
	end
	for x = -HALF, HALF do for z = -HALF, HALF do
		if D.tiles[x][z] == "floor" then
			local v = math.random()
			if v < 0.07 then D.tiles[x][z] = "moss"
			elseif v < 0.11 and D.zone_at(x, z) <= 2 then D.tiles[x][z] = "puddle" end
		end
	end end
	D.start_pos = {x = 0, y = dbl.FLOOR + 0.9, z = 0}
end

-- carve the layout into the map with a VoxelManip -----------------------------
local function write_world()
	local pmin, pmax = {x = -HALF - PAD, y = -1, z = -HALF - PAD}, {x = HALF + PAD, y = 3, z = HALF + PAD}
	local vm = VoxelManip()
	local emin, emax = vm:read_from_map(pmin, pmax)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local c = {}
	local function id(name) return core.get_content_id(name) end
	local AIR, BED = core.CONTENT_AIR, id("dbl_dungeon:bedrock")
	local PUD = id("dbl_dungeon:puddle")
	for i = 1, #dbl.zones do
		c[i] = {floor = id("dbl_dungeon:floor" .. i), moss = id("dbl_dungeon:moss" .. i), wall = id("dbl_dungeon:wall" .. i),
			ore = id("dbl_dungeon:ore" .. i), torch = id("dbl_dungeon:torch" .. i)}
	end
	for z = pmin.z, pmax.z do for x = pmin.x, pmax.x do
		local t = tget(x, z)
		local zn = D.zone_at(math.max(-HALF, math.min(HALF, x)), math.max(-HALF, math.min(HALF, z)))
		local cz = c[zn]
		local f, w1, w2 = BED, BED, BED
		if t == nil then
			f, w1, w2 = BED, BED, BED
		elseif t == "rock" then
			f, w1, w2 = cz.floor, cz.wall, AIR
			if math.random() < 0.08 then w1 = cz.ore end
		else
			f = (t == "moss" and cz.moss) or (t == "puddle" and PUD) or cz.floor
			w1, w2 = AIR, AIR
		end
		data[area:index(x, -1, z)] = BED
		data[area:index(x, 0, z)] = f
		data[area:index(x, 1, z)] = w1
		data[area:index(x, 2, z)] = w2
		data[area:index(x, 3, z)] = AIR
	end end
	-- wall torches on room edges
	for _, r in ipairs(D.rooms) do
		local zn = c[D.zone_at(r.cx, r.cz)]
		local function torch(x, z)
			if tget(x, z) == "rock" then data[area:index(x, 1, z)] = zn.torch end
		end
		for _, x in ipairs({r.x1 + 1, r.cx, r.x2 - 1}) do torch(x, r.z1 - 1); torch(x, r.z2 + 1) end
		for _, z in ipairs({r.z1 + 1, r.cz, r.z2 - 1}) do torch(r.x1 - 1, z); torch(r.x2 + 1, z) end
	end
	vm:set_data(data)
	vm:write_to_map(true) -- true: let the engine relight the changed area
end

-- blow holes in the diggable layer (y >= 1); the floor and the dungeon edge survive
function dbl.explode(pos, r)
	local round = function(v) return math.floor(v + 0.5) end
	for x = round(pos.x - r), round(pos.x + r) do
		for y = math.max(1, round(pos.y - r)), math.min(2, round(pos.y + r)) do
			for z = round(pos.z - r), round(pos.z + r) do
				if (x - pos.x) ^ 2 + (y - pos.y) ^ 2 + (z - pos.z) ^ 2 <= r * r then
					local p = {x = x, y = y, z = z}
					if core.get_item_group(core.get_node(p).name, "dbl_dig") > 0 then
						core.remove_node(p)
						if math.random() < 0.25 then dbl.burst(p, "#8b7355", 1) end
					end
				end
			end
		end
	end
	dbl.burst(pos, "#ff9a2a", 14)
end

-- emerge the area once, then carve ------------------------------------------------
local started = false
local function start_generation()
	if started then return end
	started = true
	D.generate_layout()
	core.log("action", "[diablocks] emerging dungeon area...")
	core.emerge_area({x = -HALF - 16, y = -16, z = -HALF - 16}, {x = HALF + 16, y = 16, z = HALF + 16},
		function(_, _, remaining)
			if remaining > 0 then return end
			write_world()
			core.log("action", "[diablocks] dungeon carved")
			dbl.set_ready()
		end)
end
core.register_on_joinplayer(function() start_generation() end)
core.after(1, start_generation)

-- Dedicated servers and the singleplayer menu both run this too, so a headless smoke
-- test can see the generator work without a client.
