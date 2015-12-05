#!/bin/bash
heating_log='/var/log/heating.log'
arduino='10.2.2.188'

echo -e "Content-type: text/plain\r\n"
export

case "${REQUEST_URI/*\?/}" in
	on)
#		curl http://$arduino/arduino/digital/7/0
		echo "$(date) temp $HTTP_TEMP C, turning the heating ON " >> $heating_log
	;;
	off)
#		curl http://$arduino/arduino/digital/7/1
		echo "$(date) temp $HTTP_TEMP C, turning the heating OFF " >> $heating_log
	;;
	*)
		echo "Invalid option"
esac

