
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
#define MB (1024*KB)

#define ROCKS_DIR_MAX_LEN 512
#define ROCKS_DATA "data.rocks"

#define DATA_CF 0
#define META_CF 1
#define SCORE_CF 2
#define CF_COUNT 3

#define data_cf_name "data"
#define meta_cf_name "meta"
#define score_cf_name "score"
const char *swap_cf_names[CF_COUNT] = {data_cf_name, meta_cf_name, score_cf_name};

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
    if (errs[0] != NULL || errs[1] != NULL) {
        return -1;
    }


    return 1;
}