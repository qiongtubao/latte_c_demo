
#include "rocksdb/c.h"
#include <sys/statvfs.h>
#include <stddef.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>

#include <pthread.h>
#include <inttypes.h>
#include <signal.h>
#include <errno.h>
#include <stdarg.h>
#include <limits.h>
#include <math.h>

#define KB 1024
#define MB (1024*KB)

#define ROCKS_DIR_MAX_LEN 512
#define ROCKS_DATA "data.rocks"

#define DATA_CF 0
#define META_CF 1
#define SCORE_CF 2
#define CF_COUNT 3

#define data_cf_name "default"
#define meta_cf_name "meta"
#define score_cf_name "score"
const char *swap_cf_names[CF_COUNT] = {data_cf_name, meta_cf_name, score_cf_name};


void EncodeFixed64(char *buf, uint64_t value) {
  if (BYTE_ORDER == BIG_ENDIAN) {
    memcpy(buf, &value, sizeof(value));
  } else {
    buf[0] = (uint8_t)((value >> 56) & 0xff);
    buf[1] = (uint8_t)((value >> 48) & 0xff);
    buf[2] = (uint8_t)((value >> 40) & 0xff);
    buf[3] = (uint8_t)((value >> 32) & 0xff);
    buf[4] = (uint8_t)((value >> 24) & 0xff);
    buf[5] = (uint8_t)((value >> 16) & 0xff);
    buf[6] = (uint8_t)((value >> 8) & 0xff);
    buf[7] = (uint8_t)(value & 0xff);
  }
}
void PutDouble(char *buf, double value) {
  uint64_t u64;
  memcpy(&u64, &value, sizeof(value));
  uint64_t* ptr = &u64;
  if ((*ptr >> 63) == 1) {
    // signed bit would be zero
    *ptr ^= 0xffffffffffffffff;
  } else {
    // signed bit would be one
    *ptr |= 0x8000000000000000;
  }
  EncodeFixed64(buf,  *ptr);
}


uint32_t DecodeFixed32(const char *ptr) {
  if (BYTE_ORDER == BIG_ENDIAN) {
    uint32_t value;
    memcpy(&value, ptr, sizeof(value));
    return value;
  } else {
    return (((uint32_t)((uint8_t)(ptr[3])))
        | ((uint32_t)((uint8_t)(ptr[2])) << 8)
        | ((uint32_t)((uint8_t)(ptr[1])) << 16)
        | ((uint32_t)((uint8_t)(ptr[0])) << 24));
  }
}
uint64_t DecodeFixed64(const char *ptr) {
  if (BYTE_ORDER == BIG_ENDIAN) {
    uint64_t value;
    memcpy(&value, ptr, sizeof(value));
    return value;
  } else {
    uint64_t hi = DecodeFixed32(ptr);
    uint64_t lo = DecodeFixed32(ptr+4);
    return (hi << 32) | lo;
  }
}
double DecodeDouble(const char *ptr) {
  uint64_t decoded = DecodeFixed64(ptr);
  if ((decoded>>63) == 0) {
    decoded ^= 0xffffffffffffffff;
  } else {
    decoded &= 0x7fffffffffffffff;
  }
  double value;
  memcpy(&value, &decoded, sizeof(value));
  return value;
}
int rmdirRecursive(const char *path) {
	struct dirent *p;
	DIR *d = opendir(path);
	size_t path_len = strlen(path);
	int r = 0;

	if (d == NULL) return -1;

	while (!r && (p=readdir(d))) {
		int r2 = -1;
		char *buf;
		size_t len;
		struct stat statbuf;

		/* Skip the names "." and ".." as we don't want to recurse on them. */
		if (!strcmp(p->d_name, ".") || !strcmp(p->d_name, ".."))
			continue;

		len = path_len + strlen(p->d_name) + 2; 
		buf = malloc(len);

		snprintf(buf, len, "%s/%s", path, p->d_name);
		if (!stat(buf, &statbuf)) {
			if (S_ISDIR(statbuf.st_mode))
				r2 = rmdirRecursive(buf);
			else
				r2 = unlink(buf);
		}

		free(buf);
		r = r2;
	}
	closedir(d);

	if (!r) r = rmdir(path);

	return r;
}

