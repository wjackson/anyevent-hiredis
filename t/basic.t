use strict;
use warnings;
use Test::More;
use Test::Exception;

use t::Redis;

use ok 'AnyEvent::Hiredis';

test_redis {
    my $port = shift;

    my $redis = AnyEvent::Hiredis->new(port => $port);

    my $done;

    $done = AE::cv;
    $redis->command([qw/SET KEY VALUE/], sub {
        is $_[0], 'OK', 'got ok';

        $redis->command([qw/GET KEY/], sub {
            is $_[0], 'VALUE', 'got VALUE for KEY';
            $done->send;
        });
    }); 
    $done->recv;

    $done = AE::cv;
    my $cnt = 1;
    for my $e (qw(a b c)) {

        $redis->command([qw/ZADD myzset 0 /, $e], sub {
            my ($res, $error) = @_;

            is $error, undef, 'no error';
            is $res, 1, 'got 1';

            return if $cnt++ < 3; 

            $redis->command([qw/ZRANGE myzset 0 -1/], sub {
                my ($zrange) = @_;
                is_deeply $zrange, [qw(a b c)], 'ZRANGE';
                $done->send;
            });
        }); 
    }
    $done->recv;

    $done = AE::cv;
    $redis->command([qw/BOGUS/], sub {
        my ($result, $error) = @_;

        is $result, undef, 'got undefined result on error';
        is $error, q{ERR unknown command 'BOGUS'}, 'got error';

        $done->send;
    }); 
    $done->recv;
};

{ # connection errors

    # Hiredis is lazy about connecting to the redis server so connection
    # related errors can occur at different times.

    # unresolvable hostname is reported right away
    throws_ok { AnyEvent::Hiredis->new(host => 'bogus')->command }
        qr/Can't resolve/, 'got connection failure';

    # bad port is reported when the first command is run
    my $redis = AnyEvent::Hiredis->new(port => 12345);
    my $done  = AE::cv;
    $redis->command([qw/GET KEY/], sub { $done->send }); 

    throws_ok { $done->recv } qr/Connection refused/,
        'got connection exception';
}

done_testing;
