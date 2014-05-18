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
    sub hashy {
        my ($class, %args) = @_;
        return 'hashy';
    }
}

package main;
subtest "input, Test::Deep, and count" => sub {
    with_shadow Foo => inner => {
        in => [ any(1,2,3) ],
        count => 3,
    }, sub {
        Foo->outer;
    };
};

subtest "change output" => sub {
    with_shadow Foo => inner => {
        out => 'haha',
        count => 1,
    }, sub {
        is (Foo->outer, 'eeek');
    };
};

subtest "Multiple" => sub {
    with_shadow 
        Foo => inner => { out => 'one' },
        Foo => hashy => { out => 'two' },
    sub {
        is (Foo->inner, 'one');
        is (Foo->hashy, 'two');
    };
};

subtest "Hash ref" => sub {
    with_shadow 
        Foo => hashy => { in => { foo => 1, bar => 2 } },
    sub {
        Foo->hashy( foo => 1, bar => 2 );
    };
};
done_testing;
