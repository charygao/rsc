#!/bin/bash
set -e
RSC=$1
if [ "${RSC}" == "" ];then
  RSC=rsc
fi
OS=$2
if [ "${OS}" == "" ];then
  OS=macOS
fi

if [ ! -f ./rsc-e2e ];then
  echo ">>> Download rsc-e2e"
  wget -qO rsc-e2e https://github.com/making/rsc-e2e/releases/download/0.1.0/rsc-e2e-${OS}
fi
chmod +x rsc-e2e
./rsc-e2e &

while ! `perl -mIO::Socket::INET -le 'exit(IO::Socket::INET->new(PeerAddr=>shift,PeerPort=>shift,Proto=>shift,Timeout=>5)?0:1)' localhost 7001`; do
  sleep 1
done

${RSC} -v
${RSC} --showSystemProperties

echo ">>> Test Fire and Forget"
DEBUG=`${RSC} --fnf -r uppercase.fnf -d hello -q --debug tcp://localhost:7001`
set -x
echo "$DEBUG" | grep "Stream ID: 1 Type: REQUEST_FNF" > /dev/null
set +x

echo ">>> Test Request Response"
${RSC} -r uppercase.rr -d hello tcp://localhost:7001 | grep "^HELLO$" > /dev/null
DEBUG=`${RSC} -r uppercase.rr -d hello -q --debug tcp://localhost:7001`
set -x
echo "$DEBUG" | grep "Stream ID: 1 Type: REQUEST_RESPONSE" > /dev/null
echo "$DEBUG" | grep "Stream ID: 1 Type: NEXT_COMPLETE" > /dev/null
set +x

echo ">>> Test Request Stream"
${RSC} --stream -r uppercase.stream -d hello --limitRate 3 --take 3 tcp://localhost:7001 | grep "^HELLO$" | wc -l | grep "3$" > /dev/null
DEBUG=`${RSC} --stream -r uppercase.stream -d hello --limitRate 3 --take 3 -q --debug tcp://localhost:7001`
set -x
echo "$DEBUG" | grep "Stream ID: 1 Type: REQUEST_STREAM" > /dev/null
echo "$DEBUG" | grep "Stream ID: 1 Type: NEXT" | wc -l | grep "3$" > /dev/null
echo "$DEBUG" | grep "Stream ID: 1 Type: CANCEL" > /dev/null
set +x

echo ">>> Test Request Channel"
FILE=$(mktemp)
cat <<EOF > ${FILE}
abc
def
ghi
jkl
EOF
CHANNEL=`cat ${FILE} | ${RSC} --channel -r uppercase.channel -d - tcp://localhost:7001`
DEBUG=`cat ${FILE} | ${RSC} --channel -r uppercase.channel -d - -q --debug tcp://localhost:7001`
set -x
echo "$CHANNEL" | grep "^ABC$" > /dev/null
echo "$CHANNEL" | grep "^DEF$" > /dev/null
echo "$CHANNEL" | grep "^GHI$" > /dev/null
echo "$CHANNEL" | grep "^JKL$" > /dev/null
echo "$DEBUG" | grep "Stream ID: 1 Type: REQUEST_CHANNEL" > /dev/null
echo "$DEBUG" | grep "Stream ID: 1 Type: NEXT" | wc -l | grep "7$" > /dev/null
echo "$DEBUG" | grep "Stream ID: 1 Type: REQUEST_N" > /dev/null
echo "$DEBUG" | grep "Stream ID: 1 Type: COMPLETE" | wc -l | grep "2$" > /dev/null
set +x

pkill -KILL rsc-e2e
echo "✅ E2E test succeeded!"