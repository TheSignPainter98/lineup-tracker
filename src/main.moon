import read, open, stderr, stdout, write from io
import max from math
import exit, getenv from os
import dump, load from require 'lyaml'
import Ability, Map, Progress, Usage, Zone from require 'src.model'
import Coloured, insert_sorted, named_get, sorted, StringBuilder, Table from require 'src.util'
import is_bad, statuses, problem from require 'src.prog-stat'
import concat, insert, unpack from table

HOME = (getenv 'HOME') or (getenv 'HOMEPATH') or (getenv 'HOMEDRIVE')
error "Cannot find home directory" unless HOME
DEFAULT_SAVE_FILE = "#{HOME}/.lineup-progress.yml"

import PASS, FAIL, EXIT from statuses

class Commands
	new: (@cmds, @help={}) =>
		unless @cmds.help
			@cmds.help = (ps) -> @show_help ps
			@help.help = => "Show help"
	__call: (...) => @execute ...
	__pairs: => next, @cmds
	execute: (prog_state, cmd, ...) =>
		return problem "Missing command" unless cmd
		if f = @get_cmd cmd
			return f if is_bad f
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
				problem "Unknown command '#{cmd}'"
			when 1
				@cmds[matching_keys[1]]
			else
				problem "Ambiguous command '#{cmd}' can match any of: #{concat matching_keys, ', '}"
	cmd_keys: => [ k for k in pairs @cmds ]
	show_help: (prog_state) =>
		for cmd in pairs @cmds
			stderr\write "no help for #{cmd}\n" unless @help[cmd]
		prog_state.no_render_at_prompt = true
		Table sorted [ { cmd, @help[cmd] and (@help[cmd] @) or '' } for cmd in pairs @cmds ], (a,b) -> a[1] < b[1]

class QueryState
	new: (@maps, @abilities) =>
		@map = nil
		@zone = nil
		@ability = nil
		@usage = nil
	reset: =>
		@map = named_get @maps, 1
		@zone = @map and named_get @map.zones, 1
		@ability = named_get @abilities, 1
		@usage = @ability and named_get @ability.usages, 1
	is_complete: => @map and @zone and @ability and @usage
	@load: (maps, abilities, state) =>
		with QueryState maps, abilities
			if state
				.map = named_get .maps, state.map
				.zone = .map and named_get .map.zones, state.zone
				.ability = named_get .abilities, state.ability
				.usage = .ability and named_get .ability.usages, state.usage
	save: => {
			map: @map and @map.name
			zone: @zone and @zone.name
			ability: @ability and @ability.name
			usage: @usage and @usage.name
		}
	__eq: (s) => @map == s.map and @zone == s.zone and @ability == s.ability and @usage == s.usage


