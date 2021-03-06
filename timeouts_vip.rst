Ref https://github.com/varnishcache/varnish-cache/pull/2983

Draft
=====

This document is work in progress to suggest a more consistent naming
scheme for timeout parameters in Varnish-Cache and add new timeouts.

Consistent timeout naming
-------------------------

In the form of: ${subject}_${type}_timeout

Subjects:

- client (client session)
- backend (backend context)
- req
- resp
- bereq
- beresp
- pipe
- cli
- thread

We might want to consider new timeouts too, especially for req and
bereq (see below).

Types:

- task (complete client, backend or pipe task)
- send (complete send of a message)
- fetch (complete fetch of a message)
- start (first byte received)
- idle (waiting to receive or send more)
- linger (time before disembarking)
- pool (time before an unused item leaves a pool)

The "idle" type also has "between_bytes" as a contender.

There is an additional "resp" type that could be confused with the "resp"
subject (cli_resp_timeout, see below). Better ideas to avoid overloading
"resp" are welcome. Maybe cli_child_timeout?

Mapping existing timeouts
-------------------------

In alphabetic order:

- backend_idle_timeout => backend_pool_timeout
- between_bytes_timeout => beresp_idle_timeout
- cli_timeout => cli_resp_timeout
- connect_timeout => beresp_connect_timeout
- first_byte_timeout => beresp_start_timeout
- idle_send_timeout => resp_idle_timeout
- pipe_timeout => pipe_idle_timeout
- send_timeout => resp_send_timeout
- thread_pool_timeout => no change
- timeout_idle => client_idle_timeout
- timeout_linger => client_linger_timeout

The goal besides consistent naming is to also increase clarity regarding
the role of each timeout, and make it easier for new timeouts to be added
in this model. It should also help better define how they relate to the
differences between http/1 and h2, or in broader terms http/1 and stream-based
protocols.

Question: should thread_pool_watchdog become thread_watchdog_timeout?

New timeouts to consider
------------------------

- bereq_send_timeout (wanted by both UPLEX and Varnish Software)
- req_fetch_timeout (wanted by both UPLEX and Varnish Software)
- beresp_fetch_timeout (Varnish Software use case, would be the equivalent
  of last_byte_timeout from Varnish Enterprise)
- pipe_task_timeout (Varnish Software use case)
- req_task_timeout (UPLEX use case)
- bereq_task_timeout (UPLEX use case)

New timeouts could have a default value of zero (no timeout) to maintain
existing behavior.

Other considerations
--------------------

Taken from past and current discussions.

Dedicated parameter tweaks
~~~~~~~~~~~~~~~~~~~~~~~~~~

Timeout parameters currently have a "seconds" unit (side note, why do we use
plural for "Units" in the manual?) which has some disadvantages. For starters
it's not possible to specify an actual unit::

    param.set resp_idle_timeout 1m

It's also not clear what a zero timeout would mean between disabled
and an immediate trigger. With dedicated tweaks we could solve both
limitations.  First, a "duration" tweak that optionally takes an
actual unit, or falls back to seconds if omitted. Second, a "timeout"
tweak that accepts the string "disabled" or falls back to a duration::

    param.set pipe_task_timeout disabled

The "duration" tweak could generally replace the "seconds" unit.

Expose all relevant timeouts to VCL
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The title of this section doesn't leave much to say here, yet.

The VCL versions 4.0 and 4.1 need to support the established timeout names
as aliases to the new ones.

* XXX rename vcl sess.* -> client.* _or_ rename parameters client_* ->
  sess_*

* XXX backend_connect_timeout & backend_idle_timeout

  -> expose to vcl as backend.connect_timeout / backend.idle_timeout?
  -> or transfer ownership to directors?

* XXX fill in paramter list from gen.txt which we did not maintain
  properly anyway

* XXX For client_*_timeout, would they ideally be accessible from a
  new vcl_sess subroutine?

  -> would still need them on the client side (also) because setting
     them might depend on things like the request just seen, a cookie etc.

We propose that everything except cli_resp_timeout and
thread_pool_timeout are exposed to VCL.

How timeouts behave for VCL
~~~~~~~~~~~~~~~~~~~~~~~~~~~

In general, when timeouts are read from VCL for the first time, the
time which might already have passed since the beginning of the scope
of that parameter is deduced.

So, for example, req_fetch_timeout is to fetch the entire request,
including the body. When we enter vcl_recv, time has already passed
for fetching the request headers (and possibly (part of) the body,
depending on buffering), and that time is deduced for
req.fetch_timeout.

Likewise for ESI, resp.send_timeout at esi level 0 is the time for the
entirety of the ESI response. At lower levels, it is the time
(remaining) for that sub-request and all below. We are aware that
these calculations are affected by buffering, in that a higher ESI
level vcl_deliver may be called as soon as bytes to send have been
handed to the kernel or buffered by some lower level protocol like
QUIC.

Additional timeouts can be implemented in VCL
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This VIP aims to add all required building blocks to implement
arbitrary timeouts. Based on these, additional timeouts can be
calculated in vcl. For example, to limit the total time for a backend
request to take, the fetch timeout can be set dynamically (using the
constant & taskvar vmods in this example)::

	sub vcl_init {
		new bereq_total_timeout = constant.duration(1m);
		new bereq_start = taskvar.time();
	}

	sub vcl_backend_fetch {
		bereq_start.set(now);
		set bereq.send_timeout = bereq_total_timeout.get();
	}

	sub vcl_backend_response {
		# goes directly to error if negative
		set beresp.fetch_timeout = bereq_total_timeout.get() -
		    (now - bereq_start.get());
	}
