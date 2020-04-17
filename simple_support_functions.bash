#!/usr/bin/env bash


function stop_server () {
    server_type=$1;
    serverdir=$2;

    #world=$(sed -nr 's/level-name=(.*)/\1/p' < "$serverdir/server.properties");
    #rcon.port=25575
    #enable-rcon=true
    rcon=$(sed -nr 's/enable-rcon=(.*)/\1/p' < "$serverdir/server.properties" |grep -c 'true');
    if [ $rcon -eq 1 ];then
	echo "issusing mcrcon stop";
	pw=$(sed -nr 's/rcon.password=(.*)/\1/p' < "$serverdir/server.properties");
	port=$(sed -nr 's/rcon.port=(.*)/\1/p' < "$serverdir/server.properties");
	cmd_pref=""
	# default minecraft servertype ends in server, and only they do, so we use
	# that to detect the proper setting. 
	if [ $( echo "$server_type"|grep -c 'server') -gt 0 ]; then
	    cmd_pref="/"
	fi;
	echo "${cmd_pref}stop" | mcrcon -H localhost -p "$pw" -P $port;
    fi;
    
    #serverpid=`ps ax | grep ${server_type} | head -n 1 | cut -d " " -f 1 `
    #servertoolpid=`ps ax | grep ${servertool} | head -n 1 | cut -d " " -f 1 `
    #serverpid=`ps -ef | grep $server_type | awk '{ print $2 }'|head -n 1`
    # ps -ef --sort=-pcpu | awk '/.*minecraft_server.*/ {print $2}'

    echo "Doublechecking pid stop(will wait up to 30 seconds)."
    #echo "serverpid=ps -ef --sort=-pcpu | awk "/$server_type/"'{ print \$2 }'|head -n 1";
    #serverpid=$(ps -ef --sort=-pcpu | awk "/$server_type/"'{ print $2 }'|head -n 1)
    echo "serverpid=$(pgrep -af "$server_type" |grep -v tmux|awk '{ print $1}')";
    serverpid=$(pgrep -af "$server_type" |grep -v tmux|awk '{ print $1}');
    wait=0;
    WAIT_LIM=30;
    while [ ! -z "$serverpid" -a $wait -lt $WAIT_LIM ]; do 
	sleep 1; 
	serverpid=$(pgrep -af "$server_type" |grep -v tmux|awk '{ print $1}')
	let wait=$wait+1;
	echo -n ".";
    done
    echo "";
    if [ ! -z "$serverpid" ];then
	echo "Waited $WAIT_LIM seconds for process to close";
	echo "Status: Minecraft server update needed."
	read -n 1 -p " Do you wish to force close? y/N" choice
	if [ "$choice" == "y" -o "$choice" == "Y" ]
	then echo "";
	     echo "kill ${serverpid}"
	     kill ${serverpid};
	fi;
    fi;

    #if [ "${servertoolcount}" -ge 2 ]; then
	#servertoolpid=`ps -ef --sort=-pcup |grep $servertool | awk '{ print $2 }'|head -n 1`
    #	servertoolpid=$(ps -ef --sort=-pcu | awk "/$servertool/{ print $2 }"|head -n 1)
    #	kill -9 ${servertoolpid}
    #fi
    return;
}

function get_server_type (){
    serverdir=$1;
    debug_mode=$2;

    if [ -z "$debug_mode" ];then
	debug_mode=0;
    fi;
    # Vanilla serverfile
    #serverext="jar";
    #server_type="minecraft_server";

    #forge 
    all_server_files=(paper fabric spigot minecraft_server bedrock_server);
    server_type="";
    let alternate_files_found=0;
    for serverfile in ${all_server_files[@]}; do
	#server_file=$(ls -tr ${serverdir}/${serverfile}*${serverext} 2> /dev/null|tail -n 1);
	server_file=$(find $serverdir -maxdepth 1 -name "${serverfile}*" -size +2M -printf "%T@ %f\n" | sort -nr | head -n 1 | sed 's/[^ ]\+ //')
	#server_file=$(ls -tr $(for f in $( cd $serverdir; find "${serverdir}" -maxdepth 1 -type f -size +2M -name "${serverfile}*" -exec basename {} \; ); do if [ ! -z "$f" ];then echo $serverdir/$f;else echo "NOFILEFOR$serverfile";fi; done)|tail -n1 )
	
	# This didn't work either due to paper.yml vs paper-VER.jar...
	#server_file=$(ls -tr ${serverdir}/${serverfile}* 2> /dev/null|tail -n 1);
	#if [ ! -z "$server_file" ];then
	#    if [ -z "$(find "$server_file" -prune -size +2M)" ];then
	#	unset server_file; fi;
	#fi;
	# Tried more complicated one liners to set min size, and they were not effective, and also ugly. 
	#server_file=$(find "${serverdir}" -maxdepth 1 -type f -size +2M -name "${serverfile}*")
	#server_file=$( ls -tr $(for f in $(find "${serverdir}" -maxdepth 1 -type f -size +2M -name "${serverfile}*"); do echo "${serverdir}/$f"; done ) 2> /dev/null |tail -n 1 )
	#server_file=$(find "${serverdir}" -maxdepth 1 -type f -size +2M -name "${serverfile}*"|sort -n |tail -n 1);
	if [ ! -z "$server_file" ];then
	    if [ $debug_mode -ge 1 ];then
		echo "Found serverfile:$server_file" 1>&2 ;
	    fi;
	    if [ -z "$found_server_file" ];then
		found_server_file=$server_file;
		serverext=${found_server_file##*.};
		server_type=$serverfile;
	    else
		let alternate_files_found=$alternate_files_found+1;
	    fi;
	fi;
    done
    if [ $alternate_files_found -gt 0 ] ;then
	echo "Additional server files matched, that shouldn't happen";
	echo "We're going to exit for safety.";
	exit 1 ; fi;
    if [ -z "$found_server_file" ];then
	echo "Error: No server file found" 1>&2;
	exit 1; fi;
    echo $server_type $serverext $(basename $found_server_file);
    return;
}

function get_mc_download_url () {
    urlofpage=$1
    server_type=$2
    serverext=$3
    downloadpath=$4
    
    # This is for minecraft urls.
    # Use curl to get page with download link on it.
    if [ ! -e ${downloadpath}/dlpage.txt ];then
	echo "Fetch download page" 1>&2;
	curl ${urlofpage} > ${downloadpath}/dlpage.txt
    fi;
    echo "get version number" 1>&2;
    versionnumber=$(sed -nr "s/.*(${server_type}\.)((:?[0-9]+\.?)+)(${serverext}).*/\2/p" <${downloadpath}/dlpage.txt |head -n 1);
    echo "get server file" 1>&2;
    server_file=$(sed -nr "s/.*(${server_type})((:?\.[0-9]+\.?)+)(${serverext}).*/\1\2\4/p" <${downloadpath}/dlpage.txt |head -n 1);
    echo "get url" 1>&2;
    downloadurl=$(sed -nr "s/.*<a href=\"(https:\/\/launcher.mojang.com.*${serverext})\".*/\1/p" <${downloadpath}/dlpage.txt);

    #echo u:$downloadurl v:$versionnumber f:$server_file 1>&2;
    echo $downloadurl $versionnumber $server_file;
    return;
}
