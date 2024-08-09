{ pkgs, ... }:
let
  remux = pkgs.writeShellApplication {
    name = "remux";
    runtimeInputs = [ pkgs.mkvtoolnix-cli ];
    text = /*bash */ ''
      set +o nounset
      set +o errexit
      set +o pipefail
      # shellcheck disable=SC2154
      if [ "$sonarr_eventtype" = "Test" ] || [ "$radarr_eventtype" = "Test" ]; then
          echo "Got test event."
          exit 0
      fi 

      if [ $# -gt 0 ]; then
          in="$1"
      elif [ -n "$sonarr_episodefile_sourcepath" ]; then
          in="$sonarr_episodefile_sourcepath"
      elif [ -n "$radarr_moviefile_sourcepath" ]; then
          in="$radarr_moviefile_sourcepath"
      else
          exit 1
      fi

      if [[ "$in" != *.mkv ]]; then
          exit 0
      fi

      ok_audio=("en" "de" "ja" "eng" "ger" "jpn" "unknown" "und")
      ok_subtitles=("en" "de" "eng" "ger" "unknown" "und")
      track_info=$(mkvmerge -J "$in")
      echo "$track_info" | jq -c '.tracks[]' | while read -r track; do
          track_type=$(echo "$track" | jq -r '.type')
          track_language=$(echo "$track" | jq -r '.properties.language')
          if [[ ("$track_type" == "audio" && ! " ''${ok_audio[*]} " =~ $track_language) || ("$track_type" == "subtitles" && ! " ''${ok_subtitles[*]} " =~ $track_language)  ]]; then
              echo "''${in##*/}, $track_type: $track_language"
              touch "tmp"
          fi
      done
      if [ -f "tmp" ]; then
          rm "tmp"
          mkvmerge -o "$in.tmp" -a de,en,ja,und -s de,en,und -B -M "$in"
          mv -f "$in.tmp" "$in"
          echo "Processed ''${in##*/}."
      else
          echo "Skipping ''${in##*/}."
      fi
    '';
  };
  remux-all = pkgs.writeShellApplication {
    name = "remux-all";
    runtimeInputs = [ remux ];
    text = ''
      find "/media/NAS/Filme & Serien/Serien" -type f -name "*.mkv" | while read -r file; do
          ${remux}/bin/remux "$file"
      done
      find "/media/NAS/Filme & Serien/Filme" -type f -name "*.mkv" | while read -r file; do
          ${remux}/bin/remux "$file"
      done
    '';
  };
in
pkgs.mkShell {
  nativeBuildInputs = [ remux remux-all ];
}
