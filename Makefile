# A Makefile to create bundled outputs so that this repository can be
# used before git is installed.

BUNDLE=bundle.tar
COMPRESSED_BUNDLE=bundle.tar.gz

.PHONY: regenerate
regenerate: clean $(BUNDLE) $(COMPRESSED_BUNDLE)

$(BUNDLE):
	git submodule update --init --recursive  # make sure we're up to date
	tar cvf "$@" . \
		--exclude="$@" --exclude=".git*" \
		--transform 's/^\./dotfiles/' \
		;

$(COMPRESSED_BUNDLE): $(BUNDLE)
	gzip -c -k "$(BUNDLE)" > "$@"

.PHONY: clean
clean:
	rm -f "$(BUNDLE)" "$(COMPRESSED_BUNDLE)"
