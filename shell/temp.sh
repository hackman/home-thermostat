#!/bin/bash

version='3.0'
min_temp='25.4'
max_temp='26.2'
arduino='10.2.2.195'
trigger='/var/run/heating'
# Get the current temperature 
kitchen=( $(curl -s http://$arduino/arduino/digital/8) )
kitchen[1]=${kitchen[1]/C}

# Get the current power state
power=$(curl -s http://$arduino/arduino/digital/7 2>/dev/null)
heating_log=/dev/null

temp=${kitchen[1]}

turn_on() {
	curl -s http://$arduino/arduino/digital/7/0 > /dev/null
	curl -s http://$arduino/arduino/digital/6/0 > /dev/null
	echo "$(date) temp $temp C, turning the heating ON " >> $heating_log
	exit 0
}
turn_off() {
	curl -s http://$arduino/arduino/digital/7/1 > /dev/null
	curl -s http://$arduino/arduino/digital/6/1 > /dev/null
	echo "$(date) temp $temp C, turning the heating OFF" >> $heating_log
	exit 0
}

remove_old() {
	file=${trigger}-$1
	if [[ ! -f $file ]]; then return; fi
	# Clean old trigger
	# stat is missing on the default Arduino Yun installations
	file_date=$(ls -e $file | awk '{print $7,$8,$10,$9}')    
	file_time=$(date -d "$file_date" -D '%b %d %Y %H:%M:%S' +%s)
	if [[ $file_time -lt $(($(date +%s)-3600)) ]]; then
		rm -f $file
	fi
}

# in case the arduino returned an error
if [[ -z $temp ]] || ! [[ $temp =~ ^[0-9.]+$ ]]; then
	exit 0
fi

remove_old on
remove_old off
if [[ -f $trigger ]]; then
	rm -f $trigger
	# Handle the manual trigger
	if [[ $power =~ on ]]; then
		touch ${trigger}-on
	else
		touch ${trigger}-off
	fi
fi

# if $temp is lower then $min_temp
if echo "$temp $min_temp"|awk '{if($1>$2)exit 1}'; then
	# Turn ON the heating, only if it is currently off
	if [[ $power =~ off ]] && [[ ! -f ${trigger}-off ]]; then
		turn_on
	fi
fi

# if $temp is higher then $max_temp
if echo "$temp $max_temp"|awk '{if($1<$2)exit 1}'; then
	# Turn OFF the heating, only if it is currently on 
	if [[ $power =~ on ]] && [[ ! -f ${trigger}-on ]]; then
		turn_off
	fi
fi
