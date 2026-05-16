#!/usr/bin/env lua
-- vim: ft=lua
-- ezr.lua : explainable multi-objective optimization
-- (c) 2026, Tim Menzies <timm@ieee.org>, MIT license
package.path="./?.lua;"..package.path

local help=[[
ezr.lua : explainable multi-objective optimization
(c) 2026, Tim Menzies <timm@ieee.org>, MIT license
  -b bins=2        num numeric split candidates
  -B Budget=50     initial building budget
  -C Check=5       final check budget
  -c cliffs=0.195  Cliff's delta threshold
  -e eps=0.35      Cohen's threshold
  -f f=auto93.csv  input csv path
  -k ksconf=1.36   KS test threshold
  -l leaf=3        min rows per tree leaf
  -p p=2           distance coefficient
  -s seed=1        random number seed
  -S Show=30       width LHS tree display
  -h               show help
  --egs            list all examples
]]

local lib=require"lib"

local the,b4,Num,Sym,Cols,Data,Tree,
      new,push,sort,map,keys,
      slice,shuffle,csv,weibull,o,fmt,
      min,max,floor =
        {},{},{},{},{},{},{},
        lib.new,lib.push,lib.sort,
        lib.map,lib.keys,
        lib.slice,lib.shuffle,lib.csv,lib.weibull,
        lib.o,lib.fmt,
        math.min,math.max,math.floor

for k,_ in pairs(_ENV) do b4[k]=true end

-- ## Classes
function Num.new(txt, at)
  return new(Num,{txt=txt or "",at=at or 0,
    n=0,mu=0,m2=0,
    heaven=(txt or ""):find"-$" and 0 or 1}) end

function Sym.new(txt, at)
  return new(Sym,
    {txt=txt or "",at=at or 0,has={},n=0}) end

function Cols.new(names,    xs,ys,all,cls,col)
  xs,ys,all={},{},{}
  for at,txt in ipairs(names) do
    cls=txt:find"^[A-Z]" and Num or Sym
    col=push(all, cls.new(txt, at))
    if not txt:find"X$" then
      push(txt:find"[%+%-!]$" and ys or xs, col) end end
  return new(Cols, {x=xs,y=ys,all=all,names=names}) end

function Tree.new(score)
  return new(Tree, {score=score}) end

function Data.new(src,    d)
  d=new(Data,{rows={},cols=nil,_mid=nil})
  if type(src)=="string" then
    for r in csv(src) do d:add(r) end
  else
    for _,r in ipairs(src or {}) do d:add(r) end end
  return d end

-- ## Update
function Num.add(i, v, w)
  if v=="?" then return v end
  i.n, i.mu, i.m2 = lib.welford(i.n, i.mu, i.m2, v, w)
  return v end

function Sym.add(i, v, w)
  w=w or 1
  if v=="?" then return v end
  i.n = i.n + w
  i.has[v] = w + (i.has[v] or 0)
  return v end

function Cols.add(i, row, w)
  for _,c in ipairs(i.all) do c:add(row[c.at], w) end
  return row end

function Data.add(i, row, w)
  if not i.cols then i.cols=Cols.new(row); return row end
  w=w or 1
  i._mid=nil
  i.cols:add(row, w)
  if w>0 then push(i.rows, row); return row end
  for n,r in ipairs(i.rows) do
    if r==row then table.remove(i.rows,n); break end end
  return row end

local function adds(src, i)
  i = i or Num.new()
  for _,v in ipairs(src or {}) do i:add(v) end
  return i end

function Data.clone(i, rows)
  return adds(rows or {}, Data.new({i.cols.names})) end

-- ## Query
function Num.mid(i) return i.mu end

function Sym.mid(i,    most, mode)
  most=-1
  for v,n in pairs(i.has) do
    if n>most then most,mode=n,v end end
  return mode end

function Num.spread(i) return lib.sd(i.n, i.m2) end

function Sym.spread(i,    n)
  n=0
  for _,v in pairs(i.has) do
    n=n - v/i.n*math.log(v/i.n, 2) end
  return n end

function Num.norm(i, v,    z)
  if v=="?" then return v end
  z=(v-i.mu)/(i:spread()+1e-32)
  return 1/(1+math.exp(-1.7*max(-3, min(3, z)))) end

