#!/bin/bash

# Functionality switches
isTTW=0
STEAMLIBRARYDIR=""

# Script constants
readonly STEAMAPPSDIR=$STEAMLIBRARYDIR/steamapps
readonly STEAMGAMEDIR=$STEAMAPPSDIR/common
readonly STEAMPREFIXDIR=$STEAMAPPSDIR/compatdata
readonly UTILDIR=./utils
readonly STL=$UTILDIR/steamtinkerlaunch
readonly FNVAPPID=22380
# shellcheck disable=SC2034
readonly FNVCONFIGDIR=$STEAMPREFIXDIR/$FNVAPPID/pfx/drive_c/users/steamuser/Documents/My\ Games/FalloutNV
readonly FNVEXEPATH=$STEAMGAMEDIR/Fallout\ New\ Vegas/FalloutNV.exe
readonly FO3APPID=22370

# shellcheck disable=SC2034
readonly FNVROOT=$STEAMGAMEDIR/Fallout\ New\ Vegas
# shellcheck disable=SC2034
readonly FO3ROOT=$STEAMGAMEDIR/Fallout\ 3\ goty

# Install SteamTinkerLaunch and add it to PATH
install_stl() {
    git clone https://github.com/sonic2kk/steamtinkerlaunch "$HOME"

    # Move STL to hidden directory to prevent hapless users from deleting it
    mv "$HOME"/steamtinkerlaunch "$HOME"/.steamtinkerlaunch 
    chmod +x "$HOME"/.steamtinkerlaunch/steamtinkerlaunch

    # Add STL to PATH
    {
        echo "# Steam Tinker Launch"
        echo "export STL_INSTALL=$HOME/.steamtinkerlaunch"
        echo "export PATH=$STL_INSTALL:$PATH"
    } >> "$HOME/.bash_profile"

    # Reload bash_profile
    # shellcheck disable=SC1091
    . "$HOME/.bash_profile"

    # Add STL to Steam
    steamtinkerlaunch compat add
}

start() {
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

    if ! command -v steamtinkerlaunch > /dev/null 2>&1; then
        install_stl
    fi

    if zenity --question --text="Please choose the option for the ModdingLinked guide you intend to follow" --ok-label="Viva New Vegas" --cancel-label="The Best of Times"; then
        isTTW=0  # "Viva New Vegas" clicked
    else
        isTTW=1  # "The Best of Times" clicked
    fi
}

