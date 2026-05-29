{ pkgs, ... }:
{
  # Standalone fuzzy-match conversation agent.
  #
  # Reads `services.home-assistant.config.conversation.intents` at YAML
  # load time, fuzzy-matches user input against those patterns, captures
  # whatever the user said in slot positions, then re-feeds the canonical
  # sentence to HA's default conversation agent. From that point on it's
  # a normal Hassil-handled command — slot lists, intent dispatch, the
  # whole thing.
  #
  # After deploy, pick `conversation.closest_intent` as the conversation
  # agent in HA → Settings → Voice assistants → (pipeline) → Edit. To
  # have the default agent tried first (with this acting only as a
  # fallback), enable **"Prefer handling commands locally"** on the same
  # pipeline screen.
  services.home-assistant.customComponents = [
    pkgs.ours.home-assistant.custom-components.closest_intent
  ];

  services.home-assistant.extraPackages =
    python3Packages: with python3Packages; [
      rapidfuzz
    ];

  services.home-assistant.config.closest_intent = {
    threshold = 70;
    slot_threshold = 60;
    expansion_cap = 16;
    slot_extraction = true;
    include_builtins = false;
  };

  services.home-assistant.config.logger.logs."custom_components.closest_intent" = "debug";
}
