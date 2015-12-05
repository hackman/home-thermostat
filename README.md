This is a very simple home thermostat with Adruino YUN.

It gives you graphs and web control over your heating.

Arduino YUN + remote server installation istructions:

Arduino YUN installation instructions:

  1. Upload the skatch from the arduino dir

  2. Login to your yun and install bash and bc:
    opkg install bash bc

  3. Create the web dir:
    mkdir -p /www/t/js

  4. Download jQuery and CanvasJS libraries into /www/t/js

  5. Copy the t.html to /www/t/index.html

  6. Copy web/*.js to /www/t/js 

  7. Copy web/*.sh /www/t/

  8. Copy shell/temp.sh to /root

Add the cron job:
 * * * * * /root/temp.sh > /dev/null 2>&1

