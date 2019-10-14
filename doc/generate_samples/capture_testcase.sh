#!/bin/bash
SERVER_MASTER_KEY_FILE=$(basename $(ls master_keys/*.key))
SERVER_MASTER_KEY_ID="${SERVER_MASTER_KEY_FILE%.*}"
read SERVER_MASTER_KEY < master_keys/$SERVER_MASTER_KEY_FILE

echo "localparam [$((${#SERVER_MASTER_KEY_ID}*8-1)):0] NTS_TEST_REQUEST_MASTER_KEY_ID=$((${#SERVER_MASTER_KEY_ID}*8))'h${SERVER_MASTER_KEY_ID};"
echo "localparam [$((${#SERVER_MASTER_KEY}*8-1)):0] NTS_TEST_REQUEST_MASTER_KEY=$((${#SERVER_MASTER_KEY}*8))'h${SERVER_MASTER_KEY};"

for i in {1..5}
do
  (python3 ntske-server.py > /dev/null) &
  NTSKE_SERVER_PID=$!
  sleep 1
  python3 ntske-client.py localhost 4446 rootCaBundle.pem > /dev/null
  kill $NTSKE_SERVER_PID
  C2S=$(grep c2s client.ini | cut -f 3 -d ' ')
  S2C=$(grep s2c client.ini | cut -f 3 -d ' ')
  (python nts-server.py > /dev/null)&
  NTS_SERVER_PID=$!
  coproc TCPDUMP { sudo tcpdump -w - -c 1 -s0 -ilo dst port 4126 2>/dev/null | rawshark -s -d encap:1 -r - -F frame |
    tail -n 1 | cut -f 2 -d \" | tr -d :; }
  sleep 1
  python nts-client.py > /dev/null
  kill $NTS_SERVER_PID
  read PACKET <&"${TCPDUMP[0]}"
  echo "localparam [$((${#PACKET}*8-1)):0] NTS_TEST_REQUEST_WITH_KEY_${i} = $((${#PACKET}*8))'h${PACKET};"
  echo "localparam [$((${#C2S}*8-1)):0] NTS_TEST_REQUEST_C2S_KEY_${i} = $((${#C2S}*8))'h${C2S};"
  echo "localparam [$((${#S2C}*8-1)):0] NTS_TEST_REQUEST_S2C_KEY_${i} = $((${#S2C}*8))'h${S2C};"
done
exit
