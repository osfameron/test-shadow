package Test::Shadow;

use strict; use warnings;

use parent 'Test::Builder::Module';
use Test::Deep::NoTest qw(deep_diag cmp_details);

use Scope::Upper qw(reap SCOPE);
use Class::Method::Modifiers 'install_modifier';

our @EXPORT = qw( shadow );

=head1 SYNOPSIS

    use Test::More;
    use Test::Shadow;

    use Foo;

    {
        shadow Foo=>'inner_method', (
            in => [ 'list', 'of', 'parameters' ],
            # in => { or => 'hashref' },
            # we can also use Test::Deep comparisons here
            out => 'barry',
            calls => 3
        );

        my $foo = Foo->new;
        $foo->outer_method(); # if inner_method is called, it will return
                              # 'barry' and fail if called with wrong arguments

        # at end of scope, Test::Shadow automagically checks that it was called exactly 3 times
    }

=cut

sub shadow {
    my ($class, $method, %shadow_params) = @_;

    my $tb = __PACKAGE__->builder;
    my $orig = $class->can($method) or die "$class has no such method $method";

    my $count = do { my $count = 0; \$count };
    my $uninstalled;
    my $uninstall = sub {
        return if $uninstalled++;
        no warnings 'redefine';
        no strict 'refs';
        *{"${class}::${method}"} = $orig;
        delete $Class::Method::Modifiers::MODIFIER_CACHE{$class}{$method};
    };

    install_modifier $class, 'around', $method, sub {
        $$count++;
        my $orig = shift;
        my ($self, @args) = @_;

        if (my $expected_in = $shadow_params{in}) {
            my $got = (ref $expected_in eq 'HASH') ? { @args } : \@args;
            my ($ok, $stack) = cmp_details($got, $expected_in);
            if (!$ok) {
                $tb->ok(0, sprintf '%s->%s unexpected parameters on call no. %d', $class, $method, $$count);
                $tb->diag( deep_diag($stack) );
                $tb->diag( '(Uninstalling wrapper)' );
                $uninstall->();
            }
        }
        if (!$uninstalled and my $stubbed_out = $shadow_params{out}) {
            return $stubbed_out;
        }
        else {
            return $self->$orig(@args);
        }
    };

    reap {
        return if $uninstalled;
        if (my $expected_in = $shadow_params{in}) {
            $tb->ok(! $uninstalled, "$class->$method parameters as expected"); 
        }
        if (my $expected_count = $shadow_params{calls}) {
            $tb->is_num($$count, $expected_count, "$class->$method call count as expected ($expected_count)"); 
        }
        $uninstall->();
    } SCOPE(1);
}

1;
