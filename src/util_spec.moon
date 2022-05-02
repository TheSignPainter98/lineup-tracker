import is from assert

describe 'Util', ->
	it 'exists', -> is.table require 'src.util'

	describe 'StringBuilder', ->
		setup ->
			import StringBuilder from require 'src.util'
			_G.StringBuilder = StringBuilder
		it 'exists', -> is.truthy StringBuilder

		describe 'instance', ->
			it 'defaults to building empty string', -> is.same '', StringBuilder!!
			it 'can take a default value', ->
				sb = StringBuilder { 'asdf', 'fdsa' }
				is.same 'asdffdsa', sb!
			it 'allows concatenation of strings', ->
				sb = StringBuilder!
				sb ..= '1234'
				sb ..= '4321'
				is.same '12344321', sb!

	describe 'sorted', ->
		setup ->
			import sorted from require 'src.util'
			_G.sorted = sorted
		it 'is a function', -> is.function sorted
		it 'sorts a list and returns it', ->
			to_sort = { 3, 5, 1, 6 }
			to_sort = sorted to_sort
			is.table to_sort
			for i=2,#to_sort
				is.true to_sort[i-1] < to_sort[i]

	describe 'Coloured', ->
		setup ->
			import Coloured from require 'src.util'
			_G.Coloured = Coloured
		it 'exists', -> is.truthy Coloured

		describe 'instance', ->
			it 'makes no change by default', -> is.same 'hello', tostring Coloured 'hello'
			it 'can have its foreground changed', ->
				c = Coloured 'hello'
				is.function c\fg
				c\fg 'blue'
				is.match '\x1b%[0;34mhello\x1b%[0m', c\render!
			it 'can be bold', ->
				c = Coloured 'hello'
				is.function c\bold
				c\bold!
				is.match '\x1b%[1;37mhello\x1b%[0m', c\render!

	describe 'Table', ->
		setup ->
			import Table from require 'src.util'
			_G.Table = Table
		it 'exists', -> is.truthy Table

		describe 'instance', ->
			it 'renders empty by default', -> is.same '', Table!\render!
			it 'can render single cell', ->
				with Table!
					\add { 'hello' }
					is.same 'hello', \render!
			it 'takes coloured data', ->
				with Table!
					\add {
						with Coloured 'hello'
							\fg 'blue'
					}
					is.match '\x1b%[0;34mhello\x1b%[0m', \render!
			it 'allows multi-col', ->
				with Table!
					\add { 'asdf', 'fdsa' }
					is.match 'asdf%s+fdsa', \render!
			it 'allows multi-row', ->
				with Table!
					\add { 'foo' }
					\add { 'bar' }
					is.match 'foo\nbar', \render!
			it 'allows multi-row and multi-col', ->
				with Table!
					\add { '1', '2' }
					\add { '3', '4' }
					is.match '^1%s+2\n3%s+4$', \render!
			it 'can take non-string and non-table cell values', ->
				with Table!
					\add { 1, 2, 3 }
					is.match '^1%s+2%s+3$', \render!