int main() {
    rocksdb_options_t* db_opts = rocksdb_options_create();
    rocksdb_options_set_create_if_missing(db_opts, 1); 
    rocksdb_options_set_create_missing_column_families(db_opts, 1);
    rocksdb_options_set_max_write_buffer_number(db_opts, 6);
    rocksdb_options_optimize_for_point_lookup(db_opts, 1); 

    rocksdb_options_set_min_write_buffer_number_to_merge(db_opts, 2);
    rocksdb_options_set_max_write_buffer_number(db_opts, 6);
    rocksdb_options_set_level0_file_num_compaction_trigger(db_opts, 2);
    rocksdb_options_set_target_file_size_base(db_opts, 32*MB);
    rocksdb_options_set_max_bytes_for_level_base(db_opts, 256*MB);


    rocksdb_readoptions_t* ropts = rocksdb_readoptions_create();
    rocksdb_readoptions_set_verify_checksums(ropts, 0);
    rocksdb_readoptions_set_fill_cache(ropts, 1);

    rocksdb_writeoptions_t* wopts = rocksdb_writeoptions_create();
    rocksdb_writeoptions_disable_WAL(wopts, 1);

    struct stat statbuf;
    if (!stat(ROCKS_DATA, &statbuf) && S_ISDIR(statbuf.st_mode)) {
        /* "data.rocks" folder already exists, remove it on start */
        rmdirRecursive(ROCKS_DATA);
    }
    if (mkdir(ROCKS_DATA, 0755)) {
        return -1;
    }

    char *err = NULL, dir[ROCKS_DIR_MAX_LEN];
    snprintf(dir, ROCKS_DIR_MAX_LEN, "%s/%d", ROCKS_DATA, 0);
    rocksdb_options_t *cf_opts[CF_COUNT];
    rocksdb_block_based_table_options_t *block_opts[CF_COUNT];
    rocksdb_column_family_handle_t *cf_handles[CF_COUNT];
    cf_opts[DATA_CF] = rocksdb_options_create();
    block_opts[DATA_CF] = rocksdb_block_based_options_create();
    rocksdb_block_based_options_set_block_size(block_opts[DATA_CF], 8*KB);
    rocksdb_options_set_block_based_table_factory(cf_opts[DATA_CF], block_opts[DATA_CF]);

    cf_opts[META_CF] = rocksdb_options_create();
    block_opts[META_CF] = rocksdb_block_based_options_create();
    rocksdb_block_based_options_set_block_size(block_opts[META_CF], 8*KB);
    rocksdb_cache_t *cache = rocksdb_cache_create_lru(512*MB);
    rocksdb_block_based_options_set_block_cache(block_opts[META_CF], cache);
    rocksdb_cache_destroy(cache);
    rocksdb_options_set_block_based_table_factory(cf_opts[META_CF], block_opts[META_CF]);

    cf_opts[SCORE_CF] = rocksdb_options_create();
    block_opts[SCORE_CF] = rocksdb_block_based_options_create();
    rocksdb_block_based_options_set_block_size(block_opts[SCORE_CF], 8*KB);
    rocksdb_options_set_block_based_table_factory(cf_opts[SCORE_CF], block_opts[SCORE_CF]);
    char *errs[CF_COUNT] = {NULL};
    rocksdb_t* db = rocksdb_open_column_families(db_opts, dir, CF_COUNT,
            swap_cf_names, (const rocksdb_options_t *const *)cf_opts,
            cf_handles, errs);
    if (errs[0] != NULL || errs[1] != NULL ||  errs[2] != NULL) {
        printf("errs: %s \n %s \n %s \n", errs[0], errs[1], errs[2]);
        return -1;
    }

    double d1 = -1.12345;
    double d2 = 6.124;
    char key[100] = "a";
    
    PutDouble(key + 1, d1);
    key[sizeof(d1) + 2] = '\0';
    char key2[100] = "a";
    PutDouble(key2 + 1, d2);
    key2[sizeof(d2) + 2] = '\0';
    char prefix[100] = "a";
    prefix[1] = '\0';
    
    rocksdb_put_cf(db, wopts, cf_handles[SCORE_CF],  key, sizeof(d1) + 1, "a", 1, &err);
    rocksdb_put_cf(db, wopts, cf_handles[SCORE_CF],  key2, sizeof(d1) + 1, "a", 1, &err);
    
    rocksdb_iterator_t *iter = NULL;
    int numkeys = 0;
    int reversed = 0;
    int minex = 0;
    int maxex = 1;
    double min = -10;
    double max = 10;
    char start[100] = "a";
    PutDouble(start + 1, reversed? max: min);
    start[sizeof(min) + 2] = '\0';

    iter = rocksdb_create_iterator_cf(db, ropts,
            cf_handles[SCORE_CF]);
    rocksdb_iter_seek(iter,start,strlen(start));

    if(reversed && (!rocksdb_iter_valid(iter))) {
        rocksdb_iter_seek_for_prev(iter, start, strlen(start));
    }
    
    for (;rocksdb_iter_valid(iter);reversed?rocksdb_iter_prev(iter): rocksdb_iter_next(iter)) {
        size_t klen, vlen;
        const char *rawkey, *rawval;
        rawkey = rocksdb_iter_key(iter, &klen);
        // if (klen < strlen(prefix))
        //     break;
        double score = DecodeDouble(rawkey + 1);
        if (reversed) {
            if ((minex && score == min) || score < min) break;
            if ((maxex && score == max) || score > max) {
                continue;
            }
        } else {
            if ((minex && score == min) || score < min) {
                continue;
            }
            if ((maxex && score == max) || score > max) break;
        }
        printf("score: %.3f\n",score);
        numkeys++;
    }
    return 1;
}