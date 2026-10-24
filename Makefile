.PHONY: lint test install uninstall

lint:
	shellcheck dirpin.sh install.sh uninstall.sh

test:
	bats test/

install:
	./install.sh

uninstall:
	./uninstall.sh
