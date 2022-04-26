import currentdir from require 'lfs'
package.path ..= ";#{currentdir!}/src/?.o"
-- package.path ..= ";#{currentdir!}/src/?.moon"

import read, open, stderr, write from io
import max from math
import exit from os
import dump, load from require 'lyaml'
import Ability, Map, Progress, Usage, Zone from require 'model'
import Coloured, insert_sorted, named_get, sorted, StringBuilder, Table from require 'util'
import concat, insert, unpack from table

DEFAULT_SAVE_FILE = '.progress.yml'

FAIL = 1
EXIT = -1
PASS = 0

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
			\fg last and (last\get 'bg') or 'cyan'
		sb ..= part\render! for part in *prompt_parts
		sb!
	execute: (cmd, ...) =>
		return PASS unless cmd
		cmd = cmd\gsub '-', '_'
		if f = @get_cmd cmd
			ret = (f @, ...)
			switch type ret
				when 'nil', 'integer', 'number'
					ret or PASS
				else
					print ret
					PASS
		else
			stderr\write "Unknown command '#{cmd}'\n"
			PASS
	get_cmd: (cmd) =>
		if f = @cmds[cmd]
			return f
		for cmd_key in *@cmd_keys!
			if cmd_key\match '^' .. cmd
				return @cmds[cmd_key]
	cmds:
		map: (map) =>
			@map = named_get @maps, map
			@zone = nil
		zone: (zone) =>
			unless @map
				@zone = nil
				return @problem "Zone requires a map"
			@zone = named_get @map.zones, zone
			@usage = nil
		ability: (ability) =>
			@ability = named_get @abilities, ability
			@usage = nil
		usage: (usage) =>
			unless @ability
				@usage = nil
				return @problem "Usage requies an ability"
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
		quit: => @cmds.exit @
		Save: => nil, @save!
		new: (kind, name) =>
			unless kind
				@problem "Need a kind of data to add!"
			switch kind\lower!
				when 'map'
					@map = Map name
					@progress\new_map @map
				when 'zone'
					unless @map
						@problem "Cannot set zone without first setting a map!"
					@zone = Zone name
					@progress\new_zone @map, @zone
				when 'ability'
					@ability = Ability name
					@progress\new_ability @ability
				when 'usage'
					unless @ability
						@problem "Cannot set usage without first setting an ability!"
					@usage = Usage name
					@progress\new_usage @ability, @usage
		list: (kind) =>
			if kind
				if kind\match '^_'
					return @problem "Invalid data kind: #{kind}\n"
				valid_kinds =
					maps: true
					zones: true
					abilities: true
					usages: true
				return @problem "Unknown data kind #{kind} expected one of: #{concat (sorted [ k for k in pairs valid_kinds ]), ', '}" unless valid_kinds[kind]
				return concat [ tostring d for d in *@[kind] ], '\n'
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
		progress: => @progress\render @map, @zone, @ability, @usage
		update: (what, how_much) =>
			unless @map and @zone and @ability and @usage
				return @problem "Must set a map, zone, ability and usage before updating a target!"
			switch what
				when 'progress'
					@progress\set_progress @map, @zone, @ability, @progress, how_much
				when 'target'
					@progress\set_target @map, @zone, @ability, @progress, how_much
				else
					@problem "Cannot update target #{what}: expected one of progress, target"
	cmd_keys: => [ k for k in pairs @cmds ]
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
	problem: (msg, fatal=false) =>
		stderr\write msg .. '\n'
		fatal and FAIL or PASS

main = (...) ->
	local rc
	with ProgState!
		\load!
		rc = \loop {...}
		\save!
	exit rc

main ...
0
