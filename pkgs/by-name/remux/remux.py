#!/usr/bin/env python3

import json
import logging
import os
import shutil
import subprocess
import sys
from pathlib import Path

import puremagic
import shellescape
import shortuuid


def setup_logging():
    """
    Setup logging for TTY and the logfile.
    """
    formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")

    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)
    ch.setFormatter(formatter)

    log = logging.getLogger()
    log.setLevel(logging.DEBUG)
    log.addHandler(ch)

    fh = logging.FileHandler(os.environ.get("REMUX_LOG", "/media/NAS/remux.log"))
    fh.setLevel(logging.ERROR)
    fh.setFormatter(formatter)
    log.addHandler(fh)

    global logger
    logger = log


def check_test():
    """
    Helper function to allow Sonarr and Radarr to test connectivity with the script
    """
    sonarr_eventtype = os.environ.get("sonarr_eventtype")
    radarr_eventtype = os.environ.get("radarr_eventtype")
    if "Test" in (sonarr_eventtype, radarr_eventtype):
        subprocess.run("ffmpeg -h", check=True, shell=True)
        subprocess.run("mkvmerge -V", check=True, shell=True)

        logger.info("Got test event.")
        sys.exit(os.EX_OK)


def get_file():
    """
    Determine the input file, and check if it can be worked with.
    """
    try:
        in_file = sys.argv[1]
    except IndexError:
        in_file = os.environ.get(
            "sonarr_episodefile_path", os.environ.get("radarr_moviefile_path", "")
        )

    if not in_file:
        logger.error("No file given. Something wrong?")
        sys.exit(os.EX_USAGE)

    if not os.path.isfile(in_file):
        logger.error(f'File "{in_file}" does not exist.')
        sys.exit(os.EX_IOERR)

    try:
        file_type = puremagic.magic_file(in_file)[0]
    except puremagic.PureError:
        logger.error(
            f'PureMagic could not determine filetype for "{in_file}"! Will not continue remuxing.'
        )
        sys.exit(os.EX_IOERR)
    except IndexError:
        logger.error(
            f'PureMagic did not return any result for "{in_file}"! Will not continue remuxing.'
        )
        sys.exit(os.EX_IOERR)

    if not file_type.mime_type == "video/x-matroska":
        logger.error(
            f'File "{in_file}" does not appear to be of type mkv. Cannot remux.'
        )
        sys.exit(os.EX_OK)

    return in_file


def get_tmp_file(in_file, copy=False):
    """
    Get a temporary copy of the original file.
    """
    tmp_file = f"/tmp/{shortuuid.uuid()}.mkv"
    if copy:
        shutil.copyfile(in_file, tmp_file)
    return tmp_file


def get_tracks(in_file, raw_lists=False):
    """
    Helper function to get the existing video, audio, and subtitle tracks of a file
    """
    mkv_info = json.loads(
        subprocess.check_output(
            f"mkvmerge -J {shellescape.quote(in_file)}",
            shell=True,
        )
    )
    subtitles = (
        track["properties"]["language"]
        for track in mkv_info["tracks"]
        if track["type"] == "subtitles"
    )
    audio = (
        track["properties"]["language"]
        for track in mkv_info["tracks"]
        if track["type"] == "audio"
    )
    video = any(track["type"] == "video" for track in mkv_info["tracks"])

    if raw_lists:
        return (video, list(audio), list(subtitles))
    return (video, set(audio), set(subtitles))


def remux_successful(in_file, expected_audio, expected_subtitles):
    """
    Helper function to validate remuxed mkv files.
    """
    video, audio, subtitles = get_tracks(in_file)
    if not video:
        logger.critical("FATAL: remuxing removed video stream!")
        return False
    if not list(set(expected_audio) & audio):
        logger.critical("FATAL: remuxing removed wanted audio!")
        return False
    if not list(set(expected_subtitles) & subtitles):
        logger.critical("FATAL: remuxing removed wanted subtitles!")
        return False
    return True


def track_numbers_match(in_file, tmp_file):
    """
    Helper function to validate the number of video/audio/subtitle streams has not changed.
    """
    _, original_audio, original_subtitles = get_tracks(in_file, raw_lists=True)
    video, audio, subtitles = get_tracks(tmp_file, raw_lists=True)
    if not video:
        logger.critical("FATAL: subtitle conversion removed video stream!")
        return False
    if not len(audio) == len(original_audio):
        logger.critical("FATAL: subtitle conversion altered audio!")
        return False
    if not len(subtitles) == len(original_subtitles):
        logger.critical("FATAL: subtitle conversion altered subtitles!")
        return False
    return True


