#!/usr/bin/make

.DEFAULT: lineup-tracker

BINDIR = /usr/bin

rwildcard=$(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))

MOONSCRIPT_SRCS = $(filter-out %_spec.moon,$(call rwildcard,src,*.moon))
MOONSCRIPT_CHECK_SRCS = $(call rwildcard,src,*.moon)
LUA_OBJS = $(subst .moon,.lua,$(MOONSCRIPT_SRCS))
LUA_CHECK_OBJS = $(subst .moon,.lua,$(MOONSCRIPT_CHECK_SRCS))
OBJS = $(subst .moon,.o,$(MOONSCRIPT_SRCS))

lineup-tracker: lineup-tracker.lua
	echo "#!/usr/bin/lua" > $@
	luac -o - $< >> $@
	chmod 700 $@
.DELETE_ON_ERROR: lineup-tracker

lineup-tracker.lua: $(LUA_OBJS)
	>$@
	cat $(subst .moon,.lua,$(shell ./po-lin $(subst .lua,.moon,$^))) >> $@
.INTERMEDIATE: lineup-tracker.lua

%.luac: %.lua
	luac -o $@ $<
.INTERMEDIATE: %.o

%.lua: %.mod
	moonc -l $<
	moonc -- < $< > $@
.INTERMEDIATE: %.lua

%.mod: %.moon ./moon-to-mod
	./moon-to-mod -v module_name=$$(echo $< | sed 's|/|.|g' | sed 's/\.moon$$//') < $< > $@
.INTERMEDIATE: %.mod

%.moon:

install: lineup-tracker
	install -Dm755 $< $(BINDIR)
.PHONY: install

clean:
	rm -f src/*.o src/*.mod src/*.lua lineup-tracker lineup-tracker.lua
.PHONY: clean

count:
	@wc -l $$(git ls-files) | sort -nr | head
.PHONY: count
