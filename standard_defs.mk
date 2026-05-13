export ISOLATION_ID ?= local
PWD = $(shell pwd)

export MAKE_BIN ?= $(PWD)/bin

ORGANIZATION ?= $(shell git remote show -n origin | grep Fetch | \
	awk '{print $$NF}' | sed -e 's/git@github.com://' | \
	sed -e 's@https://github.com/@@' | awk -F'[/.]' '{print $$1}' )
REPO ?= $(shell git remote show -n origin | grep Fetch | awk '{print $$NF}' | \
	sed -e 's/git@github.com://' | sed -e 's@https://github.com/@@' | \
	awk -F'[/.]' '{print $$2}' )
VERSION ?= $(shell git describe | cut -c2-  )
LONG_VERSION ?= $(shell git describe --long --dirty | cut -c2- )

RELEASABLE != if [ "$(LONG_VERSION)" = "$(VERSION)" ] || \
	(echo "$(LONG_VERSION)" | grep -q dirty); then \
	  echo "no"; else echo "yes"; fi

MAVEN_REVISION != if [ "$(LONG_VERSION)" = "$(VERSION)" ] || \
	      (echo "$(LONG_VERSION)" | grep -q dirty); then \
	    bump_ver=$(VERSION); \
	    if [ -x bin/semver ]; then \
	      bump_ver=$$(bin/semver bump patch $(VERSION))-SNAPSHOT; \
	    elif command -v semver >/dev/null; then \
	      bump_ver=$$(command semver bump patch $(VERSION))-SNAPSHOT; \
	    fi; \
	    echo $$bump_ver ; \
	  else \
	    echo $(VERSION); \
	  fi

MARKERS = markers
CLEAN_DIRS = build markers target
GH ?= gh
GH_RELEASE = $(GH) release

##
# Standard targets used by this repository and its GitHub Actions workflows.
##

.PHONY: all
.DEFAULT: all
all: build test package analyze archive

.PHONY: clean
clean: clean_dirs

.PHONY: distclean
distclean: clean

.PHONY: build
build: $(MARKERS)/build_dirs

.PHONY: test
test: build

.PHONY: package
package: build

.PHONY: analyze
analyze:

.PHONY: archive
archive: $(MARKERS) archive_git

.PHONY: publish
publish: package

.PHONY: run
run: package

.PHONY: archive_git build/$(REPO)-$(VERSION).zip build/$(REPO)-$(VERSION).tgz
archive_git: build/$(REPO)-$(VERSION).zip build/$(REPO)-$(VERSION).tgz

$(MARKERS):
	mkdir -p $@

build/$(REPO)-$(VERSION).zip: $(MARKERS)/build_dirs
	if [ -d .git ]; then \
	  git archive HEAD --format=zip -9 --output=build/$(REPO)-$(VERSION).zip; \
	fi

build/$(REPO)-$(VERSION).tgz: $(MARKERS)/build_dirs
	if [ -d .git ]; then \
	  git archive HEAD --format=tar.gz -9 --output=build/$(REPO)-$(VERSION).tgz; \
	fi

$(MARKERS)/build_dirs:
	mkdir -p $(CLEAN_DIRS)
	mkdir -p build
	touch $@

.PHONY: clean_markers
clean_markers:
	rm -rf $(CLEAN_DIRS)

.PHONY: clean_dirs_standard
clean_dirs_standard:
	rm -rf $(CLEAN_DIRS)

.PHONY: clean_dirs
clean_dirs: clean_dirs_standard

$(MARKERS)/check_ignores:
	git check-ignore build
	git check-ignore $(MARKERS)
	@touch $@

.PHONY: what_version
what_version:
	@echo VERSION=$(VERSION)
	@echo LONG_VERSION=$(LONG_VERSION)
	@echo MAVEN_REVISION=$(MAVEN_REVISION)

.PHONY: gh-create-draft-release
gh-create-draft-release:
	if [ "$(RELEASABLE)" = "yes" ];then \
	  $(GH_RELEASE) create $(VERSION) -t "$(VERSION)" -F CHANGELOG.md; \
	fi