def srt_conversion_successful(in_file, tmp_file):
    """
    Helper function to validate files with converted subtitles.
    """
    if not track_numbers_match(in_file, tmp_file):
        return False

    subtitles = [
        track
        for track in json.loads(
            subprocess.check_output(
                f"mkvmerge -J {shellescape.quote(tmp_file)}",
                shell=True,
            )
        )["tracks"]
        if track["type"] == "subtitles"
    ]
    if any(subtitle["codec"] != "SubRip/SRT" for subtitle in subtitles):
        logger.critical(
            f'FATAL: subtitle conversion failed in at least one case for "{in_file}"!'
        )
        return False

    return True


def audio_conversion_successful(in_file, tmp_file):
    """
    Helper function to validate files with converted audio.
    """
    if not track_numbers_match(in_file, tmp_file):
        return False

    audio = [
        track
        for track in json.loads(
            subprocess.check_output(
                f"mkvmerge -J {shellescape.quote(tmp_file)}",
                shell=True,
            )
        )["tracks"]
        if track["type"] == "audio"
    ]
    if any(track["codec"] != "AAC" for track in audio):
        logger.critical(
            f'FATAL: audio conversion failed in at least one case for "{in_file}"!'
        )
        return False

    return True


def get_extra_wanted_tracks(in_file):
    """
    Recurse up the tree and check for .remux files, which can contain
    extra languages to keep for all files in all subdirs.
    """
    in_file = os.environ.get(
        "sonarr_episodefile_sourcepath",
        os.environ.get("radarr_moviefile_sourcepath", in_file),
    )
    p = Path(in_file).resolve()

    remux_files = []
    while str(p) != "/":
        p = p.parent
        remux_files.append(p / ".remux")

    tracks = []
    for f in remux_files:
        try:
            with f.open("r", encoding="utf-8") as file:
                tracks += [t.strip() for t in file.read().split(",") if t.strip()]
        except FileNotFoundError:
            continue

    return tracks


def remux_languages(languages):
    """
    Removes all >2-char length language codes, only leaving those that mkvmerge accepts,
    then readds the `und` (undefined) code and returns comma-separated string
    """
    return ",".join([lang for lang in languages if len(lang) == 2] + ["und"])


def remove_unwanted_tracks(in_file):
    """
    Remove all audio and subtitle tracks which are in unmonitored languages
    """
    ok_subtitles = ["en", "eng", "de", "ger", "ja", "jpn", "und", "unknown"]
    ok_audio = ["en", "eng", "de", "ger", "ja", "jpn", "und", "unknown"]

    extra_tracks = get_extra_wanted_tracks(in_file)
    ok_subtitles += extra_tracks
    ok_audio += extra_tracks

    _, existing_audio, existing_subtitles = get_tracks(in_file)
    if not (
        list(set(ok_subtitles) & existing_subtitles)
        or list(set(ok_audio) & existing_audio)
    ):
        logger.info(
            f'Video "{in_file}" has no subtitles or audio in any acceptable language. Will not remove any tracks.'
        )
        return

    if existing_subtitles <= set(ok_subtitles) and existing_audio <= set(ok_audio):
        logger.info(f"No unwanted tracks in {in_file}. No need to remux.")
        return

    tmp_file = get_tmp_file(in_file)
    try:
        subprocess.run(
            f"mkvmerge -o {tmp_file} -a {remux_languages(ok_audio)} -s {remux_languages(ok_subtitles)} -B -M {shellescape.quote(in_file)}",
            check=True,
            shell=True,
        )
    except Exception:
        logger.error(f'Something went wrong during the remux of "{in_file}". Skipping.')
        os.remove(tmp_file)
        return

    if not remux_successful(tmp_file, ok_audio, ok_subtitles):
        logger.error(
            f'Remuxing had unintended consequences. Restoring original file "{in_file}".'
        )
        os.remove(tmp_file)
        return

    os.remove(in_file)
    shutil.copyfile(tmp_file, in_file)
    os.remove(tmp_file)
    logger.info(f"Removed unwanted tracks from {in_file}.")


