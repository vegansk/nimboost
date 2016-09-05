srcdir = "src"

import ospaths

type Target {.pure.} = enum JS, C

template dep(task: untyped): stmt =
  exec "nim " & astToStr(task)

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
    setCommand "c", src
  of Target.JS:
    switch("d", "nodeJs")
    setCommand "js", src

proc test(name: string, target: Target) =
  if not dirExists "bin":
    mkDir "bin"
  --run
  let fName = name.splitPath[1]
  buildBase true, joinPath("bin", fName), joinPath("tests/boost", name), target

task test_c, "Run all tests (C)":
  test "test_all", Target.C

task test_js, "Run all tests (JS)":
  test "test_js", Target.JS

task test, "Run all tests":
  deps test_c, test_js
  setCommand "nop"
