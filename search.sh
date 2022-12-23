#!/usr/bin/env zsh

local root=`echo "$np_root"`
local calendar_format=`echo "$format_calendar_title"`

local query="$1"

# Generate the regex from the query
local regex=`echo "$query" | ./lib/jq-osx-amd64 -cRr '
    .
    | gsub("[^\\\p{L}\\\s\\\d]"; "") #remove everything except letters, numbers and spaces
    | gsub("\\\s+"; " ") # collapse spaces
    | gsub("^\\\s+"; "") # trim beginning
    | gsub("\\\s+$"; "") # trim end
    | split(" ")
    | map(. + "(?s:(?!" + . + ").)*?")
    | join("")
'`

# Get the actual file matches
local matches=`./lib/rg --pcre2 -iU --max-count=1 "$regex" "$root/Notes" "$root/Calendar"`

# Transform the matches into an alfred result list and append the "Create new note" item
local items=`echo "$matches" | ./lib/jq-osx-amd64 -csR "
    def callback_openNote(path): (\"noteplan://x-callback-url/openNote?filename=\" + (path | @uri));
    def callback_openCalendar(date): (\"noteplan://x-callback-url/openNote?noteDate=\" + date);
    .
    # map & create objects
    | split(\"\n\")
    | map(select(. != \"\"))
    | map(
        .
        | capture(\"(?<type>Calendar|Notes)/(?<path>.*?):(?<match>.*)\")
    )
    # keep only one match per file
    | unique_by(.path)
    # Add alfred required fields
    | map(
        .
        | if (.type == \"Calendar\") then
            {
                title: (if (.path | test(\"-W\")) then
                    .path[0:4] + \" Week \" + .path[6:8] 
                else
                    (
                        .path[0:4] + \"-\" + .path[4:6] + \"-\" + .path[6:8] + \"T12:00:00Z\"
                    ) | fromdate | strftime(\"$calendar_format\")
                end),
                subtitle: .match | gsub(\"\\\\\\s\"; \" \"),
                icon: {path: \"icons/icon-calendar.icns\"},
                arg: (callback_openCalendar(.path[0:8]) + \"&useExistingSubWindow=yes\"),
                mods: {
                    cmd: {
                        arg: (callback_openCalendar(.path[0:8]) + \"&subWindow=yes\"),
                        subtitle: \"Open in a new window\"
                    }
                }
            }
        else
            {
                title: .path | capture(\"^(?<skip>.*/)(?<title>.*?).md$\") | .title,
                subtitle: ((.path | capture(\"^(?<path>.*)/.*$\") | .path) + \" • \" + (.match | gsub(\"\\\\\\s\"; \" \"))),
                icon: {path: \"icons/icon-note.icns\"},
                arg: (callback_openNote(.path) + \"&useExistingSubWindow=yes\"),
                mods: {
                    cmd: {
                        arg: (callback_openNote(.path) + \"&subWindow=yes\"),
                        subtitle: \"Open in a new window\"
                    }
                }
            }
        end
    )
    | . + [{
        title: \"Create '$query'\",
        subtitle: \"Create a new note\",
        icon: {path: \"icons/icon-create.icns\"},
        arg: \"$query\",
    }]
    | {items: .}
"`

# hell yeah
echo $items