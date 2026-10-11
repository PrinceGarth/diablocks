-- Loot: rarity, affixes, ground drops, equip-or-salvage.
local rnd, pick = dbl.rnd, dbl.pick

dbl.RAR = {
	{name = "Common",    color = "#cfcfcf", m = 1,    aff = 0, plus = 0},
	{name = "Magic",     color = "#6c8cff", m = 1.25, aff = 1, plus = 1},
	{name = "Rare",      color = "#ffd23f", m = 1.6,  aff = 2, plus = 2},
	{name = "Legendary", color = "#ff7a1a", m = 2.2,  aff = 3, plus = 3},
}

dbl.AFF = {
	crit  = {label = function(v) return "+" .. v .. "% crit" end,       roll = function(l) return math.floor(3 + math.random() * 5 + l * 0.3 + 0.5) end},
	life  = {label = function(v) return "+" .. v .. " life" end,        roll = function(l) return math.floor(10 + math.random() * 10 + l * 4 + 0.5) end},
	haste = {label = function(v) return "+" .. v .. "% haste" end,      roll = function(l) return math.floor(4 + math.random() * 6 + l * 0.4 + 0.5) end},
	vamp  = {label = function(v) return "+" .. v .. "% life steal" end, roll = function(l) return math.floor(2 + math.random() * 3 + l * 0.2 + 0.5) end},
}
local AFF_KEYS = {"crit", "life", "haste", "vamp"}

local T = function(n) return "voxeldungeon_tool_" .. n .. ".png" end
local I = function(n) return "voxeldungeon_item_" .. n .. ".png" end

local BASES = {
	weapon = {
		{"Dagger", T"weapon_dagger"}, {"Shortsword", T"weapon_shortsword"}, {"Handaxe", T"weapon_handaxe"},
		{"Mace", T"weapon_mace"}, {"Spear", T"weapon_spear"}, {"Longsword", T"weapon_longsword"},
		{"Battle Axe", T"weapon_battleaxe"}, {"Warhammer", T"weapon_warhammer"}, {"Glaive", T"weapon_glaive"},
		{"Scimitar", T"weapon_scimitar"}, {"Quarterstaff", T"weapon_quarterstaff"},
	},
	armor = {
		-- by rarity index
		{{"Cloth Armor", T"armor_cloth"}, {"Leather Armor", T"armor_leather"}, {"Cactus Armor", T"armor_cactus"}},
		{{"Mail Armor", T"armor_mail"}, {"Scale Armor", T"armor_scale"}, {"Steel Armor", T"armor_steel"}},
		{{"Plate Armor", T"armor_plate"}, {"Diamond Armor", T"armor_diamond"}},
		{{"Demonite Armor", T"armor_demonite"}, {"Mese Armor", T"armor_mese"}},
	},
	charm = {
		{"Ankh", I"ankh"}, {"Dewdrop", I"dew"}, {"Honeypot", I"honeypot"}, {"Dew Vial", I"dewvial"}, {"Torch", I"torch"},
	},
}
local LEGENDARY = {
	weapon = {{"Oran's Edge", T"weapon_sword"}, {"Yog's Wrath", T"weapon_battleaxe"}, {"Demonite Blade", T"weapon_sword_demonite"}},
	armor = {{"Demonite Aegis", T"armor_demonite"}, {"Mese Bulwark", T"armor_mese"}},
	charm = {{"Blessed Ankh", I"ankh_blessed"}, {"Demonite Shard", I"demonite_lump"}},
}
local PRE = {{"Rusty", "Worn", "Crude"}, {"Sturdy", "Fine", "Mossy"}, {"Ancient", "Runed", "Gnoll-forged"}}

function dbl.item_label(it)
	return it.name .. ((it.plus or 0) > 0 and (" +" .. it.plus) or "")
end

