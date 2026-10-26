{
  lib,
  pkgs,
  ...
}:
let
  # Speech-to-text: Moondream's Parakeet Ultra (a fine-tune of Parakeet TDT
  # 0.6B v3) on the NPU via cibernox/wyoming-parakeet-on-intel-npu, which
  # compiles onnx-asr's encoder (static-shape buckets) and decoder for the
  # NPU. Winner of the STT comparison (see the voice pipeline ToDo).
  stt = {
    repo = "Masterx/parakeet-tdt-0.6b-ultra-onnx";
    port = 10300;
    dataDir = "/var/lib/wyoming-parakeet-npu/ultra";
  };

  # Text-to-speech: Kyutai Pocket TTS (German model) via
  # marco-taylor/pocket-tts-german-wyoming. Advertises all 27 German preset
  # voices; the one used is picked per pipeline in HA. Shortlist: alba, anna,
  # charles, eve, jean, mary, michael, paul.
  tts = {
    port = 10200;
    voice = "eve"; # fallback for requests without a voice
    speed = "1.15"; # 0.8–1.2, time-stretched after synthesis; 1.0 bypasses it
    dataDir = "/var/lib/pocket-tts";
  };
in
{
  vm = {
    id = 2402;
    name = "SRV-VOICE";
    runOnGPUHost = true;
    # Intel NPU passed through for speech-to-text (see modules/vms/npu.nix).
    hardware.npu.enable = true;

    # TTS (Pocket) is the only real CPU user (~3 cores while speaking); STT
    # runs on the NPU and needs ~0.2 CPU-s per command. 8 vCPUs on 0-7 were no
    # faster than 6 unpinned, as vCPUs also landed on E-cores.
    hardware.cores = 4;
    # Core Ultra 5 225H on px-gpu: 0-3 P-cores, 4-7 and 8-11 E-core clusters,
    # 12-13 LP-E cores (`cat /sys/devices/cpu_core/cpus`, `lscpu -e`). Pinned to
    # the P-cores. Only applied when the image is created; on the existing VM:
    # `qm set 2402 --cores 4 --affinity 0-3`.
    hardware.affinity = "0-3";
    # 4.5 GB in use; headroom for compiling the encoder buckets at startup.
    hardware.memory = 12288;
    hardware.storage = "64G";

    networking.openPorts.tcp = [
      tts.port
      stt.port
    ];
  };

  systemd.services.pocket-tts = {
    description = "Wyoming Pocket TTS (German) text-to-speech";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    environment = {
      POCKET_TTS_LANGUAGE = "german";
      POCKET_TTS_VOICE = tts.voice;
      POCKET_TTS_SPEED = tts.speed;
      POCKET_TTS_THREADS = "4"; # upstream maximum
      # Upstream's default int8 weights suit the N100; on this CPU full
      # precision is far faster (first audio 0.12 s instead of 0.79 s).
      POCKET_TTS_QUANTIZE = "false";
      # Spells out numbers, times, dates, temperatures and units; the model
      # garbles digits otherwise.
      POCKET_TTS_NORMALIZE = "true";
      POCKET_TTS_NORMALIZER = "safe";
      POCKET_TTS_DOWNLOAD_VOICES = "true";
      POCKET_TTS_MODELS_DIR = "${tts.dataDir}/models";
      POCKET_TTS_VOICES_DIR = "${tts.dataDir}/voices";
      WYOMING_HOST = "0.0.0.0";
      WYOMING_PORT = toString tts.port;
      SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    };
    serviceConfig = {
      ExecStart = lib.getExe pkgs.ours.pocket-tts-german-wyoming;
      DynamicUser = true;
      StateDirectory = lib.removePrefix "/var/lib/" tts.dataDir;
      # The first start downloads the model (~220 MB) and the voices.
      TimeoutStartSec = "15min";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  systemd.services.wyoming-parakeet-npu = {
    description = "Wyoming Parakeet speech-to-text on the Intel NPU";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    environment.HF_REPO = stt.repo;
    serviceConfig = {
      # Downloads missing model files, builds the static decoder IR.
      ExecStartPre = "${lib.getExe' pkgs.ours.wyoming-parakeet-npu "wyoming-parakeet-npu-bootstrap"} --data-dir ${stt.dataDir}";
      ExecStart = lib.escapeShellArgs [
        (lib.getExe pkgs.ours.wyoming-parakeet-npu)
        "--uri"
        "tcp://0.0.0.0:${toString stt.port}"
        "--data-dir"
        stt.dataDir
        "--language"
        "de"
        "--device"
        "NPU"
        # Commands take 2.5 s (median), 3.4 s (90 %), 5.4 s at most in our 100
        # test recordings. Audio longer than the largest bucket is truncated,
        # which only hits TV or stray speech. All buckets compile at startup and
        # are cached in ov_cache (a 20 s bucket needs ~11 GB of RAM to compile).
        "--encoder-buckets"
        "1.8,3.2,5,10"
        "--encoder-lazy-buckets"
        ""
      ];
      DynamicUser = true;
      StateDirectory = lib.removePrefix "/var/lib/" stt.dataDir;
      Environment = [
        "HOME=${stt.dataDir}"
        "XDG_CACHE_HOME=${stt.dataDir}/cache"
      ];
      SupplementaryGroups = [ "render" ]; # /dev/accel/accel0
      # The first start downloads the model and compiles it for the NPU.
      TimeoutStartSec = "30min";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };
}
