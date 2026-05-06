# TODO

## 7. Smarter builtins handling

`include_builtins=true` previously blew up with synchronous file IO on the
event loop. The fix wrapped `_rebuild` in an executor; that works but the
combinatorial blow-up is still painful (HA's builtin pack expands to
thousands of candidates per language).

- Pre-compute on a worker once at startup with hard per-intent caps.
- Or lazy-load: only fuzz against builtins after user-defined candidates
  have all been tried below threshold.
- Document the cost honestly so users opt in eyes-open.
