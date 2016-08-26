srcdir = "src"

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
    
  setCommand "c", src

proc test(name: string) =
  if not dirExists "bin":
    mkDir "bin"
  --run
  let fName = name.splitPath[1]
  buildBase true, joinPath("bin", fName), joinPath("tests/boost", name)

task test, "Run all tests":
  test "test_all"
