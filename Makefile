MAKEFILE_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
include $(MAKEFILE_DIR)/standard_defs.mk

all: package

clean:
	rm -rf dist

.PHONY: test test_bats
test: test_bats
	bash tests/run.sh

test_bats:
	tests/bats/bin/bats tests/*.bats

package: package_scripts

publish: package gh-create-draft-release
	if [ "$(RELEASABLE)" = "yes" ];then \
	  $(GH_RELEASE) upload $(VERSION) dist/*.tar.gz; \
	fi

.PHONY: package_scripts
package_scripts: dist/doc-$(VERSION).tar.gz dist/bin-$(VERSION).tar.gz dist/lib-$(VERSION).tar.gz


dist/doc-$(VERSION).tar.gz:
	mkdir -p dist/doc/bash
	for inc in $$(find bash -name \*.sh); do \
	  mdname=$$(echo $$inc | sed -e 's/\.sh/\.md/') ; \
	  bash/bashadoc $$inc > dist/doc/$$mdname ; done
	tar -zcf dist/doc-$(VERSION).tar.gz -C dist doc
	rm -rf dist/doc

dist/bin-$(VERSION).tar.gz:
	mkdir -p dist/bin
	for s in $$(find bash -type f -exec grep -q "includer" {} \; -print|grep -v ".sh$$"); do \
	  base=$$(basename $$s) ; \
	  bash/pack-script -v -f $$s -o dist/bin/$$base ; \
	done
	tar -zcf dist/bin-$(VERSION).tar.gz -C dist bin
	rm -rf dist/bin

dist/lib-$(VERSION).tar.gz:
	mkdir -p dist/lib
	cp bash/*.sh dist/lib
	tar -zcf dist/lib-$(VERSION).tar.gz -C dist lib
	rm -rf dist/lib
