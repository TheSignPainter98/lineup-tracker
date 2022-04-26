#!/usr/bin/make

.DEFAULT: lineup-tracker

MOONSCRIPT_SRCS = $(shell find src/ -name '*.moon')
LUA_OBJS = $(subst .moon,.lua,$(MOONSCRIPT_SRCS))
OBJS = $(subst .moon,.o,$(MOONSCRIPT_SRCS))

lineup-tracker: $(LUA_OBJS)
	echo "#!/usr/bin/lua" > $@
	luac -o - $(subst .moon,.lua,$(shell ./po-lin $(subst .lua,.moon,$^))) >> $@
	chmod 700 $@
# .DELETE_ON_ERROR: lineup-tracker

%.luac: %.lua
	luac -o $@ $<
.INTERMEDIATE: %.o

%.lua: %.mod
	moonc -l $<
	moonc -- < $< > $@
.INTERMEDIATE: %.lua

%.mod: %.moon ./moon-to-mod
	./moon-to-mod -v module_name=$$(echo $< | sed 's|^src/||g' | sed 's|/|.|g' | sed 's/\.moon$$//') < $< > $@
.INTERMEDIATE: %.mod

%.moon:

clean:
	rm -f src/*.o src/*.mod src/*.lua lineup-tracker
.PHONY: clean

count:
	@wc -l $$(git ls-files) | sort -nr | head
.PHONY: count
