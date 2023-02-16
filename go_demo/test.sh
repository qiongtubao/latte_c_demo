#!/bin/bash

unset LC_ALL
LC_ALL=C
IP=127.0.0.1
port=6379
redis_instance_running=`netstat -atunlp | grep $port`
REDIS_CLI="/opt/app/redis/sbin/redis-cli"
LOG_FILE="/tmp/hickwall_cache.log"

check_instance_status() {
    if [ -z "$redis_instance_running" ];then
        echo "redis instance $port not running"
        exit 0
    fi
}

collect_info_to_log_file() {
    echo "info all"|$REDIS_CLI -h 127.0.0.1 -p $port > $LOG_FILE
}

# change me !!!
get_monitor_version() {
    echo -n "1.0.1"
}

is_master() {
    role=`awk -F: '/^role/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ "$role"x = "master"x ]; then
        echo -n "1"
    else
        echo -n "0"
    fi
}

get_sha1() {
    sha1="unknown"
    if [ "$PAAS_TYPE"x = "redis"x ] || [ "$PAAS_TYPE"x = "ror"x ]; then
        sha1=`awk -F: '/^redis_git_sha1:/{print $2}' $LOG_FILE|sed "s/\r//"`
    elif [ "$PAAS_TYPE"x = "kvrocks"x ]; then
        sha1=`awk -F: '/^git_sha1:/{print $2}' $LOG_FILE|sed "s/\r//"`
    fi
    echo -n "$sha1"
}

get_redis_version() {
    redis_version=`awk -F: '/^redis_version:/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$redis_version" ]; then
        echo -n "$redis_version"
    else
        echo -n "unknown"
    fi
}

get_xredis_version() {
    xredis_version=`awk -F: '/^xredis_version:/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$xredis_version" ]; then
        echo -n "$xredis_version"
    else
        echo -n "unknown"
    fi
}

get_kvrocks_version() {
    kvrocks_version=`awk -F: '/^version:/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$kvrocks_version" ]; then
        echo -n "$kvrocks_version"
    else
        echo -n "unknown"
    fi
}

get_swap_version() {
    swap_version=`awk -F: '/^swap_version:/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$swap_version" ]; then
        echo -n "$swap_version"
    else
        echo -n "unknown"
    fi
}

get_rocksdb_version() {
    rocksdb_version=`awk -F: '/^rocksdb_version:/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$rocksdb_version" ]; then
        echo -n "$rocksdb_version"
    else
        echo -n "unknown"
    fi
}

print() {
    metric_name=$1
    value=$2
    if [ -n "$value" ]; then
        if [ "$PAAS_TYPE"x = "redis"x ]; then
            echo "cache.$metric_name,port=$port,arch=$arch,is_master=$is_master,sha1=$sha1,monitor_version=$monitor_version,redis_version=$redis_version,xredis_version=$xredis_version value=$value"
        elif [ "$PAAS_TYPE"x = "kvrocks"x ]; then
            echo "cache.$metric_name,port=$port,arch=$arch,is_master=$is_master,sha1=$sha1,monitor_version=$monitor_version,redis_version=$redis_version,xredis_version=$xredis_version,kvrocks_version=$kvrocks_version value=$value"
        elif [ "$PAAS_TYPE"x = "ror"x ]; then
            echo "cache.$metric_name,port=$port,arch=$arch,is_master=$is_master,sha1=$sha1,monitor_version=$monitor_version,redis_version=$redis_version,xredis_version=$xredis_version,swap_version=$swap_version,rocksdb_version=$rocksdb_version value=$value"
        fi
    fi
}

