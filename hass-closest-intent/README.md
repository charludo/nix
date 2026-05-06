# Closest Intent

A Home Assistant conversation agent that wraps your existing
conversation pipeline with **token-level fuzzy matching** for
STT-error tolerance. When on-device speech recognition mishears
"Pumpe an" as "pumpr an", or merges "wohn zimmer" into a single
token, this agent recognises the closest defined intent, rebuilds a
canonical sentence with the slot values the user actually spoke, and
forwards it to your real conversation agent (HA's bundled one by
default).

It's surface-level fuzz only. It will not infer "make it warmer" →
"set thermostat to 22°C". For semantic understanding use an LLM.
For "the user almost said one of my known phrases", use this.

## When to use this

- **You want low-latency, deterministic, offline voice control** over
  a closed set of phrases (your `intent_script` patterns or
  `custom_sentences`).
- **Your STT pipeline is fast but lossy** — Whisper-tiny, Vosk, etc.
  often emit slightly mangled text that Hassil's strict matcher
  rejects.
- **You don't want LLM-shaped costs and latency** for every utterance.
  An LLM fallback for a closed-set match is overkill.

## When *not* to use this

- You need natural-language understanding ("turn it down a bit").
  → Use HA's LLM agent (Anthropic, OpenAI, Ollama).
- Your STT is already accurate enough that Hassil matches reliably.
  → You don't need this layer.
- You want intent matching against entity *aliases* you haven't yet
  defined. Closest Intent reads HA's area/floor/entity registries to
  power slot-value resolution but doesn't invent new vocabulary.

## How it works

```
                  user speech (STT-mangled)
                              │
                              ▼
            ┌──────────────────────────────────┐
            │ Closest Intent agent             │
            │ ─────────────────────────────────│
            │ 1. Expand each pattern           │
            │    [opt] / (a|b) / {slot} /      │
            │    <expansion_rule>              │
            │                                  │
            │ 2. Score user text against each  │
            │    candidate via RapidFuzz       │
            │                                  │
            │ 3. Pick highest above threshold  │
            │                                  │
            │ 4. Extract slot values, fuzz-    │
            │    resolve against known lists   │
            │    (areas, floors, entity names) │
            │                                  │
            │ 5. Build canonical sentence      │
            └──────────────┬───────────────────┘
                           │ canonical text
                           ▼
            ┌──────────────────────────────────┐
            │ Base conversation agent          │
            │ (HA's bundled one by default)    │
            │ Hassil parses → dispatches intent│
            └──────────────────────────────────┘
```

If nothing scores above threshold, the user's original text is
forwarded unchanged — the base agent gets a chance to handle it
itself, and the user gets that agent's locale-appropriate "I don't
understand" if it doesn't.

## Cascading with the default agent

Closest Intent is a **peer** to HA's default conversation agent, not a
wrapper. The recommended setup is to enable HA's
**"Prefer handling commands locally"** toggle on the Assist pipeline:

> Settings → Voice assistants → (pipeline) → Edit → Conversation
>   agent → Prefer handling commands locally

Then:

1. HA's default Hassil agent gets the utterance first.
2. If it cleanly handles it (lights, areas, built-ins) → done.
3. If it returns `NO_INTENT_MATCH` → falls through to Closest Intent,
   which fuzzy-matches your `conversation.intents` patterns.

If the toggle is off, this agent runs solo and is responsible for
matching every utterance.

## Installation

### HACS (recommended)

1. HACS → ⋮ → Custom repositories
2. Add `https://github.com/charludo/hass-closest-intent` as
   "Integration"
3. Install **Closest Intent**, restart Home Assistant
4. Settings → Devices & services → Add integration → "Closest Intent"
5. Pick your base agent and tune the threshold; you're done.

### YAML

If you prefer YAML, add a `closest_intent:` block to
`configuration.yaml`. The integration sets itself up on the next
restart. YAML and the UI options flow coexist — UI options override
YAML on a per-key basis.

```yaml
closest_intent:
  threshold: 70
```

## Configuration reference

| Option              | Default                          | Range / type                  | Description |
|---------------------|----------------------------------|-------------------------------|-------------|
| `threshold`         | `70`                             | `0`–`100`                     | Minimum similarity score (RapidFuzz `token_sort_ratio` / `partial_ratio`) for a candidate to be considered. Higher = stricter. |
| `expansion_cap`     | `16`                             | `0` or positive int           | Max number of variants generated per pattern by `[opt]` / `(a\|b)` expansion. `0` disables expansion entirely (useful if your patterns have no alternation). |
| `allowlist`         | `null` (= all)                   | list of intent names          | Restrict matching to these intent names. Names not in the list are ignored. |
| `slot_extraction`   | `true`                           | bool                          | If `false`, intents containing `{slot}` placeholders are skipped — only fixed-string patterns are matched. |
| `include_builtins`  | `false`                          | bool                          | Also fuzz-match HA's built-in intents (`HassTurnOn` etc.) from the `home_assistant_intents` package. **Costly** — the built-in pack expands to thousands of candidates per language. |
| `base_agent`        | `conversation.home_assistant`    | conversation entity ID        | The agent to forward the canonical (post-match) sentence to. **Don't** point this at this entity itself — that loops. |

## Examples

### Plain pattern, no slots

