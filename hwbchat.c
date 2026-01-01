/*
  hwbchat.c
  - Enforces running from /opt/cataised/hbwchat
  - Logs to /opt/cataised/hwbchat.log
  - Exits if /tmp/hwbchat.lock exists
  - Collects local system info and logs it
  - Simple interactive loop to "refresh" report or "quit"

  Build:
    gcc -O2 -Wall -Wextra -o hwbchat hwbchat.c

  Run (from /opt/cataised/hbwchat):
    ./hwbchat
*/

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>
#include <limits.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <sys/types.h>
#include <dirent.h>
#include <fcntl.h>

static const char *REQUIRED_DIR = "/opt/cataised/hbwchat";
static const char *LOG_PATH     = "/opt/cataised/hwbchat.log";
static const char *LOCK_PATH    = "/tmp/hwbchat.lock";

static FILE *g_log = NULL;

static void log_line(const char *fmt, ...) {
    if (!g_log) return;

    time_t now = time(NULL);
    struct tm tm_now;
    localtime_r(&now, &tm_now);

    char ts[64];
    strftime(ts, sizeof(ts), "%Y-%m-%d %H:%M:%S", &tm_now);

    fprintf(g_log, "[%s] ", ts);

    va_list ap;
    va_start(ap, fmt);
    vfprintf(g_log, fmt, ap);
    va_end(ap);

    fputc('\n', g_log);
    fflush(g_log);
}

static int file_exists(const char *path) {
    struct stat st;
    return (stat(path, &st) == 0);
}

static int ensure_running_from_required_dir(void) {
    char cwd[PATH_MAX];
    if (!getcwd(cwd, sizeof(cwd))) {
        log_line("ERROR: getcwd failed: %s", strerror(errno));
        return 0;
    }

    if (strcmp(cwd, REQUIRED_DIR) == 0) {
        log_line("OK: Running from required directory: %s", cwd);
        return 1;
    }

    log_line("FAIL: Not running from required directory. CWD=%s REQUIRED=%s", cwd, REQUIRED_DIR);
    return 0;
}

static void log_uptime(void) {
    FILE *f = fopen("/proc/uptime", "r");
    if (!f) {
        log_line("ERROR: fopen /proc/uptime: %s", strerror(errno));
        return;
    }
    double up = 0.0, idle = 0.0;
    if (fscanf(f, "%lf %lf", &up, &idle) == 2) {
        log_line("Uptime: %.0f seconds (%.2f hours)", up, up / 3600.0);
    } else {
        log_line("ERROR: failed to parse /proc/uptime");
    }
    fclose(f);
}

static void log_disk_space_root(void) {
    struct statvfs vfs;
    if (statvfs("/", &vfs) != 0) {
        log_line("ERROR: statvfs('/'): %s", strerror(errno));
        return;
    }

    unsigned long long block = (unsigned long long)vfs.f_frsize;
    unsigned long long total = block * (unsigned long long)vfs.f_blocks;
    unsigned long long freeb = block * (unsigned long long)vfs.f_bfree;
    unsigned long long avail = block * (unsigned long long)vfs.f_bavail;
    unsigned long long used  = total - freeb;

    log_line("Disk (/): total=%llu MB used=%llu MB avail=%llu MB",
             total / (1024ULL*1024ULL),
             used  / (1024ULL*1024ULL),
             avail / (1024ULL*1024ULL));
}

static void log_meminfo(void) {
    FILE *f = fopen("/proc/meminfo", "r");
    if (!f) {
        log_line("ERROR: fopen /proc/meminfo: %s", strerror(errno));
        return;
    }

    // Grab a few key lines.
    char line[256];
    unsigned long memTotal=0, memFree=0, memAvail=0, swapTotal=0, swapFree=0;

    while (fgets(line, sizeof(line), f)) {
        if (sscanf(line, "MemTotal: %lu kB", &memTotal) == 1) continue;
        if (sscanf(line, "MemFree: %lu kB", &memFree) == 1) continue;
        if (sscanf(line, "MemAvailable: %lu kB", &memAvail) == 1) continue;
        if (sscanf(line, "SwapTotal: %lu kB", &swapTotal) == 1) continue;
        if (sscanf(line, "SwapFree: %lu kB", &swapFree) == 1) continue;
    }

    fclose(f);

    log_line("Memory: MemTotal=%lu MB MemAvailable=%lu MB MemFree=%lu MB",
             memTotal/1024, memAvail/1024, memFree/1024);
    log_line("Swap:   SwapTotal=%lu MB SwapFree=%lu MB",
             swapTotal/1024, swapFree/1024);
}

