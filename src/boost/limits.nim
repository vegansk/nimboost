## This module introduces limits for some data types

template ordLimitDecl(typ: typedesc): untyped =
  proc min*(t = typ): typ = low(typ)
  proc max*(t = typ): typ = high(typ)
template intLimitDecl(typ: typedesc, minValue, maxValue: typed): untyped =
  proc min*(t = typ): typ = minValue
  proc max*(t = typ): typ = maxValue
template intLimitDeclMD(typ: typedesc, minValue4, maxValue4, minValue8, maxValue8: typed): untyped =
  proc min*(t = typ): typ =
    when sizeof(typ) == 4:
      (typ)minValue4
    elif sizeof(typ) == 8:
      (typ)minValue8
    else:
      {.fatal: "Limits: can't get minimal value for type " & astToStr(typ) & " when sizeof == " & $sizeof(typ).}
  proc max*(t = typ): typ =
    when sizeof(typ) == 4:
      (typ)maxValue4
    elif sizeof(typ) == 8:
      (typ)maxValue8
    else:
      {.fatal: "Limits: can't get maximal value for type " & astToStr(typ) & " when sizeof == " & $sizeof(typ).}

# Signed integer types
int8.ordLimitDecl
int16.ordLimitDecl
int32.ordLimitDecl
int64.ordLimitDecl
int.ordLimitDecl
  
# Unsigned integer types
uint8.ordLimitDecl
uint16.ordLimitDecl
uint32.ordLimitDecl
# uint and uint64 is not ordinal types, see ``Pre-defined integer types`` in the manual
uint64.intLimitDecl(0'u64, 0xFFFF_FFFF_FFFF_FFFF'u64)
uint.intLimitDeclMD(0'u32, 0xFFFF_FFFF'u32, 0'u64, 0xFFFF_FFFF_FFFF_FFFF'u64)