```yaml
conversation:
  intents:
    PumpeAn:
      - "(Aktiviere|Schalte) [die ][Wasser]Pumpe [an|ein]"
      - "[Wasser]Pumpe an"

intent_script:
  PumpeAn:
    action:
      - action: switch.turn_on
        target:
          entity_id: switch.water_pump
    speech.text: "Pumpe aktiviert."
```

User utterances that all hit `PumpeAn`:

| Spoken                | What STT gave HA          | Matched? |
|-----------------------|----------------------------|----------|
| "Pumpe an"            | `pumpe an`                | ✓ exact  |
| "Pumpe an"            | `pumpr an`                | ✓ fuzz (one-char typo) |
| "Pumpe an"            | `pumpe a`                 | ✓ fuzz (truncation) |
| "Aktiviere die Pumpe" | `aktivire die pumpe`      | ✓ fuzz |
| "Schalte die Pumpe ein" | `schalte die wasserpumpe ein` | ✓ exact (after expansion) |

### Pattern with slot, fuzz-resolved against the area registry

```yaml
conversation:
  intents:
    Botty_Wohnzimmer:
      - "(Reinige|Sauge) [im|das] {area}"
```

If the area registry contains `Wohnzimmer`, `Büro`, `Küche`:

| Spoken                  | STT gave              | Match → canonical                   |
|-------------------------|-----------------------|-------------------------------------|
| "Reinige das Wohnzimmer" | `reinige das wohnzma` | `reinige das wohnzimmer`           |
| "Sauge im Büro"         | `sauge im buro`       | `sauge im büro`                    |
| "Reinige die Küche"     | `reinige die kueche`  | `reinige die küche`                |

The captured slot text (`wohnzma`, `buro`, `kueche`) is fuzz-matched
against the area registry; the canonical sentence forwarded to the
base agent uses the registry's exact spelling so Hassil's strict
slot-list matcher accepts it.

### Wildcard slot (`custom_sentences/`)

For free-form slot values (a shopping-list item, a playlist name)
HA's `conversation.intents` schema isn't enough — you need a wildcard
slot list, which only `custom_sentences/` accepts.

```yaml
# custom_sentences/de/einkauf.yaml
language: de
intents:
  Einkauf_Add:
    data:
      - sentences:
          - "(setze|pack|tu|schreib) {item} auf (die|meine) Einkaufsliste"
          - "{item} auf die Einkaufsliste"
lists:
  item:
    wildcard: true
```

```yaml
intent_script:
  Einkauf_Add:
    speech.text: '"{{ item }}" hinzugefügt.'
    action:
      service: todo.add_item
      data:
        item: "{{ item }}"
      target:
        entity_id: todo.shopping_list
```

| Spoken                                    | Captured slot      |
|-------------------------------------------|--------------------|
| "Schreib Vollmilch auf die Einkaufsliste" | `vollmilch`        |
| "Pack Salami auf die Einkaufsliste"       | `salami`           |
| "Tortellini auf die Einkaufsliste"        | `tortellini`       |
| "Setze veganes Hack auf die Einkaufsliste" | `veganes hack`    |

The agent strips known STT-noise prefixes (single-letter garbles,
common 2-3-char artefacts) so `"e milch auf die einkaufsliste"` →
`milch`, not `e milch`.

## Diagnostics

When something doesn't match the way you expect, call:

```
service: closest_intent.dump_candidates
```

The integration logs:
- **INFO**: a one-line summary per loaded agent.
- **DEBUG**: a full JSON dump of the candidate pool, per-language —
  expansion rules, slot values from the registries, every expanded
  candidate sentence by intent.

Set the integration's logger to `debug` in `configuration.yaml`
first:

```yaml
logger:
  default: info
  logs:
    custom_components.closest_intent: debug
```

The agent also INFO-logs every match it makes
(`pumpr an → PumpeAn (score=87, captured=[]) → forwarding pumpe an
to conversation.home_assistant`), so you can usually see what's
happening without the explicit dump.

## Multi-language (Assist pipelines)

Each Assist pipeline carries its own language. Closest Intent builds
a separate candidate pool per language on first request, so a user
with parallel German and English pipelines gets the right vocabulary
for each. The matching algorithm itself is language-agnostic — only
the candidate pool / slot vocabulary differs.

## Robustness

The agent never raises out of `async_process`. If matching fails
unexpectedly, it falls through to passthrough; if forwarding to the
base agent fails, it returns `NO_INTENT_MATCH`. The entity stays
alive and ready for the next utterance.

## Development

Two equivalent ways to get a working dev environment, depending on
your preference. Both end up with the same toolchain (`pytest`,
`ruff`, `mypy`).

### With Nix

```bash
nix develop          # drops you in a shell with everything wired up
pytest tests/        # run the test suite
ruff check .         # lint
ruff format .        # format
nix flake check      # CI-style: runs lint + tests in a sandbox
```

### Without Nix

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
pytest tests/
ruff check .
ruff format .
```

The `pyproject.toml` is the source of truth for non-Nix
contributors; `flake.nix` mirrors the same dependency list from
nixpkgs. Keep them in sync when adding deps.

The test suite stubs `homeassistant.*` modules in `tests/conftest.py`
so it runs without a Home Assistant install — fast (under a second),
hermetic, no HA boot.

## License

MIT
