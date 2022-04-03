#!/bin/bash
echo -e "Content-Type: text/plain\r\n\r\n"

brightness=${QUERY_STRING//*=/}

mosquitto_pub -d -h 10.2.2.2 -t cmnd/3395a160150f06a90f78faed443595e/power -m "{\"brightness\":$brightness}"
exit 0
