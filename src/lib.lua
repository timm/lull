#!/usr/bin/env lua
-- vim: ft=lua
-- (c) 2026, Tim Menzies <timm@ieee.org>, MIT license

local help = [[
NAME
  lib.lua -- generic utilities, stats, cli, rogues

USAGE
  lua lib.lua [-s SEED] [--FLAG ...]

OPTIONS
  -s seed=1    PRNG seed (Park-Miller LCG; platform-stable)
  -h           show this help + list egs

EGS  (also: --all to run every eg)
  --stat       welford / summary / mode / entropy
  --rand       srand reproducibility, rint range
  --cdf        logistic CDF approx
  --pdf        Gaussian pdf at z=0,+1,-1
  --ih         Irwin-Hall mean check
  --normal     Irwin-Hall convergence to normal (n=1,3,12)
  --hist       ASCII histogram demo
  --ranks      bestRanks on 20 weibull treatments
  --same       same() on two same-dist + one diff-dist
  --the        print parsed config

API
  Tables
    push(t,x):x              append, return x
    sort(t,fn?):t            in-place sort
    slice(t,lo,hi,step):u    subrange
    keysort(t,key,desc?):t   sort by extractor; desc flips
    at(k):fn                 field accessor: x -> x[k]
    map(t,fn):u              fn(v,k) over values
    kap(t,fn):u              fn(k,v); good for dict-like
    keys(t):u                collect keys
    filter(t,p):u            keep where p(v)
    sum(t,fn):n              sum of fn(x)
    shuffle(t):t             Fisher-Yates, in place
    bisect(t,x):n            rightmost i where t[i] <= x
  I/O
    csv(src):iter            yields typed row tables
    o(x):s                   pretty-print scalar / table
    thing(s):v               coerce "1.2"/"true" -> typed
    fmt                      = string.format
  Math
    welford(n,mu,m2,v,w?):n,mu,m2   online mean/var update
    sd(n,m2):n                      stdev from welford state
    summary(xs):mu,sd               mean + stdev of list
    pooledSd(xs,ys):n               pooled stdev of 2 samples
    mode(t):k                       most-common key
    entropy(t):n                    Shannon entropy (log2)
  Random  (Park-Miller LCG; cross-platform stable)
    srand(s)                 seed the PRNG
    rand():n                 uniform in [0,1)
    rint(lo,hi):n            uniform int in [lo,hi]
    irwinHall(n?):n          sum of n uniforms (default 3)
    weibull(k,lam):n         Weibull(k,lam) sample
  Prob
    pdf(v,num):n             Gaussian pdf (num.mu, num.sd)
    cdf(z):n                 logistic-sigmoid CDF approx
  Stats
    cliffsDelta(xs,ys):n     effect size in [0,1]
    ks(xs,ys):n              max CDF gap
    same(xs,ys,e,c,k):ok     3-gate same-distribution test
    bestRanks(d,e,c,k):u     top-tier treatments from dict
    hist(xs,b,w?)            ASCII histogram (bin b, width w)
  CLI
    options(help):the        parse defaults from help string
    cli(the):the             apply -k VAL overrides from arg
    main(the,eg)             dispatch egs, pcall, exit
    eq(a,b,msg)              non-throwing eq; count + print
    rogues(b4)               warn rogue lowercase globals
  OO
    new(mt,t):t              setmetatable with __index=mt
]]

local lib = {}

--  _  _
-- / \/ \
-- \_/\_/

-- Attach mt as metatable; mt is its own __index.
function lib.new(mt, t)
  mt.__index = mt
  return setmetatable(t, mt) end

