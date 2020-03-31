use strict;
use warnings;

my %types = (
    'conn_in'	=> [qw(
		    idle
		    linger
		    )],

    'conn_out'	=> [qw(
		    connect
		    idle
		    )],

    'send'	=> [qw(
		    send
		    write
		    )],

    'recv'	=> [qw(
		    start
		    fetch
		    read
		    )],

    'pipe'	=> [qw(
		    sess
		    idle
		    )],
    );

my %subjs = (
    'client'	=> 'conn_in',
    'backend'	=> 'conn_out',
    'pipe'	=> 'pipe',
    'req'	=> 'recv',
    'bereq'	=> 'send',
    'resp'	=> 'send',
    'beresp'	=> 'recv'
    );

# from ## Mapping existing timeouts
my %old2new = (
    'backend_idle_timeout' => 'backend_idle_timeout',
    'between_bytes_timeout' => 'beresp_read_timeout',
    'cli_timeout' => 'cli_resp_timeout',
    'connect_timeout' => 'backend_connect_timeout',
    'first_byte_timeout' => 'beresp_start_timeout',
    'idle_send_timeout' => 'resp_write_timeout',
    'pipe_timeout' => 'pipe_idle_timeout',
    'send_timeout' => 'resp_send_timeout',
    'thread_pool_timeout' => 'thread_pool_timeout',
    'timeout_idle' => 'client_idle_timeout',
    'timeout_linger' => 'client_linger_timeout'
    );

my @old = keys %old2new;
my %new2old = map { defined($old2new{$_}) ? ($old2new{$_} => $_) : ()} @old;
my @removed = grep {! defined($old2new{$_})} @old;

# from ## New timeouts to consider
my %new = map {$_ => '(new)'}
    (qw(
     bereq_send_timeout
     req_fetch_timeout
     beresp_fetch_timeout
     pipe_sess_timeout
     ));

my @controversial = (qw(
    resp_write_timeout
    ));

my %seen;

my $fmt = "%-25s%s";
printf("\n${fmt}\n", 'NEW', 'OLD/NEW/DONTHAVE');

for my $s (sort keys %subjs) {
    for my $t (sort @{$types{$subjs{$s}}}) {
	my $n = $s . '_' . $t . '_timeout';
	my $old;
	$old = $new2old{$n};
	$old = $new{$n} unless (defined ($old));
	$old = 'x' unless (defined ($old));

	printf("${fmt}\n", $n, $old);

	$seen{$n} = 1;
    }
}

my $line = 0;
for my $n (sort @removed) {
    printf("\nREMOVED:\n") if ($line++ == 0);
    printf("%s\n", $n);
}

$line = 0;
for my $n (sort @controversial) {
    printf("\nCONTROVERSIAL:\n") if ($line++ == 0);
    printf("%s\n", $n);
    $seen{$n} = 1;
}

$line = 0;
for my $n (sort (keys %new2old, keys %new)) {
    next if $seen{$n};
    printf("\nOTHER:\n") if ($line++ == 0);
    printf("%s\n", $n);
}
