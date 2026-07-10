#!/usr/bin/env bash
green='\033[0;32m'
red='\033[0;31m'
bred='\033[1;31m'
cyan='\033[0;36m'
grey='\033[2;37m'
reset="\033[0m"

SHPATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

install_dependencies () {
    echo -e "${grey}Installing dependencies with 'pacman'...${reset}"
    sudo pacman -S --needed sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg
}

copy_files () {
    echo -e "${grey}Copying files from '${SHPATH}/' to '/usr/share/sddm/themes/silent/'...${reset}"
    sudo mkdir -p /usr/share/sddm/themes/silent
    sudo cp -rf "$SHPATH"/. /usr/share/sddm/themes/silent/
}

copy_fonts () {
    echo -e "${grey}Copying fonts to '/usr/share/fonts/'...${reset}"
    sudo cp -r /usr/share/sddm/themes/silent/fonts/{redhat,redhat-vf} /usr/share/fonts/
}

apply_theme () {
    echo -e "${grey}Editing '/etc/sddm.conf'...${reset}"
    if [[ -f /etc/sddm.conf ]]; then
        sudo cp -f /etc/sddm.conf /etc/sddm.conf.bkp
        echo -e "${green}Backup for SDDM config saved in '/etc/sddm.conf.bkp'${reset}"

        if grep -Pzq '\[Theme\]\nCurrent=' /etc/sddm.conf; then
            sudo sed -i '/^\[Theme\]$/{N;s/\(Current=\).*/\1silent/;}' /etc/sddm.conf
        else
            echo -e "\n[Theme]\nCurrent=silent" | sudo tee -a /etc/sddm.conf
        fi

        if ! grep -Pzq 'InputMethod=qtvirtualkeyboard' /etc/sddm.conf; then
            echo -e "\n[General]\nInputMethod=qtvirtualkeyboard" | sudo tee -a /etc/sddm.conf
        fi

        # "InputMethod" was supposed to automatically set "QT_IM_MODULE", but it doesn't, so we manually export it.
        if ! grep -Pzq 'GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard' /etc/sddm.conf; then
            echo -e "\n[General]\nGreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard" | sudo tee -a /etc/sddm.conf
        fi
    else
        echo -e "[Theme]\nCurrent=silent" | sudo tee -a /etc/sddm.conf
        echo -e "\n[General]\nInputMethod=qtvirtualkeyboard" | sudo tee -a /etc/sddm.conf
        echo -e "GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard" | sudo tee -a /etc/sddm.conf
    fi
}

install_dependencies ;
copy_files &&
copy_fonts ;
apply_theme &&
echo -e "\n${green} Theme successfully installed!${reset}"
