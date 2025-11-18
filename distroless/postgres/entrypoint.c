#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <dirent.h>
#include <string.h>
#include <errno.h>

static int is_sql_file(const char *name) {
    size_t len = strlen(name);
    return (len > 4 && strcmp(name + len - 4, ".sql") == 0);
}

static int is_regular_file(const char *path) {
    struct stat st;
    return (stat(path, &st) == 0 && S_ISREG(st.st_mode));
}

static int file_exists(const char *path) {
    struct stat st;
    return stat(path, &st) == 0;
}

static void run_initdb(const char *pgdata) {
    fprintf(stderr, "[entrypoint] Running initdb...\n");

    pid_t pid = fork();
    if (pid < 0) {
        perror("[entrypoint] fork() for initdb failed");
        exit(1);
    }

    if (pid == 0) {
        // child
        execlp("initdb",
               "initdb",
               "-D", pgdata,
               "--locale=en_US.utf8",
               NULL);

        perror("[entrypoint] exec initdb failed");
        exit(1);
    }

    // parent
    int status;
    waitpid(pid, &status, 0);

    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
        fprintf(stderr, "[entrypoint] initdb failed with status %d\n", status);
        exit(1);
    }
}

static void run_sql_files(const char *pgdata) {
    DIR *d = opendir("/initdb");
    if (!d) {
        if (errno == ENOENT)
            return;
        perror("[entrypoint] opendir /initdb failed");
        exit(1);
    }

    struct dirent *ent;

    while ((ent = readdir(d)) != NULL) {
        if (!is_sql_file(ent->d_name))
            continue;

        char path[512];
        snprintf(path, sizeof(path), "/initdb/%s", ent->d_name);

        if (!is_regular_file(path))
            continue;

        fprintf(stderr, "[entrypoint] Running %s...\n", path);

        int pipefd[2];
        if (pipe(pipefd) != 0) {
            perror("[entrypoint] pipe failed");
            exit(1);
        }

        pid_t pid = fork();
        if (pid < 0) {
            perror("[entrypoint] fork() failed");
            exit(1);
        }

        if (pid == 0) {
            // child: postgres --single < SQL
            close(pipefd[1]);
            dup2(pipefd[0], STDIN_FILENO);

            execlp("postgres",
                   "postgres",
                   "--single",
                   "-D", pgdata,
                   "postgres",
                   NULL);

            perror("[entrypoint] exec postgres --single failed");
            exit(1);
        }

        // parent: feed the SQL file
        close(pipefd[0]);
        FILE *fp = fopen(path, "r");
        if (!fp) {
            perror("[entrypoint] fopen SQL file failed");
            exit(1);
        }

        char buf[4096];
        size_t n;
        while ((n = fread(buf, 1, sizeof(buf), fp)) > 0) {
            write(pipefd[1], buf, n);
        }

        fclose(fp);
        close(pipefd[1]);

        int status;
        waitpid(pid, &status, 0);

        if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
            fprintf(stderr, "[entrypoint] SQL load failed: %s\n", path);
            exit(1);
        }
    }

    closedir(d);
}

int main(int argc, char **argv, char **envp) {
    const char *pgdata = "/var/lib/postgresql/data";

    char version_path[512];
    snprintf(version_path, sizeof(version_path), "%s/PG_VERSION", pgdata);

    if (!file_exists(version_path)) {
        run_initdb(pgdata);
        run_sql_files(pgdata);
    }

    fprintf(stderr, "[entrypoint] Starting real postgres...\n");

    execve("/usr/bin/postgres", argv, envp);
    perror("[entrypoint] execve real postgres failed");
    return 1;
}
