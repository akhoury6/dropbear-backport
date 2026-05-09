#ifndef DROPBEAR_BACKPORT_STDINT_H
#define DROPBEAR_BACKPORT_STDINT_H

#include <sys/types.h>
#include <limits.h>
#include <stddef.h>

typedef u_int8_t uint8_t;
typedef u_int16_t uint16_t;
typedef u_int32_t uint32_t;
typedef unsigned long long uint64_t;

#ifndef UINT8_MAX
#define UINT8_MAX ((uint8_t)0xff)
#endif
#ifndef UINT16_MAX
#define UINT16_MAX ((uint16_t)0xffffU)
#endif
#ifndef UINT32_MAX
#define UINT32_MAX ((uint32_t)0xffffffffU)
#endif
#ifndef UINT64_MAX
#define UINT64_MAX ((uint64_t)18446744073709551615ULL)
#endif
#ifndef SIZE_MAX
#define SIZE_MAX ((size_t)-1)
#endif

#endif