common() {
    # instantaneous_ops_per_sec
    instantaneousOpsPerSec=`awk -F: '/^instantaneous_ops_per_sec:/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$instantaneousOpsPerSec" ]; then
        print "instantaneous_ops_per_sec" "$instantaneousOpsPerSec"
    fi

    # hits_rate
    keyspace_hits=`awk -F: '/^keyspace_hits:/{printf("%d",$2)}' $LOG_FILE`
    keyspace_misses=`awk -F: '/^keyspace_misses:/{printf("%d",$2)}' $LOG_FILE`
    if [ -n "$keyspace_hits" ] && [ -n "$keyspace_misses" ]; then
        if [ "$keyspace_hits" == "0" ] && [ "$keyspace_misses" == "0" ]; then
            print "hits_rate" "0"
        else
            print "hits_rate" "$(printf "%.2f" `echo "scale=2; ${keyspace_hits}*100/(${keyspace_misses}+${keyspace_hits})"|bc`)"
        fi
    fi

    # memory_hits_rate
#    swapMemoryHits=`awk -F: '/^swap_memory_hits:/{printf("%d",$2)}' $LOG_FILE`
#    if [ -n "$keyspace_hits" ] && [ -n "$keyspace_misses" ] && [ -n "$swapMemoryHits" ]; then
#        if [ "$keyspace_hits" == "0" ] && [ "$keyspace_misses" == "0" ]; then
#            print "memory_hits_rate" "0"
#        else
#            print "memory_hits_rate" "$(printf "%.2f" `echo "scale=2; ${swapMemoryHits}*100/(${keyspace_misses}+${keyspace_hits})"|bc`)"
#        fi
#    fi

    # latest_fork_usec
    lastestForkUsec=`awk -F: '/^latest_fork_usec:/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$lastestForkUsec" ]; then
        print "latest_fork_usec" "$lastestForkUsec"
    fi

    # instantaneous_input_bps
    netin_value=`awk -F: '/^instantaneous_input_kbps:/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$netin_value" ]; then
        print "instantaneous_input_Bps" "$(printf "%.2f" `echo "scale=2; ${netin_value}*1000" | bc`)"
    fi

    # instantaneous_output_bps
    netout_value=`awk -F: '/^instantaneous_output_kbps:/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$netout_value" ]; then
        print "instantaneous_output_Bps" "$(printf "%.2f" `echo "scale=2; ${netout_value}*1000" | bc`)"
    fi

    # slowlog
    num=$(echo "slowlog len"|$REDIS_CLI -h 127.0.0.1 -p ${port})
    if [ "$num" ]; then
        print "slowlog" "$num"
    else
        print "slowlog" "0"
    fi

    # lazyfree_pending_objects
    lazyfree_pending_objects=`awk -F: '/^lazyfree_pending_objects:/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$lazyfree_pending_objects" ]; then
        print "lazyfree_pending_objects" "$lazyfree_pending_objects"
    fi

    # rdb_bgsave_in_progress
    rdb_bgsave_in_progress=`awk -F: '/^rdb_bgsave_in_progress:/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$rdb_bgsave_in_progress" ]; then
        print "rdb_bgsave_in_progress" "$rdb_bgsave_in_progress"
    fi

    # loading
    loading=`awk -F: '/^loading:/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$loading" ]; then
        print "loading" "$loading"
    fi
}

memory() {
    # used_memory
    usedMemory=`awk -F: '/^used_memory:/{printf("%.2f\n",$2/1024/1024)}' $LOG_FILE`
    if [ -n "$usedMemory" ];then
        print "used_memory" "$usedMemory"
    fi

    # maxMemory
    maxMemory=`awk -F: '/^maxmemory:/{printf("%.2f\n",$2/1024/1024)}' $LOG_FILE`
    if [ -n "$maxMemory" ];then
    print "maxmemory" "$maxMemory"
    fi

    # used_memory_percent
    if [ -n "$usedMemory" ] && [ -n "$maxMemory" ]; then
        print "used_memory_percent" "$(printf "%.2f" `echo "scale=2; ${usedMemory}*100/${maxMemory}"|bc`)"
    fi

    # used_memory_rss
    usedMemoryRss=`awk -F: '/^used_memory_rss:/{printf("%.2f\n",$2/1024/1024)}' $LOG_FILE`
    if [ -n "$usedMemoryRss" ]; then
        print "used_memory_rss" "$usedMemoryRss"
    fi

    # used_memory_overhead
    usedMemoryOverhead=`awk -F: '/^used_memory_overhead:/{printf("%.2f\n",$2/1024/1024)}' $LOG_FILE`
    if [ -n "$usedMemoryOverhead" ]; then
        print "used_memory_overhead" "$usedMemoryOverhead"
    fi

    # mem_rocksdb
    usedMemoryRocksdb=`awk -F: '/^swap_mem_rocksdb:/{printf("%.2f\n",$2/1024/1024)}' $LOG_FILE`
    if [ -n "$usedMemoryRocksdb" ]; then
        print "swap_mem_rocksdb" "$usedMemoryRocksdb"
    fi
}

status() {
    # process_status
    if [ -n "$redis_instance_running" ]; then
        print "process_status" "1"
    else
        print "process_status" "0"
    fi

    # master_link_status
    if [ "`awk -F: '/^role:/{print $2}' $LOG_FILE|grep master|wc -l`" == 1 ]; then
        print "master_link_status" "1"
    else
        if [ "`awk -F: '/^master_link_status:/{print $2}' $LOG_FILE|grep up|wc -l`" == 1 ]; then
            print "master_link_status" "1"
        else
            print "master_link_status" "0"
        fi
    fi

    # rdb_last_bgsave_status
    rdb_last_bgsave_status=`awk -F: '/^rdb_last_bgsave_status:/{print $2}' $LOG_FILE`
    if [ -n "$rdb_last_bgsave_status" ]; then
        ok=$(echo "$rdb_last_bgsave_status" | grep ok)
        if [ -n "$ok" ]; then
            print "rdb_last_bgsave_status" "1"
        else
            print "rdb_last_bgsave_status" "0"
        fi
    fi
}

keys() {
    # key_count
    dbCount=0
    if [ "$PAAS_TYPE"x = "redis"x ] || [ "$PAAS_TYPE"x = "ror"x ]; then
        dbCount=$(echo "dbsize"|$REDIS_CLI -h 127.0.0.1 -p ${port})
    elif [ "$PAAS_TYPE"x = "kvrocks"x ]; then
        dbCount=`awk -F: '/^estimate_keys\[metadata\]/{print $2}' $LOG_FILE|sed "s/\r//"`
    fi
    if [ -n "$dbCount" ]; then
        print "key_count" "$dbCount"
    fi

    # expires_key_count
    expires_key_count=0
    if [ "$PAAS_TYPE"x = "redis"x ] || [ "$PAAS_TYPE"x = "kvrocks"x ]; then
        expires_key_count=`awk -F: '/^db0:/{print $2}' $LOG_FILE | awk -F, '{print $2}' | awk -F= '{print $2}'`
    elif [ "$PAAS_TYPE"x = "ror"x ]; then
        expires_key_count=`awk -F: '/^db0:/{print $2}' $LOG_FILE | awk -F, '{print $4}' | awk -F= '{print $2}'`
    fi
    if [ -n "$expires_key_count" ]; then
        print "expires_key_count" "$expires_key_count"
    else
        print "expires_key_count" "0"
    fi

    # evicted_key_count
    evicted_key_count=`awk -F: '/^evicted_keys:/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$evicted_key_count" ]; then
        print "evicted_key_count" "$evicted_key_count"
    fi
}

