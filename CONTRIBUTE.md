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

* **Section headers:** small ASCII figlets via `figlet -f mini WORD`, each
  line prefixed with `-- `, followed by a blank `--` line, then the section's
  first description comment. Words: `OO`, `Tables`, `I/O`, `Math`, `Random`,
  `Prob`, `Stats`, `CLI`, `Runner`, `Examples`, `Main` (or whatever applies).
  Example:

  ```
  -- ___
  --  | _.|_ | _  _
  --  |(_||_)|(/__>
  --
  -- Append x; return x.
  function lib.push(t, x) ...
  ```

* **Print columns (form feed):** insert an ASCII form feed (`\f`, 0x0C) on
  its own line before *some* section headers so the file prints as columns of
  roughly 100 lines each. Lua treats `\f` as whitespace; printers (and a2ps)
  treat it as a page break. Don't put one before every section — just enough
  to break the file into ~5–7 columns. `local lib = {}` and the file's help
  string live in column 1 (before the first form feed).

  Insert with a one-line python: each `\x0c` is on its own line, before the
  target figlet header.

  ```bash
  python3 -c '
  s = open("FILE.lua").read()
  s = s.replace("\n-- HEADER_FIRST_LINE",
                "\n\x0c\n-- HEADER_FIRST_LINE")
  open("FILE.lua","w").write(s)'
  ```

  As a sanity check, `grep -nP "^\x0c" FILE.lua` lists every break.

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

`lib.run` reseeds via `lib.srand(the.seed)` before each eg — the Park-Miller
PRNG in `lib` is platform- and version-stable, so the same seed produces the
same sequence everywhere.

Careful: if your Makefile invokes the same action N times without varying the
seed, you get **the same answer N times** — useless for statistics. In bash
xargs loops, pass `-s $$RANDOM` so each spawn gets a fresh seed and the run is
still reproducible (bash will dump the seed into the log line if you echo it).

## SSOT / CLI

Config lives in one `help` string parsed at startup. Format per line:

```
  -k key=default   description
```

Two functions: `options` (always-on, builds `the` from the defaults so the
config is populated even when the file is `require`'d) and `cli` (script-only,
applies `-k VAL` overrides from `arg`).

```lua
local the = lib.options(help)        -- always
...
if (arg[0] or ""):match"APP%.lua" then
  lib.cli(the)                       -- overrides only when main
  lib.run(the, eg)
  lib.rogues(b4) end
```

## `eg` standards

Every source file — `lib`, `lull`, and each app — maintains a table `eg = {}`
of named callbacks keyed by `--flag`. Rules:

* **Name = what it exercises**, no prefix. `--stat`, `--hist`, `--num`,
  `--data`, `--nb`. No `--testXxx`. If the name is the subject, the eg is
  obviously testing or demoing that subject — the prefix added nothing.
* **Bundle related checks.** One eg covers a *subject* (a single section in
  the file, or one logical building block), not a single assertion. Stuff
  many `eq(...)` calls into one eg. For example `lib.lua --stat` covers
  `welford`, `summary`, `mode`, and `entropy` in one go (5 asserts):

  ```lua
  eg["--stat"] = function(    xs,mu,sd)
    xs = {1,2,3,4,5}
    mu, sd = lib.summary(xs)
    eq(mu, 3, "summary mu")
    eq(math.floor(sd*100), 158, "summary sd")
    eq(lib.mode({a=3,b=2,c=1}), "a", "mode")
    eq(lib.entropy({a=1,b=1}), 1, "entropy uniform binary")
    eq(lib.entropy({a=3,b=0,c=0}), 0, "entropy deterministic")
    end
  ```

  Each `eq` carries its own `msg` so a failure tells you which check broke.
* **Callable two ways.** From the CLI as `lua FILE.lua --foo`, and also
  directly in Lua (`require"FILE".eg["--foo"]()`) for in-process composition.
* **Assert when you can.** Use `eq(actual, expected, "msg")` for anything
  with a known answer. Demos that just print are fine when there's nothing
  meaningful to assert (e.g. a histogram render); prefer at least one `eq` if
  possible.
