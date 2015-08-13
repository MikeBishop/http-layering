# Original makefile from https://github.com/martinthomson/i-d-template

# The following tools are used by this file.
# All are assumed to be on the path, but you can override these
# in the environment, or command line.

# Mandatory:
#   https://pypi.python.org/pypi/xml2rfc
xml2rfc ?= xml2rfc

# If you are using markdown files:
#   https://github.com/cabo/kramdown-rfc2629
kramdown-rfc2629 ?= kramdown-rfc2629

# If you are using outline files:
#   https://github.com/Juniper/libslax/tree/master/doc/oxtradoc
oxtradoc ?= oxtradoc.in

# For sanity checkout your draft:
#   https://tools.ietf.org/tools/idnits/
idnits ?= idnits

# For diff:
#   https://tools.ietf.org/tools/rfcdiff/
rfcdiff ?= rfcdiff

# For generating PDF:
#   https://www.gnu.org/software/enscript/
enscript ?= enscript
#   http://www.ghostscript.com/
ps2pdf ?= ps2pdf

# Where to get references
XML_RESOURCE_ORG_PREFIX ?= http://xml2rfc.ietf.org/public/rfc


## Work out what to build

drafts := $(sort $(basename $(wildcard $(foreach pattern,? *-[-a-z]? *-?[a-z] *[a-z0-9]??,$(foreach ext,xml org md,draft-$(pattern).$(ext))))))

ifeq (,$(drafts))
$(warning No file named draft-*.md or draft-*.xml or draft-*.org)
$(error Read README.md for setup instructions)
endif

draft_types := $(foreach draft,$(drafts),$(suffix $(firstword $(wildcard $(draft).md $(draft).org $(draft).xml))))

f_prev_tag = $(shell git tag | grep '$(draft)-[0-9][0-9]' | tail -1 | sed -e"s/.*-//")
f_next_tag = $(if $(f_prev_tag),$(shell printf "%.2d" $$(( 1$(f_prev_tag) - 99)) ),00)
drafts_next := $(foreach draft,$(drafts),$(draft)-$(f_next_tag))
drafts_prev := $(foreach draft,$(drafts),$(draft)-$(f_prev_tag))

drafts_txt := $(addsuffix .txt,$(drafts))
drafts_html := $(addsuffix .html,$(drafts))
drafts_next_txt := $(addsuffix .txt,$(drafts_next))
drafts_prev_txt := $(addsuffix .txt,$(drafts_prev))

## Basic Targets
.PHONY: latest txt html pdf
latest: txt html
txt: $(drafts_txt)
html: $(drafts_html)
pdf: $(addsuffix .pdf,$(drafts))

## Basic Recipes
.INTERMEDIATE: $(addsuffix .xml,$(drafts))
%.xml: %.md
	XML_RESOURCE_ORG_PREFIX=$(XML_RESOURCE_ORG_PREFIX) \
	  $(kramdown-rfc2629) $< > $@

%.xml: %.org
	$(oxtradoc) -m outline-to-xml -n "$@" $< > $@

%.txt: %.xml
	$(xml2rfc) $< -o $@ --text

%.htmltmp: %.xml
	$(xml2rfc) $< -o $@ --html
%.html: %.htmltmp lib/addstyle.sed lib/style.css
	sed -f lib/addstyle.sed $< > $@

%.pdf: %.txt
	$(enscript) --margins 76::76: -B -q -p - $< | $(ps2pdf) - $@

## Turns the drafts into README.md
.PHONY: readme
readme: README.md
README.md: $(drafts_txt)
	@echo '```' > README.md
	@cat $^ >> README.md
	@echo '```' >> README.md

## Build copies of drafts for submission
.PHONY: submit
submit: $(drafts_next_txt)

define makerule_submit_xml =
$(1)
	sed -e"s/$$(basename $$<)-latest/$$(basename $$@)/" $$< > $$@
