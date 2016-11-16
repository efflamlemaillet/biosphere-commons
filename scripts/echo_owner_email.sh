username=$(cat /opt/slipstream/client/bin/slipstream.context | grep username | sed 's/username = //g')
cat /opt/slipstream/client/bin/slipstream.context | grep cookie | sed 's/cookie = //g' > /root/.slipstream-cookie
ss-user-get $username 1> /root/user.xml
export OWNER_EMAIL=$(cat /root/user.xml | sed 's/ /\n/g' | grep email= | sed 's/email=//g' | sed 's/"//g')
echo $OWNER_EMAIL
rm -f /root/user.xml /root/.slipstream-cookie
