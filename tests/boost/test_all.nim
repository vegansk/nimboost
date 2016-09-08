when defined(js):
  # Core
  import test_typeclasses,
         test_limits
  # Data
  import data.test_stackm,
         data.test_rbtreem,
         data.test_rbtree
         #TODO: add data.test_props test when https://github.com/nim-lang/Nim/pull/4735 will be merged
else:
  # Core
  import test_limits,
         test_parsers,
         test_typeclasses
  # Data
  import data.test_stackm,
         data.test_rbtreem,
         data.test_rbtree,
         data.test_props
  # I/O
  import io.test_asyncstreams
  # HTTP
  import http.test_httpcommon,
         http.test_asynchttpserver,
         http.test_jester