class ProgState
	new: =>
		@maps = {}
		@abilities = {}
		@query_state = QueryState @maps, @abilities
		@progress = Progress @maps, @abilities
		@no_render_at_prompt = false
	save: (file=DEFAULT_SAVE_FILE) =>
		with open file, 'w+'
			\write dump {{
				maps: [ m\save! for m in *@maps ]
				abilities: [ a\save! for a in *@abilities ]
				progress: @progress\save!
				query_state: @query_state\save!
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
			@query_state = QueryState\load @maps, @abilities, data.query_state
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
				unless (is_bad @prev_rc) or @no_render_at_prompt
					if pr = @progress\render @query_state
						stdout\write '\x1b[H\x1b[2J'
						print pr
				@no_render_at_prompt = false
				write @prompt!
				resp = read!
				unless resp
					print!
					return 0
				for cmd in resp\gmatch '%s*([^;]*);*'
					@prev_rc = @execute unpack [ w for w in cmd\gmatch '%s*([^%s]+)' ]
					switch @prev_rc
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
	prompt_end: '??? '
	prompt_inter: '???'
	prompt_initial: ' '
	prompt: =>
		sb = StringBuilder!
		prompt_data = {}
		if @query_state.map
			insert prompt_data, with Coloured " #{@query_state.map} "
				\bg 'green'
		if @query_state.zone
			insert prompt_data, with Coloured " #{@query_state.zone} "
				\bg 'blue'
		if @query_state.ability
			insert prompt_data, with Coloured " #{@query_state.ability} "
				\bg 'cyan'
		if @query_state.usage
			insert prompt_data, with Coloured " #{@query_state.usage} "
				\bg 'purple'
		if is_bad @prev_rc
			insert prompt_data, with Coloured " ! "
				\bg 'red'
				\bold!
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
			local err
			with @query_state
				.zone = nil
				if map
					tmap, err = named_get @maps, map
					.map = tmap unless err
				else
					.map = nil
			err
		zone: (zone) =>
			local err
			with @query_state
				unless .map
					.zone = nil
					return problem "Zone requires a map"
				if zone
					tzone, err = named_get .map.zones, zone
					.zone = tzone unless err
				else
					.zone = nil
			err
		ability: (ability) =>
			local err
			with @query_state
				.usage = nil
				if ability
					tability, err = named_get @abilities, ability
					.ability = tability unless err
				else
					.ability = nil
			err
		usage: (usage) =>
			local err
			with @query_state
				unless .ability
					.usage = nil
					return problem "Usage requires an ability"
				if usage
					tusage, err = named_get .ability.usages, usage
					.usage = tusage unless err
				else
					.usage = nil
			err
		reset: => @query_state\reset!
		state: => Table {
				{ "Map", @query_state.map or 'none' }
				{ "Zone", @query_state.zone or 'none' }
				{ "Ability", @query_state.ability or 'none' }
				{ "Usage", @query_state.usage or 'none' }
			}
		exit: => EXIT
		quit: => @execute 'exit'
		Save: => nil, @save!
		new: (...) =>
			cmds = Commands {
				map: (name) =>
					return problem "New map needs a name" unless name
					@query_state.map = Map name
					@progress\new_map @query_state.map
				zone: (name) =>
					return problem "New zone needs a name" unless name
					return problem "Cannot set zone without first setting a map!" unless @query_state.map
					@query_state.zone = Zone name
					@progress\new_zone @query_state.map, @query_state.zone
				ability: (name) =>
					return problem "New ability needs a name" unless name
					@query_state.ability = Ability name
					@progress\new_ability @query_state.ability
				usage: (name) =>
					return problem "New ability needs a name" unless name
					return problem "Cannot set usage without first setting an ability!" unless @query_state.ability
					@query_state.usage = Usage name
					@progress\new_usage @query_state.ability, @query_state.usage
			}, {
				map: => 'Create a new map'
				zone: => 'Create a new zone in the current map'
				ability: => 'Create a new ability'
				usage: => 'Create a new usage'
			}
			cmds @, ...
		list: (kind) =>
			if kind
				list_kind = (vs) -> concat [ tostring d for d in *vs ], '\n'
				kind_commands = Commands {
					maps: => list_kind @query_state.maps
					zones: =>
						return problem "Must specify a map" unless @query_state.map
						list_kind @query_state.map.zones
					abilities: => list_kind @abilities
					usages: =>
						return problem "Must specify an ability" unless @query_state.ability
						list_kind @query_state.ability.usages
				}, {
					maps: => 'List known maps'
					zones: => 'List known zones of the current map'
					abilities: => 'List known abilities'
					usages: => 'List known usages of the current ability'
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
			unless 0 < nargs
				@no_render_at_prompt = true
				stdout\write '\x1b[H\x1b[2J'
				return @progress\render @query_state, false
			update_command = (f) -> (...) ->
				return problem "Must specify what to update (progress or target)" unless 1 <= nargs
				return problem "Must specify an amount to update" unless 2 <= nargs
				f ...
			update_commands = Commands {
				progress: (how_much) => (update_command -> @progress\set_progress @query_state, how_much)!
				target: (how_much) => (update_command -> @progress\set_target @query_state, how_much)!
			}, {
				progress: => "Set progress to a specified amount or +/- to increment/decrement existing value"
				target: => "Set target to a specified amount or +/- to increment/decrement existing value"
			}
			update_commands @, ...
		'+': => @execute 'progress', 'progress', '+'
		'-': => @execute 'progress', 'progress', '-'
		'>': => @execute 'progress', 'target', '+'
		'<': => @execute 'progress', 'target', '-'
		'++': => @execute 'progress', 'progress', 'm'
		'--': => @execute 'progress', 'progress', '0'
		'>>': => @execute 'progress', 'target', 'm'
		'<<': => @execute 'progress', 'target', '0'
	}, {
		ability: => "Set the current ability to $1"
		exit: => "Exit the program"
		quit: => @help.exit @
		help: => "Display this help message"
		list: => "List available data, optionally specify the kind"
		map: => "Set the current map to $1"
		new: => "Add a new $1 called $2"
		progress: => "Show progress"
		reset: => "Reset the current query state"
		Save: => "Save changes"
		state: => "Print the current query state"
		usage: => "Set the current usage in the current ability to $1"
		zone: => "Set the current zone in the current map to $1"
		'+': => "Alias, executes 'progress progress +'"
		'-': => "Alias, executes 'progress progress -'"
		'>': => "Alias, executes 'progress target +'"
		'<': => "Alias, executes 'progress target -'"
		'++': => "Alias, executes 'progress progress m'"
		'--': => "Alias, executes 'progress progress 0'"
		'>>': => "Alias, executes 'progress target m'"
		'<<': => "Alias, executes 'progress target 0'"
	}

main = (...) ->
	local rc
	with ProgState!
		\load!
		rc = \loop {...}
		\save!
	exit rc

main ...
0
