## Atomic operations

when defined(JS) or defined(nimscript):
  {.error: "Module boost.system.atomics can't be used with current target".}

const hasThreadSupport = compileOption("threads") and not defined(nimscript)

const someGcc = defined(gcc) or defined(llvm_gcc) or defined(clang)

type AtomValue* = ptr|pointer

when someGcc or defined(nimdoc) and hasThreadSupport:
  proc xchg*[T: AtomValue](x: ptr T, y: T): T =
    ## Atomic exchange of the value stored in `x[]` with `y`.
    ## Returns the old value stored in `x[]`.
    atomicExchangeN(x, y, ATOMIC_RELAXED)

elif defined(vcc) and hasThreadSupport:

  import winlean

  proc InterlockedExchangePointer(target: ptr pointer, value pointer): pointer{.cdecl, header: "windows.h".}

  proc xchg*[T: AtomValue](x: ptr T, y: T): T =
    cast[T](InterlockedExchangePointer(cast[ptr pointer](x), cast[T](y)))

elif not hasThreadSupport:
  proc xchg*[T: AtomValue](x: ptr T, y: T): T =
    result = x[]
    x[] = y
