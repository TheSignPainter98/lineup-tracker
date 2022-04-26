import currentdir from require 'lfs'
package.path ..= ";#{currentdir!}/src/?.o"
-- package.path ..= ";#{currentdir!}/src/?.moon"

import read, open, stderr, write from io
import max from math
import exit from os
import dump, load from require 'lyaml'
import Ability, Map, Progress, Usage, Zone from require 'model'
import Coloured, insert_sorted, named_get, sorted, StringBuilder, Table from require 'util'
import statuses, problem from require 'status'
import concat, insert, unpack from table

DEFAULT_SAVE_FILE = '.progress.yml'

import PASS, FAIL, EXIT from statuses

class Commands
	new: (@cmds) =>
	__call: (...) => @execute ...
	__pairs: => next, @cmds
	execute: (prog_state, cmd, ...) =>
		return problem "Missing command" unless cmd
		if f = @get_cmd cmd
			ret = (f prog_state, ...)
			switch type ret
				when 'nil', 'integer', 'number'
					ret or PASS
				else
					print ret
					PASS
		else
			PASS
	get_cmd: (cmd) =>
		if f = @cmds[cmd]
			return f
		matching_keys = {}
		for cmd_key in *@cmd_keys!
			if cmd_key\match '^' .. cmd
				insert matching_keys, cmd_key
		switch #matching_keys
			when 0
				stderr\write "Unknown command '#{cmd}'\n"
				nil
			when 1
				@cmds[matching_keys[1]]
			else
				stderr\write "Ambiguous command '#{cmd}' can match any of: #{concat matching_keys, ', '}"
	cmd_keys: => [ k for k in pairs @cmds ]


