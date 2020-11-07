#!/usr/bin/env bash
# Start server in this dir, trying to be a quasi general start.
# Uses tmux, lastest server file in this dir, and world name from server properties.


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
    echo "Error: couldn't resolve server_type for $serverdir";
    exit 1; fi;

echo "Starting minecraft $world @ $(basename $current_server_file) in 3 seconds"
echo "serverdir:$serverdir";
sleep 3;

# Java optfun
if [ "$serverext" == "jar" ];then
    # basic as offered from minec...net
    simple_java_params="-Xmx1024M -Xms1024M";
    # On research people indicate not many GB needed for server.
    # Tested 4G briefly while generating terrain and never saw over 3GB used
    # however, constant cpu of 360% was in effect.
    # The more the merrier memory suggestion is from the adv param mc nerd referencing his server running with 12.
    # In simple testing strongly suspect 11 is overkill, and 3 would be plenty for expected usage. While server is not busy with anything else 11 will be left.
    simple_java_params="-Xmx11G -Xms11G";
    #simple_java_params="-Xmx6G -Xms6G";
    #simple_java_params="-Xmx4G -Xms4G";
    # advanced by MC nerd per following post. Of note, he was using a paper mc server
    # https://aikar.co/2018/07/02/tuning-the-jvm-g1gc-garbage-collector-flags-for-minecraft/
    # Tested the adv params with 2G server and found performance was worse...
    # Bumped up to 6 to try again, 6 was not apprecaibly different. Don't like thd idea of keeping this high for nothing.
    adv_java_params="    -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:-OmitStackTraceInFastThrow -XX:+AlwaysPreTouch  -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=8 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=true -Daikars.new.flags=true    ";
    
    java_params="$simple_java_params"
    java_params="$simple_java_params $adv_java_params";
    
    svr_start="java $java_params -jar $current_server_file nogui";
else
    svr_start="declare -x LD_LIBRARY_PATH=$serverdir && cd $serverdir && ./$current_server_file"
fi;
# force agree in license
if [ -e $serverdir/eula.txt ];then
    sed -i"" 's/eula=false/eula=true/' $serverdir/eula.txt
fi;

# set tmux session name
tmux_sesh="${world}_$(basename $current_server_file)";
#Minor addjustment for valid filnames.  . -> p
tmux_sesh=$(echo $tmux_sesh|sed 's/[.]/p/g');

#echo $tmux_sesh
echo $svr_start
#tmux new-session -d -s "$tmux_sesh" -- $svr_start |tee "${serverdir}/console.log"
#tmux new-session -d -s "$tmux_sesh" -- $svr_start \; pipe-pane tee "${serverdir}/console.log"
tmux new-session -d -s "$tmux_sesh" -- "$svr_start"