connection() {
    # connected_clients
    connectedClients=`awk -F: '/^connected_clients:/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$connectedClients" ]; then
        print "connected_clients" "$connectedClients"
    fi

    # blocked_clients
    blockedClients=`awk -F: '/^blocked_clients:/{print $2}' $LOG_FILE |sed "s/\r//"`
    if [ -n "$blockedClients" ]; then
        print "blocked_clients" "$blockedClients"
    fi

    # rejected_connections
    rejectedConnections=`awk -F: '/^rejected_connections:/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$rejectedConnections" ]; then
        print "rejected_connections" "$rejectedConnections"
    fi
}

dbsize(){
    used_db_size=`awk -F: '/used_db_size:/{printf("%.2f\n",$2/1024/1024/1024)}' $LOG_FILE`
    if [ -n "$used_db_size" ]; then
        print "used_db_size" "$used_db_size"
    fi

    max_db_size=`awk -F: '/max_db_size:/{printf("%.2f\n",$2/1024/1024/1024)}' $LOG_FILE`
    if [ -n "$max_db_size" ]; then
        print "max_db_size" "$max_db_size"
    fi

    if [ -n "$used_db_size" ] && [ -n "$max_db_size" ]; then
        if [ "$used_db_size" == "0.00" ] || [ "$max_db_size" == "0.00" ]; then
            print "used_db_size_percent" "0"
        else
            print "used_db_size_percent" "$(printf "%.2f" `echo "scale=2; ${used_db_size}*100/${max_db_size}"|bc`)"
        fi
    fi

    usedDisk=`awk -F: '/used_disk_size:/{print $2}' $LOG_FILE | sed "s/\r//"`
    if [ -n "$usedDisk" ]; then
        print "used_disk_size" "$usedDisk"
    fi

    maxdisk=`awk -F: '/disk_capacity:/{print $2}' $LOG_FILE | sed "s/\r//"`
    if [ -n "$maxdisk" ]; then
        print "max_disk_size" "$maxdisk"
    fi

    if [ -n "$usedDisk" ] && [ -n "$maxdisk" ]; then
        if [ "$usedDisk" == "0.00" ] || [ "$maxdisk" == "0.00" ]; then
            print "used_disk_size_percent" "0"
        else
            print "used_disk_size_percent" "$(printf "%.2f" `echo "scale=2; ${usedDisk}*100/${maxdisk}"|bc`)"
        fi
    fi
}

