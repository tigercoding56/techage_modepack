--[[

	TechAge
	=======

	Copyright (C) 2019-2022 Joachim Stolberg

	AGPL v3
	See LICENSE.txt for more information

	TA4 Isolation Transformer (to separate networks)

]]--

-- for lazy programmers
local P2S = minetest.pos_to_string
local M = minetest.get_meta
local S = techage.S

local CYCLE_TIME = 2
local PWR_PERF = 100

local Cable = techage.ElectricCable
local power = networks.power
local control = networks.control


local function formspec(self, pos, nvm, data)
	data = data or {curr_load1 = 0, curr_load2 = 0, max_capa1 = 0, max_capa2 = 0, moved = 0}
	return "size[7.5,5.2]"..
		default.gui_bg..
		default.gui_bg_img..
		default.gui_slots..
		"box[0,-0.1;7.3,0.5;#c6e8ff]"..
		"label[0.2,-0.1;"..minetest.colorize( "#000000", S("TA4 Isolation Transformer")).."]"..
		techage.formspec_storage_bar(pos, 0.0, 0.7, S("Storage"),  data.curr_load1, data.max_capa1)..
		techage.formspec_power_bar(pos, 2.5, 0.7, S("Power"), data.moved, PWR_PERF)..
		techage.formspec_storage_bar(pos, 5.0, 0.7, S("Storage"),  data.curr_load2, data.max_capa2)..
		"image_button[3.3,4.3;1,1;" .. self:get_state_button_image(nvm) .. ";state_button;]" ..
		"tooltip[3.3,4.3;1,1;" .. self:get_state_tooltip(nvm) .. "]"
end

local function start_node(pos, nvm, state)
	local outdir = M(pos):get_int("outdir")
	power.start_storage_calc(pos, Cable, outdir)
	outdir = networks.Flip[outdir]
	power.start_storage_calc(pos, Cable, outdir)
end

local function stop_node(pos, nvm, state)
	local outdir = M(pos):get_int("outdir")
	power.start_storage_calc(pos, Cable, outdir)
	outdir = networks.Flip[outdir]
	power.start_storage_calc(pos, Cable, outdir)
end

local State = techage.NodeStates:new({
	node_name_passive = "techage:ta4_transformer",
	infotext_name = S("TA4 Isolation Transformer"),
	cycle_time = CYCLE_TIME,
	standby_ticks = 0,
	formspec_func = formspec,
	start_node = start_node,
	stop_node = stop_node,
})

local function node_timer(pos, elapsed)
	local nvm = techage.get_nvm(pos)
	local data
	if techage.is_running(nvm) then
		local outdir2 = M(pos):get_int("outdir")
		local outdir1 = networks.Flip[outdir2]
		data = power.transfer_duplex(pos, Cable, outdir1, Cable, outdir2, PWR_PERF)
		if data then
			nvm.load = (data.curr_load1 / data.max_capa1 + data.curr_load2 / data.max_capa2) / 2 * PWR_PERF
			nvm.moved = data.moved
		end
	end
	if techage.is_activeformspec(pos) then
		M(pos):set_string("formspec", formspec(State, pos, nvm, data))
	end
	return true
end

local function on_rightclick(pos, node, clicker)
	techage.set_activeformspec(pos, clicker)
end

local function on_receive_fields(pos, formname, fields, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	local nvm = techage.get_nvm(pos)
	State:state_button_event(pos, nvm, fields)
end

local function after_place_node(pos, placer, itemstack)
	local meta = M(pos)
	local nvm = techage.get_nvm(pos)
	local own_num = techage.add_node(pos, "techage:ta4_transformer")
	meta:set_string("owner", placer:get_player_name())
	local outdir = networks.side_to_outdir(pos, "R")
	meta:set_int("outdir", outdir)
	Cable:after_place_node(pos, {outdir, networks.Flip[outdir]})
	State:node_init(pos, nvm, own_num)
end

local function after_dig_node(pos, oldnode, oldmetadata, digger)
	local outdir = tonumber(oldmetadata.fields.outdir or 0)
	Cable:after_dig_node(pos, {outdir, networks.Flip[outdir]})
	techage.del_mem(pos)
end

local function get_generator_data(pos, outdir, tlib2)
	local nvm = techage.get_nvm(pos)
	if techage.is_running(nvm) then
		return {level = (nvm.load or 0) / PWR_PERF, perf = PWR_PERF, capa = PWR_PERF * 2}
	end
end

minetest.register_node("techage:ta4_transformer", {
	description = S("TA4 Isolation Transformer"),
	tiles = {
		-- up, down, right, left, back, front
		"techage_filling_ta4.png^techage_frame_ta4_top.png^techage_appl_trafo.png",
		"techage_filling_ta4.png^techage_frame_ta4.png",
		"techage_trafo.png^techage_frame_ta4.png^techage_appl_hole_electric.png",
		"techage_trafo.png^techage_frame_ta4.png^techage_appl_hole_electric.png",
		"techage_trafo.png^techage_frame_ta4.png",
		"techage_trafo.png^techage_frame_ta4.png",
	},

	on_timer = node_timer,
	on_rightclick = on_rightclick,
	on_receive_fields = on_receive_fields,
	after_place_node = after_place_node,
	after_dig_node = after_dig_node,
	get_generator_data = get_generator_data,
	paramtype2 = "facedir",
	groups = {cracky=2, crumbly=2, choppy=2},
	on_rotate = screwdriver.disallow,
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
})

power.register_nodes({"techage:ta4_transformer"}, Cable, "gen", {"R", "L"})

-- for logical communication
techage.register_node({"techage:ta4_transformer"}, {
	on_recv_message = function(pos, src, topic, payload)
		return State:on_receive_message(pos, topic, payload)
	end,
	on_beduino_receive_cmnd = function(pos, src, topic, payload)
		return State:on_beduino_receive_cmnd(pos, topic, payload)
	end,
	on_beduino_request_data = function(pos, src, topic, payload)
		return State:on_beduino_request_data(pos, topic, payload)
	end,
})

control.register_nodes({"techage:ta4_transformer"}, {
		on_receive = function(pos, tlib2, topic, payload)
		end,
		on_request = function(pos, tlib2, topic)
			if topic == "info" then
				local nvm = techage.get_nvm(pos)
				local meta = M(pos)
				return {
					type = S("TA4 Isolation Transformer"),
					number = meta:get_string("node_number") or "",
					running = techage.is_running(nvm) or false,
					available = PWR_PERF,
					provided = nvm.moved or 0,
					termpoint = "-",
				}
			end
			return false
		end,
	}
)

minetest.register_craft({
	output = "techage:ta4_transformer",
	recipe = {
		{"default:steel_ingot", "dye:blue", "default:steel_ingot"},
		{"techage:electric_cableS", "basic_materials:copper_wire", "techage:electric_cableS"},
		{"default:steel_ingot", "techage:ta4_wlanchip", "default:steel_ingot"},
	},
})
