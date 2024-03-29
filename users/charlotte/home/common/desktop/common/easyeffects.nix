{ config, pkgs, ... }:
let
  kernel-path = ".config/easyeffects/irs/Dolby ATMOS ((128K MP3)) 1.Default.irs";
in
{
  services.easyeffects = {
    enable = true;
    preset = "Default";
  };
  home.file."${kernel-path}".source = "${pkgs.fetchurl {
    url = "https://github.com/JackHack96/EasyEffects-Presets/raw/master/irs/Dolby%20ATMOS%20((128K%20MP3))%201.Default.irs";
    sha256 = "sha256-9Ft1HZLFTBiGRfh/wJiGZ9WstMtvdtX+u3lVY3JCVAM=";
  }}";
  home.file.".config/easyeffects/output/Default.json".text = /* json */ ''
    {
        "output": {
            "bass_enhancer#0": {
                "amount": 3.0000000000000027,
                "blend": 0.0,
                "bypass": false,
                "floor": 20.0,
                "floor-active": false,
                "harmonics": 8.5,
                "input-gain": 0.0,
                "output-gain": 0.0,
                "scope": 80.0
            },
            "blocklist": [],
            "convolver#0": {
                "autogain": false,
                "bypass": false,
                "input-gain": -1.9,
                "ir-width": 100,
                "kernel-path": "${config.home.homeDirectory}/${kernel-path}",
                "output-gain": -3.3
            },
            "equalizer#0": {
                "balance": 0.0,
                "bypass": false,
                "input-gain": -3.1,
                "left": {
                    "band0": {
                        "frequency": 32.0,
                        "gain": 4.0,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.504760237537245,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    },
                    "band1": {
                        "frequency": 64.0,
                        "gain": 2.0,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.5047602375372453,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    },
                    "band2": {
                        "frequency": 125.0,
                        "gain": 1.0,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.504760237537245,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    },
                    "band3": {
                        "frequency": 250.0,
                        "gain": 0.96,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.504760237537245,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    },
                    "band4": {
                        "frequency": 500.0,
                        "gain": 0.23,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.5047602375372453,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    },
                    "band5": {
                        "frequency": 1000.0,
                        "gain": 0.14,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.504760237537245,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    },
                    "band6": {
                        "frequency": 2000.0,
                        "gain": 1.14,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.5047602375372449,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    },
                    "band7": {
                        "frequency": 4000.0,
                        "gain": 2.0,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.5047602375372449,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    },
                    "band8": {
                        "frequency": 8000.0,
                        "gain": 3.0,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.5047602375372453,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    },
                    "band9": {
                        "frequency": 16000.0,
                        "gain": 3.0,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.504760237537245,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    }
                },
                "mode": "IIR",
                "num-bands": 10,
                "output-gain": -2.6,
                "pitch-left": 0.0,
                "pitch-right": 0.0,
                "right": {
                    "band0": {
                        "frequency": 32.0,
                        "gain": 4.0,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.504760237537245,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    },
                    "band1": {
                        "frequency": 64.0,
                        "gain": 2.0,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.5047602375372453,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    },
                    "band2": {
                        "frequency": 125.0,
                        "gain": 1.0,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.504760237537245,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    },
                    "band3": {
                        "frequency": 250.0,
                        "gain": 0.96,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.504760237537245,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    },
                    "band4": {
                        "frequency": 500.0,
                        "gain": 0.23,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.5047602375372453,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    },
                    "band5": {
                        "frequency": 1000.0,
                        "gain": 0.14,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.504760237537245,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    },
                    "band6": {
                        "frequency": 2000.0,
                        "gain": 1.14,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.5047602375372449,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    },
                    "band7": {
                        "frequency": 4000.0,
                        "gain": 2.0,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.5047602375372449,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    },
                    "band8": {
                        "frequency": 8000.0,
                        "gain": 3.0,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.5047602375372453,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    },
                    "band9": {
                        "frequency": 16000.0,
                        "gain": 3.0,
                        "mode": "RLC (BT)",
                        "mute": false,
                        "q": 1.504760237537245,
                        "slope": "x1",
                        "solo": false,
                        "type": "Bell",
                        "width": 4.0
                    }
                },
                "split-channels": false
            },
            "plugins_order": [
                "equalizer#0",
                "convolver#0",
                "bass_enhancer#0"
            ]
        }
    }
  '';
  home.file.".config/easyeffects/input/Default.json".text = /* json */ ''
      {
        "input": {
            "blocklist": [],
            "deesser#0": {
                "bypass": false,
                "detection": "RMS",
                "f1-freq": 6000.0,
                "f1-level": 0.0,
                "f2-freq": 4500.0,
                "f2-level": 12.0,
                "f2-q": 1.0,
                "input-gain": 0.0,
                "laxity": 15,
                "makeup": 0.0,
                "mode": "Wide",
                "output-gain": 0.1,
                "ratio": 3.0,
                "sc-listen": false,
                "threshold": -18.0
            },
            "echo_canceller#0": {
                "bypass": false,
                "filter-length": 100,
                "input-gain": 0.0,
                "near-end-suppression": -70,
                "output-gain": 0.0,
                "residual-echo-suppression": -70
            },
            "plugins_order": [
                "speex#0",
                "rnnoise#0",
                "echo_canceller#0",
                "deesser#0"
            ],
            "rnnoise#0": {
                "bypass": false,
                "enable-vad": false,
                "input-gain": 0.0,
                "model-path": "",
                "output-gain": 1.1,
                "release": 20.0,
                "vad-thres": 50.0,
                "wet": 0.0
            },
            "speex#0": {
                "bypass": false,
                "enable-agc": false,
                "enable-denoise": true,
                "enable-dereverb": false,
                "input-gain": 0.0,
                "noise-suppression": -70,
                "output-gain": 0.0,
                "vad": {
                    "enable": false,
                    "probability-continue": 90,
                    "probability-start": 95
                }
            }
        }
    }
  '';
}
