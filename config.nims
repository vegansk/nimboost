version       = "0.1.0"
author        = "Anatoly Galiulin <galiulin.anatoly@gmail.com>"
description   = "Additions to the Nim's standard library, like boost for C++"
license       = "MIT"

srcdir        = "src"

requires "nim >= 0.13.1"

import ospaths

proc buildBase(debug: bool, bin: string, src: string) =
  switch("out", (thisDir() & "/" & bin).toExe)
  --nimcache: build
  if not debug:
    --forceBuild
    --define: release
    --opt: size
  else:
    --define: debug
    --define: exportPrivate
    --debuginfo
    --debugger: native
    --linedir: on
    --stacktrace: on
    --linetrace: on
    --verbosity: 1

    --NimblePath: src
    --NimblePath: srcdir
    
  setCommand "c", src

proc test(name: string) =
  if not dirExists "bin":
    mkDir "bin"
  --run
  let fName = name.splitPath[1]
  buildBase true, joinPath("bin", fName), joinPath("tests/boost", name)

task test, "Run all tests":
  test "test_all"
