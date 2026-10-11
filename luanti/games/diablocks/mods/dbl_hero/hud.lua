-- HUD: stats, gear, hp bar, skill cooldowns, message log. Elements are only re-sent when they change.
local H = dbl.hero

local function num(color) return tonumber(color:sub(2), 16) or 0xffffff end

local function add_text(player, st, key, def)
	def.type = "text"
	def.text = def.text or ""
	def.number = num(def.color or "#e8dcc0")
	def.color = nil
	def.z_index = def.z_index or 100
	def.alignment = def.alignment or {x = -1, y = 0}
	st.hud[key] = player:hud_add(def)
end

local function set(player, st, key, field, value)
	local ck = key .. "." .. field
	if st.hud_cache[ck] ~= value then
		st.hud_cache[ck] = value
		player:hud_change(st.hud[key], field, value)
	end
end
local function set_text(player, st, key, text, color)
	set(player, st, key, "text", text)
	if color then set(player, st, key, "number", num(color)) end
end

local GOLD = "#c8a24a"

function H.build_hud(player, st)
	-- top left: hero panel
	add_text(player, st, "title", {position = {x = 0, y = 0}, offset = {x = 20, y = 20}, text = "ORAN THE WARRIOR", color = GOLD, size = {x = 2, y = 0}})
	add_text(player, st, "stats", {position = {x = 0, y = 0}, offset = {x = 20, y = 58}, alignment = {x = -1, y = -1}})
	add_text(player, st, "zone", {position = {x = 0.5, y = 0}, offset = {x = 0, y = 24}, alignment = {x = 0, y = 0}, color = "#9be37a", size = {x = 2, y = 0}})
	-- top right: gear
	for i = 1, 3 do
		local y = 20 + (i - 1) * 66
		st.hud["gicon" .. i] = player:hud_add({type = "image", position = {x = 1, y = 0}, offset = {x = -380, y = y},
			alignment = {x = -1, y = -1}, text = "dbl_blank.png", scale = {x = 3.5, y = 3.5}, z_index = 100})
		add_text(player, st, "gname" .. i, {position = {x = 1, y = 0}, offset = {x = -318, y = y + 6}, alignment = {x = -1, y = -1}})
		add_text(player, st, "gstat" .. i, {position = {x = 1, y = 0}, offset = {x = -318, y = y + 30}, alignment = {x = -1, y = -1}, color = "#9a8f78"})
	end
	-- bottom centre: hp bar + skills
	st.hud.hpbg = player:hud_add({type = "image", position = {x = 0.5, y = 1}, offset = {x = 0, y = -110}, alignment = {x = 0, y = 0},
		text = "[fill:1x1:0,0:#2f2029", scale = {x = 324, y = 20}, z_index = 98})
	st.hud.hpfg = player:hud_add({type = "image", position = {x = 0.5, y = 1}, offset = {x = -160, y = -110}, alignment = {x = -1, y = 0},
		text = "[fill:1x1:0,0:#c0392b", scale = {x = 320, y = 16}, z_index = 99})
	add_text(player, st, "hptext", {position = {x = 0.5, y = 1}, offset = {x = 0, y = -110}, alignment = {x = 0, y = 0}, color = "#ffffff", z_index = 101})
	add_text(player, st, "skills", {position = {x = 0.5, y = 1}, offset = {x = 0, y = -138}, alignment = {x = 0, y = 0}})
	-- bottom right: resources
	add_text(player, st, "res", {position = {x = 1, y = 1}, offset = {x = -20, y = -20}, alignment = {x = 1, y = 1}, size = {x = 2, y = 0}, color = "#e0b440"})
	-- bottom left: log
	for i = 1, 6 do
		add_text(player, st, "log" .. i, {position = {x = 0, y = 1}, offset = {x = 20, y = -120 - (6 - i) * 22}, alignment = {x = -1, y = 0}})
	end
	-- centre: death + help
	add_text(player, st, "center", {position = {x = 0.5, y = 0.4}, offset = {x = 0, y = 0}, alignment = {x = 0, y = 0}, color = "#ff5252", size = {x = 4, y = 0}})
	add_text(player, st, "help", {position = {x = 0.5, y = 0.68}, offset = {x = 0, y = 0}, alignment = {x = 0, y = 0}, color = "#d8ccb0"})
