/* This file is part of the Scalar::Vec::Util Perl module.
 * See http://search.cpan.org/dist/Scalar-Vec-Util/ */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define __PACKAGE__ "Test::Valgrind"

#ifndef Newx
# define Newx(v, n, c) New(0, v, n, c)
#endif

#ifndef DEBUGGING
# define DEBUGGING 0
#endif

const char *tv_leaky = NULL;

extern void tv_leak(void) {
 tv_leaky = malloc(10000);

 return;
}

/* --- XS ------------------------------------------------------------------ */

MODULE = Test::Valgrind            PACKAGE = Test::Valgrind

PROTOTYPES: DISABLE

BOOT:
{
 HV *stash = gv_stashpv(__PACKAGE__, 1);
 newCONSTSUB(stash, "DEBUGGING", newSVuv(DEBUGGING));
}

void
leak()
CODE:
 tv_leak();
 XSRETURN_UNDEF;

SV *
notleak(SV *sv)
CODE:
 Newx(tv_leaky, 10000, char);
 Safefree(tv_leaky);
 RETVAL = newSVsv(sv);
OUTPUT:
 RETVAL
