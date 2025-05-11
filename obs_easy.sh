#!/bin/bash
#

STEAMDECK=0
DISTROBOX_CONTAINER_NAME="obs"
DISTROBOX=""
TEXT_FALLBACK=0
NDI_INSTALL_SCRIPT_URL="https://github.com/DistroAV/DistroAV/raw/refs/heads/master/CI/libndi-get.sh"
TEMP_NDI="/tmp/libndi-get.sh"
DISTROAV_DEB="https://github.com/DistroAV/DistroAV/releases/download/6.0.0/distroav-6.0.0-x86_64-linux-gnu.deb"
TEMP_DEB="/tmp/distroav-6.0.0-x86_64-linux-gnu.deb"
SHORTCUT_PATH="$HOME/Desktop/OBS-Distrobox.desktop"
OBS_SC_PATH="/usr/share/applications/com.obsproject.Studio.desktop"
NDI_CONFIG="$HOME/.ndi/ndi-config.v1.json"
INPUT=""

source /etc/os-release

display_info() {
    local MESSAGE="$1"

    if [[ "$TEXT_FALLBACK" -eq 1 ]]; then
        echo -e "$MESSAGE"
        echo "Press Enter to continue..."
        read -r
    else
        # Zenity-based information display
        zenity --info \
            --text="$MESSAGE" \
            --title="Information" \
            --ok-label="Continue"
        if [[ $? -ne 0 ]]; then
            echo "Dialog was closed or canceled." >&2
            return 1
        fi
    fi

    return 0
}

ask_yes_no() {
    local PROMPT="$1"
    local RESPONSE

    if [[ "$TEXT_FALLBACK" -eq 1 ]]; then
        while true; do
            echo -e "$PROMPT"
            read -p "[Y/N]: " RESPONSE
            case "$RESPONSE" in
                [Yy]* ) return 1 ;;
                [Nn]* ) return 0 ;;
                * ) echo "Please answer Y or N." ;;
            esac
        done
    else
        zenity --question --text="$PROMPT" --title="Question"
        if [[ $? -eq 0 ]]; then
            echo "YES"
            return 1
        else
            echo "NO"
            return 0
        fi
    fi
}

ask_for_string() {
    local PROMPT="$1"

    if [[ "$TEXT_FALLBACK" -eq 1 ]]; then
        echo -e "$PROMPT"
        read -rp "" INPUT
    else
        INPUT=$(zenity --entry --text="$PROMPT" --title="Question")
    fi
}

ndi_distrobox_install() {
    distrobox enter $DISTROBOX_CONTAINER_NAME -- "curl -fsSL -o \"$TEMP_NDI\" \"$NDI_INSTALL_SCRIPT_URL\""
    distrobox enter $DISTROBOX_CONTAINER_NAME -- "sudo bash $TEMP_NDI install"
    distrobox enter $DISTROBOX_CONTAINER_NAME -- "curl -fsSL -o \"$TEMP_DEB\" \"$DISTROAV_DEB\""
    distrobox enter $DISTROBOX_CONTAINER_NAME -- "sudo dpkg -i $TEMP_DEB"
    distrobox enter $DISTROBOX_CONTAINER_NAME -- "sudo apt install -y -f"
}

ndi_os_install() {
    curl -fsSL -o "$TEMP_NDI" "$NDI_INSTALL_SCRIPT_URL"
    sudo bash $TEMP_NDI install
    curl -fsSL -o "$TEMP_DEB" "$DISTROAV_DEB"
    sudo dpkg -i $TEMP_DEB
    sudo apt install -y -f
}

distrobox_install() {
    distrobox create -n $DISTROBOX_CONTAINER_NAME -i docker.io/library/ubuntu:latest --additional-flags "-v /run/dbus/system_bus_socket:/run/dbus/system_bus_socket"
    distrobox enter $DISTROBOX_CONTAINER_NAME -- "sudo apt install -y obs-studio ffmpeg vainfo mesa-vulkan-drivers"
}

os_install() {
    sudo apt-add-repository ppa:obsproject/obs-studio
    sudo apt-get update
    sudo apt-get install ffmpeg obs-studio
    sudo apt install -y obs-studio ffmpeg vainfo mesa-vulkan-drivers
}

os_fluxbox_install() {
    sudo apt install -y fluxbox
}

os_pulseaudio_install() {
    sudo apt install -y pulseaudio pavucontrol
    # config fix
    echo <<EOF >> sudo tee -a /etc/pulse/daemon.conf > /dev/null
default-sample-rate = 48000
default-sample-channels = 2
default-fragments = 2
default-fragment-size-msec = 114
EOF
}

fluxbox_configs() {
    if [ "$DISTROBOX" == "1" ]; then
        OBS_CMD='distrobox enter obs -- "obs"'
    else
        OBS_CMD="obs"
    fi
    mkdir -p ~/.fluxbox
    cat <<EOF > ~/.fluxbox/menu
[begin] (fluxbox)
    [submenu] (OBS and Tools) {}
        [exec] (OBS) { $OBS_CMD } <>
        [exec] (Pulse Audio Volume Control) { pavucontrol } <>
        [exec] (Alsamixer) { x-terminal-emulator -T "Alsamixer" -e /usr/bin/alsamixer} <>
        [exec] (Terminal) { x-terminal-emulator -T "Bash" -e /bin/bash --login } <>
    [end]
[include] (/etc/X11/fluxbox/fluxbox-menu)
[end]
EOF
}

