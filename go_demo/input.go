package main

import (
	"errors"
	"fmt"
	"log"
	"os"
	"regexp"
	"strconv"
)

// "go-redis"

type Redis struct {
	port           int
	arch           string
	is_master      int
	redis_version  string
	xredis_version string
	sha1           string
}

func out(self Redis, key string) {

}

func unuse(s string) {

}

func dbsize(content string) error {

	reg := regexp.MustCompile(`used_db_size:(?s:(.*?))\r`)
	if reg == nil {
		return errors.New("MustCompile err")
	}

	result := reg.FindAllStringSubmatch(content, -1)
	if len(result) != 1 || len(result[0]) != 2 {
		return errors.New("content err")
	}

	dbsize, err := strconv.ParseFloat(result[0][1], 32)
	if err != nil {
		log.Fatal(err)
	}
	// fmt.Printf("%.2f\n", dbsize/1024/1024/1024)
	res := fmt.Sprintf("%.2f", dbsize/1024/1024/1024)
	unuse(res)
	// fmt.Println(res)
	return nil
}

func main() {
	// rdb := redis.NewClient(&redis.Options{
	// 	Addr:     "localhost:6379",
	// 	Password: "", // 密码
	// 	DB:       0,  // 数据库
	// 	PoolSize: 2,  // 连接池大小
	// })
	// fmt.Printf("cache.instantaneous_ops_per_sec,port=6379,arch=aarch64,is_master=0,sha1=bd22d463,monitor_version=1.0.1,redis_version=6.2.6,xredis_version=2.0.1,swap_version=1.0.4,rocksdb_version=7.7.3 value=8\n")
	// content, err := os.ReadFile("hickwall_cache.log")
	content, err := os.ReadFile("/tmp/hickwall_cache.log")
	if err != nil {
		log.Fatal(err)
	}
	file_content := string(content)
	// fmt.Println(file_content)
	for i := 0; i < 100; i++ {
		dbsize(file_content)
	}
}
