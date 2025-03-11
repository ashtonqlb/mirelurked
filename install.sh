#!/bin/bash

# Script constants
readonly STEAMAPPSDIR=$HOME/.steam/steam/steamapps
# TODO: Add Steam Library detection rather than assuming install on root drive
readonly STEAMGAMEDIR=$STEAMAPPSDIR/common
readonly STEAMPREFIXDIR=$STEAMAPPSDIR/compatdata
readonly UTILDIR=./utils
readonly STL=$UTILDIR/steamtinkerlaunch
readonly ASSETDIR=./assets
readonly FNVAPPID=22380
# shellcheck disable=SC2034
readonly FNVCONFIGDIR=$STEAMPREFIXDIR/$FNVAPPID/pfx/drive_c/users/steamuser/Documents/My\ Games/FalloutNV
readonly FNVEXEPATH=$STEAMGAMEDIR/Fallout\ New\ Vegas/FalloutNV.exe
readonly FO3APPID=22370
# TODO Determine these ad-hoc
readonly MLMO2GAMEID=17784172602999177216
readonly MO2APPID=4140700354
# shellcheck disable=SC2034
readonly FNVROOT=$STEAMGAMEDIR/Fallout\ New\ Vegas
# shellcheck disable=SC2034
readonly FO3ROOT=$STEAMGAMEDIR/Fallout\ 3\ goty

# Functionality switches
isTTW=0

start() {
    if zenity --question --text="Please choose the option for the ModdingLinked guide you intend to follow" --ok-label="Viva New Vegas" --cancel-label="The Best of Times"; then
        isTTW=0  # "Viva New Vegas" clicked
    else
        isTTW=1  # "The Best of Times" clicked
    fi
}

# Function to check and set sudo password
check_sudo_password() {
    if  pgrep -s 0 '^sudo$' > /dev/null; then
        echo "Please set a password for your account now."
        until sudo passwd "$(whoami)"; do
            echo "Password setup failed. Please try again."
            sleep 1
        done
        echo "Sudo password set successfully."
    else
        echo "Sudo password already set. Good job!"
    fi
}

