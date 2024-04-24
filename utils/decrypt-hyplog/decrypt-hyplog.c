// SPDX-License-Identifier:

/* Utility to decrypt a log from a hypervisor.
 * Author: Grigoriy Romanov <grigoriy.romanov@unikie.com>
 */
#include <stdio.h>
#include <fcntl.h>
#include <string.h>

#include <chacha20_simple.h>

#define LOG_SIZE            4096
#define ENTRY_SIZE          64
#define DECRYPTED_LOG_FILE  "hyplog.decryted.dump"

char ramlog[LOG_SIZE];
char ramlog_dec[LOG_SIZE];

/* avoid to use chacha20_setup as the initial state of chacha excpected
 * to be in a log */
static int ctx_from_file(chacha20_ctx *ctx, char *filename)
{
    FILE *ramlogf;
    ramlogf = fopen(filename, "rb");

    if (!ramlogf) {
        fprintf(stderr, "can't open a file: %s\n", filename);
        return -1;
    }

    fread(ramlog, LOG_SIZE, 1, ramlogf);

    /* init chacha state from the log */
    memcpy(ctx->schedule, ramlog, ENTRY_SIZE);

    if (fclose(ramlogf))
        fprintf(stderr, "can't close a file: %s\n", filename);

    return 0;
}

static int save_decrypted_log(void)
{
    FILE *ramlog_dec_f;
    int i;
    ramlog_dec_f = fopen(DECRYPTED_LOG_FILE, "wb");

    if (!ramlog_dec_f) {
        fprintf(stderr, "can't open a file: %s\n", DECRYPTED_LOG_FILE);
        return -1;
    }

    /* TODO: need to have information inside log how many entries are inside */
    for (i = 0; i < 63; i++)
        fprintf(ramlog_dec_f, "%s\n", ramlog_dec + i * ENTRY_SIZE);

    if (fclose(ramlog_dec_f))
        fprintf(stderr, "can't close a file: %s\n", DECRYPTED_LOG_FILE);

    return 0;
}

int main(int argc, char * argv[])
{
    chacha20_ctx ctx;

    if (argc != 2) {
        fprintf(stderr, "Usage: %s <hyplogdump>", argv[0]);
        return -1;
    }

    if (ctx_from_file(&ctx, argv[1])) {
        return -1;
    }

    ctx.available = 0;

    chacha20_decrypt(&ctx,
                    (uint8_t *) (ramlog + ENTRY_SIZE),
                    (uint8_t *) (ramlog_dec), LOG_SIZE - ENTRY_SIZE);

    if(save_decrypted_log())
        return -1;

    return 0;
}
