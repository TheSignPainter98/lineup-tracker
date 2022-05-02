rockspec_format = '3.0'
package = 'lineup-tracker'
version = '1.0.0-1'
description = {
	summary = 'A minimalist progress tracker for lineups',
	detailed = "lineup-tracker is a command-line program which allows a user to track a number of lineups which they know and would like to know at each given zone in each given map, for each usage of each of their character's ability.",
	license = "GPL-3",
	homepage = "https://github.com/TheSignPainter98/lineup-tracker",
	issues_url = "https://github.com/TheSignPainter98/lineup-tracker/issues",
	maintainer = "kcza",
	labels = {
		"valorant",
		"cs:go",
		"commandline",
		"spreadsheet",
		"game",
	}
}

source = {
	url = "git://github.com/TheSignPainter98/lineup-tracker.git",
	md5 = "1",
}

supported_platforms = { 'linux' }
dependencies = {
	'lyaml ~> 6.2'
}
build_dependencies = {
	'moonscript dev-1'
}

build = {
	type = "make",
	install_variables = {
		BINDIR = "~/.local/bin",
	},
	install_pass = false,
	install = {
		bin = {
			"lineup-tracker"
		},
	}
}

-- test = {
-- 	type = "busted",
-- }