function Data.mids(i)
  i._mid=i._mid or
    map(i.cols.all, function(c) return c:mid() end)
  return i._mid end

function Data.disty(i, row,    n)
  n=lib.sum(i.cols.y, function(c)
    return math.abs(c:norm(row[c.at])-c.heaven)^the.p end)
  return (n/#i.cols.y)^(1/the.p) end

function Data.wins(i,    ys, lo, md)
  ys=sort(map(i.rows, function(r) return i:disty(r) end))
  lo,md = ys[1], ys[#ys//2+1]
  return function(row,    r)
    r=(i:disty(row)-lo)/(md-lo+1e-32)
    return floor(100*(1-r)) end end

-- ## Tree
function Num.test(_,cut) return function(x) return x<=cut end end
function Sym.test(_,cut) return function(x) return x==cut end end

Num.yes,Num.no = "<=",">"
Sym.yes,Sym.no = "==","!="

function Sym.cuts(i) return keys(i.has) end

function Num.cuts(i, rows,    vs, step)
  vs={}
  for _,r in ipairs(rows) do
    if r[i.at]~="?" then push(vs, r[i.at]) end end
  step=max(1, #vs//the.bins)
  return slice(sort(vs), step, #vs-step, step) end

function Data.cut(_, col,rows,fn,cv,test,
                  lhs,rhs,L,R,v,ok)
  lhs,rhs,L,R = Num.new(),Num.new(),{},{}
  for _,row in ipairs(rows) do
    v=row[col.at]
    ok=v=="?" or test(v)
    push(ok and L or R, row);
    (ok and lhs or rhs):add(fn(row)) end
  return {col=col,cut=cv,left=L,right=R,
          lhs=lhs,rhs=rhs} end

function Tree.leafstats(i, data, rows,    centroid)
  centroid=data:clone(rows):mids()
  i.y=adds(map(rows, i.score))
  i.mids={}
  for _,c in ipairs(data.cols.y) do
    i.mids[c.txt]=centroid[c.at] end end

function Tree.bestCut(i, data, rows,    best,bestW,c,w)
  bestW=1e32
  for _,col in ipairs(data.cols.x) do
    for _,v in ipairs(col:cuts(rows)) do
      c=data:cut(col, rows, i.score, v, col:test(v))
      w=c.lhs.n*c.lhs:spread() + c.rhs.n*c.rhs:spread()
      if w<bestW and min(#c.left,#c.right)>=the.leaf then
        best,bestW = c,w end end end
  return best end

function Tree.build(i, data, rows,    best)
  i:leafstats(data, rows)
  if #rows<2*the.leaf then return i end
  best=i:bestCut(data, rows)
  if best then
    i.col, i.cut, i.at = best.col, best.cut, best.col.at
    i.left  = Tree.new(i.score):build(data, best.left)
    i.right = Tree.new(i.score):build(data, best.right) end
  return i end

-- ## Tree (apply)
function Tree.leaf(i, row,    v, ok)
  if not i.col then return i end
  v=row[i.at]
  if v=="?" then return i.left:leaf(row) end
  ok=i.col:test(i.cut)(v)
  return (ok and i.left or i.right):leaf(row) end

function Tree.nodes(i, fn, lvl, pre,    kids)
  lvl,pre = lvl or 0, pre or ""
  fn(i, lvl, pre)
  if not i.col then return end
  kids=lib.keysort(
    {{i.left, i.col.yes}, {i.right, i.col.no}},
    function(p) return p[1].y:mid() end)
  for _,p in ipairs(kids) do
    p[1]:nodes(fn, lvl+1,
      i.col.txt.." "..p[2].." "..o(i.cut)) end end

function Tree.show(i)
  i:nodes(function(node, lvl, pre,    p)
    p=lvl==0 and "" or ("|   "):rep(lvl-1)..pre
    io.write(fmt(
      "%-"..the.Show.."s ,%5.2f ,(%3d),  %s\n",
      p, o(node.y:mid()),
      node.y.n, o(node.mids))) end) end

-- ## Examples
local _asserts=0
local function eq(a, b, msg)
  if a==b then _asserts=_asserts+1
  else error(msg.." want "..tostring(b)
                 .." got "..tostring(a)) end end

local eg={}

eg["-h"]   = function() print(help) end
eg["--the"]= function() print(o(the)) end

eg["--egs"]= function()
  print("\nlua ezr.lua:")
  for _,k in ipairs(sort(keys(eg))) do print("  "..k) end end

eg["--all"]= function(    ss)
  ss=lib.filter(keys(eg), function(k) return k~="--all" end)
  for _,k in ipairs(sort(ss)) do
    print("\n"..k)
    math.randomseed(the.seed)
    eg[k]() end
  print("\nasserts passed: ".._asserts) end

eg["--csv"]= function(    n)
  n=0
  for r in csv(the.f) do
    if n%30==0 then print(o(r)) end
    n=n+1 end end

eg["--ranks"]= function(    dict, name, k, lam)
  dict={}
  for n=1,20 do
    name="t"..n
    dict[name]={}
    k   = n<=5 and 2  or 1
    lam = n<=5 and 10 or 20
    for _=1,50 do push(dict[name], weibull(k, lam)) end end
  print("\nTop Tier Treatments:")
  for _,r in ipairs(lib.bestRanks(dict, the.eps,
                       the.cliffs, the.ksconf)) do
    print(fmt("%-5s median: %5.2f", r.name, r.mid)) end end

eg["--data"]= function(    data)
  data=Data.new(the.f)
  for _,c in ipairs(data.cols.y) do
    print(c.txt, o(c:mid())) end end

eg["--tree"]= function(    data, rs)
  data=Data.new(the.f)
  rs=slice(shuffle(data.rows), 1, the.Budget)
  data=data:clone(rs)
  Tree.new(function(r) return data:disty(r) end)
      :build(data, data.rows):show() end

eg["--test"]= function(
              data, stats, fnWin, n, test, d2, tree, top)
  data=Data.new(the.f)
  stats=Num.new("win")
  if not data.cols then return end
  fnWin=data:wins()
  for _=1,20 do
    shuffle(data.rows)
    n=#data.rows//2
    test=slice(data.rows, n+1)
    d2=data:clone(slice(data.rows,1,min(n,the.Budget)))
    tree=Tree.new(function(r) return d2:disty(r) end)
             :build(d2, d2.rows)
    sort(test, function(a,b)
      return tree:leaf(a).y:mid()
           < tree:leaf(b).y:mid() end)
    top=sort(slice(test, 1, the.Check),
      function(a,b) return d2:disty(a)<d2:disty(b) end)
    stats:add(fnWin(top[1])) end
  print(o(floor(stats:mid()))) end

eg["--testNum"]= function(    num)
  num=adds({1,2,3,4,5})
  eq(num:mid(), 3, "Num mid")
  eq(floor(num:spread()*100), 158, "Num spread") end

eg["--testSym"]= function(    sym)
  sym=Sym.new()
  for _,v in pairs{"a","a","a","b","b","c"} do sym:add(v) end
  eq(sym:mid(), "a", "Sym mode")
  eq(sym.has["a"], 3, "Sym count a") end

eg["--testTree"]= function(    data, tree)
  data=Data.new(the.f)
  tree=Tree.new(function(r) return data:disty(r) end)
            :build(data, slice(data.rows, 1, 50))
  eq(type(tree.col), "table", "tree root has split col") end

eg["--testStat"]= function(    mk, a, b, c, eps)
  math.randomseed(the.seed)
  mk=function(k, lam,    xs)
    xs={}
    for _=1,50 do push(xs, weibull(k, lam)) end
    return xs end
  a,b,c = mk(2,10),mk(2,10),mk(1,20)
  eps=adds(a):spread() * the.eps
  eq(lib.same(a,b,eps,the.cliffs,the.ksconf), true,
     "same dist -> true")
  eq(lib.same(a,c,eps,the.cliffs,the.ksconf), false,
     "diff dist -> false") end

-- ## Main
lib.cli(the, help)
if (arg[0] or ""):match"ezr%.lua" then lib.run(the, eg) end
lib.rogues(b4)