class ProgState
	new: =>
		@maps = {}
		@abilities = {}
		@progress = Progress @maps, @abilities
	save: (file=DEFAULT_SAVE_FILE) =>
		with open file, 'w+'
			\write dump {{
				maps: [ m\save! for m in *@maps ]
				abilities: [ a\save! for a in *@abilities ]
				progress: @progress\save!
			}}
			\close!
	load: (file=DEFAULT_SAVE_FILE) =>
		if f = open file, 'r'
			local data
			with f
				data = load \read '*all'
				\close!
			return unless data
			@maps = [ Map\load m for m in *data.maps or {} ]
			@abilities = [ Ability\load a for a in *data.abilities or {} ]
			@progress = Progress\load @maps, @abilities, data.progress
	loop: (args) =>
		if #args != 0
			for cmd in *@arg_cmds args
				switch @execute unpack cmd
					when FAIL
						1
					when EXIT
						0
		else
			while true
				write @prompt!
				resp = read!
				unless resp
					print!
					return 0
				switch @execute unpack [ w for w in resp\gmatch '%s*([^%s]+)' ]
					when FAIL
						return 1
					when EXIT
						return 0
			0
	arg_cmds: (args) =>
		list = {}
		cmd = nil
		for arg in *args
			if arg\match '^-'
				if cmd
					list[#list + 1] = cmd
					cmd = nil
				cmd = { (arg\match '^-+(.*)$'), nil }
			else
				cmd[#cmd + 1] = arg
		list[#list + 1] = cmd if cmd
		list
	prompt_end: ' '
	prompt_inter: ''
	prompt_initial: ' '
	prompt: =>
		sb = StringBuilder!
		prompt_data = {}
		if @map
			insert prompt_data, with Coloured " #{@map} "
				\bg 'green'
		if @zone
			insert prompt_data, with Coloured " #{@zone} "
				\bg 'blue'
		if @ability
			insert prompt_data, with Coloured " #{@ability} "
				\bg 'cyan'
		if @usage
			insert prompt_data, with Coloured " #{@usage} "
				\bg 'purple'
		prompt_parts = {}
		n = #prompt_data
		for i = 1, n
			if 2 <= i
				insert prompt_parts, with Coloured @prompt_inter
					prv = prompt_data[i-1]
					curr = prompt_data[i]
					\fg prv\get 'bg'
					\bg curr\get 'bg'
			insert prompt_parts, prompt_data[i]
		insert prompt_parts, with Coloured @prompt_end
			last = prompt_data[n]
			\fg last and (last\get 'bg') or 'yellow'
		sb ..= part\render! for part in *prompt_parts
		sb!
	execute: (cmd, ...) =>
		return PASS unless cmd
		@cmds cmd, ...
	cmds: Commands {
		map: (map) =>
			return problem "Specify map!" unless map
			@map = named_get @maps, map
			@zone = nil
		zone: (zone) =>
			unless @map
				@zone = nil
				return problem "Zone requires a map"
			return problem "Specify zone!" unless zone
			@zone = named_get @map.zones, zone
		ability: (ability) =>
			return problem "Specify ability" unless ability
			@ability = named_get @abilities, ability
			@usage = nil
		usage: (usage) =>
			return problem "Specify usage!" unless usage
			unless @ability
				@usage = nil
				return problem "Usage requies an ability"
			@usage = named_get @ability.usages, usage
		help: =>
			for cmd in pairs @cmds
				stderr\write "no help for #{cmd}\n" unless @help[cmd]
			Table sorted [ { cmd, @help[cmd] and (@help[cmd] @) or '' } for cmd in pairs @cmds ], (a,b) -> a[1] < b[1]
		state: => Table {
				{ "Map", @map or 'none' }
				{ "Zone", @zone or 'none' }
				{ "Ability", @ability or 'none' }
				{ "Usage", @usage or 'none' }
			}
		exit: => EXIT
		quit: => @cmds @, 'exit'
		Save: => nil, @save!
		new: (...) =>
			cmds = Commands {
				map: (name) =>
					return problem "New map needs a name" unless name
					@map = Map name
					@progress\new_map @map
				zone: (name) =>
					return problem "New zone needs a name" unless name
					return problem "Cannot set zone without first setting a map!" unless @map
					@zone = Zone name
					@progress\new_zone @map, @zone
				ability: (name) =>
					return problem "New ability needs a name" unless name
					@ability = Ability name
					@progress\new_ability @ability
				usage: (name) =>
					return problem "New ability needs a name" unless name
					problem "Cannot set usage without first setting an ability!" unless @ability
					@usage = Usage name
					@progress\new_usage @ability, @usage
			}
			cmds @, ...
		list: (kind) =>
			if kind
				list_kind = (k) => concat [ tostring d for d in *@[k] ], '\n'
				kind_commands = Commands {
					maps: => list_kind @, 'maps'
					zones: => list_kind @, 'zones'
					abilities: => list_kind @, 'abilities'
					usages: => list_kind @, 'usages'
				}
				kind_commands @, kind
			else
				sb = StringBuilder!
				sb ..= 'Maps:'
				for i,map in ipairs @maps
					sb ..= "\n- #{i}:\t#{map}\n\tZones:"
					for j,zone in ipairs map.zones
						sb ..= "\n\t- #{j}:\t#{zone}"
				sb ..= '\nAbilities:'
				for i,ability in ipairs @abilities
					sb ..= "\n- #{i}: \t#{ability}\n\tUsages:"
					for j,usage in ipairs ability.usages
						sb ..= "\n\t- #{j}:\t#{usage}"
				sb!
		progress: (...) =>
			nargs = select '#', ...
			return @progress\render @map, @zone, @ability, @usage unless 0 < nargs
			return problem "Must specify what to update (progress or target)" unless 1 <= nargs
			return problem "Must specify an amount to update" unless 2 <= nargs
			unless @map and @zone and @ability and @usage
				return problem "Must set a map, zone, ability and usage before updating a target!"
			update_commands = Commands {
				progress: (how_much) => @progress\set_progress @map, @zone, @ability, @usage, how_much
				target: (how_much) => @progress\set_target @map, @zone, @ability, @usage, how_much
			}
			update_commands @, ...
	}
	help:
		ability: => "Set the current ability to $1"
		exit: => "Exit the program"
		quit: => @help.exit @
		help: => "Display this help message"
		list: => "List available data, optionally specify the kind"
		map: => "Set the current map to $1"
		new: => "Add a new $1 called $2"
		progress: => "Show progress"
		Save: => "Save changes"
		state: => "Print the current query state"
		usage: => "Set the current usage in the current ability to $1"
		zone: => "Set the current zone in the current map to $1"

main = (...) ->
	local rc
	with ProgState!
		\load!
		rc = \loop {...}
		\save!
	exit rc

main ...
0