def convert_subtitles(in_file):
    """
    Convert all subtitles to embedded SRT subs, since some players have problems with e.g. ASS
    """
    mkv_info = json.loads(
        subprocess.check_output(
            f"mkvmerge -J {shellescape.quote(in_file)}",
            shell=True,
        )
    )
    subtitles = [track for track in mkv_info["tracks"] if track["type"] == "subtitles"]
    if all(subtitle["codec"] in ["SubRip/SRT", "HDMV PGS"] for subtitle in subtitles):
        logger.info(f'All subtitles of "{in_file}" are SRT. No need to convert.')
        return

    tmp_file = get_tmp_file(in_file)
    try:
        subprocess.run(
            f"ffmpeg -nostats -loglevel 0 -i {shellescape.quote(in_file)} -map 0:v -map 0:a -map 0:s -c copy -c:s text {tmp_file}",
            check=True,
            shell=True,
        )
    except Exception:
        logger.error(
            f'Something went wrong during the subtitle conversion of "{in_file}". Skipping.'
        )
        os.remove(tmp_file)
        return

    if not srt_conversion_successful(in_file, tmp_file):
        logger.error(
            f'Converting subtitles had unintended consequences. Restoring original file "{in_file}".'
        )
        os.remove(tmp_file)
        return

    os.remove(in_file)
    shutil.copyfile(tmp_file, in_file)
    os.remove(tmp_file)
    logger.info(f"Converted subtitles to SRT in {in_file}.")


def convert_unsupported_audio(in_file):
    """
    Convert audio streams with formats not supported by all clients (esp. Android TV) to AAC
    """
    unsupported_formats = ["FLAC"]

    mkv_info = json.loads(
        subprocess.check_output(
            f"mkvmerge -J {shellescape.quote(in_file)}",
            shell=True,
        )
    )
    audio = [track for track in mkv_info["tracks"] if track["type"] == "audio"]
    if all(track["codec"] not in unsupported_formats for track in audio):
        logger.info(f'All audio codecs are supported. No need to convert "{in_file}".')
        return

    tmp_file = get_tmp_file(in_file)
    try:
        subprocess.run(
            f"ffmpeg -nostats -loglevel 0 -i {shellescape.quote(in_file)} -map 0 -c:v copy -c:a aac -b:a 256k -c:s copy {tmp_file}",
            check=True,
            shell=True,
        )
    except Exception:
        logger.error(
            f'Something went wrong during the audio conversion of "{in_file}". Skipping.'
        )
        os.remove(tmp_file)
        return

    if not audio_conversion_successful(in_file, tmp_file):
        logger.error(
            f'Converting audio had unintended consequences. Restoring original file "{in_file}".'
        )
        os.remove(tmp_file)
        return

    os.remove(in_file)
    shutil.copyfile(tmp_file, in_file)
    os.remove(tmp_file)
    logger.info(f"Converted audio to AAC in {in_file}.")


def check_video_audio_present(in_file):
    """
    Helper method for checking if the file looks valid,
    i.e.: has at least one video and audio track.
    """
    video, audio, _ = get_tracks(in_file, raw_lists=True)
    if not video or not len(audio):
        logger.warning(in_file)
        with open("/media/NAS/broken.log", "a", encoding="utf-8") as f:
            f.write(f"{in_file}\n")


if __name__ == "__main__":
    setup_logging()
    check_test()

    if len(sys.argv) == 2 and sys.argv[1] == "all":
        for path in Path("/media/NAS/Filme & Serien/Anime").rglob("*.mkv"):
            subprocess.run(f'remux "{path}"', shell=True)
        for path in Path("/media/NAS/Filme & Serien/Anime Movies").rglob("*.mkv"):
            subprocess.run(f'remux "{path}"', shell=True)
        for path in Path("/media/NAS/Filme & Serien/Filme").rglob("*.mkv"):
            subprocess.run(f'remux "{path}"', shell=True)
        for path in Path("/media/NAS/Filme & Serien/Kids Movies").rglob("*.mkv"):
            subprocess.run(f'remux "{path}"', shell=True)
        for path in Path("/media/NAS/Filme & Serien/Klassiker").rglob("*.mkv"):
            subprocess.run(f'remux "{path}"', shell=True)
        for path in Path("/media/NAS/Filme & Serien/Serien").rglob("*.mkv"):
            subprocess.run(f'remux "{path}"', shell=True)

        sys.exit(os.EX_OK)

    path = get_file()
    remove_unwanted_tracks(path)
    # convert_subtitles(path)
    # convert_unsupported_audio(path)
    check_video_audio_present(path)
