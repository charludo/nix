# Intradel, Hergenrath (4728). No machine-readable source exists (recycleapp.be
# lists 4728 as unavailable); dates come from the "Kelmis - La Calamine" PDF:
# https://issuu.com/intradel/docs/kelmis_-_la_calamine_2026
# Re-check the next year's PDF in December and bump `until`, else the sensors run dry.
{
  hass.wasteCollection = {
    enable = true;

    collections = {
      # Zone 2 (Neu-Moresnet, Hergenrath & Lütticher Straße), yellow/orange bags.
      restmuell = {
        name = "Restmüll";
        subject = "der Restmüll";
        aliases = [
          "Restmüll"
          "Hausmüll"
          "orange Sack"
        ];
        weekday = "TH";
        start = "2026-10-01";
        until = "2026-12-31";
      };

      # Zone P1 (Hergenrath): paper/cardboard and blue PMC bags, same day.
      papier_plastik = {
        name = "Papier und Plastik";
        plural = true;
        aliases = [
          "Papier und Plastik"
          "Papier"
          "Altpapier"
          "Karton"
          "Pappe"
          "Plastik"
          "Plastikmüll"
          "blaue Sack"
          "blauen Säcke"
        ];
        weekday = "MO";
        everyWeeks = 2;
        start = "2026-10-12";
        until = "2026-12-31";
      };
    };
  };
}
