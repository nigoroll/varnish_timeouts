my @subj = (qw(
	    client
	    backend
	    beresp
	    resp
	    pipe
	    ));

my @typ = (qw(
	   send
	   fetch
	   idle
	   linger
	   ));

# from Mapping existing timeouts
my %old2new = (
    'backend_idle_timeout' => 'backend_idle_timeout',
    'between_bytes_timeout' => 'beresp_idle_timeout',
    'cli_timeout' => 'cli_resp_timeout',
    'connect_timeout' => 'backend_connect_timeout',
    'first_byte_timeout' => 'beresp_firstbyte_timeout',
    'idle_send_timeout' => 'resp_idle_timeout',
    'pipe_timeout' => 'pipe_idle_timeout',
    'send_timeout' => 'resp_send_timeout',
    'thread_pool_timeout' => 'thread_pool_timeout',
    'timeout_idle' => 'client_idle_timeout',
    'timeout_linger' => 'client_linger_timeout'
    );

my %new2old = map {$old2new{$_} => $_} keys %old2new;

# from "New timeouts to consider"
my %new = map {$_ => '(new)'}
    (qw(
     bereq_send_timeout
     req_fetch_timeout
     beresp_fetch_timeout
     pipe_sess_timeout
     ));

my %seen;

printf("\n%-20s\t%s\n", 'NEW', 'OLD/NEW/DONTHAVE');

for $s (sort @subj) {
    for $t (sort @typ) {
	my $n = $s . '_' . $t . '_timeout';
	my $old;
	$old = $new2old{$n};
	$old = $new{$n} unless (defined ($old));
	$old = 'x' unless (defined ($old));

	printf("%-20s\t%s\n", $n, $old);

	$seen{$n} = 1;
    }
}

print "\n";
for my $n (sort (keys %new2old, keys %new)) {
    next if $seen{$n};
    printf("other:\t%s\n", $n);
}
