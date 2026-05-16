# Contributing to `lull`

Coding conventions for this repo. Modeled on `../lua/ezr.lua` + `../lua/lib.lua`.
Read those two files; this document records what they teach by example.

## Architecture: three layers

| Layer | File | Purpose | Depends on |
|---|---|---|---|
| **Utilities** | `src/lib.lua` | Generic helpers, no AI knowledge. CSV, sort, slice, map, math (welford), stats (KS, Cliff, ranks, entropy, mode), tiny histogram, CLI runner, rogue-globals check. | nothing |
| **AI core** | `src/lull.lua` | Shared AI building blocks: `the`, `Num`, `Sym`, `Cols`, `Data`, `add` / `adds` / `clone`, `mid` / `spread` / `norm` / `disty` / `wins`, `like` / `likes`, `tree` / `leaf` / `nodes` / `show`. | `lib` |
| **Apps** | `src/{nb,cbayes,kmeans,rtree,ctree,sa,ls,de,acquire}.lua` | One algorithm per file. Tiny when possible (`rtree`/`ctree` are a few lines binding shared `tree`). | `lull` (and transitively `lib`) |

**Promotion rule.** Apps never import other apps. If two apps need the same
helper, promote it: into `lull.lua` if it touches `Num`/`Sym`/`Data`/etc, into
`lib.lua` otherwise. A function lives in its app until a second app needs it.

So `welford`, `mode`, `entropy`, `sd`, `summary`, `bisect`, `ks`, `cliffsDelta`,
`same`, `bestRanks`, and the histogram all live in **`lib`** — they have nothing
to do with AI, just numbers.

### Tiny histogram (lives in `lib`)

`hist(xs, b, w)` rounds the values in `xs` to bins of width `b`, then prints
one row per bin with a bar scaled to a screen width of `w` characters.

```
  0.0 | ████████████             14
  0.5 | ████████████████████     24
  1.0 | ██████                    7
```

## Code philosophies

| Acronym | Name | Idea |
|---|---|---|
| **COI**  | Composition Over Inheritance | "part-of", not "is-a" |
| **SSOT** | Single Source of Truth | All config parsed from one `help` string |
| **BOB**  | Big On Brevity | Functions ≤ 5 lines when possible |
| **KISS** | Keep It Simple, Stupid | One function, one job |
| **BAIL** | Bail Early | One-line guard clauses |
| **GAP**  | Signature Gap | 4 spaces between args and locals in signatures |
| **HINT** | Type Hinting | Variable names act as type tags |

### COI example

```lua
-- Cols is composed of lists of Num and Sym. No inheritance.
function Cols.new(names,    xs,ys,all,cls,col)
  xs, ys, all = {}, {}, {}
  for at,txt in ipairs(names) do
    cls = txt:find"^[A-Z]" and Num or Sym
    col = push(all, cls.new(txt, at)) ... end ... end
```

### SSOT example

```lua
local help = [[
  -s seed=1   random number seed
  -p p=2      distance coefficient
]]
cli(the, help)   -- the.seed, the.p now populated
```

### BOB example

```lua
function Num.add(i, v, w)
  if v=="?" then return v end
  i.n, i.mu, i.m2 = welford(i.n, i.mu, i.m2, v, w)
  return v end
```

### BAIL example

```lua
function Num.norm(i, v,    z)
  if v=="?" then return v end                 -- guard
  z = (v - i.mu) / (i:spread() + 1e-32)
  return 1/(1+math.exp(-1.7*max(-3, min(3, z)))) end
```

### GAP example

Four spaces between true arguments and internal locals. No spaces inside the
locals.

```lua
function Cols.new(names,    xs,ys,all,cls,col)
```

### HINT example

Variable names tell you the type. A reader of
`function f(num1, num2, row, cols)` knows the types without comments.

## Naming

### Casing

* `PascalCase` — class/container that also constructs (`Num`, `Sym`, `Data`,
  `Tree`, `Cols`). Holds methods. Construct via `Num.new(...)`.
* `camelCase` — instance variables and short function names (`num`, `data`,
  `bestRanks`, `treeCuts`).
* `snake_case` — avoided.
* `lower` — module-local helpers (`adds`, `eq`, `new`).

### Reserved / conventional identifiers

Standard Lua conventions first:

| Name | Meaning |
|---|---|
| `t` | input table (first arg of many helpers) |
| `u` | output table (built locally, returned) |
| `i` | **self** in methods. Never use for an integer. |
| `n` | integer count or index |
| `v` | generic scalar value |
| `k` | key |
| `fn`, `ok` | function callback / boolean flag |

AI / domain identifiers:

