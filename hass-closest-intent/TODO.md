# TODO

Ordered by impact. Items 1, 3, 5 are the hard gates before publishing to HACS.

## 1. Registry-change listener

Candidates are currently built once in `async_added_to_hass` and never refreshed.
If the user exposes a new entity, adds an area, renames a person, or changes
floor membership, closest_intent doesn't notice until HA restarts.

- Subscribe to `area_registry_updated`, `entity_registry_updated`,
  `floor_registry_updated` events.
- Debounce (e.g. 2s) so a bulk change triggers one rebuild, not N.
- Re-run `_rebuild` on the executor to avoid blocking the event loop.

## 2. Config flow UI

Currently YAML-only; the config flow is a stub that aborts with `yaml_only`.
For HACS users without Nix, expose:

- Threshold slider (0–100).
- Expansion cap (numeric).
- Allowlist (multi-select over discovered intent names).
- Slot-extraction toggle.
- Base-agent picker (entity selector restricted to conversation entities).
- `include_builtins` toggle (with a warning about cost).

Options flow so settings can be changed live without re-importing YAML.

## 3. README

Needed before HACS submission.

- One-paragraph pitch: "wraps your conversation agent with token-level fuzzy
  matching for STT-error tolerance".
- When to use this vs. LLM fallback (cheap, low-latency, closed-set; no
  semantic understanding).
- Trade-offs: surface-level fuzz only — won't infer "make it warmer" → set
  thermostat. That's the LLM's job.
- Config reference (every option, default, range).
- Examples: a couple of real intent definitions and the user phrases they
  catch (with typos / merged tokens / multi-token slot values).
- Architecture sketch: pattern expansion → score → extract → canonicalise →
  forward.
- Screenshot of HA log showing a fuzzy match firing.

## 4. Per-pipeline language handling

`_load_custom_sentences` and `_build_resolver` use `hass.config.language` as
the language. A user with multiple Assist pipelines in different languages
gets one of them broken.

- Use `user_input.language` at match time.
- Cache resolvers + candidate pools per language; build lazily on first
  request for that language.
- Fall back to `hass.config.language` only when `user_input.language` is
  unset.

## 5. Tests for `conversation.py` glue

Only `matching.py` has unit tests. The bugs hit during development —
sibling-extraction fallthrough, `partial_ratio` winner not extractable,
`include_builtins` blocking IO — would all have been caught by an
integration test with a tiny mock `hass`.

- Mock `hass.data`, `hass.config`, the registries.
- Cover: passthrough, fuzzy hit, slot extraction, sibling-fallback, no-match,
  registry change → rebuild.
- Run on the existing `pytest` fixture (no HA boot).

## 6. Diagnostic service

Developer-facing service: `closest_intent.dump_candidates`.

- Logs the current candidate pool, resolver expansion rules, and slot-list
  values to the journal at INFO.
- Saves a lot of "why didn't this match" cycles when users file issues —
  ask them to call it and paste the log.

## 7. Smarter builtins handling

`include_builtins=true` previously blew up with synchronous file IO on the
event loop. The fix wrapped `_rebuild` in an executor; that works but the
combinatorial blow-up is still painful (HA's builtin pack expands to
thousands of candidates per language).

- Pre-compute on a worker once at startup with hard per-intent caps.
- Or lazy-load: only fuzz against builtins after user-defined candidates
  have all been tried below threshold.
- Document the cost honestly so users opt in eyes-open.
