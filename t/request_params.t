use Test::More;
use strict;
use warnings FATAL => 'all';
use Dancer2::Core::Request;

diag "If you want extract speed, install URL::Encode::XS"
  if !$Dancer2::Core::Request::XS_URL_DECODE;
diag "If you want extract speed, install CGI::Deurl::XS"
  if !$Dancer2::Core::Request::XS_PARSE_QUERY_STRING;

sub run_test {
    {

        # 1. - get params
        note "get params";

        $ENV{REQUEST_METHOD} = 'GET';
        $ENV{PATH_INFO}      = '/';

        for my $separator ( '&', ';' ) {
            note "testing separator $separator";

            $ENV{QUERY_STRING} = join(
                $separator,
                (   'name=Alexis%20Sukrieh', 'IRC%20Nickname=sukria',
                    'Project=Perl+Dancer2',  'hash=2',
                    'hash=4',                'int1=1',
                    'int2=0'
                )
            );

            my $expected_params = {
                'name'         => 'Alexis Sukrieh',
                'IRC Nickname' => 'sukria',
                'Project'      => 'Perl Dancer2',
                'hash'         => [ 2, 4 ],
                int1           => 1,
                int2           => 0,
            };

            my $req = Dancer2::Core::Request->new( env => \%ENV );
            is $req->path,   '/',   'path is set';
            is $req->method, 'GET', 'method is set';
            ok $req->is_get, "request method is GET";
            is_deeply scalar( $req->params ), $expected_params,
              'params are OK';
            is $req->params->{'name'}, 'Alexis Sukrieh',
              'params accessor works';

            my %params = $req->params;
            is_deeply scalar( $req->params ), \%params,
              'params wantarray works';
        }
    }

    {

        # 2. - post params
        note "post params";

        my $body = 'foo=bar&name=john&hash=2&hash=4&hash=6&';
        open my $in, '<', \$body;

        my $env = {
            CONTENT_LENGTH => length($body),
            CONTENT_TYPE   => 'application/x-www-form-urlencoded',
            REQUEST_METHOD => 'POST',
            SCRIPT_NAME    => '/',
            'psgi.input'   => $in,
        };

        my $expected_params = {
            name => 'john',
            foo  => 'bar',
            hash => [ 2, 4, 6 ],
        };

        my $req = Dancer2::Core::Request->new( env => $env );
        is $req->path,   '/',    'path is set';
        is $req->method, 'POST', 'method is set';
        ok $req->is_post, 'method is post';
        my $request_to_string = $req->to_string;
        like $request_to_string, qr{\[#\d+\] POST /};

        is_deeply scalar( $req->params ), $expected_params, 'params are OK';
        is $req->params->{'name'}, 'john', 'params accessor works';

        my %params = $req->params;
        is_deeply scalar( $req->params ), \%params, 'params wantarray works';

    }

    {

        # 3. - mixed params
        my $body = 'x=1&meth=post';
        open my $in, '<', \$body;

        my $env = {
            CONTENT_LENGTH => length($body),
            CONTENT_TYPE   => 'application/x-www-form-urlencoded',
            QUERY_STRING   => 'y=2&meth=get',
            REQUEST_METHOD => 'POST',
            SCRIPT_NAME    => '/',
            'psgi.input'   => $in,
        };

        my $mixed_params = {
            meth => 'post',
            x    => 1,
            y    => 2,
        };

        my $get_params = {
            y    => 2,
            meth => 'get',
        };

        my $post_params = {
            x    => 1,
            meth => 'post',
        };

        my $req = Dancer2::Core::Request->new( env => $env );
        is $req->path,   '/',    'path is set';
        is $req->method, 'POST', 'method is set';

        is_deeply scalar( $req->params ), $mixed_params, 'params are OK';
        is_deeply scalar( $req->params('body') ), $post_params,
          'body params are OK';
        is_deeply scalar( $req->params('query') ), $get_params,
          'query params are OK';
    }
}

diag "Run test with XS_URL_DECODE" if $Dancer2::Core::Request::XS_URL_DECODE;
diag "Run test with XS_PARSE_QUERY_STRING"
  if $Dancer2::Core::Request::XS_PARSE_QUERY_STRING;
run_test();
if ($Dancer2::Core::Request::XS_PARSE_QUERY_STRING) {
    diag "Run test without XS_PARSE_QUERY_STRING";
    $Dancer2::Core::Request::XS_PARSE_QUERY_STRING = 0;
    $Dancer2::Core::Request::_count                = 0;
    run_test();
}
if ($Dancer2::Core::Request::XS_URL_DECODE) {
    diag "Run test without XS_URL_DECODE";
    $Dancer2::Core::Request::XS_URL_DECODE = 0;
    $Dancer2::Core::Request::_count        = 0;
    run_test();
}

done_testing;
