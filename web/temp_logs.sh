#!/bin/bash
heating_log='/var/log/heating.log'

echo -e "Content-type: text/html\r\n"

#tail -n10 $heating_log|sed ':a;N;$!ba;s|\n|<br />\n|g'
echo '<pre>'
tail -n10 $heating_log
echo '</pre>'
