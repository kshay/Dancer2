package Dancer2;

# ABSTRACT: Lightweight yet powerful web application framework

use strict;
use warnings;
use Data::Dumper;
use Dancer2::Core::Runner;
use Dancer2::Core::App;
use Dancer2::FileUtils;
use Dancer2::ModuleLoader;

our $AUTHORITY = 'SUKRIA';

# set version in dist.ini now
# but we still need a basic version for
# the tests
$Dancer2::VERSION ||= '0.05';    # 2.0.5

=head1 DESCRIPTION

Dancer2 is the new generation of L<Dancer>, the lightweight web-framework for 
Perl. Dancer2 is a complete rewrite based on L<Moo>. 

Dancer2 is easy and fun:

    use Dancer2;
    get '/' => sub { "Hello World" };
    dance;

This is the main module for the Dancer2 distribution. It contains logic for 
creating a new Dancer2 application. 

If you are looking for info on how to write a webapp with Dancer2 you probably 
want to look at L<Dancer2::Manual> or L<Dancer2::Cookbook>.  For a documentation
of the Dancer2's DSL, you'll want to read L<Dancer2::Manual::DSL>.

You are also welcome to join our mailing list at dancer-users@perldancer.org, 
and we're also on IRC: #dancer on irc.perl.org.

=func my $runner=runner();

Returns the current runner. It is of type L<Dancer2::Core::Runner>.

=cut

our $runner;

sub runner {$runner}

=method import;

If it doesn't exist already, C<import> creates a new runner, imports strict 
and warnings, loads additional libraries, creates a new Dancer2 app (of type 
L<Dancer2::Core::App>) and exports the DSL symbols to the caller.

If any additional argument processing is needed, it will be done at this point.

Import gets called when you use Dancer2. You can specify import options giving 
you control over the keywords that will be imported into your webapp and other 
things:

    use Dancer2 ':syntax';

=head3 Import Options

=over 4

=item C<:tests>

No importing of C<pass> function. This is to prevent conflict with
L<Test::More> et al.

=item C<:syntax>

Imports syntax only instead of treating your code as a script with command line
parameter parsing and built-in web server.

=item C<:script>

Do not process arguments.

=back

=cut

sub import {
    my ( $class,  @args )   = @_;
    my ( $caller, $script ) = caller;

    strict->import;
    utf8->import;

    my @final_args;
    my $syntax_only = 0;
    my $as_script   = 0;
    foreach (@args) {
        if ( $_ eq ':tests' ) {
            push @final_args, '!pass' => 1;
        }
        elsif ( $_ eq ':syntax' ) {
            $syntax_only = 1;
        }
        elsif ( $_ eq ':script' ) {
            $as_script = 1;
        }
        elsif ( substr( $_, 0, 1 ) eq '!' ) {
            push @final_args, $_, 1;
        }
        else {
            push @final_args, $_;
        }
    }

    scalar(@final_args) % 2
      and die
      "parameters to 'use Dancer2' should be one of : 'key => value', ':tests', ':script', or !<keyword>, where <keyword> is a DSL keyword you don't want to import";
    my %final_args = @final_args;

    $final_args{dsl} ||= 'Dancer2::Core::DSL';

    # never instantiated the runner, should do it now
    if ( not defined $runner ) {

        # TODO should support commandline options as well

        $runner = Dancer2::Core::Runner->new( caller => $script, );
    }

    my $local_libdir = Dancer2::FileUtils::path( $runner->location, 'lib' );
    Dancer2::ModuleLoader->use_lib($local_libdir) if -d $local_libdir;

    my $server = $runner->server;

    # the app object
    # populating with the server's postponed hooks in advanced
    my $app = Dancer2::Core::App->new(
        name            => $caller,
        environment     => $runner->environment,
        location        => $runner->location,
        runner_config   => $runner->config,
        postponed_hooks => $server->postponed_hooks,
    );

    core_debug("binding import method to $caller");
    _set_import_method_to_caller($caller);

    # register the app within the runner instance
    core_debug("binding app to $caller");
    $server->register_application($app);

    core_debug("exporting DSL symbols for $caller");

    # load the DSL, defaulting to Dancer2::Core::DSL
    Dancer2::ModuleLoader->require( $final_args{dsl} )
      or die "Couldn't require '" . $final_args{dsl} . "'\n";
    my $dsl = $final_args{dsl}->new( app => $app );
    $dsl->export_symbols_to( $caller, \%final_args );

    #
    #    # if :syntax option exists, don't change settings
    #    return if $syntax_only;
    #
    #    $as_script = 1 if $ENV{PLACK_ENV};
    #
    #    Dancer2::GetOpt->process_args() if !$as_script;
}

sub _set_import_method_to_caller {
    my ($caller) = @_;

    my $import = sub {
        my ( $self, %options ) = @_;

        my $with = $options{with};
        for my $key ( keys %$with ) {
            $self->dancer_app->setting( $key => $with->{$key} );
        }
    };

    {
        no strict 'refs';
        no warnings 'redefine';
        *{"${caller}::import"} = $import;
    }
}

=func core_debug

Output a message to STDERR and take further arguments as some data structures using 
L<Data::Dumper>

=cut

sub core_debug {
    my $msg = shift;
    my (@stuff) = @_;

    my $vars = @stuff ? Dumper( \@stuff ) : '';

    my ( $package, $filename, $line ) = caller;
    return unless $ENV{DANCER_DEBUG_CORE};

    chomp $msg;
    print STDERR "core: $msg\n$vars";
}

1;