set_terminal_dark() {
    # white terminals hurt my eyes

    # Get the current gnome-terminal profile ID
    profile_id=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d \')

    # Disable theme colors
    dconf write /org/gnome/terminal/legacy/profiles:/:$profile_id/use-theme-colors "false"

}

ndi_config() {
    mkdir -p ~/.ndi
    cat <<EOF > "$NDI_CONFIG"
{
  "ndi": {
    "machinename": "",
    "tcp": {
      "recv": {
        "enable": true
      }
    },
    "rudp": {
      "recv": {
        "enable": true
      }
    },
    "groups": {
      "send": "Public",
      "recv": "Public"
    },
    "unicast": {
      "recv": {
        "enable": true
      }
    },
    "networks": {
      "ips": "$NDI_IPS",
      "discovery": "$NDI_DISCOVERY"
    },
    "adapters": {
      "allowed": []
    },
    "multicast": {
      "send": {
        "ttl": 1,
        "enable": false,
        "netmask": "255.255.0.0",
        "netprefix": "239.255.0.0"
      }
    }
  }
}
EOF
    return
}

distrobox_desktop_shortcut() {
    distrobox enter $DISTROBOX_CONTAINER_NAME -- "cp $OBS_SC_PATH $SHORTCUT_PATH"
    ## copy svg out of container
    distrobox enter $DISTROBOX_CONTAINER_NAME -- "cp /usr/share/icons/hicolor/scalable/apps/com.obsproject.Studio.svg ~/.local/share/icons"
    cat <<EOF > "$SHORTCUT_PATH"
[Desktop Entry]
Version=1.0
Name=OBS in Distrobox
Comment=Launch OBS via Distrobox
Exec=distrobox enter obs -- "obs"
Icon=com.obsproject.Studio
Terminal=false
Type=Application
Categories=Multimedia;AudioVideo;Recorder;
EOF
    chmod +x "$SHORTCUT_PATH"
}

# check for zenity being installed
zenity --help > /dev/null
if [ "$?" != "0" ]; then
    TEXT_FALLBACK=1
fi

#TEXT_FALLBACK=1

# OS Check and Install options select
if [ "$TEXT_FALLBACK" == "0" ]; then
    ## More complicated multi choice GUI presentation, otherwise fallback to asking text questions"
    # Default options
    DISTROBOX=0
    OSINSTALL=0
    NDI=0
    APPLIANCE=0
    DISTROBOX_SELECT="FALSE"
    OSINSTALL_SELECT="FALSE"
    NDI_SELECT="FALSE"
    APPLIANCE_SELECT="FALSE"
    DISTROBOX_NAME="Distrobox"
    OSINSTALL_NAME="OS Install"
    NDI_NAME="NDI"
    APPLIANCE_NAME="Appliance"
    OSINSTALL_OPTION="Install software onto the running OS"
    DISTROBOX_OPTION="Install into a distrobox container named obs - nvidia hardware acceleration not supported at this time
Installing into a distrobox container means you cannot use the Appliance option"
    NDI_OPTION="Install NDI and DistroAV plugins for network video - if you don't know what this is you don't need it"
    APPLIANCE_OPTION="(Beta)
Create an appliance like environment for running OBS
This will make changes to the running OS:
Fluxbox window manager with menu entries
Pulseaudio sound daemone configured for 48Hz"
    if [ "$ID" == "steamos" ] && [ "$VARIANT_ID" == "steamdeck" ]; then
        TEXT="Steamdeck detected!

This will install obs-studio with vlc plugins in a distrobox container
Some install options are disabled due to the platform"
        #display_info "$TEXT"
        STEAMDECK=1
        DISTROBOX_SELECT="TRUE"
        OSINSTALL_NAME="(Disabled) OS Install"
        OSINSTALL_OPTION="(Disabled) Install software onto the running OS"
        APPLIANCE_NAME="(Disabled) Appliance"
        APPLIANCE_OPTION="(Disabled) "${APPLIANCE_OPTION}
    elif [ "$ID" == "linuxmint" ] && [ "$VERSION_ID" == "22" ]; then
        TEXT="Linux Mint 22 detected

This is an offically supported distro for using the Appliance option"
        #display_info "$TEXT"
    else
        TEXT="Distro not offically supported!

