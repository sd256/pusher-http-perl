package WWW::Pusher;

use warnings;
use strict;

use 5.008;

use JSON;
use URI;
use LWP::UserAgent;
use Digest::MD5 qw(md5_hex);
use Digest::SHA qw(hmac_sha256_hex);

my $pusher_defaults = {
	host => 'http://api.pusherapp.com',
	port => 80
};

=head1 NAME

WWW::Pusher - Interface to the Pusher WebSockets API

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';

=head1 SYNOPSIS

    use WWW::Pusher;

    my $pusher   = WWW::Pusher->new(key => 'YOUR API KEY', secret => 'YOUR SECRET', app_id => 'YOUR APP ID', channel => 'test_channel');
    my $response = $pusher->trigger(event => 'my_event', data => 'Hello, World!');

=head1 METHODS

=head2 new(auth_key => $auth_key, secret => $secret, app_id => $app_id, channel => $channel_id)

Creates a new WWW::Pusher object. All fields are all mandatory.

You can optionally specify the host and port keys and override using pusherapp.com's server if you
wish. In addtion, setting debug to a true value will return an L<LWP::UserAgent> response object in 
the event a trigger fails.

=cut

sub new
{
	my ($class, %args) = @_;
	
	die 'Pusher auth key must be defined' unless $args{auth_key};
	die 'Pusher secret must be defined'  unless $args{secret};
	die 'Pusher application ID must be defined' unless $args{app_id};
	die 'Channel must be defined' unless $args{channel};

	my $self = {
		uri	 => URI->new($pusher_defaults->{host} || $args{host}),
		lwp	 => LWP::UserAgent->new,
		debug    => $args{debug} || undef,
		auth_key => $args{auth_key},
		app_id   => $args{app_id},
		secret   => $args{secret},
		channel  => $args{channel},
		host 	 => $args{host} || $pusher_defaults->{host},
		port	 => $args{port} || $pusher_defaults->{port}
	};

	$self->{uri}->port($self->{port});
	$self->{uri}->path('/apps/'.$self->{app_id}.'/channels/'.$self->{channel}.'/events');

	return bless $self;

}


=head2 trigger(event => $event_name, data => $data, [socket_id => $socket_id, debug => 1])

Send an event to the channel. The event name should be a scalar, but data can be hash/arrayref.

Returns true on success, or undef on failure. Setting "debug" to a true value will return an L<LWP::UserAgent> 
response object.

=cut

sub trigger
{
	my ($self, %args) = @_;

	my $time     = time;
	my $uri      = $self->{uri}->clone;
	my $payload  = to_json($args{data}, { allow_nonref => 1 });
	
	# The signature needs to have args in an exact order
	my $params = [
		'auth_key'       => $self->{auth_key}, 
		'auth_timestamp' => $time, 		
		'auth_version'   => '1.0', 
		'body_md5'       => md5_hex($payload),
		'name'           => $args{event},
		'socket_id'      => $args{socket_id} || undef
	];

	$uri->query_form(@{$params});
	my $signature      = "POST\n".$uri->path."\n".$uri->query;
	my $auth_signature = hmac_sha256_hex($signature, $self->{secret});

	my $request  = HTTP::Request->new('POST', $uri->as_string."&auth_signature=".$auth_signature, ['Content-Type' => 'application/json'], $payload);
	my $response = $self->{lwp}->request($request);

	if($self->{debug} || $args{debug})
	{
		return $response;
	}
	elsif($response->is_success && $response->content eq "202 ACCEPTED\n")
	{
		return 1;
	}
	else
	{
		return undef;
	}

}

=head2 socket_auth($socket_id)

In order to establish private channels, your end must hand back a checksummed bit of data that browsers will, 
in turn will pass onto the pusher servers. On success this will return a JSON encoded hashref for you to give 
back to the client.

=cut

sub socket_auth
{
	my($self, $socket_id)  = @_;

	return undef unless $socket_id;
	my $signature = hmac_sha256_hex($self->{channel}.':'.$socket_id, $self->{secret});

	return encode_json({ 
		auth => $self->{'auth_key'}.':'.$signature
	});
}

=head1 AUTHOR

Squeeks, C<< <squeek at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www::pusher at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW::Pusher>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Pusher


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW::Pusher>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW::Pusher>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW::Pusher>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW::Pusher/>

=back

=head1 SEE ALSO

Pusher - L<http://pusherapp.com>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Squeeks.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1; # End of WWW::Pusher
