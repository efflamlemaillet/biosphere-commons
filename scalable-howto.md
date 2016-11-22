##Source

Based on ssdocs, [here](http://ssdocs.sixsq.com/en/v3.14/advanced_tutorial/automating-slipstream.html#setup) and [there](http://ssdocs.sixsq.com/en/v3.14/advanced_tutorial/scalable-applications.html#scale-up-with-cli)

## Where ?

Place yourself somewhere, on your computer, on the master, whereever you want

## Install the client

### Install virtual env

`sudo apt-get install virtualenv -y`

### Install the client

```
cd /tmp/
virtualenv ss-cli
source ss-cli/bin/activate
pip install slipstream-client
```

### Store you credentials and run id

```
export SLIPSTREAM_USERNAME=ssuser
export SLIPSTREAM_PASSWORD=sspass
export SLIPSTREAM_RUN=1fd05d69-5904-4fb1-a86b-6d823e0ac8d5
```

### Try to authentify yourself

`ss-user-get $SLIPSTREAM_USERNAME -u $SLIPSTREAM_USERNAME -p $SLIPSTREAM_PASSWORD | grep "<user"`

## scale down you cluster, remove slave #3

`ss-node-remove $SLIPSTREAM_RUN slave 3`

## scale up you cluster, add two slaves

`ss-node-add $SLIPSTREAM_RUN slave 2`

