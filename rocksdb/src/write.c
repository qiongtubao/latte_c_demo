

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

#define KB 1024
#define MB (1024*1024)

#define ROCKS_DIR_MAX_LEN 512
#define ROCKS_DATA "data.rocks"

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
/* Return the UNIX time in microseconds */
long long ustime(void) {
    struct timeval tv;
    long long ust;

    gettimeofday(&tv, NULL);
    ust = ((long long)tv.tv_sec)*1000000;
    ust += tv.tv_usec;
    return ust;
}


/* Return the number of digits of 'v' when converted to string in radix 10.
 * See ll2string() for more information. */
uint32_t digits10(uint64_t v) {
    if (v < 10) return 1;
    if (v < 100) return 2;
    if (v < 1000) return 3;
    if (v < 1000000000000UL) {
        if (v < 100000000UL) {
            if (v < 1000000) {
                if (v < 10000) return 4;
                return 5 + (v >= 100000);
            }
            return 7 + (v >= 10000000UL);
        }
        if (v < 10000000000UL) {
            return 9 + (v >= 1000000000UL);
        }
        return 11 + (v >= 100000000000UL);
    }
    return 12 + digits10(v / 1000000000000UL);
}

int ll2string(char *dst, size_t dstlen, long long svalue) {
    static const char digits[201] =
        "0001020304050607080910111213141516171819"
        "2021222324252627282930313233343536373839"
        "4041424344454647484950515253545556575859"
        "6061626364656667686970717273747576777879"
        "8081828384858687888990919293949596979899";
    int negative;
    unsigned long long value;

    /* The main loop works with 64bit unsigned integers for simplicity, so
     * we convert the number here and remember if it is negative. */
    if (svalue < 0) {
        if (svalue != LLONG_MIN) {
            value = -svalue;
        } else {
            value = ((unsigned long long) LLONG_MAX)+1;
        }
        negative = 1;
    } else {
        value = svalue;
        negative = 0;
    }

    /* Check length. */
    uint32_t const length = digits10(value)+negative;
    if (length >= dstlen) return 0;

    /* Null term. */
    uint32_t next = length;
    dst[next] = '\0';
    next--;
    while (value >= 100) {
        int const i = (value % 100) * 2;
        value /= 100;
        dst[next] = digits[i + 1];
        dst[next - 1] = digits[i];
        next -= 2;
    }

    /* Handle last 1-2 digits. */
    if (value < 10) {
        dst[next] = '0' + (uint32_t) value;
    } else {
        int i = (uint32_t) value * 2;
        dst[next] = digits[i + 1];
        dst[next - 1] = digits[i];
    }

    /* Add sign. */
    if (negative) dst[0] = '-';
    return length;
}



void *writeProcess(void *arg) {
    rocksdb_t* db = (rocksdb_t*) arg;
    long long start_time = ustime();
    long long exec_count = 0;
    long long exec_fail_count = 0;
    rocksdb_writeoptions_t* wopts = rocksdb_writeoptions_create();
    rocksdb_writeoptions_disable_WAL(wopts, 1);
    char keybuf[100];
    long long key = 0;
    char valuebuf[1001] = 
        "0001020304050607080910111213141516171819"
        "2021222324252627282930313233343536373839"
        "4041424344454647484950515253545556575859"
        "6061626364656667686970717273747576777879"
        "8081828384858687888990919293949596979899"
        "0001020304050607080910111213141516171819"
        "2021222324252627282930313233343536373839"
        "4041424344454647484950515253545556575859"
        "6061626364656667686970717273747576777879"
        "8081828384858687888990919293949596979899"
        "0001020304050607080910111213141516171819"
        "2021222324252627282930313233343536373839"
        "4041424344454647484950515253545556575859"
        "6061626364656667686970717273747576777879"
        "8081828384858687888990919293949596979899"
        "0001020304050607080910111213141516171819"
        "2021222324252627282930313233343536373839"
        "4041424344454647484950515253545556575859"
        "6061626364656667686970717273747576777879"
        "8081828384858687888990919293949596979899"
        "0001020304050607080910111213141516171819"
        "2021222324252627282930313233343536373839"
        "4041424344454647484950515253545556575859"
        "6061626364656667686970717273747576777879"
        "8081828384858687888990919293949596979899";

    while(1) {
        char *err = NULL;
        int keylen =ll2string(keybuf, 100, key++);
        if(keylen > 0) {
            rocksdb_put(db, wopts, keybuf, keylen, valuebuf, 1000, &err);
            if (err != NULL) {
                printf("[rocks] do rocksdb write failed: %s", err);
                exec_fail_count++;
            } else {
                exec_count++;
            }
        } else{
            exec_fail_count++;
        }

        
        long long now = ustime() ;
        long long used = now - start_time;
        if (used >= 1000000) {
            printf("[write]%lld/s\n", exec_count*1000000/used);
            exec_count = 0;
            start_time = now;
        }
    }
}

