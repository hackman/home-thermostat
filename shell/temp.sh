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

temp=${info[1]}
temp=${temp/C/}
humi=${info[3]}

x=$(date +%s)
if [ -n "$temp" -a -n "$humi" ]; then
	if [[ "$temp" =~ ERR ]]; then
		exit 0
	fi
	sed -i "\$i{ x: ${x}000, y: $temp }," $out_stats
	low=$(echo "$temp < $min_temp"|bc)
	if [ "$low" == 1 ]; then
		# Turn ON the heating
		if [[ "$power" =~ off ]]; then
			curl http://$arduino/arduino/digital/7/0
			echo "$(date) temp $temp C, turning the heating ON " >> $heating_log
		fi
	fi
	high=$(echo "$temp > $max_temp"|bc)
	if [ "$high" == 1 ]; then
		# Turn OFF the heating
		if [[ "$power" =~ on ]]; then
			curl http://$arduino/arduino/digital/7/1
			echo "$(date) temp $temp C, turning the heating OFF" >> $heating_log
		fi
	fi
fi
if [[ "$power" =~ off ]]; then
	echo 'var power_status = 0;' >$js_dir/power_status.js
else
	echo 'var power_status = 1;' >$js_dir/power_status.js
fi

# Rotation is done here
if [ "$(wc -l $out_stats|cut -d ' '  -f 1)" -gt 7203 ] ; then
	first_line=($(head -n3 $out_stats |tail -n1))
	echo ${first_line[*]} >> $log_stats
	sed -i "/${first_line[2]}/d" $out_stats
fi
