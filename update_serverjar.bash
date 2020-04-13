#!/usr/bin/env bash
# goes out to the web to grab latest minecraft server jar. 

mcuser="minecraft-admin"
scriptuser="$mcuser"
downloadpath="/home/$mcuser/tmp"
servertool="McMyAdmin.exe"

function cleanup () {
    rm -vfr "/home/$mcuser/tmp/"
}
# more complicated get dirname. Doesnt seem valuable here.
#serverdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
# Really what we want is the reasonable path to thsi script
# to find the bits. Relative is perfect, and hoping to abuse it.
serverdir=$(dirname "${BASH_SOURCE[0]}");
if [ -z "$serverdir" ]; then
   echo "Error: didn't get server dir.";
   exit 1; fi;
   
world=$(sed -nr 's/level-name=(.*)/\1/p' < "$serverdir/server.properties");
if [ -z "$world" ];then
    echo "Error: didn't get level name in server.properties";
    exit 1; fi;

if [ ! -e "${serverdir}/simple_support_functions.bash" ];then
    echo "Error: support functions not availble.";
    echo "They need to be linked here with the update and start scripts.";
    exit 1; fi;

source "${serverdir}/simple_support_functions.bash";

# get_server_type
read -r server_type serverext current_server_file <<<$(get_server_type $serverdir);

if [ -z "$current_server_file" -o ! -e "$current_server_file" ];then
    echo "Error: couldn't resolve server_file_base";
    exit 1; fi;

if [ ! -e $downloadpath ];then
    mkdir $downloadpath || exit 1;
fi;

minecraft_server_url="https://www.minecraft.net/en-us/download/server";
if [ $server_type == minecraft_server ];then
    read -r downloadurl versionnumber new_server_file <<<$(get_mc_download_url $minecraft_server_url $server_type $serverext $downloadpath);
fi;


#https://papermc.io/api/{API_VERSION}/{PROJECT_NAME}/{PROJECT_VERSION}/{BUILD_ID}/download
paper_api='v1'
paper_proj='paper'
if [ -z "$versionnumber" ];then 
    versionnumber='1.15.2'; fi;
paper_build='latest'
paper_url="https://papermc.io/api/${paper_api}/${paper_proj}/${versionnumber}/${paper_build}/download";

forge_url="";
spigot_url="";

if [ "$server_type" == paper ];then
    downloadurl=$paper_url; fi;

if [ $server_type == minecraft_server ];then
    urlofpage=$minecraft_server_url; fi;


if [ "$USER" != "${scriptuser}" ]
then
    echo "Error: Wrong user, run as ${scriptuser}";
    cleanup
    exit 1;
fi

if [ -z "$downloadurl" ]; then
    echo "error: didnt get download location";
    cleanup
    exit;
fi

echo  "mc_v=\"$versionnumber\""
#echo  "mc_f=\"$new_server_file\""
echo  "mc_url=\"$downloadurl\""

if [ -f "${serverdir}/${new_server_file}" ]; then
    echo "Status: Minecraft server update not needed."
    cleanup
    exit;
else
    echo didnt find "${serverdir}/${new_server_file}"
fi

if [ ! -f "${downloadpath}/${new_server_file}" ]; then
    #ls ${downloadpath}
    #echo wget -nc $downloadurl -P "${downloadpath}";
    ( cd $downloadpath; curl -JLO $downloadurl )
    read -r server_type serverext new_server_file <<<$(get_server_type $downloadpath);
    if [ -z "$new_server_file" ];then
	echo "Error: Couldn't get downloaded file name";
	exit 1; fi;
    #echo "$server_type.$serverext '$new_server_file'";exit;
    # if server jar file isnt name reasonably, rename it in downloadpath.
    if [ ! -e "${downloadpath}/${new_server_file}" ];then
	fc=$(ls -d $downloadpath/*${serverext}|wc -l);
	if [ $fc -eq 1 ];then
	    mv $downloadpath/*${serverext} ${downloadpath}/${new_server_file};
	fi
    fi
else
    echo "Downloaded $new_server_file before. Not re-downloading"
fi

# if diff, 
#current_server_file=`ls -tr ${serverdir}/${server_type}*${serverext}|tail -n 1`;
echo diff "${downloadpath}/${new_server_file}" "$current_server_file";
diff "${downloadpath}/${new_server_file}" "$current_server_file";

precompare=$?
if [ "$precompare" -ge 1 ]
then
    echo "Status: Minecraft server update needed."
    read -n 1 -p " Do you wish to upgrade now? y/N" choice
    if [ "$choice" == "y" -o "$choice" == "Y" ]
    then echo "";
	# check if server is running here.
	# if running
	servercount=$(ps ax | grep -c ${server_type})
	servertoolcount=$(ps ax | grep -c ${servertool})
	if [ "${servercount}" -ge 2 -o "${servertoolcount}" -ge 2 ]
	then # close minecraft
	    stop_server $server_type
	fi

	sleep_count=0;
	while [ "$servercount" -ge 2 -a "$sleep_count" -lt 5 -o "$servertoolcount" -ge 2 -a "$sleep_count" -lt 5 ];
	do #then #
	    servercount=$(ps ax | grep -c ${server_type});
	    servertoolcount=$(ps ax | grep -c ${servertool});
            sleep_count=$((++sleep_count));
	    #expr $sleep_count + 1
	    sleep 1;
	    echo -n "."
	    #fi 
	done

	servercount=$(ps ax | grep -c ${server_type})
	servertoolcount=$(ps ax | grep -c ${servertool})
	if [ "${servercount}" -le 1 -a "${servertoolcount}" -le 1 ]
	then # have to do le 1, because ps ax will find the grep as well as the actuall process
        # cp /Media/Bulk\ Storage/downloads/000\ games/minecraft/minecraft_server.jar ${downloadpath}/${server_type}
	#echo "Sleeping for 25 seconds before contiuing"
	#sleep 25;
	    #cp "${downloadpath}/${server_type}" "${downloadpath}/${server_type}"
	    cp "${downloadpath}/${new_server_file}" "${serverdir}/${new_server_file}"
	    chown "${mcuser}" "${serverdir}/${new_server_file}"
	    chmod a+r "${serverdir}/${new_server_file}"

	    diff "${downloadpath}/${new_server_file}" "${serverdir}/${new_server_file}" >> /dev/null
	    postcompare=$?
	    if [ "$precompare" != "$postcompare" ] 
	    then 
		if [ "$postcompare" == "0" ]
		then 
		    echo "Status: ${server_type} update Succes"

		else
		    echo "ERROR: ${server_type} update error "
		    echo "     :  Postcompare different from Precompare but not zero."
		fi
	    else
		echo "ERROR: ${server_type} update error "
		echo "     : Postcompare same as Precompare, file did not sucessfully copy from download directory."
	    fi
	else
	    "ERROR: minecraft server open and did not close"
	fi
	cleanup
    else
	echo "Status: Minecraft server update needed but not done";
	echo "    cleanup also skipped, examine $downloadpath to continue manually";
    fi
else
    echo "Status: Minecraft server update not needed."
    cleanup
fi
