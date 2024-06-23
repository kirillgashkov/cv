#!/usr/bin/env bash

set -e


# Parse arguments.

language="en"
config=""
output=""
cv=""

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -l|--language)
            language="$2"
            shift 2
            ;;
        -c|--config)
            config="$2"
            shift 2
            ;;
        -o|--output)
            output="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: cv.sh [-l|--language <language>] [-c|--config <config>] [-o|--output <output>] <input>"
            exit 0
            ;;
        -*)
            echo "Error: unknown option: $1" >&2
            exit 2
            ;;
        *)
            if [[ -z "$cv" ]]; then
                cv="$1"
                shift
            else
                echo "Error: too many arguments: $1" >&2
                exit 2
            fi
            ;;
    esac
done

if [[ -z "$output" ]]; then
    output="$(dirname -- "$cv")"
fi

if [[ -z "$cv" ]]; then
    echo "Error: missing argument: <input>" >&2
    exit 2
fi
if [[ -z "$config" ]]; then
    echo "Error: missing option: -c|--config <config>" >&2
    exit 2
fi


# Create a temporary working directory.

tempdir="$PWD/.cv"; mkdir -p "$PWD/.cv"
on_exit() { :; }
trap 'on_exit' EXIT
trap 'on_exit; trap - TERM; kill -TERM "$$"' TERM
trap 'on_exit; trap - INT; kill -INT "$$"' INT


# Convert config and CV from TOML to JSON, then collapse localized strings to
# the target language. A localized string is an object that has the "en" key.
# It allows you to localize a string (or even a whole object) where it is
# needed. Example: { "name": "John", "role": { "en": "Backend Engineer", "ru":
# "Бэкенд-разработчик" } }.

config_json="$tempdir/config.json"
cv_json="$tempdir/cv.json"

yq -p toml -o json "$config" \
  | jq "$(printf 'walk(if type == "object" and has("en") then .["%s"] else . end)' "$language")" \
  > "$config_json"
yq -p toml -o json "$cv" \
  | jq "$(printf 'walk(if type == "object" and has("en") then .["%s"] else . end)' "$language")" \
  > "$cv_json"


# Get the directory of the script regardless of whether it was a symlink or not.

scriptdir=""
scriptfile="${BASH_SOURCE[0]}"
while [ -L "$scriptfile" ]; do
  scriptdir="$( cd -P "$( dirname "$scriptfile" )" >/dev/null 2>&1 && pwd )"
  scriptfile="$(readlink "$scriptfile")"
  [[ "$scriptfile" != /* ]] && scriptfile="$scriptdir/$scriptfile"
done
scriptdir="$( cd -P "$( dirname "$scriptfile" )" >/dev/null 2>&1 && pwd )"


# Build Markdown and PDF CVs using Pandoc Lua scripts and Latexmk. Scripts can
# only understand JSON, so that's what we are feeding them.

cv_md="$tempdir/cv.md"
cv_tex="$tempdir/cv.tex"
cv_pdf_dir="$tempdir/cv"
cv_pdf="$cv_pdf_dir/cv.pdf"

LUA_PATH="$scriptdir/src/?.lua;;" pandoc lua "$scriptdir/src/cmd/cv-md/cv_md.lua" --config "$config_json" "$cv_json" > "$cv_md"
LUA_PATH="$scriptdir/src/?.lua;;" pandoc lua "$scriptdir/src/cmd/cv-tex/cv_tex.lua" --config "$config_json" "$cv_json" > "$cv_tex"
latexmk -quiet -xelatex -interaction=nonstopmode -halt-on-error -file-line-error -shell-escape -output-directory="$cv_pdf_dir" "$cv_tex"


# Move the built Markdown and PDF to the output directory.

mkdir -p "$output"
mv "$cv_md" "$output/$(basename -- "$cv" .toml).md"
mv "$cv_pdf" "$output/$(basename -- "$cv" .toml).pdf"
