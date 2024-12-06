SOURCES := $(wildcard switch/*/*.lua)
TARGETS := $(patsubst switch/%.lua, compiled/switch/%.lua, $(SOURCES))

.PHONY: all
all: $(TARGETS)

compiled/switch/%.lua: switch/%.lua
	@if not exist "$(dir $@)" mkdir "$(dir $@)"
	darklua process $< $@