select_steam_library() {
    local vdf_file="$HOME/.local/share/Steam/steamapps/libraryfolders.vdf}"
    
    # Verify VDF file exists
    if [[ ! -f "$vdf_file" ]]; then
        zenity --error --text="Could not find libraryfolders.vdf" --title="File Error"
        return 1
    fi

    # Extract library paths using proper VDF parsing
    readarray -t steam_paths < <(
        awk -F '"' '/"path"/ {print $4}' "$vdf_file" | 
        grep -v '^$'
    )

    # Verify we found paths
    if [[ ${#steam_paths[@]} -eq 0 ]]; then
        zenity --error --text="No Steam library paths found" --title="Parse Error"
        return 1
    fi

    # Present Zenity selection dialog
    selected_path=$(zenity --list \
        --title="Select Steam Library" \
        --text="Choose your Steam library folder:" \
        --column="Available Libraries" "${steam_paths[@]}")

    # Set environment variable if selection made
    if [[ -n "$selected_path" ]]; then
        export STEAMLIBRARYDIR="$selected_path"
        zenity --info --text="Steam library set to:\n$STEAMLIBRARYDIR" --title="Selection Confirmed"
        return 0
    else
        zenity --warning --text="No library selected" --title="Selection Cancelled"
        return 1
    fi
}

# Download the latest Protontricks, Hoolamike, ModdingLinked MO2 & xNVSE, put them all into the utildir
download_dependencies() {
    # Install Protontricks if it hasn't been already
    flatpak update && flatpak install -y --user flathub com.github.Matoking.protontricks
    
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
    zenity --progress \
  --title="Installing MO2" \
  --text="Checking for existing installation" \
  --percentage=0

    #Remove MLMO2 if already added
    xdg-open steam://uninstall/"$MLMO2GAMEID"

    steam -shutdown && sleep 3s &

    zenity --progress \
    --title="Installing MO2" \
    --text="Copying MLMO2 to /home" \
    --percentage=30

    # Copy MO2 to user's /home directory
    rsync -Xav --progress $UTILDIR/MLMO2 "${HOME:?}"


    zenity --progress \
    --title="Installing MO2" \
    --text="Adding MLMO2 to Steam" \
    --percentage=30

    local GAME_NAME="ModdingLinked MO2"
    local EXE_PATH="$HOME/MLMO2/ModOrganizer.exe"
    local ICON_PATH="$UTILDIR/assets/icon.png"
    local HERO_PATH="$UTILDIR/assets/hero.png"
    local BOXART_PATH="$UTILDIR/assets/boxart.png"
    local TENFOOT_PATH="$UTILDIR/assets/boxart.png"
    local START_DIR
    START_DIR=$(dirname "$EXE_PATH")

    # Add MLMO2 to Steam with Steam Tinker Launch
    $STL/steamtinkerlaunch addnonsteamgame \
    -an="$GAME_NAME" \
    -ep="$HOME/MLMO2/ModOrganizer.exe" \
    -sd="\"$START_DIR\"" \
    -ip="\"$ICON_PATH\"" \
    -hd=0 \
    -adc=1 \
    -ao=1 \
    -ct="proton_9" \
    -hr="\"$HERO_PATH\"" \
    -ba="\"$BOXART_PATH\"" \
    -tf="\"$TENFOOT_PATH\"" \
    -lo="STEAM_COMPAT_DATA_PATH=\"$HOME/.local/share/Steam/steamapps/compatdata/22380\" %command%"


    #TODO: If we can calculate GameIDs this section might be redundant.
    zenity --info --text="To Finish MO2 installation, you must run it once. To do so:\n\n1. Wait for Steam to automatically open.\n\n2. Search for <b>$GAME_NAME</b> in Steam and launch it.\n\n3. When it launches, close it when the first window appears.\n\n4. Click the button at the bottom of this dialogue box to confirm" --title="Installing $GAME_NAME" --width 500 --ok-label="I have completed these steps"
    
    # Automatically determine MO2 AppIDs (compatdata path & shortcut)
    MO2APPID=$(appId "$GAME_NAME" "ModOrganizer.exe")
    MO2LAID=$(longAppID "$MO2APPID")

    # Create prefix
    xdg-open steam://rungameid/"$MO2LAID"

    # Export MO2APPID to file. We will use this later!
    cat "$MO2APPID" < "$HOME/MLMO2/appid.txt"

    # Create mod link handler
    rsync -Xav --progress $UTILDIR/nxmhandler.sh "${HOME:?}"/MLMO2
    chmod +x "${HOME:?}"/MLMO2/nxmhandler.sh
    rsync -Xav --progress $UTILDIR/nxmhandler.desktop "${HOME:?}"/MLMO2

    # Register new apps
    update-desktop-database

    # Install dependencies to MLMO2 prefix with Protontricks
    flatpak run com.github.Matoking.protontricks --no-bwrap "$MO2APPID" -q - fontsmooth=rgb xact xact_x64 vcrun2022 dotnet6 dotnet7 dotnet8 d3dcompiler_47 d3dx11_43 d3dcompiler_43 d3dx9_43 d3dx9 vkd3d
}

download_prompt_ttw() {
    # Show a Zenity dialog box with a message and a button
    xdg-open "https://mod.pub/ttw/133/files" && zenity --info --text="There is no way to download Tale of Two Wastelands automatically, so you must do so manually\n\nTo do so, read the following instructions carefully:\n\n1. Click <b>Manual Download.</b> You may need to create an account or sign in.\n\n2. Save the file to your <b>Downloads</b> folder.\n\n3. Click the button on the bottom of this dialog box." --title="Download TTW" --width 500 --ok-label="I have read the instructions"
    
    local file="Tale\ of\ Two\ Wastelands.*\.7z"

    # Phase 1: Wait for the file to exist
    while [[ ! -f "$file" ]]; do
        sleep 1
    done

    # Phase 2: Wait for the file to contain data
    while [[ ! -s "$file" ]]; do
        sleep 1
    done

    # Phase 3: Wait for file size stabilization
    local previous_size current_size
    previous_size=$(stat -c %s "$file")

    while true; do
        sleep 5
        current_size=$(stat -c %s "$file")
        if [[ "$current_size" -eq "$previous_size" ]]; then
            break
        fi
        previous_size="$current_size"
    done

    # Extract the .7z file
    7z x -y "$HOME/Downloads/$file" -o"$UTILDIR/TTW" >/dev/null

    # Move the extracted .mpi file
    mv $UTILDIR/Tale\ of\ Two\ Wastelands*.mpi $UTILDIR/hoolamike/ttw.mpi
    # Delete the junk folder
    rm -rf $UTILDIR/TTW
}

generate_hoolamike_config() {
    mkdir -p "$UTILDIR/hoolamike/out"

    # Get connected monitors
    local monitors
    mapfile -t monitors < <(xrandr --query | awk '/ connected/ {print $1}')

    # Automatically select if only one monitor
    local monitor
    if [[ ${#monitors[@]} -eq 1 ]]; then
        monitor="${monitors[0]}"
    else
        # Show Zenity selection dialog for multiple monitors
        monitor=$(zenity --list \
            --title="Monitor Selection" \
            --text="Select your primary monitor:" \
            --column="Available Monitors" "${monitors[@]}" \
            --height=250 --width=300)
        
        # Exit if user cancelled
        if [[ -z "$monitor" ]]; then
            return 1
        fi
    fi

    # Get current resolution for selected monitor
    local current_res
    current_res=$(xrandr --query | awk -v mon="$monitor" '
        $1 == mon && $2 == "connected" {
            while (getline) {
                if ($0 !~ /^ /) break
                for (i=2; i<=NF; i++) {
                    if ($i ~ /\*/) {print $1; exit}
                }
            }
        }'
    )

    # Handle resolution detection failure
    if [[ -z "$current_res" ]]; then
        zenity --error --text="Could not detect current resolution for $monitor" --width=300
        return 1
    fi

    # Set detected resolution
    # shellcheck disable=SC2034
    RESOLUTION="$current_res"

    # Generate config file with ShellCheck-compliant replacement
    while IFS= read -r line; do
        parsed_line="${line//\"/\\\"}"
        eval echo "\"$parsed_line\""
    done < "$UTILDIR/template.yaml" > "$UTILDIR/hoolamike/hoolamike.yaml"
}

# Execute Hoolamike with the generated config, output results in utildir
install_ttw() {
    zenity --info --title "Installing TTW" --text="Tale of Two Wastelands will now be installed. This process will take a <i>long</i> time.\n\nClose any other running programs and make sure your device stays on and connected to power during the installation process." --width=500

    $SHELL
    ulimit -n 64556
    $UTILDIR/hoolamike/hoolamike tale-of-two-wastelands
    $SHELL

    #Move generated files from $UTILDIR to MLMO2 profile mods folder
    mkdir "$HOME/MLMO2/mods/Tale\ of\ Two\ Wastelands"
    mv "$UTILDIR/hoolamike/out/*" "$HOME/MLMO2/mods/Tale\ of\ Two\ Wastelands"
    rsync -Xav --progress  "$UTILDIR/meta.ini" "$HOME/MLMO2/mods/Tale\ of\ Two\ Wastelands/"
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

tester

# Main script execution

start
check_sudo_password
select_steam_library
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

# Keep the session open
echo -e "\nPre-install completed. Press enter to exit."
read -r