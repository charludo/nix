{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "remux";
  runtimeInputs = [ pkgs.mkvtoolnix-cli pkgs.ffmpeg ];
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
    elif [ -n "$sonarr_episodefile_path" ]; then
        in="$sonarr_episodefile_path"
    elif [ -n "$radarr_moviefile_path" ]; then
        in="$radarr_moviefile_path"
    else
        echo "No file given. Something wrong?"
        exit 1
    fi

    if [[ "$in" != *.mkv ]]; then
        echo "Not an mkv. Cannot remux."
        exit 0
    fi

    # remove unwanted tracks
    ok_audio=("en" "de" "ja" "eng" "ger" "jpn" "unknown" "und")
    ok_subtitles=("en" "de" "eng" "ger" "unknown" "und")
    track_info=$(mkvmerge -J "$in")
    echo "$track_info" | jq -c '.tracks[]' | while read -r track; do
        track_type=$(echo "$track" | jq -r '.type')
        track_language=$(echo "$track" | jq -r '.properties.language')
        if [[ ("$track_type" == "audio" && ! " ''${ok_audio[*]} " =~ $track_language) || ("$track_type" == "subtitles" && ! " ''${ok_subtitles[*]} " =~ $track_language)  ]]; then
            echo "''${in##*/}, $track_type: $track_language"
            touch "$in.marker"
        fi
    done
    if [ -f "$in.marker" ]; then
        rm "$in.marker"
        mkvmerge -o "$in.tmp" -a de,en,ja,und -s de,en,und -B -M "$in"
        mv -f "$in.tmp" "$in"
        echo "Removed unwanted tracks from ''${in##*/}."
    else
        echo "No unwanted tracks in ''${in##*/}."
    fi

    # convert ASS to SRT
    if ffmpeg -i "$in" 2>&1 | grep Subtitle | grep ass > /dev/null 2>&1; then
        ffmpeg -nostats -loglevel 0 -i "$in" -map 0:v -map 0:a -map 0:s -c copy -c:s text "$in.tmp.mkv"
        mv -f "$in.tmp.mkv" "$in"
        echo "Converted ASS subtitles to SRT in ''${in##*/}."
    fi
  '';
}
