# The Teal sources in src/ compile to lua/ and plugin/, which are committed
# so the plugin needs no build step to install. `make verify` (run in CI)
# fails when the committed Lua doesn't match a fresh build.

# Not $(NVIM): inside a :terminal that is the server socket, not a binary.
NVIM_BIN  ?= nvim
SHA256SUM ?= sha256sum

# Pinned compiler, fetched on first build. To upgrade, change both lines and
# delete .tools/; tl.lua is a single self-contained file.
TL_VERSION := v0.24.8
TL_SHA256  := ddb28d177f057ebe4face7aa69d92e9f8ad9bd17004fa88c53ec9370f1862c29
TL         := .tools/tl.lua

.PHONY: build check test verify

build: $(TL)
	$(NVIM_BIN) -l scripts/build.lua

# Type-check without writing anything.
check: $(TL)
	$(NVIM_BIN) -l scripts/build.lua --check

test:
	$(NVIM_BIN) -l tests/run.lua

verify: build
	@git diff --exit-code --stat -- lua plugin \
	  && test -z "$$(git ls-files --others --exclude-standard -- lua plugin)" \
	  || { echo 'lua/ or plugin/ is out of date with src/: run make and commit the result' >&2; exit 1; }

$(TL):
	mkdir -p $(@D)
	curl -fsSL https://raw.githubusercontent.com/teal-language/tl/$(TL_VERSION)/tl.lua -o $@.tmp
	echo '$(TL_SHA256)  $@.tmp' | $(SHA256SUM) -c --quiet
	mv $@.tmp $@
