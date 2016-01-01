EXTRA_EXCLUDE := Makefile '.git/*' .gitmodules .gitignore update_dotfiles.sh

.PHONY: regenerate
regenerate: clean bundle.zip

bundle.zip:
	zip -r $@ . -x $@ ${EXTRA_EXCLUDE}

.PHONY: clean
clean:
	rm -f bundle.zip
