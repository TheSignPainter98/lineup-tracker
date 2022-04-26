local *

import Cell, StringBuilder, Table from require "util"
import insert, unpack from table

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
	@load: (maps, abilities, data) => Progress maps, abilities, data
	save: =>
	new_map: (map) => -- TODO: call me!
	new_zone: (map, zone) => -- TODO: call me!
	new_ability: (ability) => -- TODO: call me!
	new_usage: (ability, usage) => -- TODO: call me!
	set_progress: (map, zone, ability, usage, progress) => -- TODO: call me!
		with @_at map, zone, ability, usage
			.amt = progress
	set_target: (map, zone, ability, usage, target) => -- TODO: call me!
		with @_at map, zone, ability, usage
			.target = target
	_at: (map, zone, ability, usage) => @data[map.name][zone.name][ability.name][usage.name]
	__tostring: => @render!
	render: (map, zone, ability, usage) =>
		tostring with Table!
			-- Upper header
			\add with { '', '' }
				i = 3
				for ability in *@abilities
					cell = with Cell ability.name
						\hifg!
						\bold!
					[i] = cell
					i += 1
					for _ = 2,#ability.usages
						[i] = ''
						i += 1
			-- Lower header
			\add with { '', '' }
				i = 3
				for ability in *@abilities
					for usage in *ability.usages
						cell = with Cell usage.name
							\bold!
							\hifg!
						[i] = cell
						i += 1

			-- Table body
			for map in *@maps
				row_header = {}
				row_header[1] = with Cell map.name
					\bold!
					\hifg!
				for zone in *map.zones
					row_header[2] = with Cell zone.name
						\bold!
						\hifg!
					\add with { unpack row_header }
						i = 3
						for ability in *@abilities
							for usage in *ability.usages
								[i] = (@_at map, zone, ability, usage)\render!
								i += 1
						row_header = { '' }

class Target
	new: (@amt=0, @target=1) =>
	render: =>
		local text
		if @target == 0
			text = "-"
		else
			text = "#{@amt}/#{@target}"
		with Cell text
			if @target == 0
				\fg 'blue'
			else if @amt <= @target / 4
				\fg 'red'
			else if @amt < @target
				\fg 'yellow'
			else
				\fg 'green'
	__tostring: => @name
	@load: (target) => Target target.amt, target.target
	save: => {
		amt: @amt
		target: @target
	}

{ :Ability, :Map, :Progress, :Usage, :Zone }
