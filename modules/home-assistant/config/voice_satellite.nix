{ config, ... }:
let
  e = config.hass.entities;
in
{
  # Wyoming satellite (ReSpeaker mic array v2.0) has no speaker, so the
  # TTS leg of the assist pipeline has nowhere to land. ``tts_relay``
  # catches the pipeline's TTS_END event in-process and replays the
  # audio on the living-room Sonos with ``announce: true`` (ducks,
  # plays, restores).
  #
  # The satellite entity_id is whatever HA auto-discovered after
  # wyoming-satellite came online — check Settings → Devices &
  # services → Wyoming Protocol and adjust the string below if needed.
  hass.ttsRelay = [
    {
      satellite = "assist_satellite.hub_satellite";
      target = e.media_player.living_room;
      volume = 0.4;
    }
  ];
}
