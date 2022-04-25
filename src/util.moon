import max from math
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

MARGIN = 4
class Table
	new: (@data={}) =>
		@_hrules = {}
		@_vrules = {}
		@_halign = {}
		@_valign = {}
	hrules: (hrules) => @_hrules = Set hrules
	vrules: (vrules) => @_vrules = Set vrules
	halign: (halign) =>
		halign = { halign\sub i, i for i=1,#halign} if 'string' == type halign
		@_halign = halign
	valign: (valign) =>
		@_halign = valign
	_set_alignment: (direc, val) =>
		val = { val\sub i, i for i=1,#val} if 'string' == type val
		@['_' .. direc] = val
	__index: (i) => @data[i]
	row: (i) => @data[i]
	col: (j) => [ @data[i][j] for i = 1, #@data ]
	__add: (row) =>
		if @data[1] and #row != #@data[1]
			error "Added row has wrong number of columns: got #{#row}, expected #{#@data[1]}"
	__tostring: =>
		ncols = #(@data[1] or {})
		for num,row in ipairs @data
			if #row != ncols
				error "Table is not a rectangle: row #{num} has #{#row} fields, expected #{ncols}"

		strtab = [ [ tostring cell for cell in *row ] for row in *@data ]
		col_lens = [ max unpack [ #cell for cell in *row ] for row in *strtab ]

		sb = StringBuilder!
		nrows = #strtab
		for rownum, row in ipairs strtab
			for col,cell in ipairs row
				switch type cell
					when 'table'
						sb ..= cell\render col_lens[col]
					else
						sb ..= cell
						sb ..= ' '\rep MARGIN + col_lens[col] - #cell
			sb ..= '\n' if rownum != nrows
		sb!

ansi_escape = (colour, area, category) ->
	if category
		"\033[#{category};#{area}#{colour}m"
	else
		"\033[#{area}#{colour}m"

class Cell
	new: (@str) =>
		@_fg = ''
		@_bg = ''
	render: (width) =>
		width -= #@str
		@_fg .. @_bg .. @str .. (' '\rep width) .. '\033[0m'
	fg: (fg) => @_fg = ansi_escape @colours[fg], 3, 0
	bg: (bg) => @_bg = ansi_escape @colours[bg], 4
	colours:
		black: 0
		red: 1
		green: 2
		yellow: 3
		blue: 4
		purple: 5
		cyan: 6
		white: 7

insert_sorted = (list, thing, cmp=(a,b) -> a < b) ->
	insertion_point = #list + 1
	for i = 1, #list
		print thing, list[i]
		if cmp thing, list[i]
			insertion_point = i
			break
	insert list, insertion_point, thing

named_get = (list, id) ->
	return list[tonumber id] if id\match '^%d+$'
	for elem in *list
		if elem.name == id
			return elem


{ :Cell, :insert_sorted, :named_get, :StringBuilder, :sorted, :Table }
