local *

import StringBuilder from require "util"
import insert from table

class Map
	new: (@name, @zones={}) =>
	render: (sb=StringBuilder!) =>
		for zone in *@zones
			zone\render sb
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
	render: (sb=StringBuilder!) => sb .. @name
	__tostring: => @name
	@load: (zone) => Zone zone
	save: => @name

class Ability
	new: (@name, @usages={}) =>
	render: (sb=StringBuilder!) => usage\render sb for usage in *@usages
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
	render: (sb=StringBuilder!) => sb .. @name
	__tostring: => @name
	@load: (usage) => Usage usage
	save: => @name

class Target
	new: (@amt, @target) =>
	render: (sb=StringBuilder!) => sb .. "#{100 * @amt // @target}%"
	__tostring: => @name
	@load: (target) => Target target.amt, target.target
	save: => {
		amt: @amt
		target: @target
	}

{ :Ability, :Map, :Usage, :Zone }
