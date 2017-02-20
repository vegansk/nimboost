when defined(js):
  # Core
  import test_typeclasses,
         test_limits,
         test_parsers,
         test_formatters,
         test_richstring,
         test_objutils
  # Data
  import data.test_stackm,
         data.test_rbtreem,
         data.test_rbtree
         #TODO: https://github.com/vegansk/nimboost/issues/5
else:
  # Core
  import test_limits,
         test_parsers,
         test_typeclasses,
         test_formatters,
         test_richstring,
         test_objutils
  # Data
  import data.test_stackm,
         data.test_rbtreem,
         data.test_rbtree,
         data.test_props,
         data.test_memory
  # I/O
  import io.test_asyncstreams
  # HTTP
  import http.test_httpcommon,
         http.test_multipart,
         http.test_asynchttpserver
         # Disabled because of https://github.com/nim-lang/Nim/issues/5417
         # http.test_jester