# -------------------- kvrocks ----------------------
cumulativeProperty() {
    target=("cumulative_writes_num\(K\)" "cumulative_writes_keys\(K\)" "cumulative_writes_commit_group\(K\)" "cumulative_writes_per_commit_group" "cumulative_writes_ingest_size\(GB\)" "cumulative_writes_ingest_speed\(MB\/s\)" "cumulative_wal_writes\(K\)" "cumulative_wal_syncs" "cumulative_wal_writes_per_sync" "cumulative_wal_writen_size\(GB\)" "cumulative_wal_writen_speed\(MB\/s\)" "cumulative_stall_percent")
    for i in "${!target[@]}";
    do
        value=`awk -F: '/'''${target[$i]}'''/{print $2}' $LOG_FILE|sed "s/\r//"`
        if [ -n "$value" ]; then
            metric=$(echo "${target[$i]}"|sed 's/\\//g;s/)//g;s/(//g;s/\///g')
            print "$metric" "$value"
        fi
    done

    cumulative_stall_time=`awk -F: '/^cumulative_stall_time:/{printf("%s:%s:%s",$2,$3,$4)}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$cumulative_stall_time" ]; then
        cumulative_stall_time_arr=(${cumulative_stall_time//:/ })
        cumulative_stall_time_hour=`echo ${cumulative_stall_time_arr[0]} | awk '{print $0*1000*60*60}'`
        cumulative_stall_time_minute=`echo ${cumulative_stall_time_arr[1]} | awk '{print $0*1000*60}'`
        cumulative_stall_time_second=`echo ${cumulative_stall_time_arr[2]} | awk '{print $0*1000}'`
        cumulative_stall_time_millisecond=`expr $cumulative_stall_time_hour + $cumulative_stall_time_minute + $cumulative_stall_time_second`
        print "cumulative_stall_time" "$cumulative_stall_time_millisecond"
    fi;
}

intervalProperty()
{
target=("interval_writes_num\(K\)" "interval_writes_keys\(K\)" "interval_writes_commit_group\(K\)" "interval_writes_per_commit_group" "interval_writes_ingest_size\(MB\)" "interval_writes_ingest_speed\(MB\/s\)" "interval_wal_writes\(K\)" "interval_wal_syncs" "interval_wal_writes_per_sync" "interval_wal_writen_size\(MB\)" "interval_wal_writen_speed\(MB\/s\)" "interval_stall_percent")
for i in "${!target[@]}";
do
    value=`awk -F: '/'''${target[$i]}'''/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$value" ]; then
        metric=$(echo "${target[$i]}"|sed 's/\\//g;s/)//g;s/(//g;s/\///g')
        print "$metric" "$value"
    fi
done

interval_stall_time=`awk -F: '/^interval_stall_time:/{printf("%s:%s:%s",$2,$3,$4)}' $LOG_FILE|sed "s/\r//"`
if [ -n "$interval_stall_time" ]; then
    interval_stall_time_arr=(${interval_stall_time//:/ })
    interval_stall_time_hour=`echo ${interval_stall_time_arr[0]} | awk '{print $0*1000*60*60}'`
    interval_stall_time_minute=`echo ${interval_stall_time_arr[1]} | awk '{print $0*1000*60}'`
    interval_stall_time_second=`echo ${interval_stall_time_arr[2]} | awk '{print $0*1000}'`
    interval_stall_time_millisecond=`expr $interval_stall_time_hour + $interval_stall_time_minute + $interval_stall_time_second`
    print "interval_stall_time" "$interval_stall_time_millisecond"
fi
}

levelCompaction(){
target=("TotalFiles" "CompactingFiles" "Size\(GB\)" "Score" "Read\(GB\)" "Rn\(GB\)" "Rnp1\(GB\)" "Write\(GB\)" "Wnew\(GB\)" "Moved\(GB\)" "W-Amp" "Rd\(MB\/s\)" "Wr\(MB\/s\)" "Comp\(sec\)" "CompMergeCPU\(sec\)" "Comp\(cnt\)" "Avg\(sec\)" "KeyIn\(K\)" "KeyDrop\(K\)")
awk '/TotalFiles/{f=1}f;/KeyDrop/{f=0}' $LOG_FILE > /tmp/level_compaction_cahe.log
for i in "${!target[@]}";
do
    value=`cat /tmp/level_compaction_cahe.log`
    # |awk -F: '/'''${target[$i]}'''/{print $2}'`
    # | awk 'NR==1{print}' | awk '{print $1*1}'`
    # if [ -n "$value" ]; then
    #     if [ ${target[$i]} = "W-Amp" ]; then
    #         print "L0W_Amp" "$value"
    #     else
    #         metric=$(echo "L0${target[$i]}" | sed 's/\\//g;s/)//g;s/(//g;s/\///g')
    #         # print "$metric" "$value"
    #     fi
    # fi
done

for i in "${!target[@]}";
do
    echo "test"
    value=`cat /tmp/level_compaction_cahe.log `
    #|awk -F: '/'''${target[$i]}'''/{print $2}'`
    #| awk 'NR==2{print}' | awk '{print $1*1}'`
    # if [ -n "$value" ]; then
    #     if [ ${target[$i]} = "W-Amp" ]; then
    #         print "L1W_Amp" "$value"
    #     else
    #         metric=$(echo "L1${target[$i]}" | sed 's/\\//g;s/)//g;s/(//g;s/\///g')
    #         # print "$metric" "$value"
    #     fi
    # fi
done
}

transaction(){
target=("lock_total" "lock_processing" "lock_conflict")
for i in "${!target[@]}";
do
    value=`awk -F: '/'''${target[$i]}'''/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$value" ]; then
        print "${target[$i]}" "$value"
    fi
done
}

sync(){
target=("level" "select_slave_on_working" "select_times" "last_sync_lag" "sync_slave_changed_times")
for i in "${!target[@]}";
do
    value=`awk -F: '/'''${target[$i]}'''/{print $2}' $LOG_FILE|sed "s/\r//"`
    if [ -n "$value" ]; then
        print "${target[$i]}" "$value"
    fi
done

duration=`awk -F: '/'''"server_no_write_duration"'''/{print $2}' $LOG_FILE|sed "s/\r//"`
if [ -n "$duration" ]; then
    duration_arr=($duration)
    print "server_no_write_duration" "${duration_arr[0]}"
fi
}

# --------------------- ror ----------------------
ror_keys() {
    # hot, cold, meta key_count
    dbHotCount=`awk -F: '/^db0:/{print $2}' $LOG_FILE | awk -F, '{print $1}' | awk -F= '{print $2}'`
    if [ -n "$dbHotCount" ]; then
        print "hot_key_count" "$dbHotCount"
    else
        print "hot_key_count" "0"
    fi

    dbEvictsCount=`awk -F: '/^db0:/{print $2}' $LOG_FILE | awk -F, '{print $2}' | awk -F= '{print $2}'`
    if [ -n "$dbEvictsCount" ]; then
        print "cold_key_count" "$dbEvictsCount"
    else
        print "cold_key_count" "0"
    fi

    dbMetaCount=`awk -F: '/^db0:/{print $2}' $LOG_FILE | awk -F, '{print $3}' | awk -F= '{print $2}'`
    if [ -n "$dbMetaCount" ]; then
        print "meta_key_count" "$dbMetaCount"
    else
        print "meta_key_count" "0"
    fi

    # swap_swapin_memory_hit_perc, swap_swapin_keyspace_hit_perc
    swap_swapin_attempt_count=`awk -F: '/^swap_swapin_attempt_count:/{printf("%d",$2)}' $LOG_FILE`
    swap_swapin_not_found_count=`awk -F: '/^swap_swapin_not_found_count:/{printf("%d",$2)}' $LOG_FILE`
    swap_swapin_no_io_count=`awk -F: '/^swap_swapin_no_io_count:/{printf("%d",$2)}' $LOG_FILE`
    if [ -n "$swap_swapin_attempt_count" ] && [ -n "$swap_swapin_not_found_count" ] && [ -n "$swap_swapin_no_io_count" ]; then
        if [ "$swap_swapin_attempt_count" == "0" ]; then
            print "swap_swapin_memory_hit_perc" "0"
            print "swap_swapin_keyspace_hit_perc" "0"
        else
            print "swap_swapin_memory_hit_perc" "$(printf "%.2f" `echo "scale=2; ${swap_swapin_no_io_count}*100/${swap_swapin_attempt_count}"|bc`)"
            print "swap_swapin_keyspace_hit_perc" "$(printf "%.2f" `echo "scale=2; (${swap_swapin_attempt_count}-${swap_swapin_not_found_count})*100/${swap_swapin_attempt_count}"|bc`)"
        fi
    fi
}

rectified()
{
fragRatio=`awk -F: '/^swap_rectified_frag_ratio:/{print $2}' $LOG_FILE | sed "s/\r//"`
if [ ! -z "$fragRatio" ]; then
    print "swap_rectified_frag_ratio" "$fragRatio"
fi
fragBytes=`awk -F: '/^swap_rectified_frag_bytes:/{print $2}' $LOG_FILE | sed "s/\r//"`
if [ ! -z "$fragBytes" ]; then
    print "swap_rectified_frag_bytes" "$fragBytes"
fi
}

swap_metric_process() {
    swap_metric_name=$1

    ops_value=`cat $LOG_FILE | grep "^$swap_metric_name:" | awk -F: '{print $2}' | awk -F, '{print $3}' | awk -F= '{print $2}' | sed "s/\r//"`
    bps_value=`cat $LOG_FILE | grep "^$swap_metric_name:" | awk -F: '{print $2}' | awk -F, '{print $4}' | awk -F= '{print $2}' | sed "s/\r//"`

    print "$swap_metric_name"_"ops" "$ops_value"
    print "$swap_metric_name"_"Bps" "$bps_value"
}

swap(){
swapInprogressCount=`awk -F: '/^swap_inprogress_count:/{print $2}' $LOG_FILE | sed "s/\r//"`
print "swap_inprogress_count" "$swapInprogressCount"

swapInprogressMemory=`awk -F: '/^swap_inprogress_memory:/{print $2}' $LOG_FILE | sed "s/\r//"`
print "swap_inprogress_memory" "$swapInprogressMemory"

swapInprogressEvictCount=`awk -F: '/^swap_inprogress_evict_count:/{print $2}' $LOG_FILE | sed "s/\r//"`
print "swap_inprogress_evict_count" "$swapInprogressEvictCount"

swap_metric_process "swap_IN"
swap_metric_process "swap_OUT"
swap_metric_process "swap_DEL"
swap_metric_process "swap_UTILS"
swap_metric_process "swap_rio_GET"
swap_metric_process "swap_rio_PUT"
swap_metric_process "swap_rio_DEL"
swap_metric_process "swap_rio_WRITE"
swap_metric_process "swap_rio_MULTIGET"
swap_metric_process "swap_rio_SCAN"
swap_metric_process "swap_rio_DELETERANGE"
swap_metric_process "swap_rio_ITERATE"
swap_metric_process "swap_rio_RANGE"
}

swap_compaction_metric_process() {
    swap_compaction_filter_metric_name=$1

    filt_ps_value=`cat $LOG_FILE | grep "^$swap_compaction_filter_metric_name:" | awk -F: '{print $2}' | awk -F, '{print $3}' | awk -F= '{print $2}' | sed "s/\r//"`
    scan_ps_value=`cat $LOG_FILE | grep "^$swap_compaction_filter_metric_name:" | awk -F: '{print $2}' | awk -F, '{print $4}' | awk -F= '{print $2}' | sed "s/\r//"`

    print "$swap_compaction_filter_metric_name"_"filter_ps" "$filt_ps_value"
    print "$swap_compaction_filter_metric_name"_"scan_ps" "$scan_ps_value"
}

swap_compaction_filter() {
    swap_compaction_metric_process swap_compaction_filter_default
    swap_compaction_metric_process swap_compaction_filter_meta
    swap_compaction_metric_process swap_compaction_filter_score
}

swap_scan_expire() {
    # swap_scan_expire_expired_key_per_second
    swap_scan_expire_expired_key_per_second=`awk -F: '/^swap_scan_expire_expired_key_per_second:/{printf("%.2f\n",$2/1024/1024)}' $LOG_FILE`
    if [ -n "$swap_scan_expire_expired_key_per_second" ]; then
        print "swap_scan_expire_expired_key_per_second" "$swap_scan_expire_expired_key_per_second"
    fi
}

#test

check_instance_status
# collect_info_to_log_file

#Tag
PAAS_TYPE=`env | grep PAAS_TYPE | awk -F '=' '{print $2}'` #redis,kvrocks,ror
is_master=$(is_master)
sha1=$(get_sha1)
arch=`arch`
redis_version=$(get_redis_version)
xredis_version=$(get_xredis_version)
kvrocks_version=$(get_kvrocks_version)
swap_version=$(get_swap_version)
rocksdb_version=$(get_rocksdb_version)
monitor_version=$(get_monitor_version)

# collect
# common
# memory
# status
# keys
# connection

# # kvrocks
# if [ "$PAAS_TYPE"x = "kvrocks"x ]; then
#     dbsize
#     cumulativeProperty
#     intervalProperty
#     levelCompaction

#     transaction
#     sync
# fi

# # ror
# if [ "$PAAS_TYPE"x = "ror"x ]; then
    # dbsize
    # cumulativeProperty
    # intervalProperty
    # levelCompaction

    # ror_keys
    # rectified
    # swap
    # swap_compaction_filter
    # swap_scan_expire
# fi



#test 

echo "cache.instantaneous_ops_per_sec,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=8"
echo "cache.hits_rate,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.latest_fork_usec,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.instantaneous_input_Bps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=520.00"
echo "cache.instantaneous_output_Bps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=2690.00"
echo "cache.slowlog,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=66"
echo "cache.lazyfree_pending_objects,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.rdb_bgsave_in_progress,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.loading,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.used_memory,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=72.16"
echo "cache.maxmemory,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=1792.00"
echo "cache.used_memory_percent,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=4.02"
echo "cache.used_memory_rss,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=83.21"
echo "cache.used_memory_overhead,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=74.00"
echo "cache.swap_mem_rocksdb,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=1.93"
echo "cache.process_status,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=1"
echo "cache.master_link_status,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=1"
echo "cache.rdb_last_bgsave_status,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=1"
echo "cache.key_count,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.expires_key_count,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.evicted_key_count,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.connected_clients,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=14"
echo "cache.blocked_clients,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.rejected_connections,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.used_db_size,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.00"
echo "cache.max_db_size,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=40.00"
echo "cache.used_db_size_percent,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.used_disk_size,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=12230656"
echo "cache.max_disk_size,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=214748364800"
echo "cache.used_disk_size_percent,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.00"
echo "cache.cumulative_writes_numK,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.003"
echo "cache.cumulative_writes_keysK,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.003"
echo "cache.cumulative_writes_commit_groupK,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.003"
echo "cache.cumulative_writes_per_commit_group,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=1.0"
echo "cache.cumulative_writes_ingest_sizeGB,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.00"
echo "cache.cumulative_writes_ingest_speedMBs,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.00"
echo "cache.cumulative_wal_writesK,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.000"
echo "cache.cumulative_wal_syncs,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.cumulative_wal_writes_per_sync,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.00"
echo "cache.cumulative_wal_writen_sizeGB,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.00"
echo "cache.cumulative_wal_writen_speedMBs,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.00"
echo "cache.cumulative_stall_percent,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.0"
echo "cache.cumulative_stall_time,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.interval_writes_numK,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.000"
echo "cache.interval_writes_keysK,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.000"
echo "cache.interval_writes_commit_groupK,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.000"
echo "cache.interval_writes_per_commit_group,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.0"
echo "cache.interval_writes_ingest_sizeMB,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.00"
echo "cache.interval_writes_ingest_speedMBs,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.00"
echo "cache.interval_wal_writesK,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.000"
echo "cache.interval_wal_syncs,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.interval_wal_writes_per_sync,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.00"
echo "cache.interval_wal_writen_speedMBs,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.00"
echo "cache.interval_stall_percent,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.0"
echo "cache.interval_stall_time,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0TotalFiles,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0CompactingFiles,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0SizeGB,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0Score,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0ReadGB,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0RnGB,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0Rnp1GB,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0WriteGB,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0WnewGB,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0MovedGB,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0W_Amp,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0RdMBs,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0WrMBs,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0Compsec,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0CompMergeCPUsec,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0Compcnt,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0Avgsec,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0KeyInK,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L0KeyDropK,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1TotalFiles,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1CompactingFiles,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1SizeGB,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1Score,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1ReadGB,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1RnGB,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1Rnp1GB,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1WriteGB,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1WnewGB,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1MovedGB,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1W_Amp,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1RdMBs,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1WrMBs,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1Compsec,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1CompMergeCPUsec,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1Compcnt,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1Avgsec,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1KeyInK,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.L1KeyDropK,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.hot_key_count,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.cold_key_count,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.meta_key_count,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_swapin_memory_hit_perc,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_swapin_keyspace_hit_perc,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_rectified_frag_ratio,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=1.12"
echo "cache.swap_rectified_frag_bytes,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=9623766"
echo "cache.swap_inprogress_count,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_inprogress_memory,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_inprogress_evict_count,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_IN_ops,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_IN_Bps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_OUT_ops,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_OUT_Bps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_DEL_ops,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_DEL_Bps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_UTILS_ops,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_UTILS_Bps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=305"
echo "cache.swap_rio_GET_ops,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_rio_GET_Bps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_rio_PUT_ops,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_rio_PUT_Bps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_rio_DEL_ops,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_rio_DEL_Bps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_rio_WRITE_ops,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_rio_WRITE_Bps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_rio_MULTIGET_ops,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_rio_MULTIGET_Bps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_rio_SCAN_ops,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_rio_SCAN_Bps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_rio_DELETERANGE_ops,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_rio_DELETERANGE_Bps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_compaction_filter_default_filter_ps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_compaction_filter_default_scan_ps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_compaction_filter_meta_filter_ps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_compaction_filter_meta_scan_ps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_compaction_filter_score_filter_ps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_compaction_filter_score_scan_ps,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0"
echo "cache.swap_scan_expire_expired_key_per_second,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=0.00"