-- ___
--  | _.|_ | _  _
--  |(_||_)|(/__>

-- Append x; return x.
function lib.push(t, x) t[1+#t] = x; return x end

-- Sort in place; return t.
function lib.sort(t, fn) table.sort(t, fn); return t end

-- Sort t by key(x). Pass desc=true for descending.
function lib.keysort(t, key, desc)
  return lib.sort(t, function(a,b)
    if desc then return key(a) > key(b) end
    return key(a) < key(b) end) end

-- Field accessor: x -> x[k]. Pair with keysort or map.
function lib.at(k) return function(x) return x[k] end end

-- Map values via fn(v,k).
function lib.map(t, fn,    u)
  u={}; for k,v in pairs(t) do u[1+#u]=fn(v,k) end; return u end

-- Map keys via fn(k,v).
function lib.kap(t, fn,    u)
  u={}; for k,v in pairs(t) do u[1+#u]=fn(k,v) end; return u end

-- Collect keys.
function lib.keys(t,    u)
  u={}; for k,_ in pairs(t) do u[1+#u]=k end; return u end

-- Keep v where p(v).
function lib.filter(t, p,    u)
  u={}
  for _,v in ipairs(t) do if p(v) then u[1+#u]=v end end
  return u end

-- Sum fn(x) over t.
function lib.sum(t, fn,    n)
  n=0; for _,x in ipairs(t) do n=n+fn(x) end; return n end

-- t[lo..hi step].
function lib.slice(t, lo, hi, step,    u)
  u={}
  for i=(lo or 1),(hi or #t),(step or 1) do u[1+#u]=t[i] end
  return u end

-- Fisher-Yates shuffle in place.
function lib.shuffle(t,    j)
  for i=#t,2,-1 do
    j=lib.rint(1,i); t[i],t[j] = t[j],t[i] end
  return t end

-- Rightmost i where t[i] <= x.
function lib.bisect(t, x,    lo,hi,m)
  lo,hi = 1,#t
  while lo <= hi do
    m = (lo+hi)//2
    if t[m] <= x then lo = m+1 else hi = m-1 end end
  return lo-1 end


-- ___   _
--  |  // \
-- _|_/ \_/

-- Coerce string to bool / number / string.
function lib.thing(s)
  return s == "true" or
    (s ~= "false" and (tonumber(s) or s)) end

lib.fmt = string.format

-- Pretty-print scalar or table.
function lib.o(x,    u)
  if type(x) ~= "table" then
    if math.type(x) == "float" then
      return lib.fmt("%.2f", x) end
    return tostring(x) end
  u = lib.kap(x, function(k,v)
    if type(k) == "number" then return lib.o(v) end
    return k.."="..lib.o(v) end)
  return "{"..table.concat(lib.sort(u), ", ").."}" end

-- Iterate typed rows from a CSV file.
function lib.csv(src,    f)
  f = io.open(src)
  return function(    s,t)
    s = f:read()
    if not s then f:close(); return end
    t = {}
    for x in s:gmatch"[^,]+" do
      lib.push(t, lib.thing(x:match"^%s*(.-)%s*$")) end
    return t end end

-- |\/| _._|_|_
-- |  |(_| |_| |

-- Welford online mean+variance update.
function lib.welford(n, mu, m2, v, w,    err)
  w = w or 1
  if w < 0 and n <= 1 then return 0,0,0 end
  n   = n + w
  err = v - mu
  mu  = mu + w*err/n
  m2  = m2 + w*err*(v - mu)
  return n, mu, m2 end

-- Stdev from welford state.
function lib.sd(n, m2)
  return n <= 1 and 0
    or (math.max(0, m2)/(n-1))^0.5 end

-- Mean + stdev of xs.
function lib.summary(xs,    n,mu,m2)
  n,mu,m2 = 0,0,0
  for _,v in ipairs(xs) do
    n,mu,m2 = lib.welford(n, mu, m2, v) end
  return mu, lib.sd(n, m2) end

-- Pooled stdev of two samples.
function lib.pooledSd(xs, ys,    n,m,sd1,sd2)
  n,m = #xs, #ys
  _,sd1 = lib.summary(xs)
  _,sd2 = lib.summary(ys)
  return (((n-1)*sd1^2 + (m-1)*sd2^2)/(n+m-2))^0.5 end

-- Most-common key in a {key=count} table.
function lib.mode(t,    most,k)
  most=-1
  for v,n in pairs(t) do if n>most then most,k=n,v end end
  return k end

-- Shannon entropy (log2) of a {key=count} table.
function lib.entropy(t,    n,e,p)
  n,e = 0,0
  for _,v in pairs(t) do n=n+v end
  for _,v in pairs(t) do
    if v>0 then p=v/n; e=e-p*math.log(p,2) end end
  return e end


--  _
-- |_) _.._  _| _ ._ _
-- | \(_|| |(_|(_)| | |

-- (Park-Miller LCG; stable across platforms/Lua)
lib._seed = 1

-- Seed the PRNG.
function lib.srand(s) lib._seed = s or 1 end

-- Uniform random in [0,1).
function lib.rand()
  lib._seed = (lib._seed * 48271) % 2147483647
  return lib._seed / 2147483647 end

-- Uniform random integer in [lo,hi].
function lib.rint(lo, hi)
  return lo + math.floor(lib.rand() * (hi - lo + 1)) end

-- Irwin-Hall: sum of n uniforms in [0,1].
-- Default n=3 (cheap normal-ish; mean=n/2, var=n/12).
function lib.irwinHall(n,    s)
  n,s = n or 3, 0
  for _=1,n do s=s+lib.rand() end
  return s end

-- Weibull random sample (shape k, scale lam).
function lib.weibull(k, lam)
  return lam*(-math.log(1-lib.rand()))^(1/k) end

--  _
-- |_).__ |_
-- |  |(_)|_)

-- Gaussian pdf of v under num (uses num.mu, num.sd).
function lib.pdf(v, num,    sd,z)
  sd = num.sd + 1e-32
  z  = (v - num.mu) / sd
  return math.exp(-z*z/2) / (sd*math.sqrt(2*math.pi)) end

-- Logistic-sigmoid CDF approximation; clipped to [-3,3].
function lib.cdf(z)
  return 1/(1+math.exp(-1.7*math.max(-3,math.min(3,z)))) end


--  __
-- (__|_ _._|_ _
-- __)|_(_| |__>

-- Cliff's delta effect size in [0,1].
function lib.cliffsDelta(xs, ys,    n,m,ngt,nlt)
  n,m,ngt,nlt = #xs,#ys,0,0
  for _,v in ipairs(xs) do
    ngt = ngt + lib.bisect(ys, v)
    nlt = nlt + (m - lib.bisect(ys, v+1e-32)) end
  return math.abs(ngt-nlt)/(n*m) end

-- Kolmogorov-Smirnov: max CDF gap.
function lib.ks(xs, ys,    n,m,d,gap)
  n,m,d = #xs,#ys,0
  gap = function(v) return math.abs(
    lib.bisect(xs,v)/n - lib.bisect(ys,v)/m) end
  for _,v in ipairs(xs) do d=math.max(d,gap(v)) end
  for _,v in ipairs(ys) do d=math.max(d,gap(v)) end
  return d end

-- Same? eps is a Cohen-d coefficient: real gate is
-- eps * pooledSd. Then Cliff; then KS.
function lib.same(xs, ys, eps, cliffs, ksconf,    n,m)
  xs,ys = lib.sort(xs), lib.sort(ys)
  n,m = #xs,#ys
  eps = eps * lib.pooledSd(xs, ys)
  if math.abs(xs[n//2+1]-ys[m//2+1]) <= eps then
    return true end
  if lib.cliffsDelta(xs,ys) > cliffs then return false end
  return lib.ks(xs,ys) <= ksconf*((n+m)/(n*m))^0.5 end

-- Top-tier treatments from {name=samples,...}.
function lib.bestRanks(dict, eps, cliffs, ksconf,
                       out, names, rows)
  out = {}
  names = lib.keysort(lib.keys(dict),
    function(a) return (lib.summary(dict[a])) end)
  rows = dict[names[1]]
  out[1] = {name=names[1], mid=(lib.summary(rows))}
  for n = 2, #names do
    if not lib.same(rows, dict[names[n]], eps,
                    cliffs, ksconf) then break end
    out[#out+1] = {name=names[n],
                   mid=(lib.summary(dict[names[n]]))} end
  return out end

-- ASCII histogram: bins of width b, bars to width w.
function lib.hist(xs, b, w,    bins,mx,fill,n,key)
  w = w or 40
  bins, mx = {}, 0
  for _,v in ipairs(xs) do
    key = math.floor(v/b + 0.5) * b
    bins[key] = (bins[key] or 0) + 1 end
  for _,c in pairs(bins) do if c>mx then mx=c end end
  for _,k in ipairs(lib.sort(lib.keys(bins))) do
    n = bins[k]
    fill = math.floor(w*n/mx + 0.5)
    print(lib.fmt("%7.2f | %s %5d",
      k, ("█"):rep(fill)..(" "):rep(w-fill), n)) end end

--  _  ___
-- / |  |
-- \_|__|_

-- Always-on: build `the` from the defaults in `help`.
function lib.options(help,    the)
  the = {}
  for k,v in help:gmatch"([%w_]+)%s*=%s*([^%s]+)" do
    the[k] = lib.thing(v) end
  return the end

-- Script-only: override `the` via -k V on the command line.
function lib.cli(the)
  for n = 1, #arg do
    for k,_ in pairs(the) do
      if arg[n] == "-"..k:sub(1,1) then
        the[k] = lib.thing(arg[n+1] or "") end end end
  return the end

-- Warn about rogue (post-snapshot) lowercase globals.
function lib.rogues(b4)
  for k,_ in pairs(_ENV) do
    if not b4[k] and k:match"^[a-z]" then
      print("rogue: "..k) end end end


--  _
-- |_)   ._ ._  _ ._
-- | \|_|| || |(/_|

lib._asserts = 0
lib._fails   = {}
lib._egname  = "?"

-- xpcall message handler: error + small traceback snack.
local function snack(err,    tb,out,n)
  tb  = debug.traceback(tostring(err), 2)
  out,n = {}, 0
  for line in tb:gmatch"[^\n]+" do
    out[#out+1] = line
    if line:match"^%s+%S" then
      n = n + 1; if n >= 4 then break end end end
  return table.concat(out, "\n") end

-- Non-throwing assert: counts pass/fail, names eg of failure.
function lib.eq(a, b, msg)
  if a == b then
    lib._asserts = lib._asserts + 1
  else
    print(lib.fmt("  FAIL [%s] %s: want %s got %s",
      lib._egname, msg, tostring(b), tostring(a)))
    lib._fails[#lib._fails+1] = lib._egname.." "..msg end end

-- Dispatch egs from arg[]; reseed each; xpcall-wrap;
-- exit nonzero if any fail.
function lib.main(the, eg,    ok,err)
  for n = 1, #arg do
    if eg[arg[n]] then
      lib.srand(the.seed); lib._egname = arg[n]
      ok, err = xpcall(eg[arg[n]], snack)
      if not ok then
        print("  CRASH ["..arg[n].."]\n"..err)
        lib._fails[#lib._fails+1] = arg[n].." crashed" end end end
  if #lib._fails > 0 then os.exit(1) end end


--  _
-- |_   _.._ _ ._ | _  _
-- |_><(_|| | ||_)|(/__>
--             |

local eq  = lib.eq
local the = lib.options(help)

local eg = {}

eg["-h"]    = function() print(help) end
eg["--the"] = function() print(lib.o(the)) end

eg["--all"] = function(    ss,ok,err)
  ss = lib.filter(lib.keys(eg),
    function(k) return k ~= "--all" end)
  for _,k in ipairs(lib.sort(ss)) do
    print("\n"..k); lib.srand(the.seed); lib._egname = k
    ok, err = xpcall(eg[k], snack)
    if not ok then
      print("  CRASH ["..k.."]\n"..err)
      lib._fails[#lib._fails+1] = k.." crashed" end end
  print(lib.fmt("\n%d asserts passed, %d failed",
    lib._asserts, #lib._fails)) end

eg["--stat"] = function(    xs,mu,sd)
  xs = {1,2,3,4,5}
  mu, sd = lib.summary(xs)
  eq(mu, 3, "summary mu")
  eq(math.floor(sd*100), 158, "summary sd")
  eq(lib.mode({a=3,b=2,c=1}), "a", "mode")
  eq(lib.entropy({a=1,b=1}), 1, "entropy uniform binary")
  eq(lib.entropy({a=3,b=0,c=0}), 0, "entropy deterministic") end

eg["--rand"] = function(    a,b)
  lib.srand(42); a={}
  for _=1,5 do lib.push(a, lib.rand()) end
  lib.srand(42); b={}
  for _=1,5 do lib.push(b, lib.rand()) end
  eq(a[1], b[1], "rand reproducible 1")
  eq(a[5], b[5], "rand reproducible 5")
  eq(lib.rint(7,7), 7, "rint degenerate") end

eg["--cdf"] = function()
  eq(lib.fmt("%.2f", lib.cdf(0)), "0.50", "cdf(0)=0.5")
  eq(lib.cdf(-99) < 0.01, true, "cdf low")
  eq(lib.cdf( 99) > 0.99, true, "cdf high") end

eg["--pdf"] = function(    n)
  n = {mu=0, sd=1}
  eq(lib.fmt("%.4f", lib.pdf(0, n)), "0.3989",
     "pdf(0|N(0,1)) peak")
  eq(lib.pdf(1, n), lib.pdf(-1, n), "pdf symmetric") end

eg["--ih"] = function(    xs,mu)
  xs = {}
  for _=1,2000 do lib.push(xs, lib.irwinHall()) end
  mu = lib.summary(xs)
  eq(math.abs(mu - 1.5) < 0.05, true,
     "irwinHall(3) mean ~1.5") end

-- Show Irwin-Hall converging to a normal as n grows.
eg["--normal"] = function(    xs)
  for _,n in ipairs{1,3,12} do
    xs = {}
    for _=1,2000 do
      lib.push(xs, lib.irwinHall(n) - n/2) end
    print(lib.fmt("\nirwinHall(%d) - %.1f:", n, n/2))
    lib.hist(xs, n<=3 and 0.1 or 0.25, 30) end end

eg["--hist"] = function(    xs)
  xs = {}
  for _=1,1000 do lib.push(xs, lib.irwinHall(3)) end
  lib.hist(xs, 0.25, 30) end

eg["--ranks"] = function(    dict,name,k,lam)
  dict = {}
  for n=1,20 do
    name = "t"..n; dict[name] = {}
    k   = n<=5 and 2  or 1
    lam = n<=5 and 10 or 20
    for _=1,50 do
      lib.push(dict[name], lib.weibull(k, lam)) end end
  for _,r in ipairs(lib.bestRanks(dict, 0.35, 0.195, 1.36)) do
    print(lib.fmt("  %-5s median: %5.2f", r.name, r.mid)) end end

eg["--same"] = function(    mk,a,b,c)
  mk = function(k,lam,    xs)
    xs = {}
    for _=1,200 do lib.push(xs, lib.weibull(k,lam)) end
    return xs end
  a,b,c = mk(2,10), mk(2,10), mk(2,40)
  eq(lib.same(a,b,0.35,0.195,1.36), true,
     "same dist -> true")
  eq(lib.same(a,c,0.35,0.195,1.36), false,
     "diff dist -> false") end

-- |\/| _.o._
-- |  |(_||| |
--
if (arg[0] or ""):match"lib%.lua$" then
  lib.cli(the); lib.main(the, eg) end

return lib