void *compactProcess(void *arg)  {
    rocksdb_t* db = (rocksdb_t*) arg;
    while(1) {
        rocksdb_compact_range(db, NULL, 0, NULL, 0);
        sleep(100);
    }
}

int main() {
    // init options
    rocksdb_options_t* db_opts = rocksdb_options_create();
    rocksdb_options_set_max_write_buffer_number(db_opts, 6);
    rocksdb_options_set_create_if_missing(db_opts, 1); 
    const char *default_cf_name = "default";

    struct rocksdb_block_based_table_options_t *block_opts = rocksdb_block_based_options_create();
    rocksdb_block_based_options_set_block_size(block_opts, 8*KB);
    struct rocksdb_cache_t* block_cache = rocksdb_cache_create_lru(1*MB);

    rocksdb_block_based_options_set_block_cache(block_opts, block_cache);
    rocksdb_block_based_options_set_cache_index_and_filter_blocks(block_opts, 0);
    rocksdb_options_set_block_based_table_factory(db_opts, block_opts);

    rocksdb_options_optimize_for_point_lookup(db_opts, 1);

    rocksdb_options_set_min_write_buffer_number_to_merge(db_opts, 2);
    rocksdb_options_set_max_write_buffer_number(db_opts, 6);
    rocksdb_options_set_level0_file_num_compaction_trigger(db_opts, 2);
    rocksdb_options_set_target_file_size_base(db_opts, 32*MB);
    rocksdb_options_set_max_bytes_for_level_base(db_opts, 256*MB);

    rocksdb_options_set_max_background_compactions(db_opts, 4); /* default 1 */
    rocksdb_options_compaction_readahead_size(db_opts, 2*1024*1024); /* default 0 */
    rocksdb_options_set_optimize_filters_for_hits(db_opts, 1); /* default false */

    rocksdb_options_set_compression(db_opts, rocksdb_no_compression);


    struct stat statbuf;
    if (!stat(ROCKS_DATA, &statbuf) && S_ISDIR(statbuf.st_mode)) {
        /* "data.rocks" folder already exists, remove it on start */
        rmdirRecursive(ROCKS_DATA);
    }
    if (mkdir(ROCKS_DATA, 0755)) {
        printf("[ROCKS] mkdir %s failed: %s\n",
                ROCKS_DATA, strerror(errno));
        return -1;
    }
    char *err = NULL, dir[ROCKS_DIR_MAX_LEN];
    snprintf(dir, ROCKS_DIR_MAX_LEN, "%s/%d", ROCKS_DATA, 0);
    rocksdb_options_t *cf_opts[1];
    cf_opts[0] = db_opts;
    rocksdb_column_family_handle_t* default_cf;
    rocksdb_t* db = rocksdb_open_column_families(db_opts, dir, 1,
            &default_cf_name, (const rocksdb_options_t *const *)cf_opts,
            &default_cf, &err);
    if (err != NULL) {
        printf("[ROCKS] rocksdb open failed: %s\n", err);
        return -1;
    }

    //start write thread
    pthread_attr_t write_attr;
    pthread_t write_t;
    size_t write_stacksize;

    pthread_attr_init(&write_attr);
    pthread_attr_getstacksize(&write_attr,&write_stacksize);
    if (!write_stacksize) write_stacksize = 1;
    while (write_stacksize < 1024 * 1024 * 4) write_stacksize *= 2;
    pthread_attr_setstacksize(&write_attr, write_stacksize);
    if (pthread_create(&write_t, &write_attr, writeProcess, db) != 0) {
        printf("Fatal: Can't initialize Background Jobs.\n");
        return -1;
    }

    // pthread_attr_t compact_attr;
    // pthread_t compact_t;
    // size_t compact_stacksize;

    // pthread_attr_init(&compact_attr);
    // pthread_attr_getstacksize(&compact_attr,&compact_stacksize);
    // if (!compact_stacksize) compact_stacksize = 1;
    // while (compact_stacksize < 1024 * 1024 * 4) compact_stacksize *= 2;
    // pthread_attr_setstacksize(&compact_attr, compact_stacksize);
    // if (pthread_create(&compact_t, &compact_attr, compactProcess, db) != 0) {
    //     printf("Fatal: Can't initialize Background Jobs.\n");
    //     return -1;
    // }
    while(1) {
        long long start_time = ustime();
        printf("[compact] start %lldus\n", start_time);
        rocksdb_compact_range(db, NULL, 0, NULL, 0);
        long long end_time = ustime();
        printf("[compact] start %lldus, used %llds\n", end_time, (end_time-start_time)/1000000);
        sleep(100);
    }
    
    return 1;
}