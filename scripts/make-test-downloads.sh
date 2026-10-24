#!/bin/bash
# Makes a folder of empty files named like downloads, for trying Reelmark
# by hand: drag the folder (or one of its subfolders) into the window.
# Reelmark only ever reads file names, never contents, so empty files
# behave exactly like real ones and take no space.
#
#   Screenshot/  Blender's open movies (Creative Commons) and public-domain
#                classics, named like typical releases. All are on TMDB, so
#                they match cleanly: good for screenshots anyone may share.
#   Stress/      Made-up names that try to break things: thousands of
#                episodes, season folders, multi-episode files, accents and
#                emoji, very long names, samples and hidden files that must
#                be skipped, non-video files, deep nesting, a folder linked
#                back into itself, and the same file reached twice.
#
# Usage: scripts/make-test-downloads.sh [folder] [--count N]
#   folder     where to create it (default: ~/Desktop/Reelmark Test Downloads)
#   --count N  how many made-up episodes to add to Stress/ (default 500)
#
# It refuses to touch a folder that already exists, so it can never
# overwrite anything. Delete the folder when you're done with it.
set -euo pipefail

folder="$HOME/Desktop/Reelmark Test Downloads"
count=500
while [ $# -gt 0 ]; do
  case "$1" in
    --count) count="${2:?--count needs a number}"; shift 2 ;;
    -h | --help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) folder="$1"; shift ;;
  esac
done
case "$count" in '' | *[!0-9]*) echo "--count must be a whole number" >&2; exit 1 ;; esac

if [ -e "$folder" ]; then
  echo "$folder already exists. Choose another folder, or delete that one first." >&2
  exit 1
fi

# Creates an empty file, and any folders it needs.
make() {
  mkdir -p "$(dirname "$folder/$1")"
  : > "$folder/$1"
}

# --- Screenshot: free-to-show films, named like real releases ------------

make "Screenshot/Big.Buck.Bunny.2008.1080p.BluRay.x264-GROUP.mkv"
make "Screenshot/Elephants.Dream.2006.720p.WEB-DL.AAC2.0.H.264.mkv"
make "Screenshot/Sintel (2010)/Sintel.2010.2160p.WEB-DL.DDP5.1.mkv"
make "Screenshot/Tears.of.Steel.2012.1080p.BluRay.DTS.x264.mkv"
make "Screenshot/Cosmos.Laundromat.2015.1080p.WEBRip.mp4"
make "Screenshot/Spring.2019.1080p.WEB.h264.mkv"
make "Screenshot/Sprite.Fright.2021.2160p.WEB.mkv"
make "Screenshot/Charge.2022.1080p.WEB-DL.mkv"
make "Screenshot/Nosferatu.1922.1080p.BluRay.FLAC.x264.mkv"
make "Screenshot/The.General.1926.REMASTERED.720p.BluRay.mkv"
make "Screenshot/Metropolis.1927.RESTORED.1080p.BluRay.mkv"
make "Screenshot/His.Girl.Friday.1940.1080p.BluRay.mkv"
make "Screenshot/Plan.9.from.Outer.Space.1957.720p.mkv"
make "Screenshot/Charade.1963.1080p.BluRay.mkv"
make "Screenshot/Night.of.the.Living.Dead.1968.1080p.BluRay.mkv"

# --- Stress: made-up names that try to break things ------------------------

# Many episodes, 50 to a season folder.
i=1
while [ "$i" -le "$count" ]; do
  season=$(( (i - 1) / 50 + 1 ))
  episode=$(( (i - 1) % 50 + 1 ))
  name=$(printf "Made.Up.Show.S%02dE%02d.1080p.WEB.h264-GROUP.mkv" "$season" "$episode")
  make "Stress/Made Up Show/Made.Up.Show.S$(printf %02d "$season").1080p/$name"
  i=$((i + 1))
done

# Episode layouts: multi-episode files, and season folders.
make "Stress/Episodes/Made.Up.Series.S02E01-E02.720p.mkv"
make "Stress/Episodes/Made Up Series 3x07.mkv"
make "Stress/Episodes/Invented Drama (2021)/Season 2/Episode 03.mkv"
make "Stress/Episodes/Invented Drama (2021)/Season 2/S02E04.mkv"
make "Stress/Episodes/Invented Drama (2021)/Season 2/05 - The One With A Title.mkv"

# Awkward names.
make "Stress/Names/Café.Été.2019.1080p.mkv"
make "Stress/Names/Ünïcödé Tëst 2020 🎬.mkv"
make "Stress/Names/1999.mkv"
make "Stress/Names/Untitled.Made.Up.Movie.mkv"
make "Stress/Names/UPPERCASE.MADE.UP.MOVIE.2018.MKV"
make "Stress/Names/$(printf 'A.Very.Long.Made.Up.Title%.0s' 1 2 3 4 5 6).2017.1080p.mkv"
make "Stress/Names/Made Up Movie 2016 [1080p] {edition-Director's Cut} (Dual Audio).mkv"
make "Stress/Names/Made.Up.Disc.2015.m2ts"
make "Stress/Names/Made.Up.Disc.2014.vob"
make "Stress/Names/Made.Up.Image.2013.iso"

# Must be skipped: samples, hidden files, non-video files, split archives.
make "Stress/Skipped/Made.Up.Movie.2012.sample.mkv"
make "Stress/Skipped/Sample/Made.Up.Movie.2012.mkv"
make "Stress/Skipped/.hidden.Made.Up.Movie.2012.mkv"
make "Stress/Skipped/Made.Up.Movie.2012.nfo"
make "Stress/Skipped/Made.Up.Movie.2012.en.srt"
make "Stress/Skipped/poster.jpg"
make "Stress/Skipped/Made.Up.Movie.2012.part.001"

# Deep nesting.
make "Stress/Deep/a/b/c/d/e/f/g/h/i/j/Deep.Made.Up.Movie.2011.mkv"

# Links: a folder linked back into itself must not loop, and a file
# reached through two paths must be listed once.
make "Stress/Links/Linked.Made.Up.Movie.2010.mkv"
ln -s .. "$folder/Stress/Links/Loop"
ln -s "$folder/Stress/Links" "$folder/Stress/Links Again"

files=$(find "$folder" -type f | wc -l | tr -d ' ')
echo "Made $files empty files in: $folder"
echo "Drag the whole folder, or Screenshot/ or Stress/, into Reelmark."
