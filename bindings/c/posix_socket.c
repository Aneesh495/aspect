/**
 * Non-blocking POSIX TCP and Unix domain socket primitives implementation.
 */

#include "posix_socket.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/un.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>

static int set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags == -1) {
        return -1;
    }
    return fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

int aspect_socket_listen_tcp(uint16_t port) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) {
        return -1;
    }

    int opt = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK); /* Listen on 127.0.0.1 */
    addr.sin_port = htons(port);

    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        close(fd);
        return -2;
    }

    if (set_nonblocking(fd) != 0) {
        close(fd);
        return -3;
    }

    if (listen(fd, 8) != 0) {
        close(fd);
        return -4;
    }

    return fd;
}

int aspect_socket_listen_unix(const char *path) {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        return -1;
    }

    unlink(path);

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, path, sizeof(addr.sun_path) - 1);

    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        close(fd);
        return -2;
    }

    if (set_nonblocking(fd) != 0) {
        close(fd);
        return -3;
    }

    if (listen(fd, 8) != 0) {
        close(fd);
        return -4;
    }

    return fd;
}

int aspect_socket_accept(int server_fd) {
    struct sockaddr_storage client_addr;
    socklen_t addr_len = sizeof(client_addr);

    int client_fd = accept(server_fd, (struct sockaddr *)&client_addr, &addr_len);
    if (client_fd < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            return -1; /* No pending connection */
        }
        return -2; /* Fatal accept error */
    }

    set_nonblocking(client_fd);

    int nodelay = 1;
    setsockopt(client_fd, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));

    return client_fd;
}

int aspect_socket_send(int client_fd, const char *data, size_t len) {
    ssize_t sent = send(client_fd, data, len, 0);
    if (sent < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            return 0;
        }
        return -1;
    }
    return (int)sent;
}

int aspect_socket_receive(int client_fd, char *buffer, size_t max_len) {
    ssize_t recvd = recv(client_fd, buffer, max_len, 0);
    if (recvd < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            return -1; /* No data ready */
        }
        return -2; /* Read error */
    }
    return (int)recvd;
}

void aspect_socket_close(int fd) {
    if (fd >= 0) {
        close(fd);
    }
}