endef
submit_deps := $(join $(addsuffix .xml: ,$(drafts_next)),$(addsuffix .xml,$(drafts)))
$(foreach rule,$(submit_deps),$(eval $(call makerule_submit_xml,$(rule))))

## Check for validity
.PHONY: check idnits
check: idnits
idnits: $(drafts_next_txt)
	echo $^ | xargs -n 1 sh -c '$(idnits) $$0'

## Build diffs between the current draft versions and any previous version
# This is makefile magic that requires Make 4.0

draft_diffs := $(addprefix diff-,$(addsuffix .html,$(drafts)))
.PHONY: diff
diff: $(draft_diffs)

.INTERMEDIATE: $(join $(drafts_prev),$(draft_types))
define makerule_diff =
$$(word 1,$$(subst ~, ,$(1))): $$(word 2,$$(subst ~, ,$(1))) $$(word 3,$$(subst ~, ,$(1)))
	-$(rfcdiff) --html --stdout $$^ > $$@
endef
concat = $(join $(1),$(addprefix ~,$(2)))
diff_deps := $(call concat,$(draft_diffs),$(call concat,$(drafts_next_txt),$(drafts_prev_txt)))
$(foreach rule,$(diff_deps),$(eval $(call makerule_diff,$(rule))))

define makerule_prev =
.INTERMEDIATE: $$(word 1,$$(subst ~, ,$(1)))
$$(word 1,$$(subst ~, ,$(1))):
	git show $$(word 2,$$(subst ~, ,$(1))):$$(word 3,$$(subst ~, ,$(1))) > $$@
endef
drafts_prev_out := $(join $(drafts_prev),$(draft_types))
drafts_prev_in := $(join $(drafts),$(draft_types))
prev_versions := $(call concat,$(drafts_prev_out),$(call concat,$(drafts_prev),$(drafts_prev_in)))
$(foreach args,$(prev_versions),$(eval $(call makerule_prev,$(args))))

## Store a copy of any github issues

GITHUB_REPO = $(shell git ls-remote --get-url | sed -e 's/^.*github\.com.//;s/\.git$$//')
.PHONY: issues
issues:
	curl https://api.github.com/repos/$(GITHUB_REPO)/issues?state=open > $@.json

## Cleanup

COMMA := ,
.PHONY: clean
clean:
	-rm -f $(addsuffix .{txt$(COMMA)html$(COMMA)pdf},$(drafts)) index.html
	-rm -f $(addsuffix -[0-9][0-9].{xml$(COMMA)md$(COMMA)org$(COMMA)txt$(COMMA)html$(COMMA)pdf},$(drafts))
	-rm -f $(draft_diffs)
	-$(foreach draft,$(drafts),[ -f $(draft).md -o -f $(draft).org ] && rm -f $(draft).xml;)true

## Update this Makefile

# The prerequisites here are what is updated
.INTERMEDIATE: .i-d-template.diff
.PHONY: update
update: Makefile lib .gitignore SUBMITTING.md
	git diff --quiet -- $^ || \
	  (echo "You have uncommitted changes to:" $^ 1>&2; exit 1)
	-if [ -f .i-d-template ]; then \
	  git diff --exit-code $$(cat .i-d-template) -- $^ > .i-d-template.diff && \
	  rm -f .i-d-template.diff; \
	fi
	git remote | grep i-d-template > /dev/null || \
	  git remote add i-d-template https://github.com/martinthomson/i-d-template.git
	git fetch i-d-template
	[ -f .i-d-template ] && [ $$(git rev-parse i-d-template/master) = $$(cat .i-d-template) ] || \
	  git checkout i-d-template/master $^
	git diff --quiet -- $^ && rm -f .i-d-template.diff || \
	  git commit -m "Update of $^ from i-d-template/$$(git rev-parse i-d-template/master)" $^
	if [ -f .i-d-template.diff ]; then \
	  git apply .i-d-template.diff && \
	  git commit -m "Restoring local changes to $$(git diff --name-only $^ | paste -s -d ' ' -)" $^; \
	fi
	git rev-parse i-d-template/master > .i-d-template

