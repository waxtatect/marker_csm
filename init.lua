--[[
marker: CSM for Minetest to create and save markers
Copyright (C) 2021 мтест

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
--]]

marker = {tp_cmd = nil}

local marker_storage, string_to_pos, display_chat_message, colorize, ESC = minetest.get_mod_storage(), minetest.string_to_pos, minetest.display_chat_message, minetest.colorize, minetest.formspec_escape
local marker_datas = {prefix = colorize("red", "[marker]"), current_list = "Star", list = {}, tp = {command = "teleport", on = false}}
local hud = {colour = 0x8B008B, t = false, id = nil, uid = nil, ids = {}, s = {}}
local fs = {list = {}, marker_list = {}, selected_marker = {}, datas_amended = nil, show_hud = false, show_preview = false}
local limit = {list = {n = 16, length = 20}, marker = {n = 100, length = 50}}
local hexcolour = {black = 0x000000, blue = 0x0000FF, cyan = 0x00FFFF, gray = 0x808080, green = 0x008000, lime = 0x00FF00, magenta = 0xFF00FF, maroon = 0x800000, navy = 0x000080,
	olive = 0x808000, orange = 0xFFA500, purple = 0x800080, red = 0xFF0000, silver = 0xC0C0C0, teal = 0x008080,	white = 0xFFFFFF, yellow = 0xFFFF00}
local init, mt5, fs_style = false, true, ""
if minetest.get_server_info().protocol_version < 37 then mt5, fs_style = false, "bgcolor[#080808BB;true]background[5,5;1,1;gui_formbg.png;true]listcolors[#00000069;#5A5A5A;#141318;#30434C;#FFF]" end

local function run_server_chatcommand(cmd, param) minetest.send_chat_message(("/%s %s"):format(cmd, param)) end

local function format_msg(msg) return ("%s %s"):format(marker_datas.prefix, msg) end
local function format_msg1(msg, param) return ("%s %s %s"):format(marker_datas.prefix, msg, param) end

local function pos_to_string(pos) return ("%s, %s, %s"):format(pos.x, pos.y, pos.z) end

local function op_t(yes, t, not_t) return yes and t or not_t end

local function get_storage(name) return minetest.deserialize(marker_storage:get_string(name)) or {} end

local function set_storage(name, data)
	if type(data) == "table" then data = minetest.serialize(data) end
	return marker_storage:set_string(name, data)
end

if not init then
	fs.list = get_storage("list")
	if #fs.list > 1 then marker_datas.current_list = fs.list[1]
	else
		fs.list = {"Star", "Star"}; set_storage("list", fs.list)
	end
	marker_datas.list = get_storage(marker_datas.current_list); init = true
end

local function set_hud_pos(name, pos, colour)
	if not name or not type(pos) == "table" or colour == "" then return false, format_msg("Error setting the HUD.") end
	local localplayer = minetest.localplayer
	if hud.id then
		localplayer:hud_change(hud.id, 'name', name)
		localplayer:hud_change(hud.id, 'number', colour)
		localplayer:hud_change(hud.id, 'world_pos', pos)
	else
		hud.id = localplayer:hud_add({
			hud_elem_type = 'waypoint',
			name		  = name,
			text		  = 'm',
			number		  = colour,
			world_pos	  = pos
		})
	end
	local pos_name = string_to_pos(name)
	return true, (pos_name and vector.equals(pos_name, pos)) and
		format_msg1("Marker set at: ", name) or ("%s Marker set to %s at: %s"):format(marker_datas.prefix, name, pos_to_string(pos))
end

local function display_marker(name, pos, colour, origin)
	local msg = nil
	if mt5 then
		local localplayer, b, hud_b = minetest.localplayer, false, true
		if hud.uid then
			hud.id = hud.uid; local hud_def = localplayer:hud_get(hud.id)
			if hud_def.name == name and (hud_def.number == colour or origin ~= "go") and vector.equals(hud_def.world_pos, pos) then
				localplayer:hud_remove(hud.id); hud.uid, hud.id, hud_b = nil, nil, false
			end
		end
		if hud_b and (origin ~= "go" or not marker_datas.tp.on) then
			b, msg = set_hud_pos(name, pos, colour)
			if not b then return false, format_msg("Usage: .go name [colour]|x,y,z [colour]") end
			hud.uid, hud.id = hud.id, nil
		end
	elseif origin ~= "go" or not marker_datas.tp.on then run_server_chatcommand("mrkr", pos_to_string(pos)) end
	return true, msg
end

local function value_limit(value, n, length)
	local b = false
	if n >= limit[value].n then
		b = true; display_chat_message(("%s Number of %s max(%s) reached."):format(marker_datas.prefix, value, limit[value].n))
	elseif length > limit[value].length then
		b = true; display_chat_message(("%s Please choose a shorter name(up to %s characters)."):format(marker_datas.prefix, limit[value].length))
	end
	return b
end

local function set_marker(name, pos)
	if name == nil or pos == nil then return false
	else
		marker_datas.list = get_storage(marker_datas.current_list); marker_datas.list[name] = {pos}; set_storage(marker_datas.current_list, marker_datas.list)
	end
	return true, format_msg(colorize("#00ff00", ("Marker set for: %s @ %s"):format(name, pos)))
end

local function delete_marker(name)
	marker_datas.list = get_storage(marker_datas.current_list)
	if marker_datas.list[name] then
		marker_datas.list[name] = nil; set_storage(marker_datas.current_list, marker_datas.list)
		if next(marker_datas.list) == nil then set_storage(marker_datas.current_list, "") end
	else return false end
	return true, format_msg(colorize("#00ff00", ("%s was successfully removed"):format(name)))
