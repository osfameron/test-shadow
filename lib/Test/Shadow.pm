package Test::Shadow;

use strict; use warnings;

use parent 'Test::Builder::Module';
use Test::Deep::NoTest qw(deep_diag cmp_details);

our @EXPORT = qw( with_shadowed );

=head1 SYNOPSIS

    use Test::More;
    use Test::Shadow;

    use Foo;

    with_shadowed Foo => inner_method => {
        in => [ 'list', 'of', 'parameters' ],
        # in => { or => 'hashref' },
        # we can also use Test::Deep comparisons here
        out => 'barry',
        calls => 3
    }, sub {
        my $foo = Foo->new;
        $foo->outer_method(); # if inner_method is called, it will return
                              # 'barry' and fail if called with wrong arguments

        # at end of scope, Test::Shadow automagically checks that it was called exactly 3 times
    };

=cut

sub with_shadowed {
    my $sub = pop @_;
    my $tb = __PACKAGE__->builder;

    my ($class, $method, $shadow_params) = @_;
    my ($wrapped, $reap) = mk_subs($tb, $class, $method, $shadow_params);

    {
        no strict 'refs';
        no warnings 'redefine';
        local *{"${class}::${method}"} = $wrapped;

        $sub->();
    }

    $reap->();
}

sub mk_subs {
    my ($tb, $class, $method, $shadow_params) = @_;

    my $orig = $class->can($method) or die "$class has no such method $method";
    my $count = 0;
    my $failed;

    my $wrapped = sub {
        $count++;
        my ($self, @args) = @_;

        if (my $expected_in = $shadow_params->{in}) {
            my $got = (ref $expected_in eq 'HASH') ? { @args } : \@args;
            my ($ok, $stack) = cmp_details($got, $expected_in);
            if (!$ok) {
                $tb->ok(0, sprintf '%s->%s unexpected parameters on call no. %d', $class, $method, $count);
                $tb->diag( deep_diag($stack) );
                $tb->diag( '(Disabling wrapper)' );
                $failed++;
            }
        }
        if (!$failed and my $stubbed_out = $shadow_params->{out}) {
            return $stubbed_out;
        }
        else {
            return $self->$orig(@args);
        }
    };
    my $reap = sub {
        return if $failed;
        if (my $expected_in = $shadow_params->{in}) {
            $tb->ok(1, "$class->$method parameters as expected"); 
        }
        if (my $expected_count = $shadow_params->{calls}) {
            $tb->is_num($count, $expected_count, "$class->$method call count as expected ($expected_count)"); 
        }
    };
    return ($wrapped, $reap);
}

1;
