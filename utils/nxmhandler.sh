#!/bin/bash

# This script is used to send downloads from the Nexus Mods website to Mod Organizer 2.

nxm_link="$1" shift

# Check if an NXM link was provided.
if [ -z "$nxm_link" ]; then
    echo "ERROR: Please specify an NXM link to download." >&2
    # Exit with an error status.
    exit 1
fi

instance_dir="$HOME/MLMO2"

instance_dir_windowspath="Z:$(sed 's/\//\\\\/g' <<<"$instance_dir")"
pgrep -f "$instance_dir_windowspath\\\\ModOrganizer.exe"
process_search_status=$?

game_appid=$(cat "$instance_dir/appid.txt")

if [ "$process_search_status" == "0" ]; then
	echo "INFO: sending download '$nxm_link' to running Mod Organizer 2 instance"
	download_start_output=$(WINEESYNC=1 WINEFSYNC=1 protontricks-launch --appid "$game_appid" "$instance_dir/modorganizer2/nxmhandler.exe" "$nxm_link")
	download_start_status=$?
else
	echo "INFO: starting Mod Organizer 2 to download '$nxm_link'"
	download_start_output=$(steam -applaunch "$game_appid" "$nxm_link")
	download_start_status=$?
fi

if [ "$download_start_status" != "0" ]; then
	zenity --ok-label=Exit --error --text \
		"Failed to start download:\n\n$download_start_output"
	exit 1
fi