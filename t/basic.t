use strict; use warnings;

use Test::More;
use Test::Deep;
use Test::Shadow;

{
    package Foo;
    sub outer {
        my $class = shift;
        for (1..3) {
            my $inner = $class->inner($_);
            return "eeek" unless $inner eq 'inner';
        }
        return "outer";
    }
    sub inner {
        return "inner";
    }
}

package main;
subtest "input and count" => sub {
    with_shadowed Foo => inner => {
        in => [ any(1,2,3) ],
        calls => 3,
    }, sub {
        Foo->outer;
    };
};

subtest "change output" => sub {
    with_shadowed Foo => inner => {
        out => 'haha',
        calls => 1,
    }, sub {
        is (Foo->outer, 'eeek');
    };
};

done_testing;
