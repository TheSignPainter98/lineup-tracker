local *

import max from math
import problem from require 'src.prog-stat'
import rep from string
import concat, insert, sort, unpack from table

class StringBuilder
	new: (@content={}) => -- @content is has type T where T <: primitive | [T] | {__tostring: => str}
	get_contents: => @content
	extend: (cs, d) =>
		if d
			return if #cs == 0
			insert @content, cs[1]
			for i=2,#cs
				insert @content, d
				insert @content, cs[i]
		else
			insert @content, c for c in *cs
	__concat: (s) =>
		insert @content, s
		@
	__call: =>
		flattened = {}
		flatten = (o) ->
			if 'table' == type o
				mt = getmetatable o
				if mt and mt.__tostring
					s = tostring o
					insert flattened, s unless s == ''
				else
					flatten e for e in *o
			else
				insert flattened, o if o != nil and o != ''
		flatten @content
		concat flattened

sorted = (t, ...) ->
	sort t, ...
	t

-- with getmetatable ''
-- 	.__mul = rep
-- 	.__index = (i) => @sub i, i

class Set
	new: (data) => @data = { d, true for d in *data }
	__index: (k) => @data[k] != nil

class Table
	new: (@data={}) =>
		@_hrules = {}
		@_vrules = {}
		@_halign = {}
		@_valign = {}
		@_margin = 4
	hrules: (hrules) => @_hrules = Set hrules
	vrules: (vrules) => @_vrules = Set vrules
	halign: (halign) =>
		halign = { halign\sub i, i for i=1,#halign} if 'string' == type halign
		@_halign = halign
	valign: (valign) =>
		halign = { halign\sub i, i for i=1,#halign} if 'string' == type halign
		@_valign = valign
	margin: (@_margin) =>
	_set_alignment: (direc, val) =>
		val = { val\sub i, i for i=1,#val} if 'string' == type val
		@['_' .. direc] = val
	__index: (i) => @data[i]
	row: (i) => @data[i]
	col: (j) => [ @data[i][j] for i = 1, #@data ]
	add: (row) => @__add row
	__add: (row) =>
		if @data[1] and #row != #@data[1]
			error "Added row has wrong number of columns: got #{#row}, expected #{#@data[1]}"
		@data[#@data + 1] = row
	__tostring: => @render!
	render: =>
		return '' if #@data == 0
		ncols = #@data[1]
		for num,row in ipairs @data
			if #row != ncols
				error "Table is not a rectangle: row #{num} has #{#row} fields, expected #{ncols}"

		strtab = [ [ tostring cell for cell in *row ] for row in *@data ]
		lens = [ [ #cell for cell in *row ] for row in *strtab ]
		col_lens = [ max unpack [ #strtab[i][j] for i = 1, #strtab ] for j = 1, #strtab[1] ]

		sb = StringBuilder!
		nrows = #strtab
		ncols = #strtab[1]
		for rownum, row in ipairs @data
			for col,cell in ipairs row
				margin_width = col == ncols and 0 or @_margin
				switch type cell
					when 'table'
						sb ..= cell\render margin_width + col_lens[col]
					else
						scell = tostring cell
						sb ..= scell
						sb ..= ' '\rep margin_width + col_lens[col] - #scell
			sb ..= '\n' if rownum != nrows
		sb!

ansi_colour = (colour, area, effect) ->
	if colour
		if effect
			"\x1b[#{effect};#{area}#{colour}m"
		else
			"\x1b[#{area}#{colour}m"
	else
		''

class Coloured
	new: (@str) =>
		@_fg = nil
		@_bg = nil
		@_bf = 0
		@_fgi = 3
		@_bgi = 4
		@@uncolours = { v, k for k, v in pairs @colours } unless @@uncolours
	render: (width=#@str) =>
		width -= #@str
		fg = ansi_colour @_fg, @_fgi, @_bf
		if not @_fg and @_bf != 0
			fg = ansi_colour @colours['white'], @_fgi, @_bf
		bg = ansi_colour @_bg, @_bgi, @_bgi == 10 and 0 or nil
		fg .. bg .. @str .. (' '\rep width) .. '\x1b[0m'
	__tostring: => @str
	fg: (fg) =>
		@_fg = @colours[fg]
		@
	hifg: (hifg=true) =>
		@_fgi = hifg and 9 or 3
		@
	bg: (bg) =>
		@_bg = @colours[bg]
		@
	hibg: (hibg=true) =>
		@_bgi = hibg and 10 or 4
		@
	bold: (bf=true) =>
		@_bf = bf and 1 or 0
		@
	get: (field) =>
		fields = {
			fg: -> @@uncolours[@_fg]
			bg: -> @@uncolours[@_bg]
			bf: -> @_bf != 0
			fgi: -> @_fgi != 3
			bgi: -> @_bgi != 4
		}
		fields[field]!
	colours:
		black: 0
		red: 1
		green: 2
		yellow: 3
		blue: 4
		purple: 5
		cyan: 6
		white: 7

insert_sorted = (list, thing, key=(v)->v) ->
	insertion_point = #list + 1
	for i = 1, #list
		if (key thing) < key list[i]
			insertion_point = i
			break
	insert list, insertion_point, thing

named_get = (list, id) ->
	if ('string' != type id) or id\match '^%d+$'
		if e = list[tonumber id]
			return e, nil
	for elem in *list
		if elem.name == id
			return elem, nil
	nil, problem "Unknown ID: #{id}"

is_list = (l) ->
	type = type
	if (type l) != 'table'
		return false
	maxk = -1
	for k,_ in pairs l
		if (type k) != 'number'
			return false
		maxk = k if maxk < k
	maxk == #l

show = (v) ->
	switch type v
		when 'boolean', 'nil', 'number', 'thread'
			tostring(v)
		when 'function', 'userdata'
			"(#{tostring(v)})"
		when 'string'
			"'#{v}'"
		when 'table'
			if 'function' == type v.show
				return v\show!
			if is_list v
				return '[' .. (concat [ show e for e in *v ], ',') .. ']'
			return '{' .. (concat [ (show e) .. ':' .. show val for e,val in pairs v ], ',') .. '}'
		else
			error 'Unknown type', type v

eq = (a,b) ->
	ta = type a
	tb = type b
	if ta != tb
		return false

	if ta != 'table' and tb != 'table'
		return a == b

	mt = getmetatable a
	if mt and mt.__eq
		return a == b

	for k1,v1 in pairs a
		v2 = b[k1]
		if v2 == nil or not eq v1,v2
			return false

	for k2,v2 in pairs b
		v1 = a[k2]
		if v1 == nil or not eq v1,v2
			return false
	true

{ :Coloured, :eq, :insert_sorted, :is_list, :named_get, :StringBuilder, :show, :sorted, :Table }