end

local function rename_marker(oldname, newname)
	marker_datas.list = get_storage(marker_datas.current_list)
	local pos = ""; if marker_datas.list[oldname] then pos = marker_datas.list[oldname][1] end
	if pos == "" or oldname == newname then return false end
	if marker_datas.list[newname] then return false, ("%s Marker: %s is already in use!"):format(marker_datas.prefix, newname) end
	if not set_marker(newname, pos) or not delete_marker(oldname) then return false end
	return true, format_msg(colorize("#00ff00", ("%s renamed to %s"):format(oldname, newname)))
end

local function format_list(list, include_hud)
	local list_data = {}
	for name, datas in pairs(list) do
		local pos = string_to_pos(datas[1])
		local distance = math.floor(vector.distance(minetest.localplayer:get_pos(), pos))
		table.insert(list_data, {name = name, distance = distance, coordinate = {x = pos.x, y = pos.y, z = pos.z}, hud = op_t(include_hud, datas[2], "")})
	end
	return list_data
end

local function sort_list(list, p)
	if p == "d-" or p == "d" then table.sort(list, function(a, b) return a.distance < b.distance end)
	elseif p == "d+" then table.sort(list, function(a, b) return a.distance > b.distance end)
	else table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end) end
	return list
end

local function update_lists(i)
	marker_datas.current_list, fs.list[1] = fs.list[i], fs.list[i]
	marker_datas.list = get_storage(marker_datas.current_list)
	fs.marker_list = sort_list(format_list(marker_datas.list))
end

