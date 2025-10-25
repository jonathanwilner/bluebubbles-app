EMACS ?= emacs
LOAD_PATH := $(abspath .)
TEST_DIR := $(LOAD_PATH)/tests

.PHONY: test byte-compile clean

test:
	$(EMACS) -Q -batch -L $(LOAD_PATH) -L $(TEST_DIR) -l bluebubbles-test-runner.el

byte-compile:
	$(EMACS) -Q -batch -L $(LOAD_PATH) -f batch-byte-compile bluebubbles.el

clean:
	rm -f *.elc tests/*.elc
