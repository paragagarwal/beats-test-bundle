#!/bin/sh
# Script to compare memory and disk dumps
/cbtransfer http://localhost:8091 csv:mem.csv -b default -u Administrator -p password --single-node &
/cbtransfer couchstore-files:///data csv:disk.csv -b default -u Administrator -p password  &
sleep 1800
sort -t, -k+1 -n  mem.csv > mem_sorted.csv &
sort -t, -k+1 -n disk.csv > disk_sorted.csv &
mem_items = wc -l mem_sorted.csv
echo "Items in memory: $mem_items"
disk_items = wc -l disk_sorted.csv
echo "Items in disk: $disk_items"
if [ "$mem_items" -ne "$disk_items" ]; then
	echo "Memory and disk items do not match"
diff mem_sorted.csv disk_sorted.csv |tee diff.txt