local function pad(str, length, pattern)
	local str_padded = ""
	if #str >= length or str == nil then str_padded = str or str_padded
	else str_padded = ("%s%s"):format(str, (pattern or " "):rep(length - #str)) end
	return str_padded
end

local function get_marker(param)
	if param == "" then return false end; local pos_string = ""
	local pos = param:match("^[%d.-]+[, ] *[%d.-]+[, ] *[%d.-]+") or ""; pos = pos:gsub(", ", ",")
	if mt5 then
		local colour = param:match("%a%a%a+$") or ""; local pname = ""
		if hexcolour[colour] == nil and param:match("^[%d.-]+[, ] *[%d.-]+[, ] *[%d.-]+$") == nil then colour = param:match(" (%x+)$") or "" end
		if pos ~= "" then if colour == "" then pname = " " .. pos else pname = " " .. pos .. " " .. colour end end
		local name = param:gsub(pname .. "$", ""); if marker_datas.list[name] then pos_string = marker_datas.list[param][1] end
		if pos_string == "" then
			if marker_datas.list[(param:gsub(" " .. colour .. "$", ""))] == nil then
				if pos ~= "" then name = pos:gsub(",", ", "); pos = vector.round(string_to_pos(pos))
				else return false, ("%s HUD: %s doesn't exist."):format(marker_datas.prefix, name) end
			else
				name = param:gsub(" " .. colour .. "$", ""); pos = string_to_pos(marker_datas.list[name][1])
			end
		else
			if name == param then colour = "" end; pos = string_to_pos(pos_string)
		end
		if hexcolour[colour] then colour = hexcolour[colour]
		elseif colour ~= "" then if colour:match("[A-F]+") or colour:match("[a-f]+") then colour = "0x" .. colour end colour = tonumber(colour)
		else colour = hud.colour end
		return name, pos, colour
	else
		if marker_datas.list[param] then pos_string = marker_datas.list[param][1] end
		if pos_string == "" and pos ~= "" then pos_string = pos elseif pos_string ~= "" then -- it's ok ...
		else return false, format_msg("Invalid position.") end
		return true, string_to_pos(pos_string)
	end
end

local function restore_hud()
	local localplayer, count_saved, count_all = minetest.localplayer, 0, 0
	if hud.t then
		hud.id, hud.ids = nil, {}
		for name, datas in pairs(marker_datas.list) do
			if #datas > 1 then
				if set_hud_pos(name, string_to_pos(datas[1]), tonumber("0x" .. datas[2])) then hud.ids[#hud.ids + 1] = hud.id; hud.id = nil end
			end
		end
		for _, v in ipairs(hud.s) do
			set_hud_pos(v.name, v.world_pos, v.number); hud.ids[#hud.ids + 1] = hud.id; hud.id = nil
		end
		hud.s = {}; count_saved = #hud.ids
	else
		local n = false
		for _, v in ipairs(hud.ids) do
			local hud_def = localplayer:hud_get(v)
			for name, datas in pairs(marker_datas.list) do
				if name == hud_def.name and tonumber("0x" .. datas[2]) == hud_def.number and vector.equals(string_to_pos(datas[1]), hud_def.world_pos) then
					count_saved = count_saved + 1; n = true; break
				end
			end
			if not n and (hud_def.name:match("^[%d.-]+[, ] *[%d.-]+[, ] *[%d.-]+$") or hud_def.name:match("^here[%d]?$")) then
				hud.s[#hud.s + 1] = hud_def; count_saved = count_saved + 1
			end
			localplayer:hud_remove(v); count_all = count_all + 1; n = false
		end
		hud.id, hud.ids = nil, {}
	end
	return count_saved, count_all - count_saved
end

local function delete_hud(name)
	marker_datas.list = get_storage(marker_datas.current_list)
	for sname, _ in pairs(marker_datas.list) do
		if sname == name then
			marker_datas.list[name][2] = nil
			set_storage(marker_datas.current_list, marker_datas.list)
			break
		end
	end
end

local function set_hud(name, colour)
	if colour == "" then return false end
	marker_datas.list = get_storage(marker_datas.current_list)
	for sname, _ in pairs(marker_datas.list) do
		if sname == name then
			marker_datas.list[name][2] = ("%X"):format(colour)
			set_storage(marker_datas.current_list, marker_datas.list)
			break
		end
	end
	return true
end

local function display_hud(name, pos, colour)
	if not name or pos == nil or colour == "" then return false end
	if not hud.t then hud.t = true; restore_hud() end
	local b_ids, del = false, false
	for i, v in ipairs(hud.ids) do
		local hud_def = minetest.localplayer:hud_get(v)
		if hud_def.name == name and hud_def.number == tonumber(colour) then
			minetest.localplayer:hud_remove(v); delete_hud(name)
			table.remove(hud.ids, i); hud.id = nil; del = true; break
		end
		if hud_def.name == name then hud.id = v; delete_hud(name); break end
	end
	if del then return true, ("%s HUD: %s removed."):format(marker_datas.prefix, name) end
	local b, msg = set_hud_pos(name, pos, colour); if not b then return false, msg end
	for _, v in ipairs(hud.ids) do if v == hud.id then b_ids = true; break end end; if not b_ids then hud.ids[#hud.ids + 1] = hud.id end; hud.id = nil; set_hud(name, colour)
	return true, ("%s HUD: %s set."):format(marker_datas.prefix, name)
end

local function validate_amendDatas(name, pos, hud)
	if name == nil or pos == nil or pos == "" or hud ~= nil and hud:match("^%x+$") == nil then
		return false, name, pos, hud
	end
	pos = pos:gsub(" ", ", ")
	if string_to_pos(pos) == nil then
		return false, name, pos, hud
	end
	return true, name, pos, hud
end

local function set_amendDatas(textarea_string, show_hud)
	if textarea_string == "" then fs.datas_amended = {}; return true end
	local datas_copy, datas, inc, j, count = table.copy(fs.datas_amended or {}), textarea_string:split("\n", true), op_t(show_hud, 3, 2), 1, 0; fs.datas_amended = {}
	for i = 1, #datas, inc do
		local hud_value = (show_hud and datas[i + 2] ~= "") and (hexcolour[datas[i + 2]] and ("%X"):format(hexcolour[datas[i + 2]]) or datas[i + 2]) or nil
		local b, name, pos, hud = validate_amendDatas(datas[i], datas[i + 1], hud_value)
		if b then
			if fs.datas_amended[datas[i]] then
				for k = j, limit.marker.n * 2 do
					local suffix = "#" .. k
					if fs.datas_amended[datas[i] .. suffix] == nil then
						name = name .. suffix; j = k; break
					end
				end
				display_chat_message(("%s Warning, name=\"%s\" previously defined, suffix #%s added line %s."):format(
					marker_datas.prefix, datas[i], j, i)); j = 1
			end
			fs.datas_amended[name] = {pos, hud}
		else
			count = count + 1
			if count < 6 then
				display_chat_message(("%s #%s:Error, marker line %s isn't properly defined: name=\"%s\", pos=\"%s\"%s."):format(
					marker_datas.prefix, count, i, name, pos, op_t(hud, (", hud=\"%s\""):format(hud), "")))
				local name_copy = datas_copy[name]
				if name_copy then
					display_chat_message(("%s Previous values: name=\"%s\", pos=\"%s\"%s."):format(
						marker_datas.prefix, name, name_copy[1]:gsub(",", ""), op_t(show_hud, (", hud=\"%s\""):format(name_copy[2] or ""), "")))
				end
			else
				display_chat_message(format_msg("Errors >5. List generation interrupted.")); break
			end
		end
	end
	if count > 0 then fs.datas_amended = datas_copy end; datas_copy = nil
	return op_t(count == 0, true, false)
end

local function set_amend_values(datas, hud, preview)
	fs.datas_amended, fs.show_hud, fs.show_preview = datas, hud, preview
end

local function get_formspec_dialogue(data)
	local type = data[1]:match("^(.+)_")
	local element = type == "delete" and ("label[0,0.6;%s]"):format(data[3]) or
		((type == "rename" or type == "new") and
		("field[0.25,0.85;2.5,0.6;f_%s;;%s]"):format(data[1], data[3] or "") or "")
	return ([[
		size[2.5,1.7]%slabel[0,0;%s]%s
		button[0,0.75;1.2,2;b_%s;Ok]button[1.2,0.75;1.2,2;cancel;Cancel]
	]]):format(fs_style, data[2], element, data[1])
end

local function get_tableDatas(list)
	local table_datas, id, displayed, d_b = {}, -1, "", false
	for i, datas in ipairs(list) do
		if mt5 and hud.uid and not d_b then
			local hud_def = minetest.localplayer:hud_get(hud.uid)
			if hud_def.name == datas.name and vector.equals(hud_def.world_pos, datas.coordinate) then id = i + 1; displayed = "*"; d_b = true end
		elseif not d_b and fs.selected_marker.name and fs.selected_marker.name == datas.name and
			fs.selected_marker.coordinate and vector.equals(fs.selected_marker.coordinate, datas.coordinate) then id = i + 1
		else displayed = "" end
		local colour = datas.distance < 500 and "#B22222" or (datas.distance < 1000 and "#FFFF66" or "#26e0d5")
		table_datas[i] = ("%s,%s%s,%s,%s, %s, %s"):format(colour, displayed, ESC(datas.name), datas.distance,
			ESC(datas.coordinate.x .. ","), ESC(datas.coordinate.y .. ","), datas.coordinate.z)
	end
	return table_datas, id
end

local function get_formspec_marker(list)
	local table_datas, id = get_tableDatas(list)
	local button_tp = op_t(marker_datas.tp.on, "button_exit", "button")
	return ([[
		size[6.25,7.5]%s
		image_button_exit[5.8,0;0.45,0.45;;marker_menu_close;x]tooltip[marker_menu_close;Exit]
		label[0.05,0.15;%s : %s marker%s]
		image_button[3.45,0.15;0.55,0.6;;b_N;N]image_button[3.85,0.15;0.55,0.6;;b_d;d]
		image_button[4.75,0.15;0.95,0.6;;list_menu;Edit]
		tableoptions[background=#1E1E1E]tablecolumns[color;text,padding=0.25;text,padding=0.25,align=right;text,align=right,padding=0.5;text,align=right,padding=0;text,align=right,padding=0]
		table[0,0.8;6,6;marker_table;#f2f2f2,Name,Distance,%s,%s,Z,%s;%s]
		button_exit[0.1,7.2;1.5,0.25;display_marker;Display]
		%s[1.6,7.2;1.5,0.25;teleport_marker;Teleport]
		button[3.1,7.2;1.5,0.25;rename_marker;Rename]
		button[4.6,7.2;1.5,0.25;delete_marker;Delete]
	]]):format(fs_style, fs.list[1], #list, op_t(#list > 1, "s", ""), ESC("X, "), ESC("Y, "), table.concat(table_datas, ","), id, button_tp)
end

local function get_textlistDatas(list)
	local textlist_datas, id = {}, 1
	for i = 2, #list do
		textlist_datas[i - 1] = ESC(list[i]); if list[i] == list[1] then id = i - 1 end
	end
	return textlist_datas, id
end

local function get_formspec_list(list)
	local textlist_datas, id = get_textlistDatas(list)
	return ([[
		size[4,5.3]%s
		image_button[2.65,0.07;0.55,0.6;;show_marker_menu;M]tooltip[show_marker_menu;Marker list]
		image_button_exit[3.55,0;0.45,0.45;;list_menu_close;x]tooltip[list_menu_close;Exit]
		label[0,0.07;Marker%s : %s]
		textlist[0,0.75;2,4.6;list_textlist;%s;%s]label[2.7,1.12;List%s : %s]
		image_button[2.05,2.55;0.55,0.55;;sort_up;▲]
		image_button[2.05,3.05;0.55,0.55;;sort_down;▼]
		button[2.7,2.05;1.2,0.5;new_list;New]
		button[2.7,2.95;1.2,0.5;amend_list;Amend]
		button[2.7,3.83;1.2,0.5;rename_list;Rename]
		button[2.7,4.71;1.2,0.5;delete_list;Delete]
	]]):format(fs_style, op_t(#fs.marker_list > 1, "s", ""), #fs.marker_list, table.concat(textlist_datas, ","), id, op_t(#list - 1 > 1, "s", ""), #list - 1)
end

local hexcolour_rev = {}
for colour, hex in pairs(hexcolour) do
	hexcolour_rev[("%X"):format(hex)] = colour
end

local function get_textareaDatas(list, show_hud)
	local textarea_datas, i, inc = {}, 1, op_t(show_hud, 3, 2)
	for _, datas in ipairs(list) do
		textarea_datas[i] = datas.name
		textarea_datas[i + 1] = pos_to_string(datas.coordinate):gsub(",", "")
		if show_hud then textarea_datas[i + 2] = hexcolour_rev[datas.hud] or datas.hud end
		i = i + inc
	end
	return textarea_datas, #textarea_datas / inc
end

local function get_tableDatas_preview(list, show_hud)
	local table_datas = {}
	for i, datas in ipairs(list) do
		local datas_marker = marker_datas.list[datas.name]
		local colour = datas_marker == nil and "#008000" or ((datas_marker[1] ~= pos_to_string(datas.coordinate) or show_hud and (datas_marker[2] or "") ~= datas.hud) and "#FFA500" or "#FFFFFF")
		table_datas[i] = ("#26e0d5,%s,%s,%s, %s, %s%s%s,%s,%s"):format(ESC(datas.name), datas.distance,
			ESC(datas.coordinate.x .. ","), ESC(datas.coordinate.y .. ","), datas.coordinate.z,
			show_hud and (datas.hud ~= "" and (",#%06X"):format(tonumber("0x" .. datas.hud)) or ",") or "", show_hud and (datas.hud ~= "" and ",•" or ",") or "", colour, "*")
	end
	return table_datas
end

local function get_formspec_amend(list, show_hud, show_preview)
	local list_sorted, width, fs_prev, chg_padding, width_prev = sort_list(format_list(list, show_hud)), 5.5, "", 0.75, 6.9
	local textarea_datas, count = get_textareaDatas(list_sorted, show_hud)
	if fs.datas_amended == nil then set_amendDatas(table.concat(textarea_datas, "\n"), show_hud) end
	if show_preview then
		local hud_col, hud_cell = "", ""; width = 12.55
		if show_hud then
			hud_col, hud_cell, chg_padding, width_prev, width = ";color,span=1;text,align=center,padding=0.75", ",#FFFFFF,Hud", 0.25, 7.33, 12.98
		end
		fs_prev = ([[
			tableoptions[background=#1E1E1E]tablecolumns[color,span=5;text,padding=0.25;text,padding=0.25,align=right;text,align=right,padding=0.5;text,align=right,padding=0;text,align=right,padding=0%s;color,span=1;text,align=center,padding=%s]
			table[5.5,0.8;%s,6;marker_table;#f2f2f2,Name,Distance,%s,%s,Z%s,#FFFFFF,Change,%s]
		]]):format(hud_col, chg_padding, width_prev, ESC("X, "), ESC("Y, "), hud_cell, table.concat(get_tableDatas_preview(list_sorted, show_hud), ","))
	end
	return ([[
		size[%s,7.5]%s
		label[0,0.07;%s : %s marker%s]
		textarea[0.3,0.8;5.5,7;textarea_amend;;%s]%s%s
		button[1.01,7.2;1.5,0.25;save_amend;Save]
		button[2.51,7.2;1.5,0.25;preview_amend;Preview]
		button[4.01,7.2;1.5,0.25;show_marker_menu;Back]tooltip[show_marker_menu;Marker list]
	]]):format(width, fs_style, fs.list[1], count, op_t(count > 1, "s", ""), table.concat(textarea_datas, "\n"), fs_prev,
		op_t(mt5, ("checkbox[0.05,6.88;show_hud_amend;Hud;%s]tooltip[show_hud_amend;Refresh content including Hud, using original list]"):format(show_hud), ""))
end

minetest.register_on_formspec_input(function(formname, fields)
	if fields == {} or (formname ~= "marker_menu" and formname ~= "list_menu" and formname ~= "amend_menu" and
		formname ~= "marker_teleport" and formname ~= "marker_rename" and formname ~= "marker_delete" and
		formname ~= "list_new" and formname ~= "list_rename" and formname ~= "list_delete" and
		formname ~= "amend_save") then return false end

	if formname == "marker_menu" or formname == "marker_teleport" or formname == "marker_rename" or formname == "marker_delete" then
		if #fs.marker_list > 0 and fields.marker_table and fields.marker_table ~= "INV" then
			local id = tonumber(fields.marker_table:match(":(%d+):")) - 1; fs.selected_marker = {}
			if id > 0 then fs.selected_marker.name, fs.selected_marker.coordinate = fs.marker_list[id].name, fs.marker_list[id].coordinate end
		elseif fields.list_menu then
			fs.selected_marker = {}; minetest.show_formspec("list_menu", get_formspec_list(fs.list))
		elseif #fs.marker_list > 0 and fs.selected_marker.name and fs.selected_marker.coordinate and
			(fields.display_marker or fields.teleport_marker or fields.rename_marker or fields.delete_marker) then
			if fields.display_marker then display_marker(fs.selected_marker.name, fs.selected_marker.coordinate, hud.colour); fs.selected_marker = {}
			elseif fields.teleport_marker then
				if not marker_datas.tp.on then minetest.show_formspec("marker_teleport", get_formspec_dialogue({"teleport_marker", "Enable teleportation ?"}))
				elseif marker.tp_cmd then marker.tp_cmd(fs.selected_marker.coordinate); fs.selected_marker = {}
				else run_server_chatcommand(marker_datas.tp.command, pos_to_string(fs.selected_marker.coordinate)); fs.selected_marker = {} end
			elseif fields.rename_marker then
				minetest.show_formspec("marker_rename", get_formspec_dialogue({"rename_marker", "Rename : ", fs.selected_marker.name}))
			elseif fields.delete_marker then
				minetest.show_formspec("marker_delete", get_formspec_dialogue({"delete_marker", "Delete : ", fs.selected_marker.name}))
			end
		elseif fields.teleport_marker and not marker_datas.tp.on then
			minetest.show_formspec("marker_teleport", get_formspec_dialogue({"teleport_marker", "Enable teleportation ?"}))
		elseif fields.b_N or fields.b_d or fields.b_teleport_marker or fields.b_rename_marker or fields.b_delete_marker or fields.cancel then
			if fields.b_N or fields.b_d or fields.b_rename_marker or fields.b_delete_marker then
				local p = ""
				if fields.b_N or fields.b_d then
					if fields.b_d and #fs.marker_list > 1 then
						if fs.marker_list[1].distance >= fs.marker_list[#fs.marker_list].distance then p = "d-" else p = "d+" end
					end
				else
					if fields.b_rename_marker then
						if value_limit("marker", 0, fields.f_rename_marker:len()) then return false end
						rename_marker(fs.selected_marker.name, fields.f_rename_marker)
					elseif fields.b_delete_marker then
						delete_marker(fs.selected_marker.name)
					end
					fs.selected_marker = {}
				end
				fs.marker_list = sort_list(format_list(marker_datas.list), p)
			elseif fields.b_teleport_marker then marker_datas.tp.on = true end
			minetest.show_formspec("marker_menu", get_formspec_marker(fs.marker_list))
		elseif fields.quit then fs.selected_marker = {} end
	end

	if formname == "list_menu" or formname == "list_new" or formname == "list_rename" or formname == "list_delete" then
		if fields.show_marker_menu then
			minetest.show_formspec("marker_menu", get_formspec_marker(fs.marker_list))
		elseif fields.new_list then
			minetest.show_formspec("list_new", get_formspec_dialogue({"new_list", "New list : "}))
		elseif fields.amend_list then
			minetest.show_formspec("amend_menu", get_formspec_amend(marker_datas.list))
		elseif fields.rename_list then
			minetest.show_formspec("list_rename", get_formspec_dialogue({"rename_list", "Rename : ", fs.list[1]}))
		elseif fields.delete_list then
			minetest.show_formspec("list_delete", get_formspec_dialogue({"delete_list", "Delete : ", fs.list[1]}))
		elseif fields.list_textlist or fields.sort_up or fields.sort_down or fields.b_new_list or fields.b_rename_list or fields.b_delete_list or fields.cancel then
			if fields.list_textlist and #fs.list > 1 then
				local id = tonumber(fields.list_textlist:match(":(%d+)")) + 1
				if id > 1 then update_lists(id); set_storage("list", fs.list) end
			elseif (fields.sort_up or fields.sort_down) and #fs.list > 1 then
				for i = 2, #fs.list do
					if fields.sort_up and i > 2 and fs.list[i] == fs.list[1] then
						fs.list[i], fs.list[i - 1] = fs.list[i - 1], fs.list[i]
						marker_datas.current_list, fs.list[1] = fs.list[i - 1], fs.list[i - 1]; set_storage("list", fs.list); break
					elseif fields.sort_down and i < #fs.list and fs.list[i] == fs.list[1] then
						fs.list[i], fs.list[i + 1] = fs.list[i + 1], fs.list[i]
						marker_datas.current_list, fs.list[1] = fs.list[i + 1], fs.list[i + 1]; set_storage("list", fs.list); break
					end
				end
			elseif fields.b_new_list then
				fs.list = get_storage("list")
				if value_limit("list", #fs.list - 1, fields.f_new_list:len()) then return false
				elseif fields.f_new_list == "list" then return false, display_chat_message(format_msg("\"list\" is a reserved name. Please choose another one."))
				else
					local b = true
					for i = 2, #fs.list do
						if fs.list[i] == fields.f_new_list then
							update_lists(i); b = false; break
						end
					end
					if b then
						table.insert(fs.list, fields.f_new_list)
						marker_datas.current_list, fs.list[1] = fs.list[#fs.list], fs.list[#fs.list]
						marker_datas.list, fs.marker_list = {}, {}
					end
					set_storage("list", fs.list)
				end
			elseif fields.b_rename_list then
				if value_limit("list", 0, fields.f_rename_list:len()) then return false
				elseif fields.f_rename_list == "list" then return false, display_chat_message(format_msg("\"list\" is a reserved name. Please choose another one."))
				else
					local b, id = true, 0; fs.list = get_storage("list")
					for i = 2, #fs.list do
						if fs.list[i] == fields.f_rename_list then update_lists(i); b = false; break end
						if fs.list[i] == fs.list[1] then id = i end
					end
					if b then
						set_storage(fs.list[1], ""); set_storage(fields.f_rename_list, marker_datas.list)
						table.remove(fs.list, id); table.insert(fs.list, fields.f_rename_list)
						marker_datas.current_list, fs.list[1] = fs.list[#fs.list], fs.list[#fs.list]
					end
					set_storage("list", fs.list)
				end
			elseif fields.b_delete_list then
				fs.list = get_storage("list")
				for i = 2, #fs.list do
					if fs.list[i] == fs.list[1] then
						table.remove(fs.list, i); set_storage(fs.list[1], "")
						if #fs.list > 1 then
							marker_datas.current_list, fs.list[1] = fs.list[2], fs.list[2]
						else
							marker_datas.current_list, fs.list[1], fs.list[2] = "Star", "Star", "Star"
						end
						marker_datas.list = get_storage(marker_datas.current_list)
						fs.marker_list = sort_list(format_list(marker_datas.list))
						set_storage("list", fs.list); break
					end
				end
			end
			minetest.show_formspec("list_menu", get_formspec_list(fs.list))
		end
	end

	if formname == "amend_menu" or formname == "amend_save" then
		if fields.show_marker_menu then
			set_amend_values(nil, false, false)
			minetest.show_formspec("marker_menu", get_formspec_marker(fs.marker_list))
		elseif fields.show_hud_amend then
			fs.show_hud = op_t(fields.show_hud_amend == "true", true, false)
			minetest.show_formspec("amend_menu", get_formspec_amend(marker_datas.list, fs.show_hud, fs.show_preview))
		elseif fields.save_amend then
			if set_amendDatas(fields.textarea_amend, fs.show_hud) then
				minetest.show_formspec("amend_save", get_formspec_dialogue({"save_amend", "Save the list ?"}))
			end
		elseif fields.preview_amend then
			fs.show_preview = not fs.show_preview
			if set_amendDatas(fields.textarea_amend, fs.show_hud) then
				minetest.show_formspec("amend_menu", get_formspec_amend(fs.datas_amended, fs.show_hud, fs.show_preview))
			end
		elseif fields.b_save_amend then
			set_storage(marker_datas.current_list, fs.datas_amended)
			marker_datas.list = get_storage(marker_datas.current_list)
			fs.marker_list = sort_list(format_list(marker_datas.list))
			set_amend_values(nil, false, false)
			minetest.show_formspec("marker_menu", get_formspec_marker(fs.marker_list))
		elseif fields.cancel then
			minetest.show_formspec("amend_menu", get_formspec_amend(fs.datas_amended, fs.show_hud, fs.show_preview))
		elseif fields.quit then	set_amend_values(nil, false, false) end
	end
end)

local function display_list(list)
	local size_prefix, size_leftRow = #minetest.strip_colors(marker_datas.prefix), 24
	display_chat_message(("%s %s | %s | %s"):format(marker_datas.prefix, colorize("orange", pad("Name", size_leftRow)), colorize("orange", "Distance"), colorize("orange", "Coordinate")))
	for _, datas in ipairs(list) do
		local colour = datas.distance < 500 and "#B22222" or (datas.distance < 1000 and "#FFFF66" or "#FFFFFF")
		local pos = ("%6s,%6s,%6s"):format(datas.coordinate.x, datas.coordinate.y, datas.coordinate.z)
		display_chat_message(("%s %s | %s | %s"):format(pad("", size_prefix), colorize(colour, pad(datas.name, size_leftRow)), colorize(colour, ("%8s"):format(datas.distance)), colorize(colour, pos)))
	end
end

local function mrkr_params(param)
	local str = ""
	str = param:match("^help$") or str; str = param:match("^list.*") or str
	str = param:match("^ren.*") or str; str = param:match("^del.*") or str
	str = param:match("^msg.*") or str; str = param:match("^tp.*") or str
	if str ~= param then return false end; return true
end

minetest.register_chatcommand("mrkr", {
	description = "Use marker", params = "help|save|s|list|ren|del|msg|tp",
	func = function(param)
		local param_lower = param:lower()
		if param_lower == "help" then
			display_chat_message(format_msg("Help: Show this help message."))
			display_chat_message(format_msg("No parameter: Show marker(s) menu."))
			local params = "Params: name|name x,y,z|name here[n]"; if not mt5 then params = params:gsub("|name here%[n%]", "") end
			display_chat_message(format_msg1("|save|s: Save a position.", params))
			display_chat_message(format_msg("List: Display marker(s) list. Param: [d[+|-]]"))
			display_chat_message(format_msg("Ren: Rename a marker. Params: oldname newname"))
			display_chat_message(format_msg("Del: Delete a marker. Param: name"))
			display_chat_message(format_msg("Msg: Message a player with coordinates of a position. Params: playername [markername]"))
			display_chat_message(format_msg("Tp: Teleport mode. Params: help|command|c|toggle"))

		elseif param == "" then
			fs.marker_list = sort_list(format_list(marker_datas.list)); minetest.show_formspec("marker_menu", get_formspec_marker(fs.marker_list))

		elseif param_lower:sub(1,4) == "save" or param_lower:sub(1,1) == "s" or not mrkr_params(param) then
			if param_lower:match("^save%s.+") then param = param:sub(6) elseif param_lower:match("^s%s.+") then param = param:sub(3) end
			local name = nil; local pos = param:match(" ([%d.-]+, *[%d.-]+, *[%d.-]+)$")
			if pos == nil then
				local here = param:match("here[%d]?$")
				if mt5 and here and param:len() > here:len() then
					for _, v in ipairs(hud.ids) do
						local hud_def = minetest.localplayer:hud_get(v)
						if here == hud_def.name then pos = vector.round(hud_def.world_pos); break end
					end
					if pos == nil then name = param else name = param:gsub("%shere[%d]?$", "") end
				else name = param end
			else name = param:gsub(" [%d.-]+, *[%d.-]+, *[%d.-]+$", "") end
			local pos_string = ""; if marker_datas.list[name] then pos_string = marker_datas.list[name][1] end
			if name == nil then
				local msg = "The marker name isn't valid. Usage: .mrkr name or .mrkr name x,y,z or .mrkr name heren"; if not mt5 then msg = msg:gsub(" or %.mrkr name heren", "") end
				return false, format_msg(msg)
			end
			if pos_string == "" then
				if pos == nil then pos = vector.round(minetest.localplayer:get_pos())
				elseif type(pos) == "string" and #pos:split() == 3 then pos = vector.round(string_to_pos(pos))
				elseif type(pos) ~= "table" then
					local msg = "Usage: .mrkr name or .mrkr name x,y,z or .mrkr name heren"; if not mt5 then msg = msg:gsub(" or %.mrkr name heren", "") end
					return false, format_msg(msg) end
				if value_limit("marker", #format_list(marker_datas.list), name:len()) then return false end
				local b, msg = set_marker(name, pos_to_string(pos))
				if not b then return false, format_msg("Error saving the marker!") elseif msg then display_chat_message(msg) end
			else
				return false, format_msg("This marker name is already in use!")
			end

		elseif param_lower:sub(1,4) == "list" then
			local list_data = format_list(marker_datas.list)
			if #list_data < 1 then display_chat_message(format_msg("No marker stored."))
			else display_list(sort_list(list_data, param_lower:match("d[+-]?"))) end

		elseif param_lower:sub(1,3) == "ren" then
			param = param:sub(5); local names = param:split(" ")
			if param == "" or #names < 2 then
				return false, format_msg("You must specify names. Usage: .mrkr ren oldname newname")
			else
				local name1, name2 = "", ""
				for _, v in ipairs(names) do
					if name1 == "" then name1 = name1 .. v else name1 = name1 .. " " .. v end
					if marker_datas.list[name1] then break end
				end
				name2 = param:sub(name1:len() + 2)
				local b, msg = rename_marker(name1, name2)
				if not b then
					if msg then return false, msg
					else
						msg = format_msg1("Error renaming marker", param)
						if #names == 2 then
							msg = ("%s Error renaming marker: %s to %s"):format(marker_datas.prefix, names[1], names[2])
						end
						return false, msg
					end
				elseif msg then display_chat_message(msg) end
			end

		elseif param_lower:sub(1,3) == "del" then
			param = param:sub(5); local b, msg = delete_marker(param)
			if not b then return false, format_msg1("Error removing the marker:", param) elseif msg then display_chat_message(msg) end

		elseif param_lower:sub(1,3) == "msg" then
			param = param:sub(5); local names = param:split(" ")
			if param == "" then
				return false, format_msg("Usage: .mrkr msg playername markername")
			elseif #names == 1 then
				local pos = vector.round(minetest.localplayer:get_pos())
				display_chat_message(format_msg1("Coordinates sent,", pos_to_string(pos)))
				run_server_chatcommand("msg", ("%s Coordinates: %s"):format(names[1], pos_to_string(pos)))
			else
				local mname = param:match(" (.+)$")
				local pos_string = marker_datas.list[mname] and marker_datas.list[mname][1] or ""
				if pos_string == "" then return false, ("%s %s doesn't exist."):format(marker_datas.prefix, mname) end
				display_chat_message(format_msg1("Coordinates sent,", pos_string))
				run_server_chatcommand("msg", ("%s Coordinates: %s"):format(names[1], pos_string))
			end

		elseif param_lower:sub(1,2) == "tp" then
			if param_lower:sub(4,7) == "help" then
				display_chat_message(format_msg("Help: Show this help message."))
				display_chat_message(format_msg("Command|c: Define teleport command. (Default: teleport)"))
				display_chat_message(format_msg("Toggle: Switch on/off. (Default: off)"))

			elseif param_lower:sub(4,10) == "command" or param_lower:sub(4,4) == "c" then
				if param_lower:match("^tp command.*") then param = param:sub(11) elseif param_lower:match("^tp c.*") then param = param:sub(5) end
				local new_command = param:match("%s([%w_]+)$"); marker_datas.tp.command = new_command or marker_datas.tp.command
				if new_command == nil then return true, format_msg1("Teleport command is:", op_t(marker.tp_cmd, "custom command", marker_datas.tp.command)) end
				marker.tp_cmd = nil; return true, format_msg1("Teleport command set to:", new_command)

			elseif param_lower:sub(4,9) == "toggle" or param:len() == 2 then
				marker_datas.tp.on = not marker_datas.tp.on
				if not marker_datas.tp.on then marker.tp_cmd = nil end
				return true, format_msg(op_t(marker_datas.tp.on, "Teleportation enabled.", "Teleportation disabled."))

			else
				return false, format_msg1("Invalid argument:", param_lower)
			end

		else
			return false, format_msg("Invalid argument. For more information: .mrkr help")
		end
	end
})

minetest.register_chatcommand("go", {
	description = "Go to a position", params = "name [colour]|x,y,z [colour]",
	func = function(param)
		local b, msg = false, nil; local name, pos, colour = get_marker(param)
		local usage = "Usage: .go name [colour]|x,y,z [colour]"; if not mt5 then usage = usage:gsub(" %[colour%]", "") end
		if not name then return false, pos or format_msg(usage) end
		b, msg = display_marker(name, pos, colour, "go")
		if not b then return false, msg	or format_msg1("Error displaying the marker:", name) elseif b and msg then display_chat_message(msg) end
		if marker_datas.tp.on then
			if marker.tp_cmd then marker.tp_cmd(pos)
			else run_server_chatcommand(marker_datas.tp.command, pos_to_string(pos)) end
		end
	end
})

if mt5 then
	local function hud_params(param)
		local str = ""
		str = param:match("^help$") or str; str = param:match("^display.*") or str
		str = param:match("^d.*") or str; str = param:match("^here[%d]?$") or str
		str = param:match("^toggle$") or str; str = param:match("^t$") or str; str = param:match("^clear$") or str
		if str ~= param then return false end; return true
	end

	minetest.register_chatcommand("hud", {
		description = "Display one ore more marker", params = "help|display|d|toggle|t|here[n]|clear",
		func = function(param)
			local param_lower = param:lower()
			if param_lower == "help" then
				display_chat_message(format_msg("Help: Show this help message."))
				display_chat_message(format_msg("|display|d: Display a HUD and save it for an existing marker. Params: name [colour]|x,y,z [colour]"))
				display_chat_message(format_msg("Here[n]: Display a HUD at the current position."))
				display_chat_message(format_msg("Toggle|t: Turn on/off HUD(s) displayed."))
				display_chat_message(format_msg("Clear: Remove all HUD(s) displayed."))

			elseif param_lower:sub(1,7) == "display" or param_lower:sub(1,1) == "d" or not hud_params(param) then
				if param_lower:match("^display%s.+") then param = param:sub(9) elseif param_lower:match("^d%s.+") then param = param:sub(3) end
				local name, pos, colour = get_marker(param); if not name then return false, pos end
				local b, msg = display_hud(name, pos, colour)
				if not b then return false, msg or format_msg1("Error displaying the HUD:", name) elseif msg then display_chat_message(msg) end

			elseif param_lower:match("^here[%d]?$") then
				local b, msg = display_hud(param_lower, minetest.localplayer:get_pos(), 0xFF8C00)
				if not b then return false, msg or format_msg1("Error displaying the HUD:", param_lower) elseif msg then display_chat_message(msg) end

			elseif param_lower == "toggle" or param_lower == "t" then
				hud.t = not hud.t; local count, count_other = restore_hud()
				if hud.t then
					return true, ("%s %d HUD%s restored."):format(marker_datas.prefix, count, op_t(count > 1, "s", ""))
				else
					return true, ("%s %d(%d) HUD%s removed."):format(marker_datas.prefix, count, count_other, op_t(count > 1, "s", ""))
				end

			elseif param_lower == "clear" then
				local count = 0
				if hud.t then
					for _, v in ipairs(hud.ids) do
						minetest.localplayer:hud_remove(v); count = count + 1
					end
					hud.t, hud.id, hud.ids, hud.s = false, nil, {}, {}
				end
				return true, ("%s %d HUD%s cleared."):format(marker_datas.prefix, count, op_t(count > 1, "s", ""))

			else
				return false, format_msg("Invalid argument. For more information: .hud help")
			end
		end
	})
end