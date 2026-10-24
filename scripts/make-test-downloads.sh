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
#                emoji, right-to-left and Chinese names, shell characters,
#                very long names, release-name noise, titles that several
#                films share, files that must be skipped (samples, hidden,
#                partial downloads, inside apps), duplicates that would
#                collide in the library, deep nesting, a folder linked back
#                into itself, broken links and the same file reached twice.
#
# Usage: scripts/make-test-downloads.sh [folder] [--count N] [--shows N]
#   folder     where to create it (default: ~/Desktop/Reelmark Test Downloads)
#   --count N  how many made-up episodes to add to Stress/Volume/
#              (default 500; try 10000 or 100000 for a data hoarder's folder)
#   --shows N  how many made-up shows they're spread across (default: one
#              per 100 episodes, 1 to 500). Each show is one TMDB search,
#              so even 100,000 episodes stay polite to TMDB.
#
# It refuses to touch a folder that already exists, so it can never
# overwrite anything. Delete the folder when you're done with it.
set -euo pipefail

folder="$HOME/Desktop/Reelmark Test Downloads"
count=500
shows=""
while [ $# -gt 0 ]; do
  case "$1" in
    --count) count="${2:?--count needs a number}"; shift 2 ;;
    --shows) shows="${2:?--shows needs a number}"; shift 2 ;;
    -h | --help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) folder="$1"; shift ;;
  esac
done
case "$count" in '' | *[!0-9]*) echo "--count must be a whole number" >&2; exit 1 ;; esac
[ -n "$shows" ] || shows=$(( count / 100 < 1 ? 1 : (count / 100 > 500 ? 500 : count / 100) ))
case "$shows" in '' | 0 | *[!0-9]*) echo "--shows must be a whole number above 0" >&2; exit 1 ;; esac

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
make "Screenshot/Agent.327.Operation.Barbershop.2017.1080p.WEB.mkv"
make "Screenshot/Sita.Sings.the.Blues.2008.720p.WEB-DL.mkv"
make "Screenshot/The.Cabinet.of.Dr.Caligari.1920.1080p.BluRay.mkv"
make "Screenshot/A.Trip.to.the.Moon.1902.RESTORED.1080p.mkv"
make "Screenshot/The.Kid.1921.1080p.BluRay.mkv"
make "Screenshot/Safety.Last.1923.1080p.BluRay.mkv"
make "Screenshot/Steamboat.Willie.1928.1080p.WEB.mkv"
make "Screenshot/Detour.1945.720p.BluRay.mkv"
make "Screenshot/The.Little.Shop.of.Horrors.1960.1080p.mkv"
make "Screenshot/Carnival.of.Souls.1962.1080p.BluRay.mkv"

# --- Stress: made-up names that try to break things ------------------------

# Volume: many episodes spread across many made-up shows, 20 to a season
# folder, as a big downloads folder would have them. Files are created a
# folder at a time, so 100,000 take seconds rather than minutes.
per_show=$(( (count + shows - 1) / shows ))
made=0
show=1
while [ "$made" -lt "$count" ]; do
  title=$(printf "Made.Up.Show.%03d" "$show")
  episode=1
  while [ "$episode" -le "$per_show" ] && [ "$made" -lt "$count" ]; do
    season=$(( (episode - 1) / 20 + 1 ))
    dir="$folder/Stress/Volume/$title/$title.S$(printf %02d "$season").1080p"
    mkdir -p "$dir"
    # This season's episodes, up to 20.
    last=$(( season * 20 < per_show ? season * 20 : per_show ))
    names=()
    while [ "$episode" -le "$last" ] && [ "$made" -lt "$count" ]; do
      names+=("$dir/$(printf "%s.S%02dE%02d.1080p.WEB.h264-GROUP.mkv" "$title" "$season" \
        $(( (episode - 1) % 20 + 1 )))")
      episode=$((episode + 1))
      made=$((made + 1))
    done
    touch "${names[@]}"
  done
  show=$((show + 1))
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
make "Stress/Names/ Made Up Movie With Spaces Around 2007 .mkv"
make "Stress/Names/סרט.מומצא.2006.mkv"
make "Stress/Names/فيلم.مختلق.2005.mkv"
make "Stress/Names/虚构的电影.2004.mkv"
make "Stress/Names/$(printf 'Cafe\xcc\x81').Decomposed.Accent.2003.mkv"
make "Stress/Names/Made.Up.Movie.2002.mkv.mkv"
make "Stress/Names/Made Up Movie 2001 ; rm -rf ~ ; .mkv"
make "Stress/Names/Made \$HOME \`whoami\` 'Quoted' \"Movie\" 2000.mkv"
make "Stress/Names/.mkv"
make "Stress/Names/no-extension-made-up-movie-1999"