## Update the gh-pages branch with useful files

GHPAGES_TMP := /tmp/ghpages$(shell echo $$$$)
.INTERMEDIATE: $(GHPAGES_TMP)
ifeq (,$(TRAVIS_COMMIT))
GIT_ORIG := $(shell git branch | grep '*' | cut -c 3-)
ifneq (,$(findstring detached from,$(GIT_ORIG)))
GIT_ORIG := $(shell git show -s --format='format:%H')
endif
else
GIT_ORIG := $(TRAVIS_COMMIT)
endif

# Only run upload if we are local or on the master branch
IS_LOCAL := $(if $(TRAVIS),,true)
ifeq (master,$(TRAVIS_BRANCH))
IS_MASTER := $(findstring false,$(TRAVIS_PULL_REQUEST))
else
IS_MASTER :=
endif

define INDEX_HTML =
<!DOCTYPE html>\n\
<html>\n\
<head><title>$(GITHUB_REPO) drafts</title></head>\n\
<body><ul>\n\
$(foreach draft,$(drafts),<li><a href="$(draft).html">$(draft)</a> (<a href="$(draft).txt">txt</a>)</li>\n)\
</ul></body>\n\
</html>
endef

index.html: $(drafts_html) $(drafts_txt)
ifeq (1,$(words $(drafts)))
	cp $< $@
else
	echo -e '$(INDEX_HTML)' >$@
endif

.PHONY: ghpages
ghpages: index.html $(drafts_html) $(drafts_txt)
ifneq (true,$(TRAVIS))
	@git show-ref refs/heads/gh-pages > /dev/null 2>&1 || \
	  ! echo 'Error: No gh-pages branch, run `make setup-ghpages` to initialize it.'
endif
ifneq (,$(or $(IS_LOCAL),$(IS_MASTER)))
	mkdir $(GHPAGES_TMP)
	cp -f $^ $(GHPAGES_TMP)
	git clean -qfdX
ifeq (true,$(TRAVIS))
	git config user.email "ci-bot@example.com"
	git config user.name "Travis CI Bot"
	git checkout -q --orphan gh-pages
	git rm -qr --cached .
	git clean -qfd
	git pull -qf origin gh-pages --depth=5
else
	git checkout gh-pages
	git pull
endif
	mv -f $(GHPAGES_TMP)/* $(CURDIR)
	git add $^
	if test `git status -s | wc -l` -gt 0; then git commit -m "Script updating gh-pages."; fi
ifneq (,$(GH_TOKEN))
	@echo git push https://github.com/$(TRAVIS_REPO_SLUG).git gh-pages
	@git push https://$(GH_TOKEN)@github.com/$(TRAVIS_REPO_SLUG).git gh-pages
endif
	-git checkout -qf "$(GIT_ORIG)"
	-rm -rf $(GHPAGES_TMP)
endif

.PHONY: setup-ghpages
setup-ghpages:
# Check if the gh-pages branch already exists locally
	@if git show-ref refs/heads/gh-pages >/dev/null 2>&1; then \
	  ! echo "Error: gh-pages branch already exists"; \
	else true; fi
# Check if the gh-pages branch already exists on origin
	@if git show-ref origin/gh-pages >/dev/null 2>&1; then \
	  echo 'Warning: gh-pages already present on the origin'; \
	  git branch gh-pages origin/gh-pages; false; \
	else true; fi
	@echo "Initializing gh-pages branch"
	git checkout --orphan gh-pages
	git rm -rf .
	touch index.html
	git add index.html
	git commit -m "Automatic setup of gh-pages."
	git push --set-upstream origin gh-pages
	git checkout -qf "$(GIT_ORIG)"
