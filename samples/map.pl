#!/usr/bin/env perl

use strict;
use warnings;

use lib qw{blib/lib blib/archpub};
use Test::Valgrind;

{
 local $SIG{ALRM} = sub { kill "TERM", $$ };
 alarm 1;
 while (1)  { map 1, 1 };
}
