# Convenience wrapper around the shell scripts, which can still be used if no Make.
SHELL = /usr/bin/env
.SHELLFLAGS = zsh -fc

NAME ?=
NAME_ARG := $(if $(NAME),--name $(NAME),)

.DEFAULT_GOAL: help

.PHONY: help # Displays this help message
help:
	@echo "Usage: make <target>\n"
	@echo "The following targets are supported:"
	@grep \
        -E '^\.PHONY: [a-zA-Z0-9_-]+ .*?# .*$$' \
        -- $(MAKEFILE_LIST) \
      | awk 'BEGIN {FS = "(: |#)"}; {printf " %-24s %s\n", $$2, $$3}' \
      | { [[ $$(command -v bat) ]] && bat -pplhelp || cat }

.PHONY: build # Compile into ./build (maintainer step)
build:
	./build.sh $(NAME_ARG)

.PHONY: install # Install to ~/Applications
install:
	./install.sh $(NAME_ARG)

.PHONY: uninstall # Remove app, CLI symlink, login item, state
uninstall:
	./uninstall.sh $(NAME_ARG)


.PHONY: test # Run the core test suite
test:
	./test/doppio_test.sh

.PHONY: clean # Remove ./build artifacts
clean:
	rm -rf build
