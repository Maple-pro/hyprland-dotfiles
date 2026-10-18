#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>

#define DRM_IOCTL_SET_MASTER  _IO('d', 0x1e)
#define DRM_IOCTL_DROP_MASTER _IO('d', 0x1f)

int main(int argc, char **argv) {
    const char *path = argc > 1 ? argv[1] : "/dev/dri/card1";
    int fd = open(path, O_RDWR | O_CLOEXEC);
    if (fd < 0) {
        fprintf(stderr, "open %s: %s\n", path, strerror(errno));
        return 2;
    }
    if (ioctl(fd, DRM_IOCTL_SET_MASTER, 0) < 0) {
        int e = errno;
        fprintf(stderr, "SET_MASTER %s: %s\n", path, strerror(e));
        close(fd);
        return e == EBUSY ? 1 : 3;
    }
    ioctl(fd, DRM_IOCTL_DROP_MASTER, 0);
    close(fd);
    return 0;
}
