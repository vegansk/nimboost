## This module introduces limits for some data types

proc min*[T: Ordinal](t: typedesc[T]): T = T.low
proc max*[T: Ordinal](t: typedesc[T]): T = T.high

# uint and uint64 are not `Ordinal` types, see ``Pre-defined integer types``
# in the manual.
proc min*(t: typedesc[uint64]): uint64 = 0'u64
proc max*(t: typedesc[uint64]): uint64 = 0xFFFF_FFFF_FFFF_FFFF'u64

proc min*(t: typedesc[uint]): uint = 0'u

when (sizeof(uint) == 8):
  proc max*(t: typedesc[uint]): uint = 0xFFFF_FFFF_FFFF_FFFF'u
elif (sizeof(uint) == 4):
  proc max*(t: typedesc[uint]): uint = 0xFFFF_FFFF'u
else:
    {.fatal: "Limits: can't get minimal value for type uint when sizeof == " & $sizeof(uint).}
