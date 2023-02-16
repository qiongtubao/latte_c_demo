package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os/exec"
	"regexp"
	"strconv"

	"github.com/go-redis/redis/v8"
)

type RedisType int

const (
	Redis RedisType = iota
	Ror
	KvRocks
)

type RedisInfo struct {
	redis_type     RedisType
	info_content   string
	port           int
	arch           string
	is_master      int
	redis_version  string
	xredis_version string
	sha1           string
	client         *redis.Client
	client_ctx     context.Context
}

func (r RedisInfo) get_info_attribute(key string) (string, error) {
	reg := regexp.MustCompile(`\n` + key + `:(?s:(.*?))\r`)
	if reg == nil {
		return "", errors.New(fmt.Sprint("MustCompile info attribute (%s) err", key))
	}
	result := reg.FindAllStringSubmatch(r.info_content, -1)
	if len(result) != 1 || len(result[0]) != 2 {
		return "", errors.New(fmt.Sprint("info find (%s) attribute err)", key))
	}
	return result[0][1], nil
}

func (r RedisInfo) get_int_info_attribute(key string) (int64, error) {
	str_value, err := r.get_info_attribute(key)
	if err != nil {
		return 0, err
	}
	value, err := strconv.ParseInt(str_value, 10, 64)
	if err != nil {
		log.Println("info %s=%s parse int fail", key, value)
	}
	return value, err
}

func (r RedisInfo) get_float_info_attribute(key string) (float64, error) {
	str_value, err := r.get_info_attribute(key)
	if err != nil {
		return 0, err
	}
	value, err := strconv.ParseFloat(str_value, 64)
	if err != nil {
		log.Println("info %s=%s parse float fail", key, value)
	}
	return value, err
}

func (r *RedisInfo) init_is_master() error {

	role_info, err := r.get_info_attribute("role")
	if err != nil {
		return err
	}
	if role_info == "master" {
		r.is_master = 1
	} else {
		r.is_master = 0
	}
	return nil
}

func (r *RedisInfo) init_sha1() error {
	var sha1 string = ""
	var err error = nil
	switch r.redis_type {
	case KvRocks:
		sha1, err = r.get_info_attribute("git_sha1")
	default:
		sha1, err = r.get_info_attribute("redis_git_sha1")
	}
	if err != nil {
		return err
	}
	r.sha1 = sha1
	return nil

}

func (r *RedisInfo) init_arch() error {
	result, err := exec.Command("arch").Output()
	if err != nil {
		return err
	}
	r.arch = string(result)
	return nil
}

func (r *RedisInfo) init_redis_version() error {
	version, err := r.get_info_attribute("redis_version")
	if err != nil {
		return err
	}
	r.redis_version = version
	return nil
}

func (r *RedisInfo) init_xredis_version() error {
	version, err := r.get_info_attribute("xredis_version")
	if err != nil {
		return err
	}
	r.xredis_version = version
	return nil
}

func (r *RedisInfo) init() (RedisInputer, error) {

	_r := r

	err := _r.init_is_master()
	if err != nil {
		return nil, err
	}
	err = _r.init_sha1()
	if err != nil {
		return nil, err
	}

	err = _r.init_arch()
	if err != nil {
		return nil, err
	}
	err = _r.init_redis_version()
	if err != nil {
		return nil, err
	}

	err = _r.init_xredis_version()
	if err != nil {
		return nil, err
	}
	return r, nil
}

func (r RedisInfo) print(key string, value string) {
	fmt.Printf("cache.%s,port=%d,arch=%s,is_master=%d,sha1=%s,monitor_version=%s,redis_version=%s,xredis_version=%s value=%s\n",
		key,
		r.port,
		r.arch,
		r.is_master,
		r.sha1,
		monitor_version,
		r.redis_version,
		r.xredis_version,
		value,
	)
}
func (r RedisInfo) input_string(self RedisInputer, key string) {
	sec, err := r.get_info_attribute(key)
	if err != nil {
		log.Println(err)
		return
	}
	self.print(key, sec)
}

func (r RedisInfo) input_hits_rate(self RedisInputer) {
	keyspace_hits, err := r.get_int_info_attribute("keyspace_hits")
	if err != nil {
		log.Println(err)
		return
	}
	keyspace_misses, err := r.get_int_info_attribute("keyspace_misses")
	if err != nil {
		log.Println(err)
		return
	}
	if 0 == keyspace_hits && 0 == keyspace_misses {
		r.print("hits_rate", "0")
		return
	}
	self.print("hits_rate", fmt.Sprintf("%.2f", keyspace_hits/(keyspace_hits+keyspace_misses)))

}

func (r RedisInfo) input_floatx(self RedisInputer, key string, printKey string, zoom int, multiple float64) {
	value, err := r.get_float_info_attribute(key)
	if err != nil {
		log.Println(err)
		return
	}
	if zoom > 0 {
		self.print(printKey, fmt.Sprintf("%.2f", value*multiple))
	} else {
		self.print(printKey, fmt.Sprintf("%.2f", value/multiple))
	}

}

func (r RedisInfo) input_slowlog_len(self RedisInputer) {
	res, err := r.client.Do(r.client_ctx, "slowlog", "len").Result()
	if err != nil {
		log.Println(err)
		return
	}
	self.print("slowlog", fmt.Sprintf("%d", res))
}
func (r RedisInfo) input_memory(self RedisInputer) {
	used_memory, err := r.get_float_info_attribute("used_memory")
	if err != nil {
		log.Println(err)
		return
	}
	self.print("used_memory", fmt.Sprintf("%.2f", used_memory/1024/1024))
	maxmemory, err := r.get_float_info_attribute("maxmemory")
	if err != nil {
		log.Println(err)
		return
	}
	self.print("maxmemory", fmt.Sprintf("%.2f", maxmemory/1024/1024))

	self.print("used_memory_percent", fmt.Sprintf("%.2f", used_memory/maxmemory))

	r.input_floatx(self, "used_memory_rss", "used_memory_rss", -1, 1024*1024)
	r.input_floatx(self, "used_memory_overhead", "used_memory_overhead", -1, 1024*1024)
}

func (r RedisInfo) input_string_equal(self RedisInputer, key string, equal_str string) {
	value, err := r.get_info_attribute(key)
	if err != nil {
		log.Println(err)
		return
	}
	if value == equal_str {
		self.print(key, "1")
	} else {
		self.print(key, "0")
	}
}
func (r RedisInfo) input_keys(self RedisInputer) {
	size, err := r.client.DBSize(r.client_ctx).Result()
	if err != nil {
		log.Println(err)
		return
	}
	self.print("key_count", fmt.Sprintf("%d", size))
}

func (r RedisInfo) input(self RedisInputer) {
	// common
	r.input_string(self, "instantaneous_ops_per_sec")
	r.input_hits_rate(self)
	r.input_string(self, "latest_fork_usec")
	r.input_floatx(self, "instantaneous_input_kbps", "instantaneous_input_Bps", 1, 1000)
	r.input_floatx(self, "instantaneous_output_kbps", "instantaneous_output_Bps", 1, 1000)
	r.input_slowlog_len(self)
	r.input_string(self, "lazyfree_pending_objects")
	r.input_string(self, "rdb_bgsave_in_progress")
	r.input_string(self, "loading")
	//memory
	r.input_memory(self)
	//status
	self.print("process_status", "1")
	if r.is_master == 1 {
		self.print("master_link_status", "1")
	} else {
		r.input_string_equal(self, "master_link_status", "up")
	}
	r.input_string_equal(self, "rdb_last_bgsave_status", "ok")
	//keys  区分类型
	r.input_keys(self)
}
