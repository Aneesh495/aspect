/**
 * High-resolution POSIX monotonic clock interface for Aspect vital cyclic executive.
 * Standards: IEEE Std 1003.1 (POSIX.1) / EN 50128 SIL 4 timing determinism.
 */

#ifndef ASPECT_POSIX_CLOCK_H
#define ASPECT_POSIX_CLOCK_H

#include <stdint.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Returns the current monotonic time in nanoseconds since an arbitrary boot epoch.
 * Guaranteed to be strictly monotonic and immune to NTP step adjustments.
 */
uint64_t aspect_get_monotonic_ns(void);

/**
 * Returns the current monotonic time in microseconds.
 */
uint64_t aspect_get_monotonic_us(void);

/**
 * Returns the current monotonic time in milliseconds.
 */
uint64_t aspect_get_monotonic_ms(void);

/**
 * Precise high-resolution sleep for the given number of nanoseconds.
 */
void aspect_nanosleep(uint64_t duration_ns);

/**
 * Precise high-resolution sleep for the given number of microseconds.
 */
void aspect_microsleep(uint64_t duration_us);

#ifdef __cplusplus
}
#endif

#endif /* ASPECT_POSIX_CLOCK_H */