end

local function cd_text(label, key, t, total)
	if t > 0 then return string.format("%s %s %.1fs", key, label, t) end
	return string.format("%s %s READY", key, label)
end

local HELP = "WASD move | mouse: turn camera / aim nearer-farther | LMB attack or dig | RMB fire or place\n" ..
	"Space Psionic Blast | E Firebolt | Shift Scroll of Upgrade (5 gold) | 1 sword  2 pickaxe  3 barricades"

local ZONE_COLOR = {"#9be37a", "#d9b873", "#b0b0c0", "#8fb7ff", "#ff6a4a"}

function H.sync_inv(player, st)
	local inv = player:get_inventory()
	local w = ItemStack("dbl_hero:weapon")
	local meta = w:get_meta()
	local it = st.eq.weapon
	if it then
		meta:set_string("inventory_image", it.tex)
		meta:set_string("description", dbl.item_label(it) .. "\n" .. dbl.item_stats(it))
	end
	inv:set_stack("main", 1, w)
	inv:set_stack("main", 2, ItemStack("dbl_hero:pickaxe"))
	inv:set_stack("main", 3, st.blocks > 0 and ItemStack("dbl_dungeon:barricade " .. math.min(st.blocks, 9999)) or ItemStack(""))
	st.sync_inv = false
end

function H.update_hud(player, st, hp)
	local S = st.stats
	set_text(player, st, "stats", string.format("Level %d  (%d/%d xp)\nDamage %d  Armor %d\nCrit %d%%  Haste %d%%  Steal %d%%\nKills %d",
		st.lvl, st.xp, st.lvl * 40, math.floor(S.dmg + 0.5), S.armor, S.crit, S.haste, S.vamp, st.kills))
	local zi = hp and dbl.dungeon.zone_at(hp.x, hp.z) or 1
	set_text(player, st, "zone", dbl.zones[zi].name, ZONE_COLOR[zi])
	for i, slot in ipairs({"weapon", "armor", "charm"}) do
		local it = st.eq[slot]
		if it then
			set(player, st, "gicon" .. i, "text", it.tex)
			set_text(player, st, "gname" .. i, dbl.item_label(it), dbl.RAR[it.rar].color)
			set_text(player, st, "gstat" .. i, dbl.item_stats(it))
		else
			set(player, st, "gicon" .. i, "text", "dbl_blank.png")
			set_text(player, st, "gname" .. i, "- empty " .. slot .. " -", "#6f6858")
			set_text(player, st, "gstat" .. i, "")
		end
	end
	local frac = math.max(0, math.min(1, st.hp / st.max_hp))
	set(player, st, "hpfg", "scale", {x = 320 * frac, y = 16})
	set_text(player, st, "hptext", string.format("%d / %d", math.ceil(math.max(0, st.hp)), st.max_hp))
	set_text(player, st, "skills", cd_text("Psionic Blast", "[Space]", st.cd.nova) .. "     " ..
		cd_text("Firebolt", "[E / RMB]", st.cd.fire))
	set_text(player, st, "res", string.format("Gold %d   Barricades %d", st.gold, st.blocks))
	for i = 1, 6 do
		local l = st.log[#st.log - 6 + i]
		set_text(player, st, "log" .. i, l and l.text or "", l and l.color or "#e8dcc0")
	end
	set_text(player, st, "center", (not dbl.heroes[player:get_player_name()] and st.dead_t > 0) and "YOU DIED" or "")
	set_text(player, st, "help", st.age < 25 and HELP or "")
end
