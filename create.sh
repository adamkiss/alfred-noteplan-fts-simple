#!/usr/bin/env zsh

# local np_root='/Users/adam/Library/Containers/co.noteplan.NotePlan-setapp/Data/Library/Application Support/co.noteplan.NotePlan-setapp'
local note_root=`echo "$np_root"`
local note_format=`echo "$format_new_note"`

local title="$1"

# Get the local folders
local note_folders=`find "$note_root"/Notes -type d`

# Create the results
local results=`echo $note_folders | ./lib/jq-osx-amd64 -csRr "
    .
    | split (\"\n\")
    | map(. | sub(\"$note_root/Notes/\"; \"\"))
    | map(. | sub(\"$note_root/Notes\"; \"\"))
    | map(select(. | startswith(\"@\") | not))
    | map(select(. | endswith(\"_attachments\") | not))
    | map(select(. != \"\"))
    | map(
        {
            title: .,
            subtitle: (\"Create note '$title' in the folder \" + (. | split(\"/\") | last)),
            arg: (\"noteplan://x-callback-url/addNote?text=\" + (\"$note_format\" | sub(\"{title}\"; \"$title\") | @uri) + \"&folder=\" + (. | @uri) + \"&openNote=yes&useExistingSubWindow=yes\"),
            valid: \"yes\",
            icon: {path: \"icons/icon-create.icns\"}
        }
    )
    | . + [{
        title: \"Root Notes folder\",
        subtitle: \"Create note '$title' in the main folder\",
        arg: (\"noteplan://x-callback-url/addNote?text=\" + (\"$note_format\" | sub(\"{title}\"; \"$title\") | @uri) + \"&openNote=yes&useExistingSubWindow=yes\"),
        valid: \"yes\",
        icon: {path: \"icons/icon-create.icns\"}
    }]
    | {items: .}
"`

echo $results