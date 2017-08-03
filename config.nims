srcdir = "src"

import ospaths, strutils, sequtils

type Target {.pure.} = enum JS, C

template dep(task: untyped): stmt =
  selfExec astToStr(task)

template deps(a, b: untyped): stmt =
  dep(a)
  dep(b)

proc buildBase(debug: bool, bin: string, src: string, target: Target) =
  let baseBinPath = thisDir() / bin
  case target
  of Target.C:
    switch("out", baseBinPath.toExe)
  of Target.JS:
    switch("out", baseBinPath & ".js")

  --nimcache: build
  if not debug:
    --forceBuild
    --define: release
    --opt: size
  else:
    --define: debug
    # --reportconceptfailures: on
    # --define: exportPrivate
    --debuginfo
    --debugger: native
    --linedir: on
    --stacktrace: on
    --linetrace: on
    --verbosity: 1

    --NimblePath: src
    --NimblePath: srcdir
    
  case target
  of Target.C:
    --threads: on
    setCommand "c", src
  of Target.JS:
    switch("d", "nodeJs")
    setCommand "js", src

proc test(name: string, target: Target) =
  if not dirExists "bin":
    mkDir "bin"
  --run
  --define:insideTheTest
  let fName = name.splitPath[1]
  buildBase true, joinPath("bin", fName), joinPath("tests/boost", name), target

proc getVersion: string =
  const PREFIX = "version: \""
  for line in (staticExec "nimble dump").splitLines:
    if line.startsWith(PREFIX):
      return line[PREFIX.len..^2]
  quit "Can't read version from project's configuration"

task version, "Show project version":
  echo getVersion()

task test_c, "Run all tests (C)":
  test "test_all", Target.C

task test_js, "Run all tests (JS)":
  test "test_all", Target.JS

task test, "Run all tests":
  deps test_c, test_js
  setCommand "nop"

import ./utils/index_html

proc listFilesRec(dir: string): seq[string] =
  result = newSeq[string]()
  withDir dir:
    result.add(".".listFiles.mapIt(it.splitPath[1]))
    for d in ".".listDirs:
      if d == "impl": continue
      result.add(listFilesRec(d).mapIt(d.splitPath[1] / it))

proc genIndex: auto =
  result = newSeq[(string, seq[string])]()
  withDir "docs":
    for d in ".".listDirs:
      result.add((d.splitPath[1], listFilesRec(d)))
  echo result

task docs, "Build documentation":
  mkDir "docs" / getVersion()
  const modules = [
    "limits.nim",
    "parsers.nim",
    "typeutils.nim",
    "typeclasses.nim",
    "types.nim",
    "formatters.nim",
    "richstring.nim",

    "data/props.nim",
    "data/rbtree.nim",
    "data/rbtreem.nim",
    "data/stackm.nim",

    "io/asyncstreams.nim",

    "http/asynchttpserver.nim",
    "http/jester.nim",
    "http/httpcommon.nim",
    "http/multipart.nim",
  ]

  for m in modules:
    let (d, f, _) = m.splitFile
    let dir = "docs" / getVersion() / "boost" / d
    if not dirExists(dir):
      mkDir(dir)
    exec "nim doc --out:" & joinPath(dir, f & ".html") & " " & joinPath("src", "boost", m)

  writeFile "index.html", index_html(genIndex())

task test_asynchttpserver, "Test asynchttpserver":
  test "http/test_asynchttpserver", Target.C

task test_jester, "Test asynchttpserver":
  test "http/test_jester", Target.C

task test_httpcommon, "Test http common utils":
  test "http/test_httpcommon", Target.C

task test_props, "Test props":
  test "data/test_props", Target.C

task test_asyncstreams, "Test asyncstreams":
  test "io/test_asyncstreams", Target.C

task test_asyncstreams_no_net, "Test asyncstreams without networking":
  --d: noNet
  test "io/test_asyncstreams", Target.C

task test_multipart, "Test multipart":
  test "http/test_multipart", Target.C

task test_memory, "Test memory":
  test "data/test_memory", Target.C

task test_richstring, "Test richstring":
  test "test_richstring", Target.C

task test_parsers, "Test richstring":
  test "test_parsers", Target.C

task test_limits, "Test richstring":
  test "test_limits", Target.C

task test_formatters, "Test formatters":
  test "test_formatters", Target.C

task test_typeutils, "Test typeutils":
  test "test_typeutils", Target.C
