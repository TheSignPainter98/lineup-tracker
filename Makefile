#!/usr/bin/make

.DEFAULT: lineup-tracker

BINDIR = /usr/bin

rwildcard=$(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))

MOONSCRIPT_SRCS = $(call rwildcard,src/,*.moon)
LUA_OBJS = $(subst .moon,.lua,$(MOONSCRIPT_SRCS))
OBJS = $(subst .moon,.o,$(MOONSCRIPT_SRCS))

lineup-tracker: $(LUA_OBJS)
	echo "#!/usr/bin/lua" > $@
	luac -o - $(subst .moon,.lua,$(shell ./po-lin $(subst .lua,.moon,$^))) >> $@; \
		[[ -f $@ ]] && chmod 700 $@ # luac seems to be memory-unsafe for multiple input files, but still outputs most of the time...
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

install: lineup-tracker
	install -Dm755 $< $(BINDIR)
.PHONY: install

clean:
	rm -f src/*.o src/*.mod src/*.lua lineup-tracker
.PHONY: clean

count:
	@wc -l $$(git ls-files) | sort -nr | head
.PHONY: count
