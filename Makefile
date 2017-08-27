OS := $(shell uname | tr '[:upper:]' '[:lower:]')

# default make target if none is specified.
.DEFAULT_GOAL := list

# MARK: utility targets.

# list: list all available targets. See http://stackoverflow.com/questions/4219255/how-do-you-get-the-list-of-targets-in-a-makefile.
.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

# MARK: documentation targets.

# Generate documentation webpages.
.PHONY: doc
doc:
	@swift build
	sourcekitten doc --spm-module OS > OS.json
ifeq ($(OS), linux)
	sourcekitten doc --spm-module Epoll > Epoll.json
else
	sourcekitten doc --spm-module Kqueue > Kqueue.json
endif
	sourcekitten doc --spm-module LowSockets > LowSockets.json
	jazzy \
		--clean \
		--min-acl public \
		--sourcekitten-sourcefile OS.json \
		--module OS \
		--output docs/OS
	jazzy \
		--clean \
		--min-acl public \
		--sourcekitten-sourcefile LowSockets.json \
		--module LowSockets \
		--output docs/LowSockets
ifeq ($(OS), linux)
	jazzy \
		--clean \
		--min-acl public \
		--sourcekitten-sourcefile Epoll.json \
		--module Epoll \
		--output docs/Epoll
else
	jazzy \
		--clean \
		--min-acl public \
		--sourcekitten-sourcefile Kqueue.json \
		--module Kqueue \
		--output docs/Kqueue
endif

# Serve documentation websites via Caddy.
.PHONY: serve-doc
serve-doc:
	caddy -root docs/

# MARK: test targets

ifeq ($(OS), darwin)
# Generate test code coverage.
.PHONY: test-cov
test-cov:
		@swift package generate-xcodeproj
		@xcodebuild -scheme Networking -derivedDataPath .build/xcode -enableCodeCoverage YES test
		@xcov --scheme Networking --configuration Debug --derived_data_path .build/xcode --skip_slack --markdown_report
		@rm -rf .build/xcode
		@open xcov_report/index.html
endif