Choose your options and good luck!"
        #display_info "$TEXT"
    fi

    while (true); do
        # ask question and set options
        DISABLED=0
        INSTALL_OPTIONS=$(zenity --list --checklist \
        --title="Select Install options" \
        --text="Select your install type and options:\n\nNot selecting any options will just install OBS\n\n$TEXT" \
        --column="Select" --column="Option" --column="Details"\
        $DISTROBOX_SELECT "$DISTROBOX_NAME" "$DISTROBOX_OPTION" \
        $OSINSTALL_SELECT "$OSINSTALL_NAME" "$OSINSTALL_OPTION" \
        $NDI_SELECT "$NDI_NAME" "$NDI_OPTION" \
        $APPLIANCE_SELECT "$APPLIANCE_NAME" "$APPLIANCE_OPTION" \
        --height=500 \
        --width=1000 \
        --separator=",")

        if [ "$INSTALL_OPTIONS" == "" ]; then
            TEXT="No options selected, please select install options"
            display_info "$TEXT"
            continue
        fi

        IFS=',' read -r -a SELECTED_ITEMS <<< "$INSTALL_OPTIONS"
        for ITEM in "${SELECTED_ITEMS[@]}"; do
            case $ITEM in
                "Distrobox")
                    DISTROBOX=1
                    ;;
                "OS Install")
                    OSINSTALL=1
                    ;;
                "NDI")
                    NDI=1
                    ;;
                "Appliance")
                    APPLIANCE=1
                    ;;
            esac
        done

        if [ "$STEAMDECK" == "1" ] && [ "$DISTROBOX" == "0" ]; then
            TEXT="Steamdeck only supports distrobox install at this time\nOther options will be ignored"
            display_info "$TEXT"
            DISTROBOX=1
        fi

        echo "$INSTALL_OPTIONS" | grep "Disabled" > /dev/null
        if [ "$?" == "0" ]; then
            TEXT="Disabled option selected, it will be ignored"
            display_info "$TEXT"
        fi

        if [ "$DISTROBOX" == "0" ] && [ "$NDI" == "0" ] && [ "$APPLIANCE" == "0" ]; then
            TEXT="No options selected\nThis will just install OBS"
            display_info "$TEXT"
        fi

        if [ "$DISTROBOX" == "0" ] && [ "$NDI" == "0" ] && [ "$APPLIANCE" == "0" ] && [ "$OSINSTALL" == "0" ]; then
            TEXT="No install options at all selected? Please select some install options"
            display_info "$TEXT"
            continue
        fi
        break
    done
    #echo $INSTALL_OPTIONS
    #echo "$DISTROBOX"
    #echo "$NDI"
    #echo "$APPLIANCE"
    #echo "$OSINSTALL"
else
    # Fallback to asking one question at at time
    #DISTROBOX=""
    # Collect options from users
    #
    if [ "$ID" == "steamos" ] && [ "$VARIANT_ID" == "steamdeck" ]; then
        TEXT="Steamdeck detected!\nThis will install obs-studio with vlc plugins in a distrobox container\nSome install options are disabled due to the platform"
        display_info "$TEXT"
        STEAMDECK=1
        DISTROBOX=1
    fi

    if [ "$DISTROBOX" == "" ]; then
        TEXT="Use distrobox to install everyting in an continer?\nAMD Hardware acelleration is supported\nNvidia hardware not fully supported in distrobox at this time\nNot using distrobox means installing into the current OS\nUse distrobox?"
        ask_yes_no "$TEXT"
        DISTROBOX=$?
        if [ "DISTROBOX" == "0" ]; then
            OSINSTALL=1
        fi
    fi

    TEXT="Install NDI plugins?\nIf you don't know what NDI is then you don't need it\nUse NDI?"
    ask_yes_no "$TEXT"
    NDI=$?

    if [ "$STEAMDECK" == "0" ]; then
        TEXT="Appliance option: (Beta)\nCreate an appliance like environment for running OBS\nThis will make changes to the running OS:\nFluxbox window manager with menu entries\nPulseaudio sound daemone configured for 48Hz"
        ask_yes_no "$TEXT"
        APPIANCE=$?
    fi
fi

## Ask for additional options here, NDI config only at this time

if [ "$NDI" == "1" ]; then
    TEXT="The NDI config is written to ~/.ndi/ndi-config.v1.json\nEnter the comma separated IP addresses of your other NDI systems\nYou can update this file anytime to add/remove IPs\nExample: 192.168.0.10,192.168.0.12\n\nEnter you IPs comma separated:"
    ask_for_string "$TEXT"
    NDI_IPS="$INPUT"
    TEXT="Enter the IP address of your discovery server\nEnter discovery server IP:"
    ask_for_string "$TEXT"
    NDI_DISCOVERY="$INPUT"
fi

# Do the install
if [ "$DISTROBOX" == "1" ]; then
    distrobox_install
    if [ "$NDI" == "1" ]; then
        ndi_distrobox_install
        ndi_config
    fi
    distrobox_desktop_shortcut
    if [ "$APPLIANCE" == "1" ]; then
        os_fluxbox_install
        fluxbox_configs
        os_pulseaudio_install
        set_terminal_dark
    fi
else
    ## Install into running OS
    os_install
    if [ "$NDI" == "1" ]; then
        ndi_os_install
        ndi_config
    fi
    if [ "$APPLIANCE" == "1" ]; then
        os_fluxbox_install
        fluxbox_configs
        os_pulseaudio_install
        set_terminal_dark
    fi
fi

