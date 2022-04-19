/**
 * High-resolution POSIX monotonic clock implementation.
 */

#include "posix_clock.h"
#include <errno.h>

uint64_t aspect_get_monotonic_ns(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
        return 0;
    }
    return ((uint64_t)ts.tv_sec * 1000000000ULL) + (uint64_t)ts.tv_nsec;
}

uint64_t aspect_get_monotonic_us(void) {
    return aspect_get_monotonic_ns() / 1000ULL;
}

uint64_t aspect_get_monotonic_ms(void) {
    return aspect_get_monotonic_ns() / 1000000ULL;
}

void aspect_nanosleep(uint64_t duration_ns) {
    struct timespec req;
    struct timespec rem;
    req.tv_sec = (time_t)(duration_ns / 1000000000ULL);
    req.tv_nsec = (long)(duration_ns % 1000000000ULL);

    while (nanosleep(&req, &rem) == -1 && errno == EINTR) {
        req = rem;
    }
}

void aspect_microsleep(uint64_t duration_us) {
    aspect_nanosleep(duration_us * 1000ULL);
}