| Name | Meaning |
|---|---|
| `txt`, `txts` | text label / list of labels (column header strings, etc.) |
| `num`, `sym` | instance of `Num` / `Sym`. Use `num1`, `num2`, `num3` to disambiguate. |
| `data`, `node` | instance of `Data` / `Tree`. `data1`, `data2` if many. |
| `row`, `rows` | one row (list of cells) / list of rows. |
| `col`, `cols` | column object / list of columns. |
| `cut` | a split (partition) object. |
| `at` | index of a column inside a row (`col.at`). |
| `err` | residual, distance, delta. |
| `lo`, `hi` | numeric bounds. |
| `mu`, `sd`, `m2` | mean / stdev / sum-of-square-deltas (welford). |
| `vs` | list of generic values (e.g. numeric samples). |
| `xs`, `ys` | feature cols / goal cols **on a `Data` object**; in stats code, two samples being compared. |

## Layout

* **Indent:** 2 spaces. No tabs.
* **Width:** ≤ 65 columns. Hard to argue with code that fits next to a PDF.
* **Lonely `end`:** join `end` to the prior line when you can. `end end end` on
  one line is fine.
* **Density:** semicolons pack related statements; prefer `and`/`or` over `if`.

  ```lua
  if v~="?" then i:add(v, w or 1) end; return v
  ```

* **Signature GAP:** four spaces between arguments and locals; no spaces between
  the locals.

  ```lua
  function mink(vs,    err,n)
  ```

* **Section headers:** `-- ## Classes`, `-- ## Update`, `-- ## Query`,
  `-- ## Tree`, `-- ## Stats`, `-- ## CLI`, `-- ## Examples`, `-- ## Main`.

* **Comments:** before any function, one blank line, then one `--` line, then
  the function. No multi-line docstrings inside functions.

* **`adds` over hand-rolled accumulators.** When you find yourself writing
  `it = Num(); for _,x in pairs(t) do add(it, x) end; return it`, replace it
  with `return adds(t)`.

## Minimize `local`

Don't pepper every line with `local`. Declare all module-level locals once at
the top in a multi-assign block (see `ezr.lua` lines 27–36 for the pattern):

```lua
local the, b4, Num, Sym, Cols, Data, Tree,
      new, push, sort, map, keys,
      slice, shuffle, csv, weibull, o, fmt,
      min, max, floor =
        {}, {}, {}, {}, {}, {}, {},
        lib.new, lib.push, lib.sort,
        lib.map, lib.keys,
        lib.slice, lib.shuffle, lib.csv, lib.weibull,
        lib.o, lib.fmt,
        math.min, math.max, math.floor
```

After that, `function Num.add(i,v,w) ... end` defines a method on the
already-local `Num` — no `local` keyword needed. Reserve `local function` for
genuinely file-private helpers that didn't make the top block (`adds`, `eq`).

### `lib` shortcuts

Any `lib.X` function used more than once in a file gets a top-of-file shortcut
in that same multi-assign block. `fred = lib.fred`. Then refer to it as
`fred(...)` in the body, **not** `lib.fred(...)`. Faster to read, faster to run
(Lua local lookup is faster than table lookup).

### `self ==> i`

In every method, the receiver is named `i`. Never `self`, never `this`. Reading
`i.cols.x` is shorter than `self.cols.x` and reinforces the convention.

## Polymorphism pattern

One constructor helper, in `lib`:

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

Group methods by **lifecycle stage**, not by class. Stack same-name methods
together so polymorphism reads top-to-bottom:

```
-- ## Update
function Num.add(i, v, w)   ... end
function Sym.add(i, v, w)   ... end
function Cols.add(i, row, w) ... end
function Data.add(i, row, w) ... end
```

## App contract

Every app under `src/*.lua` (except `lib.lua` and `lull.lua`):

* `require"lib"` and `require"lull"` at the top.
* Exposes a CLI:

```
lua src/APP.lua [-t TRAIN] [-T TEST] --ACTION
```

* `-t TRAIN` optional. If absent, app may run an internal demo.
* `-T TEST`  optional. If absent, train-only behavior (e.g. print model summary).
* `--ACTION` selects one of `eg["--xxx"]` defined in the app.

### Output convention

Each run prints **exactly one line** of `k=v, k=v, …, file=BASENAME`. When
working with a data file, include at least:

```
n_test=…, n_train=…, x=…, y=…, file=BASENAME
```

(Basename only, no directory.) Extra metrics per app are fine. This format lets
shell orchestrators tee into `~/tmp/foo.log` and post-process with
`awk` / `bestRanks`.

## Experimentation

Train/test orchestration lives **outside** the Lua code, in `Makefile`.

1. Shuffle once. Tag each row with `# bin.N` suffix.
2. For each fold `n in 0..K-1`, write `train.n` and `test.n` (each prepended
   with the header row).
3. Run treatments in parallel via `xargs -P`.
4. Tee output to `~/tmp/EXPERIMENT.log`.
5. Per-experiment awk/lua reducer (also in Makefile) calls `bestRanks` for
   stats.

### Seeding

