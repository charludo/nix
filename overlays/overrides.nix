prev: {
  # Used by GPU-VMs (esp. Jellyfin)
  vaapiIntel = prev.vaapiIntel.override { enableHybridCodec = true; };
}
