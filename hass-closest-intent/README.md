# Closest Intent

A standalone Home Assistant conversation agent that fuzzy-matches the
user's text against the explicitly-defined `intent_script` patterns and
fires the closest one.

Built for the case where on-device STT (faster-whisper, etc.) is fast
but not 100% accurate, and full LLM fallback is overkill for a small
closed set of voice commands.

## How it works

- Reads `conversation.intents` at YAML load time. Those become the pool
  of candidate intents.
- On every utterance: expand patterns (`[opt]`, `(a|b)`, `{slot}`),
  score the user text against each candidate via RapidFuzz
  `token_sort_ratio`, pick the highest scorer above the threshold.
- On a match: substitute the captured slot text back into the matched
  pattern (the canonical sentence), then forward that cleaned-up
  sentence to the configured base agent (default: HA's bundled one).
  HA does the rest — Hassil parsing, slot validation, intent dispatch.
- On no match: forward the user's *original* text to the base agent
  unchanged. The user gets the base agent's locale-aware response
  (which might recognise the utterance, or might give a polite "I
  don't understand").

## Cascading with the default agent

This is **not** a wrapper around the default agent. It's a peer.

If you want HA's default agent tried first, with this acting only as a
fallback for misrecognised speech, enable
**"Prefer handling commands locally"** on the Assist pipeline:

> Settings → Voice assistants → (pipeline) → Edit → Conversation agent
>   → Prefer handling commands locally

When that toggle is on:
1. HA's default Hassil agent gets the utterance first.
2. If it cleanly handles it (lights, areas, built-ins) → done.
3. If it returns `NO_INTENT_MATCH` → falls through to **Closest Intent**,
   which fuzzy-matches your `conversation.intents` patterns.

When it's off, this agent runs solo.

## Why not embeddings?

Surface-level STT errors (homophones, missing articles, swapped word
order) are exactly what `token_sort_ratio` handles. Embedding models
add hundreds of MB of weights and 50–200 ms of inference for a
closed-set match — overkill.

## Configuration

```yaml
# Enable the agent — patterns are read automatically from `conversation.intents`.
closest_intent:

# Your normal HA intents block; closest_intent picks them up.
conversation:
  intents:
    WetterHeute:
      - "Wie ist das Wetter heute"
      - "Wie warm ist es draußen"
    PumpeAn:
      - "Schalte die Pumpe an"
      - "Pumpe an"

intent_script:
  WetterHeute:
    speech.text: "Aktuell sind es {{ states('sensor.foo') | round(0) }} Grad."
  PumpeAn:
    action:
      - action: switch.turn_on
        target:
          entity_id: switch.water_pump
    speech.text: "Pumpe aktiviert."
```

### Options

```yaml
closest_intent:
  threshold: 70                              # 0–100, higher = stricter
  expansion_cap: 16                          # 0 disables [...] / (a|b) expansion
  slot_extraction: true                      # best-effort slot capture
  include_builtins: false                    # also fuzzy-match HassTurnOn, etc.
  intents: null                              # null = all from conversation.intents;
                                             # or a list to restrict to specific names
```

### Modes

| You want… | Set |
|---|---|
| Fuzzy-match all your custom `conversation.intents` | (default — leave `intents: null`) |
| Restrict to a few specific intent names | `intents: [WetterHeute, PumpeAn]` |
| Also fuzzy-match HA's built-in intents (HassTurnOn, etc.) | `include_builtins: true` |

## Robustness

The agent never raises out of `async_process`. If an intent fires but
its action raises (entity doesn't exist, integration is down, etc.),
the agent logs the failure and returns `NO_INTENT_MATCH` — the entity
stays alive and ready for the next utterance.

## License

MIT