static void log_os_and_cpu(void) {
    // OS
    FILE *f = fopen("/etc/os-release", "r");
    if (f) {
        char line[256];
        while (fgets(line, sizeof(line), f)) {
            if (strncmp(line, "PRETTY_NAME=", 12) == 0) {
                // Strip newline and optional quotes
                line[strcspn(line, "\r\n")] = 0;
                log_line("OS: %s", line + 12);
                break;
            }
        }
        fclose(f);
    } else {
        log_line("WARN: unable to read /etc/os-release: %s", strerror(errno));
    }

    // CPU model
    f = fopen("/proc/cpuinfo", "r");
    if (f) {
        char line[256];
        while (fgets(line, sizeof(line), f)) {
            if (strncmp(line, "model name", 10) == 0 || strncmp(line, "Hardware", 8) == 0) {
                line[strcspn(line, "\r\n")] = 0;
                log_line("CPU: %s", line);
                // log first match only
                break;
            }
        }
        fclose(f);
    }
}

static void log_process_snapshot_limited(int max_entries) {
    DIR *d = opendir("/proc");
    if (!d) {
        log_line("ERROR: opendir /proc: %s", strerror(errno));
        return;
    }

    log_line("Processes (snapshot, first %d):", max_entries);

    struct dirent *de;
    int count = 0;

    while ((de = readdir(d)) != NULL && count < max_entries) {
        // numeric dir = pid
        char *end = NULL;
        long pid = strtol(de->d_name, &end, 10);
        if (!end || *end != '\0') continue;
        if (pid <= 0) continue;

        char path[PATH_MAX];
        snprintf(path, sizeof(path), "/proc/%ld/comm", pid);

        FILE *f = fopen(path, "r");
        if (!f) continue;

        char comm[128] = {0};
        if (fgets(comm, sizeof(comm), f)) {
            comm[strcspn(comm, "\r\n")] = 0;
            log_line("  PID=%ld COMM=%s", pid, comm);
            count++;
        }
        fclose(f);
    }

    closedir(d);
    if (count == 0) log_line("  (no processes listed?)");
}

static void log_network_connections_hint(void) {
    // Without running netstat/ss, we can at least note where the kernel keeps these.
    // You can extend this to parse /proc/net/tcp, /proc/net/udp, etc.
    log_line("Network: see /proc/net/tcp /proc/net/udp /proc/net/tcp6 /proc/net/udp6 for connections (not fully parsed here).");
}

static int check_connectivity_basic(void) {
    // "Can it connect to sites like google" without making a covert agent:
    // We'll do a simple DNS + TCP attempt via system ping as a basic, visible check.
    // If you don't want system(), remove this and rely on other monitoring.
    int rc = system("ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1");
    if (rc == 0) {
        log_line("Connectivity: ping to 8.8.8.8 OK");
        return 1;
    } else {
        log_line("Connectivity: ping to 8.8.8.8 FAILED (rc=%d)", rc);
        return 0;
    }
}

static void write_report_once(void) {
    log_line("---- BEGIN REPORT ----");
    log_os_and_cpu();
    log_uptime();
    log_disk_space_root();
    log_meminfo();
    log_process_snapshot_limited(20);
    log_network_connections_hint();
    (void)check_connectivity_basic();
    log_line("---- END REPORT ----");
}

int main(void) {
    g_log = fopen(LOG_PATH, "a");
    if (!g_log) {
        fprintf(stderr, "ERROR: cannot open log file %s: %s\n", LOG_PATH, strerror(errno));
        return 1;
    }

    log_line("Program start.");

    if (!ensure_running_from_required_dir()) {
        log_line("Exiting because CWD is not required directory.");
        fclose(g_log);
        return 1;
    }

    if (file_exists(LOCK_PATH)) {
        log_line("Lock file exists (%s). Exiting.", LOCK_PATH);
        fclose(g_log);
        return 1;
    }

    // Initial report
    write_report_once();

    // Simple menu loop (local only)
    for (;;) {
        log_line("Menu: (r)efresh report, (q)uit");
        printf("hwbchat> [r/q]: ");
        fflush(stdout);

        int c = getchar();
        if (c == EOF) break;

        // consume rest of line
        int d;
        while ((d = getchar()) != '\n' && d != EOF) {}

        if (c == 'q' || c == 'Q') {
            log_line("User requested quit.");
            break;
        } else if (c == 'r' || c == 'R') {
            log_line("User requested refresh report.");
            write_report_once();
        } else {
            log_line("Unknown command: %c", c);
        }
    }

    log_line("Program exit.");
    fclose(g_log);
    return 0;
}