# Must be skipped: samples, hidden files, non-video files, split archives.
make "Stress/Skipped/Made.Up.Movie.2012.sample.mkv"
make "Stress/Skipped/Sample/Made.Up.Movie.2012.mkv"
make "Stress/Skipped/.hidden.Made.Up.Movie.2012.mkv"
make "Stress/Skipped/Made.Up.Movie.2012.nfo"
make "Stress/Skipped/Made.Up.Movie.2012.en.srt"
make "Stress/Skipped/poster.jpg"
make "Stress/Skipped/Made.Up.Movie.2012.part.001"
make "Stress/Skipped/Made.Up.Movie.2012.mkv.part"
make "Stress/Skipped/Made.Up.Movie.2012.mkv.!qB"
make "Stress/Skipped/Made Up.app/Contents/Resources/Made.Up.Clip.2012.mkv"
make "Stress/Skipped/.Hidden Folder/Made.Up.Movie.2012.mkv"

# Release-name noise the parser has to see through.
make "Stress/Noise/Made.Up.Movie.2018.PROPER.REPACK.1080p.BluRay.REMUX.AVC.DTS-HD.MA.5.1-GROUP.mkv"
make "Stress/Noise/[GROUP] Made Up Anime - 01 [1080p][ABCD1234].mkv"
make "Stress/Noise/Made.Up.Show.2019.S01E01.1080p.WEB.mkv"
make "Stress/Noise/made_up_movie_with_underscores_2017.mkv"
make "Stress/Noise/Made-Up-Movie-With-Dashes-2016.mkv"
make "Stress/Noise/Made Up Movie With Spaces (2015) - 1080p.mkv"
make "Stress/Noise/Made Up Show - S01E02 - A Made Up Episode Title.mkv"
make "Stress/Noise/Made.Up.Daily.Show.2024.03.15.720p.WEB.mkv"
make "Stress/Noise/Made.Up.Show.S00E01.Special.mkv"
make "Stress/Noise/Made.Up.Movie.Part.1.2014.mkv"
make "Stress/Noise/Made.Up.Movie.2013/CD1/Made.Up.Movie.2013.CD1.avi"
make "Stress/Noise/Made.Up.Movie.2013/CD2/Made.Up.Movie.2013.CD2.avi"
make "Stress/Noise/Made.Up.Movie.2012.3D.HSBS.1080p.mkv"
make "Stress/Noise/Made.Up.Movie.2011.Extended.Cut.1080p.mkv"
make "Stress/Noise/Made.Up.Movie.2010.1080p.www.example-site.org.mkv"
make "Stress/Noise/Made Up Show S01 COMPLETE 1080p/Made.Up.Show.S01E01.mkv"
make "Stress/Noise/Made Up Show S01 COMPLETE 1080p/Made.Up.Show.S01E02.mkv"

# Real, free-to-show titles that test matching: no year where several
# films share a title, the original-language title, and a year that
# picks one version over another.
make "Stress/Matching/Night.of.the.Living.Dead.1080p.mkv"
make "Stress/Matching/Nosferatu.mkv"
make "Stress/Matching/Metropolis.mkv"
make "Stress/Matching/Nosferatu, eine Symphonie des Grauens (1922).mkv"
make "Stress/Matching/Das Cabinet des Dr. Caligari 1920.mkv"
make "Stress/Matching/Le Voyage dans la Lune 1902.mkv"
make "Stress/Matching/Night.of.the.Living.Dead.1990.mkv"

# The same file name in two folders: both map to one place in the
# library, so the second must be refused, never overwrite the first.
make "Stress/Duplicates/First/Made.Up.Duplicate.2009.1080p.mkv"
make "Stress/Duplicates/Second/Made.Up.Duplicate.2009.1080p.mkv"
make "Stress/Duplicates/Made.Up.Case.2008.mkv"
make "Stress/Duplicates/Other/MADE.UP.CASE.2008.mkv"

# Deep nesting.
make "Stress/Deep/a/b/c/d/e/f/g/h/i/j/Deep.Made.Up.Movie.2011.mkv"

# Links: a folder linked back into itself must not loop, and a file
# reached through two paths must be listed once.
make "Stress/Links/Linked.Made.Up.Movie.2010.mkv"
ln -s .. "$folder/Stress/Links/Loop"
ln -s "$folder/Stress/Links" "$folder/Stress/Links Again"
ln -s "$folder/Stress/Links/Linked.Made.Up.Movie.2010.mkv" "$folder/Stress/Links/Link To File.mkv"
ln -s "$folder/Stress/Links/Missing.Made.Up.Movie.2010.mkv" "$folder/Stress/Links/Broken Link.mkv"

files=$(find "$folder" -type f | wc -l | tr -d ' ')
echo "Made $files empty files in: $folder"
echo "Drag the whole folder, or Screenshot/ or Stress/, into Reelmark."
