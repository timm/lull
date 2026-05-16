# Contributing to `lull`

Coding conventions for this repo. Modeled on `../lua/ezr.lua` + `../lua/lib.lua`.
Read those two files; this document records what they teach by example.

## Architecture: three layers

| Layer | File | Purpose | Depends on |
|---|---|---|---|
| **Utilities** | `src/lib.lua` | Generic helpers (no AI knowledge). CSV, sort, slice, map, stats (KS, Cliff, ranks), CLI runner, rogue-globals check. | nothing |
| **AI core** | `src/lull.lua` | Shared AI building blocks: `the`, `Num`, `Sym`, `Cols`, `Data`, `add`/`adds`/`clone`, `mid`/`spread`/`norm`/`disty`/`wins`, `like`/`likes`, `tree`/`leaf`/`nodes`/`show`. | `lib` |
| **Apps** | `src/{nb,cbayes,kmeans,rtree,ctree,sa,ls,de,acquire}.lua` | One algorithm per file. Tiny when possible (rtree/ctree are a few lines binding shared `tree`). | `lull` (and transitively `lib`) |

**Dependency rule:** apps never import other apps. If two apps need the same helper,
promote it: move into `lull.lua` (AI-aware) or `lib.lua` (generic). A function lives
in an app until a second app needs it.

## Code philosophies

| Acronym | Name | Idea |
|---|---|---|
| **COI** | Composition Over Inheritance | "part-of", not "is-a" |
| **SSOT** | Single Source of Truth | All config parsed from one `help` string |
| **ZIP** | Compressed Profile | Maximize logic per screen |
| **BOB** | Big On Brevity | Functions ≤ 5 lines when possible |
| **KISS** | Keep It Simple, Stupid | One function, one job |
| **BAIL** | Bail Early | One-line guard clauses |
| **GAP** | Signature Gap | 4 spaces between args and locals in signatures |
| **HINT** | Type Hinting | Variable names act as type tags |

## Naming

### Casing

* `PascalCase` — class/container that also constructs (`Num`, `Sym`, `Data`, `Tree`, `Cols`).
  Holds methods. Construct via `Num.new(...)`.
* `camelCase` — instance variables (`num`, `data`, `col`, `tree`).
* `snake_case` — avoided; prefer camelCase or no separator.
* `lower` — module-local helpers (`adds`, `eq`).

### Reserved / conventional identifiers

| Name | Meaning |
|---|---|
| `i` | self in methods. Never use for an integer. |
| `n` | integer / count / index |
| `s`, `v` | generic string / generic scalar |
| `fn`, `ok` | function callback / boolean flag |
| `num`, `sym` | instance of Num / Sym |
| `data`, `node` | instance of Data / Tree |
| `col`, `cut` | column object / split object |
| `at` | index inside a row (`col.at`) |
| `err` | residual, distance, or delta |
| `lo`, `hi` | numeric bounds |
| `mu`, `sd`, `m2` | mean / stdev / sum-of-sq-deltas |
| `ss`, `vs` | list of strings / list of values |
| `cols`, `rows` | list of columns / list of rows |
| `xs`, `ys` | feature cols / goal cols |

## Layout

* **Indent:** 2 spaces. No tabs.
* **Width:** ≤ 90 columns.
* **Lonely `end`:** join `end` to the prior line when possible. `end end end` on one line is fine.
* **Density:** semicolons pack related statements; prefer `and`/`or` shortcuts over `if`.
  `if v~="?" then i:add(v, w or 1) end; return v`
* **Signature GAP:** four spaces between arguments and locals; no spaces between locals.
  `function mink(vs,    err,n)`
* **Locality:** all standalone functions are `local` for speed and encapsulation.
* **Comments:** one blank line, then one `--` line, then the function. No multi-line docstrings.
* **Section headers:** `-- ## Classes`, `-- ## Update`, `-- ## Query`, `-- ## Tree`, `-- ## Stats`, `-- ## CLI`, `-- ## Examples`, `-- ## Main`.

## Object pattern

Single constructor helper:

```lua
function lib.new(mt, t)
  mt.__index = mt
  return setmetatable(t, mt) end
```

Each class is a plain table holding its methods. Construct via `Class.new(...)`:

```lua
function Num.new(txt, at)
  return new(Num, {txt=txt or "", at=at or 0,
                   n=0, mu=0, m2=0,
                   heaven=(txt or ""):find"-$" and 0 or 1}) end
```

Group methods by **lifecycle stage**, not by class. Stack same-name methods together
to make polymorphism visible:

```
-- ## Update
function Num.add(i, v, w) ... end
function Sym.add(i, v, w) ... end
function Cols.add(i, row, w) ... end
function Data.add(i, row, w) ... end
```

## App contract

Every app under `src/*.lua` (except `lib.lua` and `lull.lua`) exposes a CLI:

```
lua src/APP.lua [-t TRAIN] [-T TEST] --ACTION
```

* `-t TRAIN` optional. If absent, app may run an internal demo.
* `-T TEST` optional. If absent, train-only behavior (e.g. print model summary).
* `--ACTION` selects one of `eg["--xxx"]` defined in the app.

### Output convention

Each run prints **exactly one line** of `k=v, k=v, …, file=BASENAME`. When working
with a data file, include at least:

```
n_test=…, n_train=…, x=…, y=…, file=BASENAME
```

(Basename only, no directory.) Extra metrics per app are fine. This format lets
shell orchestrators tee into `~/tmp/foo.log` and post-process with `awk` /
`bestRanks`.

## Experimentation

Train/test orchestration lives **outside** the lua code, in `Makefile`. Pattern
(option-2 named-file prep, see CONTRIBUTE for details):

1. Shuffle once. Mark each row with `# bin.N` suffix.
2. For each fold `n in 0..K-1`, write `train.n` and `test.n` (each prepended with the header row).
3. Run treatments in parallel via `xargs -P`.
4. Tee output to `~/tmp/EXPERIMENT.log`.
5. Per-experiment awk/lua reducer (also in Makefile) calls `lib.bestRanks` for stats.

Reseed `math.randomseed(the.seed)` at the start of each action so any single line
is reproducible.

## SSOT / CLI

Config lives in one `help` string parsed at startup. Format per line:

```
  -k key=default   description
```

`lib.cli(the, help)` populates `the` from defaults, then overrides via `-k VAL` on
the command line.

## Examples / tests

Define under `eg["--name"]`:

```lua
eg["--testNum"] = function(    num)
  num = adds({1,2,3,4,5})
  eq(num:mid(), 3, "Num mid") end
```

`eq(a, b, msg)` increments a global `_asserts` counter on success; errors loudly on
failure. `eg["--all"]` runs every example except itself, reseeding per call, and
prints `asserts passed: N`.

## File header

Each source file starts with:

```lua
#!/usr/bin/env lua
-- vim: ft=lua
-- NAME.lua : ONE-LINE DESCRIPTION
-- (c) 2026, Tim Menzies <timm@ieee.org>, MIT license
package.path="./?.lua;"..package.path
```

Apps then snapshot the global namespace and check for leaks at exit:

```lua
local b4 = {}
for k,_ in pairs(_ENV) do b4[k] = true end
-- ... code ...
lib.rogues(b4)
```

## Don't

* Don't add error handling for cases that can't happen. Trust internal contracts.
* Don't write multi-line docstrings. One `--` line suffices.
* Don't import one app from another. Promote shared code to `lull` or `lib`.
* Don't add tests/checks that the code is "still working" via runtime asserts in
  hot loops. Put assertions in `eg["--testXxx"]` instead.
* Don't reach for OO inheritance. Composition only.
