#!/usr/bin/env bash


function stop_server () {
    server_type=$1;
    
    # TODO: enhance to use rcon.
    #serverpid=`ps ax | grep ${server_type} | head -n 1 | cut -d " " -f 1 `
    #servertoolpid=`ps ax | grep ${servertool} | head -n 1 | cut -d " " -f 1 `
    #serverpid=`ps -ef | grep $server_type | awk '{ print $2 }'|head -n 1`
    # ps -ef --sort=-pcpu | awk '/.*minecraft_server.*/ {print $2}'
    echo "serverpid=ps -ef --sort=-pcpu | awk "/$server_type/"'{ print \$2 }'|head -n 1";
    serverpid=$(ps -ef --sort=-pcpu | awk "/$server_type/"'{ print $2 }'|head -n 1)
    echo ""
    echo "kill ${serverpid}"
    kill ${serverpid}

    if [ "${servertoolcount}" -ge 2 ]; then
	#servertoolpid=`ps -ef --sort=-pcup |grep $servertool | awk '{ print $2 }'|head -n 1`
	servertoolpid=$(ps -ef --sort=-pcu | awk "/$servertool/{ print $2 }"|head -n 1)
	kill -9 ${servertoolpid}
    fi
    return;
}

function get_server_type (){
    serverdir=$1;
    debug_mode=$2;

    if [ -z "$debug_mode" ];then
	debug_mode=0;
    fi;
    # Vanilla serverfile
    serverext="jar";
    #server_type="minecraft_server";

    all_server_files=(paper forge fabric spigot minecraft_server);
    server_type="";
    let alternate_files_found=0;
    for serverfile in ${all_server_files[@]}; do
	server_file=$(ls -tr ${serverdir}/${serverfile}*${serverext} 2> /dev/null|tail -n 1);
	if [ ! -z "$server_file" ];then
	    if [ $debug_mode -ge 1 ];then
		echo "Found serverfile:$server_file" 1>&2 ;
	    fi;
	    if [ -z "$found_server_file" ];then
		found_server_file=$server_file;
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
	echo "Fetch download page";
	curl ${urlofpage} > ${downloadpath}/dlpage.txt
    fi;
    echo "get version number"
    versionnumber=$(sed -nr "s/.*(${server_type}\.)((:?[0-9]+\.?)+)(${serverext}).*/\2/p" <${downloadpath}/dlpage.txt);
    echo "get server file"
    server_file=$(sed -nr "s/.*(${server_type})((:?\.[0-9]+\.?)+)(${serverext}).*/\1\2\4/p" <${downloadpath}/dlpage.txt |head -n 1);
    echo "get url"
    downloadurl=$(sed -nr "s/.*<a href=\"(https:\/\/launcher.mojang.com.*${serverext})\".*/\1/p" <${downloadpath}/dlpage.txt);
    echo $downloadurl $versionnumber $server_file;
    return;
}
