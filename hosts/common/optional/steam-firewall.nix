{
  networking.firewall = {
    allowedTCPPorts = [ 80 443 4380 ];
    allowedTCPPortRanges = [
      # Steam
      { from = 27000; to = 27050; }

      # ESO
      { from = 24100; to = 24131; }
      { from = 24300; to = 24331; }
      { from = 24500; to = 24507; }
    ];
    allowedUDPPortRanges = [
      # Steam
      { from = 27000; to = 27050; }

      # ESO
      { from = 24100; to = 24131; }
      { from = 24300; to = 24331; }
      { from = 24500; to = 24507; }

      # Stellaris
      { from = 17780; to = 17785; }
    ];
  };
}
