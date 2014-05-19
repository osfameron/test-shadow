package Test::Shadow;

use strict; use warnings;

use parent 'Test::Builder::Module';
use Test::Deep::NoTest qw(deep_diag cmp_details);

our @EXPORT = qw( with_shadow );
our $VERSION = 0.0101;

=head1 NAME

Test::Shadow - override a class's methods in a scope, checking input/output

=head1 SYNOPSIS

Provides RSpec-like mocking with 'receive'/'and_return' functionality.  However
the interface is more explicit.  This may be considered a feature.

    use Test::More;
    use Test::Shadow;

    use Foo;

    with_shadow Foo => inner_method => {
        in => [ 'list', 'of', 'parameters' ],
        out => 'barry',
        count => 3
    }, sub {
        my $foo = Foo->new;
        $foo->outer_method();
    };

=head1 DETAILS

One function is provided:

=head2 C<with_shadow $class1 =E<gt> $method1 =E<gt> $args1, ..., $callback>

Each supplied class/method is overridden as per the specification in the
supplied args.  Finally, the callback is run with that specification.

The args passed are as follows:

=over 4

=item in

A list of parameters to compare every call of the method against.  This will be
checked each time, until the first failure, if any.  The parameters can be
supplied as an arrayref:

    in => [ 'list', 'of', 'parameters' ]

or a hashref:

    in => { key => 'value', key2 => 'value2 },

and the comparison may be made using any of the extended routines in L<Test::Deep>

    use Test::Deep;
    with_shadow Foo => inner_method => {
        in => { foo => any(1,2,3) },
        ...

=item out

Stub the return value.

=item count

The number of times you expect the method to be called.  This is checked at the end
of the callback scope.

This may be an exact value:

    count => 4,

Or a hashref with one or both of C<min> and C<max> declared:

    count => { min => 5, max => 10 },

=back

=cut

sub with_shadow {
    my $sub = pop @_;
    my $tb = __PACKAGE__->builder;

    my ($class, $method, $shadow_params) = splice @_, 0, 3;
    my ($wrapped, $reap) = mk_subs($tb, $class, $method, $shadow_params);

    {
        no strict 'refs';
        no warnings 'redefine';
        local *{"${class}::${method}"} = $wrapped;

        if (@_) {
            with_shadow(@_, $sub);
        }
        else {
            $sub->();
        }
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

        if (!$failed and my $expected_in = $shadow_params->{in}) {
            my $got = (ref $expected_in eq 'HASH') ? { @args } : \@args;
            my ($ok, $stack) = cmp_details($got, $expected_in);
            if (!$ok) {
                $tb->ok(0, sprintf '%s->%s unexpected parameters on call no. %d', $class, $method, $count);
                $tb->diag( deep_diag($stack) );
                $tb->diag( '(Disabling wrapper)' );
                $failed++;
            }
        }
        if (my $stubbed_out = $shadow_params->{out}) {
            # we use stub even if test has failed, as otherwise we risk calling
            # mocked service unnecessarily
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
        if (my $expected_count = $shadow_params->{count}) {
            if (ref $expected_count) {
                if (my $min = $expected_count->{min}) {
                    $tb->ok($count >= $min, "$class->$method call count >= $min");
                }
                if (my $max = $expected_count->{max}) {
                    $tb->ok($count <= $max, "$class->$method call count <= $max");
                }
            }
            else {
                $tb->is_num($count, $expected_count, 
                    "$class->$method call count as expected ($expected_count)"); 
            }
        }
    };
    return ($wrapped, $reap);
}

=head1 AUTHOR and LICENSE

Copyright 2014 Hakim Cassimally <osfameron@cpan.org>

This module is released under the same terms as Perl.

=cut

1;
