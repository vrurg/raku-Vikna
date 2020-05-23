
.NOTPARALLEL:

SHELL = /bin/sh

export MAIN_MOD=Vikna
MAIN_MOD_FILE=$(addprefix lib/,$(addsuffix .rakumod,$(subst ::,/,$(MAIN_MOD))))
MOD_VER:=$(shell raku -Ilib -e 'use $(MAIN_MOD); $(MAIN_MOD).^ver.say')
MOD_NAME_PFX=$(MAIN_MOD)
MOD_DISTRO=$(MOD_NAME_PFX)-$(MOD_VER)
MOD_ARCH=$(MOD_DISTRO).tar.gz
META6_JSON=META6.json
META6_MOD_FILE=$(addprefix lib/,$(addsuffix /META.rakumod,$(subst ::,/,$(MAIN_MOD))))
BUILD_TOOLD_DIR=./build-tools
META_BUILDER=$(BUILD_TOOLD_DIR)/gen-META.raku
DOC_BUILDER=$(BUILD_TOOLD_DIR)/gen-doc.raku

PROVE_CMD=prove6
PROVE_FLAGS=-l -j4
TEST_DIRS=t
PROVE=$(PROVE_CMD) $(PROVE_FLAGS) $(TEST_DIRS)

DIST_FILES:=$(shell git ls-files)

CLEAN_FILES=$(MOD_NAME_PFX)-v*.tar.gz \
			META6.json.out

PRECOMP_DIRS=$(shell find . -type d -name '.precomp')
BK_FILES=$(shell find . -name '*.bk')
CLEAN_DIRS=$(PRECOMP_DIRS) $(BK_FILES) .test-repo

# Doc variables
DOC_DIR=doc
DOCS_DIR=docs
MD_DIR=$(DOCS_DIR)/md
HTML_DIR=$(DOCS_DIR)/html
DOCS_SUBDIRS=$(shell find lib -type d -name '.*' -prune -o -type d -printf '%P\n')
MD_SUBDIRS:=$(addprefix $(MD_DIR)/,$(DOCS_SUBDIRS))
HTML_SUBDIRS:=$(addprefix $(HTML_DIR)/,$(DOCS_SUBDIRS))
PM_SRC=$(shell find lib -name '*.rakumod' | xargs grep -l '^=begin')
POD_SRC=$(shell find doc -name '*.rakudoc' -and -not -name 'README.rakudoc')
DOC_SRC=$(POD_SRC) $(PM_SRC)
DOC_DEST=$(shell find lib doc \( -name '*.rakumod' -o \( -name '*.rakudoc' -and -not -name 'README.rakudoc' \) \) | xargs grep -l '^=begin' | sed 's,^[^/]*/,,')

.SUFFXES: .md .rakudoc

vpath %.rakumod $(dir $(PM_SRC))
vpath %.rakudoc $(dir $(POD_SRC))

.PHONY: all html test author-test release-test is-repo-clean build depends depends-install release meta6_mod meta \
		archive upload clean install doc md html docs_dirs doc_gen version

tell_var:
	@echo $(MOD_VER)

#%.md $(addsuffix /%.md,$(MD_SUBDIRS)):: %.rakumod
#	@echo "===> Generating" $@ "of" $<
#	@raku -I lib --doc=Markdown $< >$@
#
#%.md $(addsuffix /%.md,$(MD_SUBDIRS)):: %.rakudoc
#	@echo "===> Generating" $@ "of" $<
#	@raku -I lib --doc=Markdown $< >$@
#
#%.html $(addsuffix /%.html,$(HTML_SUBDIRS)):: %.rakumod
#	@echo "===> Generating" $@ "of" $<
#	@raku -I lib --doc=HTML $< >$@
#
#%.html $(addsuffix /%.html,$(HTML_SUBDIRS)):: %.rakudoc
#	@echo "===> Generating" $@ "of" $<
#	@raku -I lib --doc=HTML $< >$@

all: release

$(DOC_BUILDER) $(META_BUILDER):
	@echo "===> Prepare submodule"
	@git submodule sync --quiet --recursive
	@git submodule init --quiet
	@git submodule update --quiet --recursive

doc: docs_dirs doc_gen

#docs_dirs: | $(MD_SUBDIRS) $(HTML_SUBDIRS)

docs_dirs: | $(MD_SUBDIRS)

$(MD_SUBDIRS) $(HTML_SUBDIRS):
	@echo "===> mkdir" $@
	@mkdir -p $@

doc_gen: $(DOC_BUILDER)
	@echo "===> Updating documentation sources"
	@raku $(DOC_BUILDER) -m=Vikna -md $(DOC_SRC)

#md: ./README.md $(addprefix $(MD_DIR)/,$(patsubst %.rakudoc,%.md,$(patsubst %.rakumod,%.md,$(DOC_DEST))))

#html: $(addprefix $(HTML_DIR)/,$(patsubst %.rakudoc,%.html,$(patsubst %.rakumod,%.html,$(DOC_DEST))))

test:
	@echo "===> Testing"
	@$(PROVE)

author-test:
	@echo "===> Author testing"
	@AUTHOR_TESTING=1 $(PROVE)

release-test:
	@echo "===> Release testing"
	@RELEASE_TESTING=1 $(PROVE)

is-repo-clean:
	@git diff-index --quiet HEAD || (echo "*ERROR* Repository is not clean, commit your changes first!"; exit 1)

build: depends doc

depends: meta depends-install

depends-install:
	@echo "===> Installing dependencies"
	@zef install META6 p6doc Pod::To::Markdown Async::Workers
	@zef --deps-only install .

version: doc meta clean
#	@git add . && git commit -m 'Minor: version bump'

release: build is-repo-clean release-test archive
	@echo "===> Done releasing"

meta6_mod:
	@zef locate META6 2>&1 >/dev/null || (echo "===> Installing META6"; zef install META6)

meta: meta6_mod $(META_BUILDER) $(META6_JSON)

archive: $(MOD_ARCH)

$(MOD_ARCH): $(DIST_FILES)
	@echo "===> Creating release archive" $(MOD_ARCH)
	@echo "Generating release archive will tag the HEAD with current module version."
	@echo "Consider carefully if this is really what you want!"
	@/bin/sh -c 'read -p "Do you really want to tag? (y/N) " answer; [ $$answer = "Y" -o $$answer = "y" ]'
	@git tag -f $(MOD_VER) HEAD
	@git push -f --tags
	@git archive --prefix="$(MOD_DISTRO)/" -o $(MOD_ARCH) $(MOD_VER)

$(META6_JSON): $(META_BUILDER) $(MAIN_MOD_FILE) $(META6_MOD_FILE)
	@echo "===> Generating $(META6_JSON)"
	@echo $(META6_MOD_FILE)
	@$(META_BUILDER) $(MAIN_MOD) >$(META6_JSON).out && cp $(META6_JSON).out $(META6_JSON)
	@rm $(META6_JSON).out

upload: release
	@echo "===> Uploading to CPAN"
	@/bin/sh -c 'read -p "Do you really want to upload to CPAN? (y/N) " answer; [ $$answer = "Y" -o $$answer = "y" ]'
	@cpan-upload -d Perl6 --md5 $(MOD_ARCH)
	@echo "===> Uploaded."

clean:
	@echo "===> Cleaning " $(CLEAN_FILES) $(CLEAN_DIRS)
	@rm -f $(CLEAN_FILES)
	@rm -rf $(CLEAN_DIRS)

install: build
	@echo "===> Installing"
	@zef install .
