local *

import abs, max from math
import problem, statuses from require 'status'
import eq, Coloured, insert_sorted, StringBuilder, Table from require "util"
import insert, unpack from table

import PASS from statuses

class Map
	new: (@name, @zones={}) =>
	__concat: (zone) =>
		insert @zones, zone
		@
	__tostring: => @name
	@load: (map) => Map map.name, [ Zone\load z for z in *map.zones ]
	save: => {
		name: @name
		zones: [ z\save! for z in *@zones ]
	}

class Zone
	new: (@name) =>
	__tostring: => @name
	@load: (zone) => Zone zone
	save: => @name

class Ability
	new: (@name, @usages={}) =>
	__concat: (usage) =>
		insert @usages, usage
		@
	__tostring: => @name
	@load: (ability) => Ability ability.name, [ Usage\load u for u in *ability.usages ]
	save: => {
		name: @name
		usages: [ u\save! for u in *@usages ]
	}

class Usage
	new: (@name) =>
	__tostring: => @name
	@load: (usage) => Usage usage
	save: => @name

class Progress -- (map * zone) * (ability * usage) -> target
	new: (@maps, @abilities, @data) =>
		unless @data
			@data = { map.name, { zone.name, { ability.name, { usage.name, Target! for usage in *ability.usages } for ability in *@abilities } for zone in *map.zones } for map in *@maps }
	@load: (maps, abilities, data) =>
		data = { map_name, { zone_name, { ability_name, { usage_name, Target\load target for usage_name,target in pairs usages } for ability_name,usages in pairs abilities } for zone_name,abilities in pairs zones } for map_name,zones in pairs data } if data
		Progress maps, abilities, data
	save: => { map_name, { zone_name, { ability_name, { usage_name, target\save! for usage_name,target in pairs usages } for ability_name,usages in pairs abilities } for zone_name,abilities in pairs zones } for map_name,zones in pairs @data }
	new_map: (map) =>
		insert_sorted @maps, map, (m) -> m.name\lower!
		@data[map.name] = {}
	new_zone: (map, zone) =>
		map ..= zone
		@data[map.name][zone.name] = { ability.name, { usage.name, Target! for usage in *ability.usages } for ability in *@abilities }
	new_ability: (ability) =>
		insert_sorted @abilities, ability, (a) -> a.name\lower!
		for map in *@maps
			for zone in *map.zones
				@data[map.name][zone.name][ability.name] = {}
	new_usage: (ability, usage) =>
		ability ..= usage
		for map in *@maps
			for zone in *map.zones
				@data[map.name][zone.name][ability.name][usage.name] = Target!
	set_progress: (query_state, progress) =>
		import map, zone, ability, usage from query_state
		n = tonumber progress
		with @_at map, zone, ability, usage
			switch progress
				when '+'
					\mut_amt 1
				when '-'
					\mut_amt -1
				else
					return problem "Progress amount must be a number: could not parse '#{progress}'" unless n
					\set_amt n
		PASS
	set_target: (query_state, target) =>
		import map, zone, ability, usage from query_state
		target = target\lower!
		n = tonumber target
		with @_at map, zone, ability, usage
			switch target
				when '+'
					\mut_target 1
				when '-'
					\mut_target -1
				else
					return problem "Target amount must be a number: could not parse '#{target}'" unless n
					\set_target n
		PASS
	_at: (map, zone, ability, usage) => @data[map.name][zone.name][ability.name][usage.name]
	__tostring: => @render!
	render: (query_state) =>
		global_target = Target 0, 0
		do_output = false
		for _,map in pairs @data
			for _,zone in pairs map
				for _,ability in pairs zone
					for _,target in pairs ability
						global_target += target
						do_output = true
		return unless do_output

		tostring with Table!
			header_square = {
				{
					with Coloured 'Progress'
						\fg 'blue'
						\bold!
					global_target\render!\bold!
				}
				{
					''
					(global_target\render 'percent')\bold!
				}
			}

			-- Upper header
			\add with header_square[1]
				i = 3
				for ability in *@abilities
					cell = with Coloured ability.name
						\hifg!
						\bold!
					[i] = cell
					i += 1
					for _ = 2,#ability.usages
						[i] = ''
						i += 1
			-- Lower header
			\add with header_square[2]
				i = 3
				for ability in *@abilities
					for usage in *ability.usages
						cell = with Coloured usage.name
							\bold!
							\hifg!
						[i] = cell
						i += 1

			-- Table body
			for map in *@maps
				row_header = {}
				row_header[1] = with Coloured map.name
					\bold!
					\hifg!
				for zone in *map.zones
					row_header[2] = with Coloured zone.name
						\bold!
						\hifg!
					\add with { unpack row_header }
						i = 3
						for ability in *@abilities
							for usage in *ability.usages
								[i] = (@_at map, zone, ability, usage)\render!
								if eq query_state, { :map, :zone, :ability, :usage }
									[i]\bg 'white'
									[i]\bold!
								i += 1
						row_header = { '' }


class Target
	new: (@amt=0, @target=2) =>
	render: (fmt='raw') =>
		local text
		if @target == 0
			text = "-"
		else
			switch fmt
				when 'raw'
					text = "#{@amt}/#{@target}"
				when 'percent'
					text = "#{100 * @amt // @target}%"
				else
					error "Unknown formatting option for target: #{fmt}"
		with Coloured text
			if @target == 0
				\fg 'blue'
			else if (abs @amt) <= @target / 4
				\fg 'red'
			else if @amt < @target
				\fg 'yellow'
			else
				\fg 'green'
	set_amt: (@amt) =>
	set_target: (target) => @target = max 0, target
	mut_amt: (delta) => @amt += delta
	mut_target: (delta) => @target = max 0, @target + delta
	__tostring: => "#{@amt}/#{@target}"
	__add: (t) => Target ((max 0, @amt) + (max 0, t.amt)), (@target) + t.target
	@load: (target) => Target target.amt, target.target
	save: => {
		amt: @amt
		target: @target
	}

{ :Ability, :Map, :Progress, :Usage, :Zone }
