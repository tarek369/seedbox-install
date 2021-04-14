#!/bin/bash

##Check if system compatible before install
compatible(){
	##Check if distribution is supported
	if [[ -z "$(uname -a | grep Ubuntu)" && -z "$(uname -a | grep Debian)" ]];then
		echo Distro not supported
		exit 1
	fi
	##Check if systemd is running
	if [[ -z "$(pidof systemd)" ]]; then
		echo systemd not running
		exit 2
	fi

	if [ "$UID" -ne 0 ]; then
		echo Must be root to run the script
		exit 3
	fi
}

##Ask user to install the app
installApp(){
	clear
	while true;	do
		read -r -p 'Do you want to install '$1'?(Y/n)' choice
		case "$choice" in
			n|N) return 1;;
			y|Y|"") return 0;;
			*) echo 'Response not valid';;
		esac
	done
}

##Updates && Upgrades
updates(){
	sudo apt-get update;
	sudo apt-get upgrade;
}

deluge(){
	sudo apt-get install deluge;
	sudo apt-get install deluge-web;
	sudo apt-get install deluged;
	sudo apt-get install deluge-console;

	sudo echo "[Unit]
	Description=Deluge Bittorrent Client Web Interface
	Documentation=man:deluge-web
	After=network-online.target deluged.service
	Wants=deluged.service
	[Service]
	Type=simple
	User=${username}
	UMask=027
	ExecStart=/usr/bin/deluge-web
	Restart=on-failure
	[Install]
	WantedBy=multi-user.target
	" > /etc/systemd/system/deluge-web.service;
	sudo systemctl enable /etc/systemd/system/deluge-web.service;
	sudo systemctl start deluge-web;

	sudo echo "[Unit]
	Description=Deluge Bittorrent Client Daemon
	Documentation=man:deluged
	After=network-online.target
	[Service]
	Type=simple
	User=${username}
	UMask=007
	ExecStart=/usr/bin/deluged -d
	Restart=on-failure
	# Time to wait before forcefully stopped.
	TimeoutStopSec=300
	[Install]
	WantedBy=multi-user.target
	" > /etc/systemd/system/deluged.service;
	sudo systemctl enable /etc/systemd/system/deluged.service;
	sudo systemctl start deluged;
}

plex(){
	cd;
	bash -c "$(wget -qO - https://raw.githubusercontent.com/mrworf/plexupdate/master/extras/installer.sh)";
	sudo service plexservermedia start;
}

sonarr(){
	## Add Mono repo
	sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
	sudo apt install apt-transport-https ca-certificates
	echo "deb https://download.mono-project.com/repo/ubuntu stable-xenial main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list
	sudo apt update
	#########
	#Add Sonarr repo
	#########
	sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 2009837CBFFD68F45BC180471F4F90DE2A9B4BF8
	echo "deb https://apt.sonarr.tv/ubuntu xenial main" | sudo tee /etc/apt/sources.list.d/sonarr.list
	sudo apt update
	############
	sudo apt install sonarr


	sudo echo "[Unit]
	Description=Sonarr Daemon

	[Service]
	User=${username}
	Type=simple
	PermissionsStartOnly=true
	ExecStart=/opt/Sonarr/Sonarr -data=/home/${username}/.config/Sonarr/
	TimeoutStopSec=20
	KillMode=process
	Restart=on-failure

	[Install]
	WantedBy=multi-user.target
	" > /etc/systemd/system/sonarr.service;

	sudo chown -R ${username}:${username} /opt/Sonarr/

	systemctl enable sonarr.service;
	sudo service sonarr start;

}

radarr(){
	sudo apt update && apt install libmono-cil-dev curl mediainfo;
	sudo apt-get install mono-devel mediainfo sqlite3 libmono-cil-dev -y;
	cd /tmp;
	wget https://radarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64;
	sudo tar -xf Radarr* -C /opt/;
	sudo chown -R ${username}:${username} /opt/Radarr;

	sudo echo "[Unit]
	Description=Radarr Daemon
	After=syslog.target network.target

	[Service]
	User=${username}
	Type=simple
	ExecStart=/usr/bin/mono /opt/Radarr/Radarr.exe -nobrowser
	TimeoutStopSec=20
	KillMode=process
	Restart=on-failure

	[Install]
	WantedBy=multi-user.target
	" > /etc/systemd/system/radarr.service;
	sudo chown -R ${username}:${username} /opt/Radarr

	sudo systemctl enable radarr;
	sudo service radarr start;
}

jackett(){
	sudo apt-get install libcurl4-openssl-dev;
	wget https://github.com/Jackett/Jackett/releases/download/v0.7.1622/Jackett.Binaries.Mono.tar.gz;
	sudo tar -xf Jackett* -C /opt/;
	sudo chown -R ${username}:${username} /opt/Jackett;

	sudo echo "[Unit]
	Description=Jackett Daemon
	After=network.target

	[Service]
	WorkingDirectory=/opt/Jackett/
	User=${username}
	ExecStart=/usr/bin/mono --debug JackettConsole.exe --NoRestart
	Restart=always
	RestartSec=2
	Type=simple
	TimeoutStopSec=5

	[Install]
	WantedBy=multi-user.target
	" > /etc/systemd/system/jackett.service;
	sudo systemctl enable jackett;
	sudo service jackett start;

	rm Jackett.Binaries.Mono.tar.gz;
}

headphones(){
	sudo apt-get install git-core python;
	cd /opt;
	git clone https://github.com/rembo10/headphones.git;
	sudo touch /etc/default/headphones;
	sudo chmod +x /opt/headphones/init-scripts/init.ubuntu;
	sudo ln -s /opt/headphones/init-scripts/init.ubuntu /etc/init.d/headphones;
	sudo update-rc.d headphones defaults;
	sudo update-rc.d headphones enable;
	sudo service headphones start;
}

createUser(){
	clear
        read -p "Enter user name : " username

        ##if user already exists quit the function
        grep -q $username /etc/passwd
        if [ $? -eq 0 ]; then
                echo "Using existing user '$username'"
                sleep 2
                return 1
        fi

        ##otherwise ask for a password for the newly created user
        read -p "Enter password : " password
        sudo adduser $username --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password
        echo "${username}:${password}" | sudo chpasswd
}

main(){
	##call compatible to check if distro is either Debian or Ubuntu
	compatible

	##create user
	createUser

	##call updates to upgrade the system
	updates

	##dictionnary to associate fonction with string name
	declare -A arr
	arr["plex"]=PlexMediaServer
	arr+=( ["deluge"]=Deluge ["sonarr"]=Sonarr ["radarr"]=Radarr ["Headphones"]=Headphones ["jackett"]=Jackett )
	for key in ${!arr[@]}; do
		installApp ${arr[${key}]}
		if [ $? == 0 ]; then
			${key}
		fi
	done
}

main

BLUE=`tput setaf 4`
echo "Thanks for using this script"
echo "If you have any issues hit me up here :"
echo "https://github.com/Tvax/seedbox-install/issues"
