#!/bin/dash
/bin/sleep 10
/usr/bin/killall iperf3
/bin/sleep 0.1
/usr/bin/killall -9 iperf3
/bin/sleep 0.1
if [ `ps -C iperf3 | wc -l` = "1" ]
then
  /usr/bin/sudo -u nobody /usr/bin/iperf3 -s -p 5200 -D >/dev/null 2>&1
  /usr/bin/sudo -u nobody /usr/bin/iperf3 -s -p 5201 -D >/dev/null 2>&1
  /usr/bin/sudo -u nobody /usr/bin/iperf3 -s -p 5202 -D >/dev/null 2>&1
  /usr/bin/sudo -u nobody /usr/bin/iperf3 -s -p 5203 -D >/dev/null 2>&1
  /usr/bin/sudo -u nobody /usr/bin/iperf3 -s -p 5204 -D >/dev/null 2>&1
  /usr/bin/sudo -u nobody /usr/bin/iperf3 -s -p 5205 -D >/dev/null 2>&1
  /usr/bin/sudo -u nobody /usr/bin/iperf3 -s -p 5206 -D >/dev/null 2>&1
  /usr/bin/sudo -u nobody /usr/bin/iperf3 -s -p 5207 -D >/dev/null 2>&1
  /usr/bin/sudo -u nobody /usr/bin/iperf3 -s -p 5208 -D >/dev/null 2>&1
  /usr/bin/sudo -u nobody /usr/bin/iperf3 -s -p 5209 -D >/dev/null 2>&1
fi
