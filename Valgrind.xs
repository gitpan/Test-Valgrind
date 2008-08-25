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

const char *tvtxs_leaky = NULL;

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
 Newx(tvtxs_leaky, 10000, char);
 XSRETURN_UNDEF;

SV *
notleak(SV *sv)
CODE:
 Newx(tvtxs_leaky, 10000, char);
 Safefree(tvtxs_leaky);
 RETVAL = newSVsv(sv);
OUTPUT:
 RETVAL