# Download the latest Protontricks, Hoolamike, ModdingLinked MO2 & xNVSE, put them all into the utildir
download_dependencies() {
    # Install Protontricks if it hasn't been already
    flatpak install --user flathub com.github.Matoking.protontricks
    
    # Download Hoolamike
    hoolamike_url=$(curl -s https://api.github.com/repos/Niedzwiedzw/hoolamike/releases/latest \
        | grep "browser_download_url.*linux-gnu.tar.gz" \
        | cut -d : -f 2,3 \
    | tr -d \" | tr -d ' ')
    hoolamike_file=$(basename "$hoolamike_url")
    zenity --progress --title="Downloading Dependencies" --text="$hoolamike_file" --pulsate --auto-close &
    zen_pid=$!
    wget -q "$hoolamike_url" -P "$UTILDIR"
    # Extract Hoolamike into a named folder
    mkdir -p "$UTILDIR/hoolamike"
    tar -xzf "$UTILDIR/$hoolamike_file" -C "$UTILDIR/hoolamike"
    kill $zen_pid
    
    # Download xNVSE
    xnvse_url=$(curl -s https://api.github.com/repos/xNVSE/NVSE/releases/latest \
        | grep "browser_download_url.*7z" \
        | cut -d : -f 2,3 \
    | tr -d \" | tr -d ' ')
    xnvse_file=$(basename "$xnvse_url")
    zenity --progress --title="Downloading Dependencies" --text="$xnvse_file" --pulsate --auto-close &
    zen_pid=$!
    wget -q "$xnvse_url" -P "$UTILDIR"
    # Extract xNVSE into a named folder
    7z x -y "$UTILDIR/$xnvse_file" -o"$UTILDIR/xNVSE" >/dev/null
    kill $zen_pid
    
    # Download ModdingLinked MO2
    mo2_url=$(curl -s https://api.github.com/repos/ModdingLinked/modorganizer/releases/latest \
        | grep "browser_download_url.*Archive.7z" \
        | cut -d : -f 2,3 \
    | tr -d \" | tr -d ' ')
    mo2_file=$(basename "$mo2_url")
    zenity --progress --title="Downloading Dependencies" --text="$mo2_file" --pulsate --auto-close &
    zen_pid=$!
    wget -q "$mo2_url" -P "$UTILDIR"
    # Extract MLMO2 into a named folder
    7z x -y "$UTILDIR/$mo2_file" -o"$UTILDIR/MLMO2" >/dev/null
    kill $zen_pid

    #Clone latest SteamTinkerLaunch
    git clone https://github.com/sonic2kk/steamtinkerlaunch $UTILDIR/steamtinkerlaunch
    chmod +x $UTILDIR/steamtinkerlaunch/steamtinkerlaunch
}

# Delete previous Fallout: New Vegas & Fallout 3 installations, delete their Steam installation records & reinstall
clean_install_titles() {
    if [ $isTTW = 1 ]; then
        rm -rf "${STEAMGAMEDIR:?/Fallout\ 3\ goty}"
        rm -rf "${STEAMPREFIXDIR:?}/$FO3APPID"
        xdg-open steam://uninstall/$FO3APPID
        xdg-open steam://install/$FO3APPID
    fi
    rm -rf "${STEAMGAMEDIR:?/Fallout\ New\ Vegas}"
    rm -rf "${STEAMPREFIXDIR:?}/$FNVAPPID"

    xdg-open steam://uninstall/$FNVAPPID
    xdg-open steam://install/$FNVAPPID
}

# Run Fallout NV (and Fallout 3) _one time_ to generate shader cache & config files. Do not move on until the game processes have been closed
generate_game_config() {
    if [ $isTTW = 1 ]; then
        xdg-open steam://rungameid/$FO3APPID
    fi
    xdg-open steam://rungameid/$FNVAPPID
}

install_xnvse() {
    rsync -Xav --progress $UTILDIR/xNVSE/* "${STEAMGAMEDIR:?}"/Fallout\ New\ Vegas/
}

install_mo2() {
    #Remove MLMO2 if already added
    xdg-open steam://uninstall/"$MLMO2GAMEID"

    steam -shutdown && sleep 3s &

    # Copy MO2 to user's /home directory
    rsync -Xav --progress $UTILDIR/MLMO2 "${HOME:?}"

    GAME_NAME="ModdingLinked MO2"
    EXE_PATH="$HOME/MLMO2/ModOrganizer.exe"
    ICON_PATH="$ASSETDIR/icon.png"
    START_DIR=$(dirname "$EXE_PATH")

    # Add MLMO2 to Steam

    $STL/steamtinkerlaunch addnonsteamgame \
    -an="$GAME_NAME" \
    -ep="/home/ky/MLMO2/ModOrganizer.exe" \
    -sd="\"$START_DIR\"" \
    -ip="\"$ICON_PATH\"" \
    -hd=0 \
    -adc=1 \
    -ao=1 \
    -ct="proton_9"
  # -hr=|--hero=                     Hero Art path    - Banner used on the Game Screen (3840x1240 recommended) - optional
  # -lg=|--logo=                     Logo Art path    - Logo that gets displayed on Game Screen (16:9 recommended) - optional   
  # -ba=|--boxart=                   Box Art path     - Cover art used in the library (600x900 recommended) - optional
  # -tf=|--tenfoot=                  Tenfoot Art path - Small banner used for recently played game in library (600x350 recommended) - optional

    # Create prefix
    xdg-open steam://nav/games/list

    zenity --info --text="To Finish MO2 installation, you must run it once. To do so:\n\n1. Wait for Steam to automatically open.\n\n2. Search for <b>$GAME_NAME</b> in Steam and launch it.\n\n3. When it launches, close it when the first window appears.\n\n4. Click the button at the bottom of this dialogue box to confirm" --title="Installing $GAME_NAME" --width 500 --ok-label="I have completed these steps"

    #TODO: Automatically determine MO2 GameID & AppID
    # export MO2APPID
    # MO2APPID=$($STL/steamtinkerlaunch gi "$GAME_NAME" | grep -Eo "[0-9]+") # heh
    # echo $MO2APPID

    # Add a G:/ drive to MO2 proton prefix that expands to steamapps/common.
    rm -f "$STEAMPREFIXDIR/$MO2APPID/pfx/dosdevices/g:" 2> /dev/null
    ln -s "$STEAMGAMEDIR" "$STEAMPREFIXDIR/$MO2APPID/pfx/dosdevices/g:"

    # Create mod link handlers
    touch "${HOME:?}"/MLMO2/nxmhandler.sh \
          "${HOME:?}"/MLMO2/nxmhamdler.desktop \
          "${HOME:?}"/MLMO2/modlhandler.desktop \
    # Write out NXM Handler
cat <<EOF > "$HOME/MLMO2/nxmhandler.sh"
    #!/bin/bash

    # This script is used to send downloads from the Nexus Mods website to Mod Organizer 2.

    nxm_link="\$1"
    shift

    # Check if an NXM link was provided.
    if [ -z "\$nxm_link" ]; then
        echo "ERROR: Please specify an NXM link to download." >&2
        # Exit with an error status.
        exit 1
    fi

    # Set MO2 directory.
    mo2_dir="\$HOME/MLMO2"

    # Set MO2 Steam AppID.
    game_appid="4140700354" # Replace this with \$MO2APPID

    # Send the download to the running Mod Organizer 2 instance.
    download_start=\$(WINEESYNC=1 WINEFSYNC=1 protontricks-launch --appid "\$game_appid" "\$mo2_dir/nxmhandler.exe" "\$nxm_link")
EOF
    chmod +x "$HOME/MLMO2/nxmhandler.sh"

    # Write out NXM handler.desktop
cat <<EOF > "$HOME/MLMO2/nxmhandler.desktop"
    [Desktop Entry]
    Categories=Game
    Exec=bash -c '"\$HOME/MLMO2/nxmhandler.sh" "\$@"' '\$HOME/MLMO2/nxmhandler.sh' %u
    MimeType=x-scheme-handler/nxm
    Name=ModdingLinked Mod Organizer 2 NXM Handler
    NoDisplay=true
    StartupNotify=false
    Terminal=false
    Type=Application
    X-KDE-SubstituteUID=false
EOF

    # Write out MODL handler.desktop
cat <<EOF > "$HOME/MLMO2/modlhandler.desktop"
    [Desktop Entry]
    Categories=Game
    Exec=bash -c '"\$HOME/MLMO2/nxmhandler.sh" "\$@"' '\$HOME/MLMO2/nxmhandler.sh' %u
    MimeType=x-scheme-handler/modl
    Name=ModdingLinked Mod Organizer 2 MODL Handler
    NoDisplay=true
    StartupNotify=false
    Terminal=false
    Type=Application
    X-KDE-SubstituteUID=false
EOF
    # Register new apps
    update-desktop-database

    # Install dependencies to MLMO2 Prefix with Protontricks
    flatpak run com.github.Matoking.protontricks --no-bwrap $MO2APPID -q xact xact_x64 d3dcompiler_47 d3dx11_43 d3dcompiler_43 vcrun2022 fontsmooth=rgb
}

download_prompt_ttw() {
    # Show a Zenity dialog box with a message and a button
    xdg-open "https://mod.pub/ttw/133/files" && zenity --info --text="There is no way to download Tale of Two Wastelands automatically, so you must do so manually\n\nTo do so, read the following instructions carefully:\n\n1. Click 'Manual Download'. You may need to create an account or sign in.\n\n2. Save the file to your Downloads folder.\n\n3. Click the button on the bottom of this dialog box." --title="Download TTW" --width 500 --ok-label="I have read the instructions"

    # TODO: Need to do this without inotifywait
    # Wait for the file download to appear
    inotifywait -m -e create --format '%f' ~/Downloads | while read -r filename; do
        if [[ "$filename" =~ Tale\ of\ Two\ Wastelands.*\.7z ]]; then
            # Extract the .7z file
            7z x -y "$HOME/Downloads/$filename" -o"$UTILDIR/TTW" >/dev/null

            # Move the extracted .mpi file
            mv $UTILDIR/Tale\ of\ Two\ Wastelands*.mpi $UTILDIR/hoolamike/ttw.mpi
            # Delete the junk folder
            rm -rf $UTILDIR/TTW
            break
        fi
    done
}

generate_hoolamike_config () {
    mkdir $UTILDIR/hoolamike/out

    while IFS= read -r line; do
    # Safely expand variables without executing commands
    parsed_line=$(echo "$line" | sed 's/"/\\"/g')
    eval echo "\"$parsed_line\""
    done < $UTILDIR/template.yaml > $UTILDIR/hoolamike/hoolamike.yaml
}

# Execute Hoolamike with the generated config, output results in utildir
install_ttw() {
    $SHELL
    ulimit -n 64556
    $UTILDIR/hoolamike/hoolamike tale-of-two-wastelands
    $SHELL
}

4gb_patch() {
    $UTILDIR/hoolamike/hoolamike fallout-new-vegas-patcher "$FNVEXEPATH"
}

finish() {
    zenity --info --text="You have successfully completed the pre-installation! Click the button below to start installing your mods" --title="Setup Complete" --width 500 --ok-label="Open ModdingLinked"

    if [ $isTTW == 1 ]; then
        xdg-open https://thebestoftimes.moddinglinked.com/essentials.html#MO2Downloads
    else
        xdg-open https://vivanewvegas.moddinglinked.com/utilities.html#Decompressor
    fi
}

# Main script execution

start
check_sudo_password
download_dependencies
clean_install_titles
generate_game_config
install_xnvse
install_mo2
if [ $isTTW == 1 ]; then
    download_prompt_ttw
fi

generate_hoolamike_config

if [ $isTTW == 1 ]; then
    install_ttw
else
    4gb_patch
fi
finish

Keep the session open
echo -e "\nPre-install completed. Press enter to exit."
read -r

#sneed :)