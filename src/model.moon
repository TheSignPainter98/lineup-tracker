local *

import StringBuilder from require "util"
import insert from table

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
	render: (map, zone, ability, usage) => 'WIP' -- TODO: turn this into a table!

class Target
	new: (@amt=0, @target=0) =>
	render: (sb=StringBuilder!) => "#{100 * (@target != 0 or @amt // @target and 1)}%"
	__tostring: => @name
	@load: (target) => Target target.amt, target.target
	save: => {
		amt: @amt
		target: @target
	}

{ :Ability, :Map, :Progress, :Usage, :Zone }
