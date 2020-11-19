#!/bin/bash

source .env

if [ -z "${SCALE_FACTOR}" ]; then
    echo "SCALE_FACTOR is not set. exiting ..."
    exit 1
fi

docker-compose -p warpme up -d --scale jibri=$SCALE_FACTOR

# Add a unique acoundrc file for eac Jibri instance (container)
# Since we add new asoundrc file, we need to restart the containers
# First container does not need any change in it's asoundrc file
for (( i=2; i<=$SCALE_FACTOR; i++ ))
do
    ii=$(expr $i - 1)
    sed "s/Loopback/Loopback_$ii/g" asoundrc > .temp
    docker cp .temp warpme_jibri_$i:/home/jibri/.asoundrc
done

rm -f .temp

echo "Restarting all jibri instances..."

# Jibries except the first one need a restart
for (( i=2; i<=$SCALE_FACTOR; i++ ))
do
    docker restart warpme_jibri_$i
done

echo "All jibri instances are now up!"

index=$(expr $SCALE_FACTOR - 1)
seq=$(seq -s , 0 $index)
rep=$(printf '1,%.0s' `seq $SCALE_FACTOR`)
rep=${rep::-1}

echo "options snd-aloop enable=$rep index=$seq" > /etc/modprobe.d/alsa-loopback.conf

#dpkg-query --show  "alsa-utils"
#if [ "$?" != "0" ]; then
#    apt-get update
#    apt-get install alsa-utils -y
#fi
apt-get install alsa-utils -y

card_count=$(aplay -l | grep -c "^card")
card_count=$(expr $card_count / 2)

diff=$(expr $SCALE_FACTOR - $card_count)

if [ "$diff" -gt 0 ]; then
    printf "**\n**\n**\nNOTICE: You must restart the server for changes to take effect\n**\n**\n**"
fi

if ! grep -Fxq "snd-aloop" /etc/modules
then
    echo "snd-aloop" >> /etc/modules
fi

echo "Adding snd-aloop module"
modprobe snd-aloop

res=$(lsmod | grep snd_aloop)
if [ -z "${res}" ]
then
    printf "**\n**\n**\nNOTICE: You must restart the server for changes to take effect\n**\n**\n**"
fi


