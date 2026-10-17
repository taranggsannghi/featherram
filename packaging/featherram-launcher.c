#include <limits.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/xattr.h>
#include <unistd.h>

#include <mach-o/dyld.h>

extern char **environ;

static void dirname_in_place(char *path) {
  char *slash = strrchr(path, '/');
  if (slash == NULL || slash == path) {
    return;
  }
  *slash = '\0';
}

static void repair_script(const char *path) {
  chmod(path, 0755);
  removexattr(path, "com.apple.quarantine", 0);
}

int main(void) {
  char executable_path[PATH_MAX];
  uint32_t size = sizeof(executable_path);

  if (_NSGetExecutablePath(executable_path, &size) != 0) {
    fprintf(stderr, "FeatherRAM could not start because its path is too long. Move it to Applications and try again.\n");
    return 1;
  }

  char macos_dir[PATH_MAX];
  snprintf(macos_dir, sizeof(macos_dir), "%s", executable_path);
  dirname_in_place(macos_dir);

  char contents_dir[PATH_MAX];
  snprintf(contents_dir, sizeof(contents_dir), "%s", macos_dir);
  dirname_in_place(contents_dir);

  char resources_dir[PATH_MAX];
  snprintf(resources_dir, sizeof(resources_dir), "%s/Resources", contents_dir);

  char runner_path[PATH_MAX];
  char command_path[PATH_MAX];
  snprintf(runner_path, sizeof(runner_path), "%s/run-featherram.sh", resources_dir);
  snprintf(command_path, sizeof(command_path), "%s/featherram.command", resources_dir);

  if (access(runner_path, F_OK) != 0 || access(command_path, F_OK) != 0) {
    fprintf(stderr, "FeatherRAM is incomplete. Reinstall the complete app.\n");
    return 1;
  }

  repair_script(runner_path);
  repair_script(command_path);

  pid_t pid;
  char *argv[] = {"/usr/bin/open", "-a", "Terminal", runner_path, NULL};
  int status = posix_spawn(&pid, "/usr/bin/open", NULL, NULL, argv, environ);

  if (status != 0) {
    fprintf(stderr, "FeatherRAM could not open Terminal. Check that Terminal is available, then reopen FeatherRAM.\n");
    return 1;
  }

  return 0;
}
