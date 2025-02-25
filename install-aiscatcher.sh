#!/bin/bash

echo "Installing build tools and dependencies..."
sudo apt install -y git make gcc g++ cmake pkg-config librtlsdr-dev whiptail libairspy-dev  libairspyhf-dev
INSTALL_FOLDER=/usr/share/aiscatcher
echo "Creating folder aiscatcher if it does not exist"
sudo mkdir -p ${INSTALL_FOLDER}

function create-config(){
echo "Creating config file aiscatcher.conf"
CONFIG_FILE=${INSTALL_FOLDER}/aiscatcher.conf
sudo touch ${CONFIG_FILE}
sudo chmod 777 ${CONFIG_FILE}
echo "Writing code to config file aiscatcher.conf"
/bin/cat <<EOM >${CONFIG_FILE}
 -v 60
 -N 8100 share_loc on
 -N STATION CATCHnn LAT -27.96 LON 153.22
 -u 5.9.207.224 CHANGE_ME
 -gm lna AUTO vga 12 mixer 12
EOM
sudo chmod 644 ${CONFIG_FILE}
}


if [[ -f "${INSTALL_FOLDER}/aiscatcher.conf" ]]; then
   CHOICE=$(sudo whiptail --title "CONFIG" --menu "An existing config file 'aiscatcher.conf' found. What you want to do with it?" 20 60 5 \
   "1" "KEEP existing config file \"aiscatcher.conf\" " \
   "2" "REPLACE existing config file by default config file" 3>&1 1>&2 2>&3);
   if [[ ${CHOICE} == "2" ]]; then
      if (whiptail --title "Confirmation" --yesno "Are you sure you want to REPLACE your existing config file by default config File?" --defaultno 10 60 5 ); then
        echo "Saving old config file as \"aiscatcher.conf.old\" ";
        sudo cp ${INSTALL_FOLDER}/aiscatcher.conf ${INSTALL_FOLDER}/aiscatcher.conf.old;
        create-config
      fi
   fi

elif [[ ! -f "${INSTALL_FOLDER}/aiscatcher.conf" ]]; then
   create-config
fi

echo "Creating startup script file start-ais.sh"
SCRIPT_FILE=${INSTALL_FOLDER}/start-ais.sh
sudo touch ${SCRIPT_FILE}
sudo chmod 777 ${SCRIPT_FILE}
echo "Writing code to startup script file start-ais.sh"
/bin/cat <<EOM >${SCRIPT_FILE}
#!/bin/sh
CONFIG=""
while read -r line; do CONFIG="\${CONFIG} \$line"; done < ${INSTALL_FOLDER}/aiscatcher.conf
cd ${INSTALL_FOLDER}
/usr/local/bin/AIS-catcher \${CONFIG}
EOM
sudo chmod +x ${SCRIPT_FILE}


echo "Creating Service file aiscatcher.service"
SERVICE_FILE=/lib/systemd/system/aiscatcher.service
sudo touch ${SERVICE_FILE}
sudo chmod 777 ${SERVICE_FILE}
/bin/cat <<EOM >${SERVICE_FILE}
# AIS-catcher service for systemd
[Unit]
Description=AIS-catcher
Wants=network.target
After=network.target
[Service]
User=aiscat
RuntimeDirectory=aiscatcher
RuntimeDirectoryMode=0755
ExecStart=/bin/bash ${INSTALL_FOLDER}/start-ais.sh
SyslogIdentifier=aiscatcher
Type=simple
Restart=on-failure
RestartSec=30
RestartPreventExitStatus=64
Nice=-5
[Install]
WantedBy=default.target

EOM

sudo chmod 644 ${SERVICE_FILE}
sudo systemctl enable aiscatcher


