when defined(js):
  # Core
  import test_typeclasses,
         test_limits
  # Data
  import data.test_stackm,
         data.test_rbtreem,
         data.test_rbtree
else:
  # Core
  import test_limits,
         test_parsers,
         test_typeclasses
  # Data
  import data.test_stackm,
         data.test_rbtreem,
         data.test_rbtree
  # I/O
  import io.test_asyncstreams
  # HTTP
  import http.test_asynchttpserver,
         http.test_jester