function dbl.item_stats(it)
	local parts = {}
	if it.dmg then parts[#parts + 1] = it.dmg .. " dmg" end
	if it.armor then parts[#parts + 1] = it.armor .. " armor" end
	for _, k in ipairs(AFF_KEYS) do
		if it.aff[k] then parts[#parts + 1] = dbl.AFF[k].label(it.aff[k]) end
	end
	return dbl.RAR[it.rar].name .. " | " .. table.concat(parts, " | ")
end

function dbl.item_score(it)
	if not it then return 0 end
	local s = it.dmg or it.armor or 0
	for _, v in pairs(it.aff) do s = s + v end
	return s
end

function dbl.roll_item(lvl)
	local r = math.random()
	local ri = r < 0.02 and 4 or r < 0.12 and 3 or r < 0.40 and 2 or 1
	local R = dbl.RAR[ri]
	local slot = pick({"weapon", "weapon", "armor", "charm"})
	local it = {slot = slot, rar = ri, lvl = lvl, aff = {}, plus = R.plus}
	local jitter = 0.9 + math.random() * 0.2
	if slot == "weapon" then it.dmg = math.floor((5 + lvl * 2.2) * R.m * jitter + 0.5) end
	if slot == "armor" then it.armor = math.floor((3 + lvl * 1.6) * R.m * jitter + 0.5) end
	local keys = table.copy(AFF_KEYS)
	for i = #keys, 2, -1 do local j = math.random(i); keys[i], keys[j] = keys[j], keys[i] end
	local n = R.aff + (slot == "charm" and 1 or 0)
	for i = 1, math.min(n, #keys) do it.aff[keys[i]] = dbl.AFF[keys[i]].roll(lvl) end
	local base
	if ri == 4 then
		base = pick(LEGENDARY[slot]); it.name = base[1]
	elseif slot == "armor" then
		base = pick(dbl.BASES_ARMOR[ri]); it.name = base[1]
		if ri > 1 then it.name = pick(PRE[ri - 1]) .. " " .. it.name end
	else
		base = pick(BASES[slot]); it.name = (ri > 1 and (pick(PRE[ri - 1]) .. " ") or "") .. base[1]
	end
	it.tex = base[2]
	return it
end
dbl.BASES_ARMOR = BASES.armor

-- ground drops -----------------------------------------------------------------
dbl.drops = {}

core.register_entity("dbl_items:drop", {
	initial_properties = {
		visual = "sprite",
		textures = {"dbl_blank.png"},
		visual_size = {x = 0.9, y = 0.9},
		physical = false,
		pointable = false,
		static_save = false,
		glow = 14,
		collisionbox = {0, 0, 0, 0, 0, 0},
	},
	on_activate = function(self, staticdata)
		local it = core.deserialize(staticdata)
		if not it then self.object:remove() return end
		self.item, self.t, self.beam = it, math.random() * 6, 0
		local R = dbl.RAR[it.rar]
		self.object:set_properties({
			textures = {it.tex},
			nametag = dbl.item_label(it),
			nametag_color = R.color,
			nametag_bgcolor = "#00000088",
		})
		self.base = self.object:get_pos()
		dbl.drops[self] = true
	end,
	on_deactivate = function(self) dbl.drops[self] = nil end,
	on_step = function(self, dtime)
		self.t = self.t + dtime
		local b = self.base
		if not b then return end
		self.object:set_pos({x = b.x, y = b.y + math.sin(self.t * 3) * 0.1, z = b.z})
		if self.item.rar >= 3 then
			self.beam = self.beam - dtime
			if self.beam <= 0 then
				self.beam = 0.12
				core.add_particle({
					pos = {x = b.x, y = b.y + 0.3, z = b.z}, velocity = {x = 0, y = 4, z = 0},
					expirationtime = 0.7, size = self.item.rar == 4 and 2.2 or 1.4, glow = 14,
					texture = "dbl_pixel.png^[colorize:" .. dbl.RAR[self.item.rar].color .. ":255",
				})
			end
		end
	end,
})

function dbl.drop_item(pos, item)
	local o = core.add_entity({x = pos.x, y = dbl.FLOOR + 0.55, z = pos.z}, "dbl_items:drop", core.serialize(item))
	if item.rar >= 3 then
		dbl.log_all(string.format("%s drop: %s", dbl.RAR[item.rar].name, dbl.item_label(item)), dbl.RAR[item.rar].color)
	end
	return o
end

-- pickup / equip ---------------------------------------------------------------
function dbl.pickup(player, st, self)
	local it = self.item
	local R = dbl.RAR[it.rar]
	if dbl.item_score(it) > dbl.item_score(st.eq[it.slot]) then
		st.eq[it.slot] = it
		dbl.recompute(st)
		dbl.log(player, "Equipped " .. dbl.item_label(it), R.color)
	else
		local g = 1 + it.rar
		st.gold = st.gold + g
		dbl.log(player, string.format("Salvaged %s -> %d gold", dbl.item_label(it), g), R.color)
	end
	dbl.drops[self] = nil
	self.object:remove()
end

core.register_globalstep(function()
	for name, hero in pairs(dbl.heroes) do
		local pos = hero.object:get_pos()
		local st = dbl.players[name]
		local player = core.get_player_by_name(name)
		if pos and st and player then
			for drop in pairs(dbl.drops) do
				local dp = drop.base
				if dp and dbl.hdist(dp, pos) < 1.3 then dbl.pickup(player, st, drop) end
			end
		end
	end
end)