Be careful. `math.randomseed(the.seed)` per action makes a single run
reproducible, but if your Makefile invokes the same action N times without
varying the seed, you get **the same answer N times** — useless for statistics.
Either vary the seed across repeats (`-s seed=$$RANDOM`, or fold index) or seed
once at the start and let the noise compound across repeats. Pick one per
experiment and document it in the Makefile target.

## SSOT / CLI

Config lives in one `help` string parsed at startup. Format per line:

```
  -k key=default   description
```

`cli(the, help)` populates `the` from defaults, then overrides via `-k VAL` on
the command line.

## `eg` standards

Each app maintains a table `eg = {}` of named callbacks keyed by `--flag`.
Rules:

* **Callable two ways.** From the CLI as `lua APP.lua --foo`, and also directly
  in Lua (`require"APP".eg["--foo"]()`) for in-process composition.
* **One job each.** An eg either tests something (asserts) or demonstrates
  something (prints). Don't mix.
* **Tests assert.** A test eg uses `eq(actual, expected, "msg")` at least once.
  Name with `--testXxx`. Failure errors loudly; success silently bumps
  `_asserts`.
* **Demos print.** A demo eg prints (usually one line, see the app output
  convention). Name with `--xxx` (no `test` prefix).
* **Reads `the`.** Egs pull inputs from the shared config table — `the.f` for
  the data file, `the.seed` for the seed, etc. They take no positional args.
* **Minimal output.** One line for a demo, nothing for a passing test. No
  banners, no decorative headers — that's the experiment Makefile's job.
* **Fast.** A single eg must finish in under a second on a typical laptop.
  Heavy benchmarks belong in a Makefile target that orchestrates many short
  runs, not inside an eg.
* **Reproducible in isolation.** Each eg is re-runnable by name from the CLI
  and must give the same answer for the same `the.seed`.
* **`--all` runs everything.** Defined once per app: iterates the keys of `eg`
  (excluding `--all` itself), reseeds, runs, then prints
  `asserts passed: N`.

## File header

Each source file starts with:

```lua
#!/usr/bin/env lua
-- vim: ft=lua
-- NAME.lua : ONE-LINE DESCRIPTION
-- (c) 2026, Tim Menzies <timm@ieee.org>, MIT license
package.path = "./?.lua;" .. package.path
```

Optionally, also at the top: a **terse, Unix-`man`-style multi-line header**
describing usage, flags, and one-liner examples. This is the only place a
multi-line comment belongs. Keep it tight — think `man grep`, not a tutorial.

For `lib.lua`, follow the man-style header with a compact one-line-per-symbol
function index using the type hints from the naming table. Aim for ~70 chars
per line; group related calls. Example shape:

```lua
-- lib.lua : generic utilities + stats.
--
-- Tables : push(t,x):x   sort(t,fn?):t   slice(t,lo,hi,step):u
--          map(t,fn):u   kap(t,fn):u     keys(t):u   filter(t,p):u
--          shuffle(t):t  bisect(t,x):n   sum(t,fn):n
-- I/O    : csv(src):iter o(x):s   fmt=string.format  thing(s):v
-- Stats  : welford(n,mu,m2,v,w?):n,mu,m2   sd(n,m2):n
--          summary(xs):mu,sd  cliffsDelta(xs,ys):n   ks(xs,ys):n
--          same(xs,ys,eps,cliffs,ksconf):ok
--          bestRanks(dict,eps,cliffs,ksconf):u
--          mode(sym):v   entropy(sym):n   hist(xs,b,w)
-- CLI    : cli(the,help):the   run(the,eg)   rogues(b4)
-- OO     : new(mt,t):t
```

`fn?` = optional function. `:u` = returns the built output table. `:n,mu,m2` =
multi-return. Bare verbs (`hist`) return nothing useful.

## File footer

The bottom of every **app** file (not `lib`) is exactly:

```lua
-- ## Main
if (arg[0] or ""):match"APP%.lua" then
  cli(the, help)
  lib.run(the, eg)
  lib.rogues(b4) end
```

Notes:

* `cli` only runs when this file is invoked as a script — not when it's
  `require`'d from another app or from a test harness.
* The leak check (`rogues`) runs **after** the CLI dispatch, so any rogue
  globals leaked while an eg executed are still caught.
* `b4` is snapshotted at the top of the file, just after `package.path`:

  ```lua
  local b4 = {}
  for k,_ in pairs(_ENV) do b4[k] = true end
  ```

## Don't

* Don't add error handling for cases that can't happen. Trust internal contracts.
* Don't write multi-line docstrings inside functions. Use the file header.
* Don't import one app from another. Promote shared code to `lull` or `lib`.
* Don't put runtime assertions in hot loops; put them in `eg["--testXxx"]`.
* Don't reach for inheritance. Composition only.
* Don't sprinkle `local` everywhere. Top-of-file multi-assign block.
* Don't use `self`. Use `i`.
* Don't call `lib.X(...)` when you've already aliased it as `X` at the top.
