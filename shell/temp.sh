#!/bin/bash

min_temp='24.7'
max_temp='25.3'
arduino='10.2.2.188'
js_dir='/var/www/html/js'
base_dir='/var/www/html/'
out_stats="$js_dir/out_stats.js"
log_stats="$js_dir/log_stats.js"
# Get the current temperature and humidity
info=($(curl http://$arduino/arduino/digital/8 2>/dev/null))
# Get the current power state
power=$(curl http://$arduino/arduino/digital/7 2>/dev/null)
heating_log='/var/log/heating.log'
# 5 days + 3 lines for the JSON structure
retantion=7203

temp=${info[1]}
temp=${temp/C/}
humi=${info[3]}

x=$(date +%s)
if [ -n "$temp" -a -n "$humi" ]; then
	# in case the arduino returned an error
	if [[ "$temp" =~ ERR ]]; then
		exit 0
	fi
	# Add the new values to the storage file
	sed -i "\$i{ x: ${x}000, y: $temp }," $out_stats
	# if $temp is lower then $min_temp
	if echo "$temp $min_temp"|awk '{if($1>$2)exit 1}'; then
		# Turn ON the heating, only if it is currently off
		if [[ "$power" =~ off ]]; then
			curl http://$arduino/arduino/digital/7/0
			echo "$(date) temp $temp C, turning the heating ON " >> $heating_log
		fi
	fi
	if [ "$high" == 1 ]; then
	# if $temp is higher then $max_temp
	if echo "$temp $max_temp"|awk '{if($1<$2)exit 1}'; then
		# Turn OFF the heating, only if it is currently on
		if [[ "$power" =~ on ]]; then
			curl http://$arduino/arduino/digital/7/1
			echo "$(date) temp $temp C, turning the heating OFF" >> $heating_log
		fi
	fi
fi
# Save the current power status for the web page
if [[ "$power" =~ off ]]; then
	echo 'var power_status = 0;' >$js_dir/power_status.js
else
	echo 'var power_status = 1;' >$js_dir/power_status.js
fi

# Rotation is done here
if [ "$(wc -l $out_stats|cut -d ' '  -f 1)" -gt $retantion ] ; then
	first_line=($(head -n3 $out_stats |tail -n1))
	echo ${first_line[*]} >> $log_stats
	sed -i "/${first_line[2]}/d" $out_stats
fi
