#!/usr/bin/env zsh

local root="/Users/adam/Library/Containers/co.noteplan.NotePlan-setapp/Data/Library/Application Support/co.noteplan.NotePlan-setapp"
local calendar_format="%d.%m.%Y"

local query="$1"

local regex=`echo "$query" | jq -Rr '
    .
    | gsub("[^\\\p{L}\\\s\\\d]"; "") #remove everything except letters, numbers and spaces
    | gsub("\\\s+"; " ") # collapse spaces
    | gsub("^\\\s+"; "") # trim beginning
    | gsub("\\\s+$"; "") # trim end
    | gsub("\\\s"; "* ") # replace spaces with wildcard
    + "*"
'`

local matches=`cd $root && rg --pcre2 -iU --max-count=1 "$regex" Calendar Notes`

local items=`echo "$matches" | jq -sR "
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
    | map(
        .
        | if (.type == \"Calendar\") then
            . + {title: (
                    .path[0:4] + \"-\" + .path[4:6] + \"-\" + .path[6:8] + \"T12:00:00Z\"
                ) | fromdate | strftime(\"$calendar_format\")}
        else
            . + {
                    title: .path | capture(\"^(?<skip>.*/)(?<title>.*?).md$\") | .title
            }
        end
    )
    
"`

echo $items