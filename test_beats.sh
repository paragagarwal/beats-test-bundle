#!/bin/bash
# Test Beats scenario 

now=$(date +"%T")
echo "$now---------------Step: Install 2.2.0-821 on all nodes and start cluster--------------------"

# install on all nodes and cluster them
python scripts/install.py -i beats.ini -p product=cb,version=2.2.0-821,parallel=true
curl -u Administrator:password 172.23.105.44:8091/controller/addNode -d "hostname=172.23.105.45&user=Administrator&password=password"
curl -u Administrator:password 172.23.105.44:8091/controller/addNode -d "hostname=172.23.105.47&user=Administrator&password=password"
curl -u Administrator:password 172.23.105.44:8091/controller/addNode -d "hostname=172.23.105.48&user=Administrator&password=password"
curl -u Administrator:password 172.23.105.44:8091/controller/addNode -d "hostname=172.23.105.49&user=Administrator&password=password"

curl -u Administrator:password 172.23.105.54:8091/controller/addNode -d "hostname=172.23.105.55&user=Administrator&password=password"
curl -u Administrator:password 172.23.105.54:8091/controller/addNode -d "hostname=172.23.105.57&user=Administrator&password=password"
curl -u Administrator:password 172.23.105.54:8091/controller/addNode -d "hostname=172.23.105.58&user=Administrator&password=password"
curl -u Administrator:password 172.23.105.54:8091/controller/addNode -d "hostname=172.23.105.60&user=Administrator&password=password"

curl -v -u Administrator:password -X POST \
'http://172.23.105.44:8091/controller/rebalance' -d \
'ejectedNodes=&knownNodes=ns_1@172.23.105.44,ns_1@172.23.105.45,ns_1@172.23.105.47,ns_1@172.23.105.48,ns_1@172.23.105.49'

curl -v -u Administrator:password -X POST  \
'http://172.23.105.54:8091/controller/rebalance' -d \
'ejectedNodes=&knownNodes=ns_1@172.23.105.54,ns_1@172.23.105.55,ns_1@172.23.105.57,ns_1@172.23.105.58,ns_1@172.23.105.60'

sleep 60

now=$(date +"%T")
echo "$now---------------Step: Bucket creation at source and destination--------------------"

# create bucket at source and dest
curl -X POST -u Administrator:password -d name=default -d ramQuotaMB=9000 -d authType=none \
     -d replicaNumber=1 -d proxyPort=11215  http://172.23.105.44:8091/pools/default/buckets

sleep 20

curl -X POST -u Administrator:password -d name=default -d ramQuotaMB=9000 -d authType=none \
     -d replicaNumber=1 -d proxyPort=11215  http://172.23.105.54:8091/pools/default/buckets

sleep 20
now=$(date +"%T")
echo "$now--------------- Step: Setup replication --------------------"

# setup bidirectional replication

# setup XDCR cluster reference from 44 -> 54
curl -v -u Administrator:password 172.23.105.44:8091/pools/default/remoteClusters \
-d name=54cluster 
-d hostname=172.23.105.54:8091 
-d username=Administrator -d password=password

sleep 10
# setup XDCR cluster reference from 54 -> 44
curl -v -u Administrator:password 172.23.105.54:8091/pools/default/remoteClusters \
-d name=44cluster 
-d hostname=172.23.105.44:8091 
-d username=Administrator -d password=password

#setup replication
curl -v -X POST -u Administrator:password http://172.23.105.44:8091/controller/createReplication -d uuid=9eee38236f3bf28406920213d93981a3 -d fromBucket=default -d toCluster=54cluster -d toBucket=default -d replicationType=continuous

curl -v -X POST -u Administrator:password http://172.23.105.54:8091/controller/createReplication -d uuid=9eee38236f3bf28406920213d93981a6 -d fromBucket=default  -d toCluster=44cluster -d toBucket=default  -d replicationType=continuous

now=$(date +"%T")
echo "$now---------------Step: Start loading source/dest --------------------"


# call loader - route data to source OR destination
#TODO

# sleep(load) for 40 mins
sleep 144#000

now=$(date +"%T")
echo "$now---------------Step: Start loading only to dest --------------------"

# call loader - route data only to destination
#TODO

now=$(date +"%T")
echo "$now---------------Step: Upgrading source cluster --------------------"

# do offline upgrade of source
python scripts/ssh.py -i beats_src.ini "/etc/init.d/couchbase-server stop"
sleep 30
python scripts/ssh.py -i beats_src.ini "rpm -Uvh couchbase-server-enterprise_centos6_x86_64_2.2.0-837-rel.rpm"
sleep 90
python scripts/ssh.py -i beats_src.ini "/etc/init.d/couchbase-server stop"
sleep 30

now=$(date +"%T")
echo "$now---------------Step: Applying beam patch on source cluster --------------------"

# apply beam patch on source
python scripts/ssh.py -i beats_src_as_couchbase.ini "wget https://s3.amazonaws.com/bugdb/jira/MB-0/xdc_vbucket_rep.beam"
python scripts/ssh.py -i beats_src_as_couchbase.ini "cp xdc_vbucket_rep.beam /opt/couchbase/lib/ns_server/erlang/lib/ns_server/ebin/"
python scripts/ssh.py -i beats_src.ini "/etc/init.d/couchbase-server start"
sleep 60


now=$(date +"%T")
echo "$now---------------Step: Loading only to dest cluster --------------------"

# call loader - route data only to source
#TODO

now=$(date +"%T")
echo "$now---------------Step: Upgrading dest cluster --------------------"

# do online upgrade of dest
python scripts/ssh.py -i beats_dest.ini "/etc/init.d/couchbase-server stop"
sleep 30
python scripts/ssh.py -i beats_dest.ini "rpm -Uvh couchbase-server-enterprise_centos6_x86_64_2.2.0-837-rel.rpm"
sleep 90
python scripts/ssh.py -i beats_dest.ini "/etc/init.d/couchbase-server stop"
sleep 30

now=$(date +"%T")
echo "$now---------------Step: Apply beam patch on dest cluster --------------------"

# apply beam patch
python scripts/ssh.py -i beats_dest_as_couchbase.ini "wget https://s3.amazonaws.com/bugdb/jira/MB-0/xdc_vbucket_rep.beam"
python scripts/ssh.py -i beats_dest_as_couchbase.ini "cp xdc_vbucket_rep.beam /opt/couchbase/lib/ns_server/erlang/lib/ns_server/ebin/"
python scripts/ssh.py -i beats_dest.ini "/etc/init.d/couchbase-server start"
sleep 30
now=$(date +"%T")

echo "$now--------------- Step: Load both source and destination --------------------"
# call loader - route data to source OR destination
#TODO

# sleep(load) for 20 mins
sleep 144000

now=$(date +"%T")
echo "$now---------------Step: Load data to src/dest cluster --------------------"

# call loader - route data to source/destination
#TODO

now=$(date +"%T")
echo "$now---------------Step: Test complete, allow queues to drain --------------------"

#stop data load, allow queues to drain
sleep 144000

now=$(date +"%T")
echo "$now--------------- Step: All docs verification --------------------"


# verification
wget -O- http://172.23.105.44:8092/default/_all_docs > 44_all_docs.txt
wget -O- http://172.23.105.54:8092/default/_all_docs > 54_all_docs.txt
diff 44_all_docs.txt 54_all_docs.txt

now=$(date +"%T")
echo "$now--------------- Step: All docs verification complete--------------------"

