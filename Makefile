# default make target if none is specified.
.DEFAULT_GOAL := list

# MARK: utility targets.

# list: list all available targets. See http://stackoverflow.com/questions/4219255/how-do-you-get-the-list-of-targets-in-a-makefile.
.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

# MARK: documentation targets.

.PHONY: doc
doc:
	@swift build
	sourcekitten doc --spm-module OS > OS.json
	sourcekitten doc --spm-module Kqueue > Kqueue.json
	sourcekitten doc --spm-module LowSockets > LowSockets.json
	jazzy \
		--clean \
		--min-acl internal \
		--sourcekitten-sourcefile OS.json \
		--module OS \
		--output docs/OS
	jazzy \
		--clean \
		--min-acl internal \
		--sourcekitten-sourcefile Kqueue.json \
		--module Kqueue \
		--output docs/Kqueue
	jazzy \
		--clean \
		--min-acl internal \
		--sourcekitten-sourcefile LowSockets.json \
		--module LowSockets \
		--output docs/LowSockets

.PHONY: serve-doc
serve-doc:
	caddy -root docs/

# MARK: test targets

.PHONY: test-cov
test-cov:
	@swift package generate-xcodeproj
	@xcodebuild -scheme Networking -derivedDataPath .build/xcode -enableCodeCoverage YES test
	@xcov --scheme Networking --configuration Debug --derived_data_path .build/xcode --skip_slack --markdown_report
	@rm -rf .build/xcode
	@open xcov_report/index.html