echo "Entering install folder..."
cd ${INSTALL_FOLDER}
echo "Cloning source-code of AIS-catcher from Github and making executeable..."
sudo git clone https://github.com/jvde-github/AIS-catcher.git
cd AIS-catcher
sudo git config --global --add safe.directory ${INSTALL_FOLDER}/AIS-catcher
sudo git fetch --all
sudo git reset --hard origin/main
sudo rm -rf build
sudo mkdir -p build
cd build
sudo cmake ..
sudo make
echo "Copying AIS-catcher binary in folder /usr/local/bin/ "
if [[ -f "${INSTALL_FOLDER}/AIS-catcher/build/AIS-catcher" ]]; then
   echo "Stoping existing aiscatcher to enable over-write"
   sudo systemctl stop aiscatcher
   sudo killall AIS-catcher
   echo "Copying newly built binary \"AIS-catcher\" to folder \"/usr/local/bin/\" "
   sudo cp ${INSTALL_FOLDER}/AIS-catcher/build/AIS-catcher /usr/local/bin/AIS-catcher

elif [[ ! -f "${INSTALL_FOLDER}/AIS-catcher/build/AIS-catcher" ]]; then
   echo " "
   echo -e "\e[1;31mAIS binary was not built\e[39m"
   echo -e "\e[1;31mPlease run install script again\e[39m"
   exit
fi

echo "Renaming existing folder \"my-plugins\" to \"my-plugins.old\" "
sudo rm -rf ${INSTALL_FOLDER}/my-plugins.old
sudo mv ${INSTALL_FOLDER}/my-plugins ${INSTALL_FOLDER}/my-plugins.old
echo "Copying files from Source code folder \"AIS-catcher/plugins\" to folder \"my-plugins\" "
sudo mkdir ${INSTALL_FOLDER}/my-plugins
sudo cp ${INSTALL_FOLDER}/AIS-catcher/plugins/* ${INSTALL_FOLDER}/my-plugins/

echo "Adding udev rule for air-spy"
sudo su -c 'echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"1d50\", ATTR{idProduct}==\"60a1\", GROUP=\"plugdev\", MODE=\"0666\"" > /etc/udev/rules.d/98-airspy.rules'
sudo su -c 'echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"0bda\", ATTR{idProduct}==\"2838\", GROUP=\"plugdev\", MODE=\"0666\"" > /etc/udev/rules.d/97-rtl-sdr.rules'
echo "Creating User aiscat to run AIS-catcher"
sudo useradd --system aiscat
sudo usermod -a -G adm dialout cdrom audio video plugdev games users input render netdev lpadmin gpio i2c spi aiscat

echo "Assigning ownership of install folder to user aiscat"
sudo chown aiscat:aiscat -R ${INSTALL_FOLDER}

sudo systemctl start aiscatcher

echo " "
echo " "
echo -e "\e[32mINSTALLATION COMPLETED \e[39m"
echo -e "\e[32m=======================\e[39m"
echo -e "\e[32mPLEASE DO FOLLOWING:\e[39m"
echo -e "\e[32m=======================\e[39m"

echo -e "\e[33m(1) Open file aiscatcher.conf by following command:\e[39m"
echo -e "\e[39m       sudo nano "${INSTALL_FOLDER}"/aiscatcher.conf \e[39m"
echo -e "\e[33m(2) In above file:\e[39m"
echo -e "\e[33m    (a) Change CHANGEME in \"-u ....\" port to send to AIVDM to\e[39m"
echo " "
echo -e "\e[01;31m(3) REBOOT RPi ... REBOOT RPi ... REBOOT RPi \e[39m"
echo " "
echo -e "\e[01;32m(4) See the Web Interface (Map etc) at\e[39m"
echo -e "\e[39m        $(ip route | grep -m1 -o -P 'src \K[0-9,.]*'):8100 \e[39m" "\e[35m(IP-of-PI:8100) \e[39m"
echo " "
echo -e "\e[32m(5) Command to see Status\e[39m sudo systemctl status aiscatcher"
echo -e "\e[32m(6) Command to Restart\e[39m    sudo systemctl restart aiscatcher"