* **Reads `the`.** Egs pull inputs from the shared config table — `the.f` for
  the data file, `the.seed` for the seed, etc. They take no positional args.
* **Minimal output.** Silent on success when possible. One line for a demo.
  No banners, no decorative headers — that's the experiment Makefile's job.
* **Fast.** A single eg must finish in under a second on a typical laptop.
  Heavy benchmarks belong in a Makefile target that orchestrates many short
  runs, not inside an eg.
* **Reproducible in isolation.** Each eg is re-runnable by name from the CLI
  and must give the same answer for the same `the.seed`.
* **`--all` runs everything.** Defined once per file: iterates the keys of
  `eg` (excluding `--all` itself), reseeds before each, runs under `xpcall`,
  then prints `N asserts passed, M failed`. `lib.main` exits with status 1
  if M > 0 (so Makefiles and CI see failures).

## File header

Each source file starts with:

```lua
#!/usr/bin/env lua
-- vim: ft=lua
-- (c) 2026, Tim Menzies <timm@ieee.org>, MIT license

local help = [[
NAME
  FILE.lua -- ONE-LINE DESCRIPTION

USAGE
  lua FILE.lua [-s SEED] [--FLAG ...]

OPTIONS
  -s seed=1    PRNG seed
  -h           show help

EGS
  --foo        what --foo does
  ...

API
  Group
    fn(a,b):t   short description
    ...
]]
```

Rules:

* **Help string is the SSOT.** `lib.options(help)` parses every line that
  matches `key=value` into `the.key`. Defaults live here and only here.
* **Terse `man`-style.** NAME / USAGE / OPTIONS / EGS / API. Think `man grep`,
  not a tutorial. This is the only multi-line comment-like block in the file.
* **`-h` action prints this string verbatim.** Documentation cannot drift
  from output.
* **API section** uses one-line-per-fn with type hints
  (`push(t,x):x`, `welford(...):n,mu,m2`) plus a short description. Group by
  the same words as the figlet section headers below in the code (Tables,
  I/O, Math, Random, Prob, Stats, CLI, OO).

For app files (`nb.lua`, `cbayes.lua`, …), prepend `package.path` so local
`require"lib"` and `require"lull"` resolve:

```lua
package.path = "./?.lua;" .. package.path
```

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

The bottom of every file (including `lib`, `lull`, every app) is exactly:

```lua
-- Main (figlet header here too)
if (arg[0] or ""):match"FILE%.lua$" then
  lib.cli(the); lib.main(the, eg) end

lib.rogues(b4)
return MODULE   -- whatever this file exports
```

Notes:

* `lib.cli` and `lib.main` only run when this file is invoked as a script —
  not when it's `require`'d from another file. `the` is already populated
  by `lib.options(help)` further up, so the config is correct in both modes.
* `lib.main` does everything: reseed via `lib.srand(the.seed)`, run each
  named eg under `xpcall` (so crashes don't kill the run), print
  `N asserts passed, M failed`, and `os.exit(1)` if any failed.
* `lib.rogues(b4)` runs **after** the script block so it catches globals
  that leaked during eg execution. `b4` is snapshotted just under
  `package.path`:

  ```lua
  local b4 = {}
  for k,_ in pairs(_ENV) do b4[k] = true end
  ```

* If an eg crashes (uncaught error), `lib.main` prints a small traceback
  "snack" (top ~3 frames) and continues. The crash counts as a failure for
  the exit-code purpose.

## Don't

* Don't add error handling for cases that can't happen. Trust internal contracts.
* Don't write multi-line docstrings inside functions. Use the file header.
* Don't import one app from another. Promote shared code to `lull` or `lib`.
* Don't put runtime assertions in hot loops; put them in an `eg["--xxx"]`.
* Don't reach for inheritance. Composition only.
* Don't sprinkle `local` everywhere. Top-of-file multi-assign block.
* Don't use `self`. Use `i`.
* Don't call `lib.X(...)` when you've already aliased it as `X` at the top.
