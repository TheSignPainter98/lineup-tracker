import is from assert

describe 'Progress model', ->
	it 'exists', -> is.table require 'src.model'

	describe 'map', ->
		setup ->
			import Map, Zone from require 'src.model'
			_G.Map = Map
			_G.Zone = Zone
		it 'exists', -> is.truthy Map
		describe 'instance', ->
			it 'has a name', -> is.same 'some_name', (Map 'some_name').name
			it 'takes zones', ->
				zones = { Zone'a', Zone'b' }
				is.same zones, (Map 'map', zones).zones
			it 'allows optional zones', -> is.same {}, Map!.zones
		it 'can be saved and loaded', ->
			z1 = Zone 'zone-1'
			z2 = Zone 'zone-2'
			raw = Map 'map', { z1, z2 }
			loaded = Map\load raw\save!
			is.same raw, loaded

	describe 'zone', ->
		setup ->
			import Zone from require 'src.model'
			_G.Zone = Zone
		it 'exists', -> is.truthy Zone
		describe 'instance', ->
			it 'has a name', -> is.same 'some_name', (Zone 'some_name').name
		it 'can be saved and loaded', ->
			raw = Zone 'z'
			loaded = Zone\load raw\save!
			is.same raw, loaded

	describe 'ability', ->
		setup ->
			import Ability, Usage from require 'src.model'
			_G.Ability = Ability
			_G.Usage = Usage
		it 'exists', -> is.truthy Ability
		describe 'instance', ->
			it 'has a name', -> is.same 'some_ability', (Ability 'some_ability').name
			it 'takes usages', ->
				usages = { Usage'a', Usage 'b' }
				is.same usages, (Ability 'ability', usages).usages
			it 'allows optional usages', -> is.same {}, Ability!.usages

		it 'can be saved and loaded', ->
			u1 = Usage 'usage-1'
			u2 = Usage 'usage-2'
			raw_ability = Ability 'ability-name', { u1, u2 }
			loaded_ability = Ability\load raw_ability\save!
			is.same raw_ability, loaded_ability

	describe 'usage', ->
		setup ->
			import Usage from require 'src.model'
			_G.Usage = Usage

		it 'exists', -> is.truthy Usage

		describe 'instance', ->
			it 'has a name', -> is.same 'some_usage', (Usage 'some_usage').name

		it 'can be saved and loaded', ->
			raw = Usage 'some-usage'
			loaded = Usage\load raw\save!
			is.same raw, loaded
