package main

import "fmt"

type RorRedisInfo struct {
	RedisInfo
	swap_version    string
	rocksdb_version string
}

func (r RorRedisInfo) print(key string, value string) {
	fmt.Printf("cache.%s,port=%d,arch=%s,is_master=%d,sha1=%s,monitor_version=%s,redis_version=%s,xredis_version=%s,swap_version=%s,rocksdb_version=%s value=%s\n",
		key,
		r.RedisInfo.port,
		r.RedisInfo.arch,
		r.RedisInfo.is_master,
		r.RedisInfo.sha1,
		monitor_version,
		r.RedisInfo.redis_version,
		r.RedisInfo.xredis_version,
		r.swap_version,
		r.rocksdb_version,
		value,
	)
}
func (r *RorRedisInfo) init_swap_version() error {
	version, err := r.get_info_attribute("swap_version")
	if err != nil {
		return err
	}
	r.swap_version = version
	return nil
}

func (r *RorRedisInfo) init_rocksdb_version() error {
	version, err := r.get_info_attribute("rocksdb_version")
	if err != nil {
		return err
	}
	r.rocksdb_version = version
	return nil
}
func (r *RorRedisInfo) init() (RedisInputer, error) {
	_, err := (&r.RedisInfo).init()
	if err != nil {
		return nil, err
	}
	err = r.init_swap_version()
	if err != nil {
		return nil, err
	}
	err = r.init_rocksdb_version()
	if err != nil {
		return nil, err
	}
	return r, nil
}

func (r RorRedisInfo) input(self RedisInputer) {
	r.RedisInfo.input(self)
}
