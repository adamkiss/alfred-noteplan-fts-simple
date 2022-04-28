#!/usr/bin/env zsh

local root=`echo "$np_root"`
local calendar_format=`echo "$format_calendar_title"`

local query="$1"

local regex=`echo "$query" | ./lib/jq-osx-amd64 -cRr '
    .
    | gsub("[^\\\p{L}\\\s\\\d]"; "") #remove everything except letters, numbers and spaces
    | gsub("\\\s+"; " ") # collapse spaces
    | gsub("^\\\s+"; "") # trim beginning
    | gsub("\\\s+$"; "") # trim end
    | gsub("\\\s"; "* ") # replace spaces with wildcard
    + "*"
'`

local matches=`./lib/rg --pcre2 -iU --max-count=1 "$regex" "$root/Notes" "$root/Calendar"`

local items=`echo "$matches" | ./lib/jq-osx-amd64 -sR "
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
                    title: (
                        .path[0:4] + \"-\" + .path[4:6] + \"-\" + .path[6:8] + \"T12:00:00Z\"
                    ) | fromdate | strftime(\"$calendar_format\"),
                    subtitle: .match | gsub(\"\\\\\\s\"; \" \"),
                    icon: {path: \"icons/icon-calendar.icns\"},
                    arg: (callback_openCalendar(.path[0:8]) + \"&useExistingSubWindow=true\"),
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
                    arg: (callback_openNote(.path) + \"&useExistingSubWindow=true\"),
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

echo $items