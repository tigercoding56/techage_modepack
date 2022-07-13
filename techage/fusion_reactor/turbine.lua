--[[

	TechAge
	=======

	Copyright (C) 2019-2022 Joachim Stolberg

	AGPL v3
	See LICENSE.txt for more information

	TA5 Gas Turbine

]]--

-- for lazy programmers
local M = minetest.get_meta
local S = techage.S

local Pipe = techage.LiquidPipe

local function generator_cmnd(pos, topic, payload)
	return techage.transfer(pos, "R", topic, payload, nil,
		{"techage:ta5_generator", "techage:ta5_generator_on"})
end

local function swap_node(pos, name)
	local node = techage.get_node_lvm(pos)
	if node.name == name then
		return
	end
	node.name = name
	minetest.swap_node(pos, node)
end

local function play_sound(pos)
	local mem = techage.get_mem(pos)
	if not mem.handle or mem.handle == -1 then
		mem.handle = minetest.sound_play("techage_turbine", {
			pos = pos,
			gain = 0.4,
			max_hear_distance = 10,
			loop = true})
		if mem.handle == -1 then
			minetest.after(1, play_sound, pos)
		end
	end
end

local function stop_sound(pos)
	local mem = techage.get_mem(pos)
	if mem.handle then
		minetest.sound_stop(mem.handle)
		mem.handle = nil
	end
end

minetest.register_node("techage:ta5_turbine", {
	description = S("TA5 Turbine"),
	tiles = {
		-- up, down, right, left, back, front
		"techage_filling_ta4.png^techage_frame_ta5_top.png^techage_appl_hole_pipe.png",
		"techage_filling_ta4.png^techage_frame_ta4_bottom.png",
		"techage_filling_ta4.png^techage_appl_open.png^techage_frame_ta5.png",
		"techage_filling_ta4.png^techage_frame_ta5.png^techage_appl_hole_pipe.png",
		"techage_filling_ta4.png^techage_appl_turbine.png^techage_frame_ta5.png",
		"techage_filling_ta4.png^techage_appl_turbine.png^techage_frame_ta5.png",
	},

	after_place_node = function(pos)
		Pipe:after_place_node(pos)
	end,
	after_dig_node = function(pos, oldnode)
		stop_sound(pos)
		Pipe:after_dig_node(pos)
		techage.del_mem(pos)
	end,
	networks = {
		pipe2 = {},
	},
	paramtype2 = "facedir",
	groups = {cracky=2, crumbly=2, choppy=2},
	on_rotate = screwdriver.disallow,
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
})

minetest.register_node("techage:ta5_turbine_on", {
	tiles = {
		-- up, down, right, left, back, front
		"techage_filling_ta4.png^techage_frame_ta5_top.png^techage_appl_hole_pipe.png",
		"techage_filling_ta4.png^techage_frame_ta4_bottom.png",
		"techage_filling_ta4.png^techage_appl_open.png^techage_frame_ta5.png",
		"techage_filling_ta4.png^techage_frame_ta5.png^techage_appl_hole_pipe.png",
		{
			image = "techage_filling4_ta4.png^techage_appl_turbine4.png^techage_frame4_ta5.png",
			backface_culling = false,
			animation = {
				type = "vertical_frames",
				aspect_w = 32,
				aspect_h = 32,
				length = 0.4,
			},
		},
		{
			image = "techage_filling4_ta4.png^techage_appl_turbine4.png^techage_frame4_ta5.png",
			backface_culling = false,
			animation = {
				type = "vertical_frames",
				aspect_w = 32,
				aspect_h = 32,
				length = 0.4,
			},
		},
	},

	tubelib2_on_update2 = function(pos, outdir, tlib2, node)
		swap_node(pos, "techage:ta5_turbine")
		stop_sound(pos)
		generator_cmnd(pos, "stop")
	end,
	networks = {
		pipe2 = {},
	},
	paramtype2 = "facedir",
	groups = {not_in_creative_inventory=1},
	diggable = false,
	on_rotate = screwdriver.disallow,
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
})

Pipe:add_secondary_node_names({"techage:ta5_turbine", "techage:ta5_turbine_on"})
Pipe:set_valid_sides("techage:ta5_turbine", {"L", "U"})
Pipe:set_valid_sides("techage:ta5_turbine_on", {"L", "U"})

techage.register_node({"techage:ta5_turbine", "techage:ta5_turbine_on"}, {
	-- used by heatexchanger1
	on_transfer = function(pos, in_dir, topic, payload)
		local nvm = techage.get_nvm(pos)
		if topic == "trigger" then
			return generator_cmnd(pos, topic, payload)
		elseif topic == "start" then
			swap_node(pos, "techage:ta5_turbine_on")
			play_sound(pos)
			return generator_cmnd(pos, topic, payload)
		elseif topic == "stop" then
			swap_node(pos, "techage:ta5_turbine")
			stop_sound(pos)
			return generator_cmnd(pos, topic, payload)
		elseif topic == "turbine" then
			return true
		else
			return generator_cmnd(pos, topic, payload)
		end
	end,
	on_node_load = function(pos, node)
		if node.name == "techage:ta5_turbine_on" then
			play_sound(pos)
		end
	end,
})

minetest.register_craft({
	output = "techage:ta5_turbine",
	recipe = {
		{"", "dye:red", ""},
		{"", "techage:turbine", ""},
		{"", "techage:ta5_ceramic_turbine", ""},
	},
})
