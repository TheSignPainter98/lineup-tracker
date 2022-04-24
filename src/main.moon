import currentdir from require 'lfs'
package.path ..= ";#{currentdir!}/src/?.o"
-- package.path ..= ";#{currentdir!}/src/?.moon"

import read, open, stderr, write from io
import max from math
import exit from os
import dump, load from require 'lyaml'
import Ability, Map, Usage, Zone from require 'model'
import insert_sorted, named_get, sorted, StringBuilder, Table from require 'util'
import concat, unpack from table

DEFAULT_SAVE_FILE = '.progress.yml'

FAIL = 1
EXIT = -1
PASS = 0

class ProgState
	new: =>
		@maps = {}
		@abilities = {}
	save: (file=DEFAULT_SAVE_FILE) =>
		with open file, 'w+'
			\write dump {{
				maps: [ m\save! for m in *@maps ]
				abilities: [ a\save! for a in *@abilities ]
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
				write @prompt! .. " "
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
	prompt_end: '$'
	prompt: =>
		sb = StringBuilder!
		sb ..= @map
		sb ..= ":#{@zone}" if @zone
		sb ..= ":#{@ability}" if @ability
		sb ..= ":#{@usage}" if @usage
		sb ..= @prompt_end
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
		help: => Table sorted [ { cmd, @help[cmd]! } for cmd in pairs @cmds ], (a,b) -> a[1] < b[1]
		state: => Table {
				{ "Map", @map or 'none' }
				{ "Zone", @zone or 'none' }
				{ "Ability", @ability or 'none' }
				{ "Usage", @usage or 'none' }
			}
		exit: => EXIT
		quit: => @cmds.exit @
		new: (kind, name) =>
			unless kind
				@problem "Need a kind of data to add!"
			switch kind\lower!
				when 'map'
					insert_sorted @maps, Map name
				when 'zone'
					unless @map
						@problem "Cannot set zone without first setting a map!"
					@map ..= Zone name
				when 'ability'
					insert_sorted @abilities, Ability name
				when 'usage'
					unless @ability
						@problem "Cannot set usage without first setting an ability!"
					@ability ..= Usage name
		list: (kind) =>
			if kind
				if kind\match '^_'
					@problem "Invalid data kind: #{kind}\n"
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
	cmd_keys: => [ k for k in pairs @cmds ]
	help:
		ability: => "Set the current ability to $1"
		exit: => "Exit the program"
		quit: => @help.exit @
		help: => "Display this help message"
		list: => "List available data, optionally specify the kind"
		map: => "Set the current map to $1"
		new: => "Add a new $1 called $2"
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
