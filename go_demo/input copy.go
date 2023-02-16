package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/go-redis/redis/v8"
)

func initLog() {
	file := "./monitor.log"
	os.Remove(file)
	logFile, err := os.OpenFile(file, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0766)
	if err != nil {
		panic(err)
	}
	log.SetOutput(logFile) // 将文件设置为log输出的文件
	log.SetPrefix("[log]")
	log.SetFlags(log.LstdFlags | log.Lshortfile | log.LUTC)
	return
}

type RedisInputer interface {
	input(RedisInputer)
	print(string, string)
}

type KvrocksInfo struct {
	RedisInfo
	kvrocks_version string
}

func (r KvrocksInfo) print(key string, value string) {
	fmt.Printf("")
}

func (r *KvrocksInfo) init() (RedisInputer, error) {
	_, err := (&r.RedisInfo).init()
	if err != nil {
		return nil, err
	}
	return r, nil
}

func (r KvrocksInfo) input(self RedisInputer) {

}

const monitor_version string = "1.0.1"

func main() {
	initLog()
	port := 6379
	c := redis.NewClient(&redis.Options{
		Addr:     "localhost:6379",
		Password: "", // 密码
		DB:       0,  // 数据库
		PoolSize: 2,  // 连接池大小
	})
	// fmt.Printf("cache.instantaneous_ops_per_sec,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=8\n")
	// content, err := os.ReadFile("hickwall_cache.log")
	// content, err := os.ReadFile("/tmp/hickwall_cache.log")
	ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
	defer cancel()
	content, err := c.Info(ctx, "all").Result()
	if err != nil {
		log.Fatal(err)
		return
	}
	info_content := string(content)
	// fmt.Println(info_content)
	var redis_info RedisInputer = nil
	//env
	// docker_type := os.Getenv("PAAS_TYPE")
	docker_type := "ror"
	switch docker_type {
	case "ror":
		redis_info, err = (&RorRedisInfo{
			RedisInfo: RedisInfo{
				redis_type:     Ror,
				port:           port,
				info_content:   info_content,
				xredis_version: "unknown",
				redis_version:  "unknown",
				client:         c,
				client_ctx:     ctx,
			},
			swap_version:    "unknown",
			rocksdb_version: "unknown",
		}).init()
	case "kvrocks":
		redis_info, err = (&KvrocksInfo{
			RedisInfo: RedisInfo{
				redis_type:     KvRocks,
				port:           port,
				info_content:   info_content,
				xredis_version: "unknown",
				redis_version:  "unknown",
				client:         c,
				client_ctx:     ctx,
			},
			kvrocks_version: "unknown",
		}).init()
	default:
		// redis
		redis_info, err = (&RedisInfo{
			redis_type:     Redis,
			port:           port,
			info_content:   info_content,
			xredis_version: "unknown",
			redis_version:  "unknown",
			client:         c,
			client_ctx:     ctx,
		}).init()
	}
	if err != nil {
		log.Fatal(err)
		return
	}
	redis_info.input(redis_info)
	// err = dbsize(file_content)
	// if err != nil {
	// 	log.Fatal(err)
	// }
}
