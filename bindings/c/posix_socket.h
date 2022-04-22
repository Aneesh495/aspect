/**
 * Non-blocking POSIX TCP and Unix domain socket primitives for Aspect telemetry.
 * Standards: IEEE Std 1003.1 (POSIX.1) / Non-blocking asynchronous I/O.
 */

#ifndef ASPECT_POSIX_SOCKET_H
#define ASPECT_POSIX_SOCKET_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Creates a non-blocking TCP server socket listening on 127.0.0.1:port.
 * Returns socket file descriptor, or negative error code on failure.
 */
int aspect_socket_listen_tcp(uint16_t port);

/**
 * Creates a non-blocking Unix domain stream socket server at path.
 * Returns socket file descriptor, or negative error code on failure.
 */
int aspect_socket_listen_unix(const char *path);

/**
 * Accepts a pending client connection on a non-blocking server socket.
 * Returns client file descriptor, -1 if no client is currently pending (EAGAIN),
 * or -2 on fatal error.
 */
int aspect_socket_accept(int server_fd);

/**
 * Sends data over a connected non-blocking socket.
 * Returns bytes transmitted, 0 if would block (EAGAIN), or negative on error.
 */
int aspect_socket_send(int client_fd, const char *data, size_t len);

/**
 * Receives data from a non-blocking socket into buffer.
 * Returns bytes received, 0 on peer disconnect, -1 if no data is ready (EAGAIN),
 * or -2 on error.
 */
int aspect_socket_receive(int client_fd, char *buffer, size_t max_len);

/**
 * Closes an open socket descriptor cleanly.
 */
void aspect_socket_close(int fd);

#ifdef __cplusplus
}
#endif

#endif /* ASPECT_POSIX_SOCKET_H */
