{
  security.rtkit.enable = true;
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;

    extraConfig.pipewire = {
      "10-combined-source" = {
        "context.objects" = [
          {
            factory = "adapter";
            args = {
              "factory.name" = "support.null-audio-sink";
              "node.name" = "Multi Source Aggregator";
              "audio.position" = [ "MONO" ];
              "media.class" = "Audio/Duplex";
              "object.linger" = true;
              "monitor.channel-volumes" = true;
              "monitor.passthrough" = true;
            };
          }
        ];
      };
    };
  };
}
