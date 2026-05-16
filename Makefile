# vim: set ft=make ts=2 sw=2 noet :
# lull/Makefile -- dev shell, tasks, push.

SHELL    := /bin/bash
GIT_ROOT := $(shell git rev-parse --show-toplevel 2>/dev/null)
ETC      := $(GIT_ROOT)/etc

export GIT_ROOT
export ETC

## Defaults: override at command line, e.g. make tree O=cars.csv
DATA ?= $(GIT_ROOT)/data
SRC  ?= $(GIT_ROOT)/src
O    ?= $(DATA)/auto93.csv    # optimization file
C    ?= $(DATA)/diabetes.csv  # classification file

LULL  := lua $(SRC)/lull.lua
NB    := lua $(SRC)/nb.lua
Chars ?= 70

.PHONY: help the tree atree active check nb diabetes soybeans heart ncheck push sh

## ===========================================================
## help
## ===========================================================

help: ## show this help
	@awk 'BEGIN{FS=":.*##"; \
	            printf "\nusage: make TARGET [VAR=val]\n\n"} \
	      /^[a-zA-Z][a-zA-Z0-9_-]*:.*##/ { \
	            printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 \
	      }' $(MAKEFILE_LIST)
	@printf "\npdf: make ~/tmp/foo.pdf  (Chars=$(Chars))\n\n"

## ===========================================================
## lull.lua tasks
## ===========================================================

the: ## print *the* config
	@$(LULL) --the

tree: ## plain-budget tree on $$O
	@$(LULL) -f $(O) --tree

atree: ## active-learning tree on $$O
	@$(LULL) -f $(O) --atree

active: ## 20 active-learning train/test runs on $$O
	@$(LULL) -f $(O) --active

check: ## run lull.lua invariants on $$O
	@$(LULL) -f $(O) --check

## ===========================================================
## nb.lua tasks
## ===========================================================

nb: ## naive Bayes on $$C
	@$(NB) -f $(C) --nb

diabetes: ## NB on diabetes.csv
	@$(MAKE) -s nb C=$(DATA)/diabetes.csv

soybeans: ## NB on soybeans.csv
	@$(MAKE) -s nb C=$(DATA)/soybeans.csv

heart: ## NB on heart.c.csv
	@$(MAKE) -s nb C=$(DATA)/heart.c.csv

ncheck: ## run nb.lua assertions
	@$(NB) --check

## ===========================================================
## git
## ===========================================================

push: ## prompt msg + commit -am + push + status
	@read -p "Reason? " msg; \
	 git commit -am "$$msg" && git push && git status

## ===========================================================
## pdf  (make ANYDIR/foo.pdf  =>  finds foo.lua in cwd)
## ===========================================================

.SECONDEXPANSION:
%.pdf: $$(notdir $$*).lua $(ETC)/lu.ssh ## .lua -> .pdf via a2ps
	@mkdir -p $(@D); \
	 echo "pdf-ing $@ ..."; \
	 a2ps --pretty-print=$(ETC)/lu.ssh -Br --quiet --landscape \
	      --pro=color --chars-per-line=$(Chars) \
	      --line-numbers=1 --borders=no --columns=3 \
	      -M letter -o - $< | ps2pdf - $@; \
	 command -v open >/dev/null && open $@ || true

## ===========================================================
## dev shell  -- sources $(ETC)/bash.rc (which loads $(ETC)/nvim.lua)
## ===========================================================

YELLOW := \033[1;33m
CYAN   := \033[1;36m
DIM    := \033[2;37m
RESET  := \033[0m
CLS    := \033[H\033[2J\033[3J

sh: ## launch dev shell (banner + aliases + nvim)
	@printf "$(CLS)$(YELLOW)\n"
	@printf '          ___\n'
	@printf '       ,-"   "-.        ┌─────────────────────┐\n'
	@printf '      /  o   o  \\       │   l u l l           │\n'
	@printf '     |   .---.   |      │   learn by doing.   │\n'
	@printf '     |  ( ___ )  |      │   teach by lua.     │\n'
	@printf "      \\\\  '---'  /       └─────────────────────┘\n"
	@printf '       \`-.___.-\`\n'
	@printf '        / | | \\\n'
	@printf '       ~~~~~~~~~\n'
	@printf "$(CYAN)\n  'I hear and I forget."
	@printf "\n   I see and I remember."
	@printf "\n   I do and I understand.'   -- Confucius\n"
	@printf "$(DIM)\n   data: $(DATA)\n   etc:  $(ETC)\n$(RESET)\n"
	@GIT_ROOT=$(GIT_ROOT) ETC=$(ETC) DATA=$(DATA) bash --init-file $(ETC)/bash.rc -i
