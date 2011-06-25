package AnyEvent::Hiredis;
# ABSTRACT: AnyEvent hiredis API
use strict;
use warnings;
use namespace::autoclean;
use Hiredis::Async;
use AnyEvent;

sub new {
    my ($class, %args) = @_;

    my $self = bless {}, $class;

    $self->{host}  = $args{host} || '127.0.0.1';
    $self->{port}  = $args{port} || 6379;

    $self->{redis} = $self->_connect;

    return $self;
}

sub _connect {
    my ($self) = @_;

    my $redis = Hiredis::Async->new(
        host => $self->{host},
        port => $self->{port},

        addRead  => sub { $self->_add_read_cb(@_)  },
        delRead  => sub { $self->_del_read_cb(@_)  },
        addWrite => sub { $self->_add_write_cb(@_) },
        delWrite => sub { $self->_del_write_cb(@_) },
    );

    return $redis;
}

sub _add_read_cb {
    my ($self, $fd) = @_;

    return if defined $self->{reader};

    $self->{reader} = AnyEvent->io( fh => $fd, poll => 'r', cb => sub {
        $self->{redis}->HandleRead;
    });

    return;
}

sub _del_read_cb {
    my ($self, $fd) = @_;

    $self->{reader} = undef;

    return;
}

sub _add_write_cb {
    my ($self, $fd) = @_;

    return if defined $self->{writer};

    $self->{writer} = AnyEvent->io( fh => $fd, poll => 'w', cb => sub {
        $self->{redis}->HandleWrite;
    });

    return;
}

sub _del_write_cb {
    my ($self, $fd) = @_;

    $self->{writer} = undef;

    return;
}

sub command {
    my ($self, $cmd, $cb) = @_;

    $self->{redis}->Command($cmd, $cb);

    return;
}

sub DESTROY {
    my ($self) = @_;

    $self->{writer} = undef;
    $self->{reader} = undef;
    $self->{redis}  = undef;
}

1;

__END__

=pod

=head1 NAME

AnyEvent::Hiredis - AnyEvent hiredis API

=head1 SYNOPSIS

  use AnyEvent::Hiredis;

  my $redis = AnyEvent::Hiredis->new(
      host => '127.0.0.1',
      port => 6379,
  );

  $redis->command( [qw/SET foo bar/], sub { warn "SET!" } );
  $redis->command( [qw/GET foo/, sub { my $value = shift } );

  $redis->command( [qw/LPUSH listkey value/] );
  $redis->command( [qw/LPOP listkey/], sub { my $value = shift } );

  # errors
  $redis->command( [qw/SOMETHING WRONG/, sub { my $error = $_[1] } );

=head1 DESCRIPTION

C<AnyEvent::Hiredis> is an AnyEvent Redis API that uses the hiredis C client
library (L<https://github.com/antirez/hiredis>).

=head1 METHODS

=head2 new

  my $redis = Redis->new; # 127.0.0.1:6379

  my $redis = Redis->new(server => '192.168.0.1', port => '6379');

=head2 command

C<command> takes an array ref representing a Redis command and a callback.
When the command has completed the callback is executed and passed the result
or error.

  $redis->command( ['SET', $key, 'foo'], sub {
      my ($result, $error) = @_;

      $result; # 'OK'
  });

  $redis->command( ['GET', $key], sub {
      my ($result, $error) = @_;

      $result; # 'foo'
  });

If the Redis server replies with an error then C<$result> will be C<undef> and
C<$error> will contain the Redis error string.  Otherwise C<$error> will be
C<undef>.

=head1 REPOSITORY

L<http://github.com/wjackson/anyevent-hiredis>

=head1 AUTHORS

Whitney Jackson

Jonathan Rockway

=head1 SEE ALSO

L<Redis>, L<Hiredis::Async>, L<AnyEvent::Redis>
