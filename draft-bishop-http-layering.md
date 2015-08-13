---
title: Decomposing the Hypertext Transfer Protocol
abbrev: Decomposing HTTP
docname: draft-bishop-decomposing-http-latest
date: 2015-07-31
category: info

ipr: trust200902
area: Applications
workgroup: HTTPBis Working Group
keyword: Internet-Draft

stand_alone: yes
pi: [toc, sortrefs, symrefs]

author:
 -
    ins: M. Bishop
    name: Mike Bishop
    organization: Microsoft
    email: michael.bishop@microsoft.com

informative:
  RFC1945:
  RFC2818:
  RFC7230:
  RFC7252:
  RFC7540:
  RFC7541:
  Goland-http-udp:
    target: http://tools.ietf.org/html/draft-goland-http-udp-01
    title: Multicast and Unicast UDP HTTP Messages
    date: 1999-11-09
    author:
      name: Yaron Y. Goland
      organization: Microsoft Corporation
  UPnP:
    target: http://upnp.org/specs/arch/UPnP-arch-DeviceArchitecture-v2.0.pdf
    title: UPnP Device Architecture 2.0
    date: 2015
  I-D.tsvwg-quic-protocol:
  RFC6347:
  I-D.natarajan-http-over-sctp:
  RFC4960:
  I-D.ietf-core-block:
    
--- abstract

The Hypertext Transfer Protocol in its various versions
combines concepts of both an application and transport-layer
protocol. As this group contemplates employing alternate
transport protocols underneath HTTP, this document attempts
to delineate the boundaries between these functions to define
a shared vocabulary in discussing the revision and/or replacement
of one or more of these components.

--- middle

Introduction        {#problems}
============

The Hypertext Transfer Protocol defines a very flexible
tool set enabling client applications to make requests
of a server for content or action. This general protocol
was conceived for "the web," interconnected pages of
Hypertext Markup Language (HTML) and associated resources
used to render the HTML, but has since been used as a
general-purpose application transport. Server APIs are
commonly exposed as REST APIs, accessed over HTTP.

HTTP/1.0 {{RFC1945}} was a text-based protocol which did not specify
its underlying transport, but describes the mapping this way:

> On the Internet, HTTP communication generally takes place over TCP/IP
> connections. The default port is TCP 80, but other ports can be
> used. This does not preclude HTTP from being implemented on top of
> any other protocol on the Internet, or on other networks. HTTP only
> presumes a reliable transport; any protocol that provides such
> guarantees can be used, and the mapping of the HTTP/1.0 request and
> response structures onto the transport data units of the protocol in
> question is outside the scope of this specification.

HTTP/1.1 {{RFC7230}} expands on the TCP binding, introducing connection
management concepts into the HTTP layer.

HTTP/2 {{RFC7540}} replaced the simple text-based protocol with a binary
framing.  Conceptually, much of what was introduced in
HTTP/2 represents implementation of new transport services
on top of TCP due to the difficulty in deploying modifications
to TCP on the Internet.  The working group's charter to
maintain HTTP's broad applicability meant that there were few
or no changes in how HTTP surfaces to applications.

Other efforts have mapped HTTP or a subset of it to various
transport protocols besides TCP -- HTTP can be implemented
over SCTP {{RFC4960}} as in {{I-D.natarajan-http-over-sctp}},
and useful profiles of HTTP have been mapped to
UDP in various ways (HTTPU and HTTPUM {{Goland-http-udp}}
and {{UPnP}}, CoAP {{RFC7252}}, QUIC {{I-D.tsvwg-quic-protocol}}).
With the publication of HTTP/2 over TCP, the working group 
is beginning to consider how a mapping to a non-TCP transport would
function.  In order to frame this conversation, common terms
must be defined.

# The Semantic Layer

At the most fundamental level, the semantic layer of HTTP consists
of a client's ability to request some action of a server and be informed
of the outcome of that action.  HTTP defines a number of possible
actions (methods) the client might request of the server, but permits the
list of actions to be extended.

A client's request consists of a desired action (HTTP method) and a
resource on which that action is to be taken (path).  The server 
responds which a status code which informs the client of the result
of the request -- the outcome of the action or the reason the action
was not performed.  Actions may or may not be idempotent or safe, and
the results may or may not be cached by intermediaries; this is
defined as part of the HTTP method.

Each message (request or response) has associated metadata, called
"headers," which provide additional information about the operation.
In a request this might include client identification, credentials
authorizing the client to request the action, or preferences about
how the client would prefer the server handle the action.  In a
response, this might include information about the resulting data,
modifications to the cacheability of the response,
details about how the server performed the action, or details of
the reason the server declined to perform the action.

The headers are structured key-value pairs, with rules defining how
keys which occur multiple times should be handled.  Due to artifacts
of existing usage, these rules vary from key to key.  For similar
legacy reasons, there is no uniform structure of the values across
all keys.  Keys are case-insensitive ASCII strings, while values
are sequences of octets typically interpreted as ASCII.  Many headers
are defined by the HTTP RFCs, but the space is not constrained and
is frequently extended with little or no notice.

Each message, whether request or response, also has an optional body.  The
presence and content of the body will vary based on the action requested.

# Transport Services Required {#transport}

The HTTP Semantic Layer depends on the availability
of the following services:

  - Separate metadata and payload
  - Parallelism
  - Partial delivery
  - Flow control and throttling
  - Reliable delivery
  - In-order delivery
  - Security

No transport over which HTTP can be mapped actually provides
all of the services on which the HTTP Semantic Layer depends.
In the following table, we can see multiple transports
over which HTTP has been deployed and the services they do
or do not offer.

| Transport | Metadata | Parallelism | Partial delivery | Flow control | Reliable | In-order | Secure |
|-----------|----------|-------------|------------------|--------------|----------|----------|--------|
| TCP       |          |             |        X         |      X       |     X    |    X     |        |
| UDP       |          |             |        X         |              |          |          |        |
| SCTP      |          |      X      |        X         |      X       |     X    |    X     |        |
| QUIC      |          |      X      |        X         |      X       |     X    |    X     |   X    |


# The Transport Adaptation Layer {#transport-adaptation}

In order to compensate for the services not provided by a given
underlying transport, each mapping of HTTP onto a new transport
must define an intermediate layer implementing the missing
services in order to enable the mapping.

Some of these have been wholesale imports of other protocols
which exist to provide such an adaptation layer (TLS {{RFC2818}}) while
others have been entirely new protocol machinery constructed
specifically to serve as an adaptation layer (HTTP/2 framing).
Others take the form of implementation-level meta-protocol behavior
(simultaneous connections handled in parallel).
Because the existence of this adaptation layer has not been
explicitly defined in the past, a clean separation
has not always been maintained between the adaptation layer
and either the transport or the semantic layer.

Some adaptation layers are so complex and fully-featured that
the transport layer plus the adaptation layer can be conceptually
treated as a new transport.  For example, QUIC was originally
designed as a transport adaptation layer for HTTP over UDP,
but is now being refactored into a general-purpose transport
layer for multiple protocols.  Such a refactoring will require
separating the services QUIC provides that are general to all
applications from the services which exist purely to enable a
mapping of HTTP to QUIC.

## Security

Integrity and confidentiality are valuable services for
communication over the Internet, and HTTP is no exception.
HTTP originally defined no additional integrity or
confidentiality mechanisms for the TCP mapping, leaving
the integrity and confidentiality levels to those provided
by the network transport.  These may be minimal (TCP
checksums) or rich (IPsec) depending on the network
environment.

For situations where the network does not provide integrity
and confidentiality guarantees sufficient to the content,
{{RFC2818}} defines the use of TLS as an additional
component of the adaptation layer in HTTP/1.1.  HTTP/2
directly defines how TLS may be used to provide these
services as part of its adaptation layer.

TLS itself requires reliable, in-order delivery.  When
those services are provided by the adaptation layer itself
rather than the underlying transport, the adaptation layer
must either provide those services to TLS as well as HTTP
(as in QUIC) or a variant of TLS which does not require
those services must be substituted (DTLS {{RFC6347}},
as used in CoAP).

## Message Framing and Request Metadata

Each request and response contains metadata about the message
(headers) and an optional body.  Since underlying transports
provide only a bytestream or message abstraction for each request,
each HTTP mapping must define a way to separate the components of
a message and package the metadata into this projection.

### HTTP/1.x and Text-Based Headers

HTTP/1.x projects a message as an octet sequence which typically
resembles a block of ASCII text.  Specific octets are used to
delimit the boundaries between message components.  Within
the portion of the message dedicated to headers, the key-value pairs
are expressed as text, with the ':' character and whitespace separating
the key from the value.

Because this region appears to be text, many text conventions have
accidentally crept into HTTP/1.x message parsers and even protocol
conventions (line-folding, CRLF differences between operating systems,
etc.).

### HTTP/2 and HPACK

HTTP/2 projects the requested action into the set of headers,
then uses separate HEADERS and DATA frames to delimit the boundary
between metadata and message body.

Because the text-based transfer of repetitive headers represented
a major inefficiency in HTTP/1.1, HTTP/2 also introduced HPACK
{{RFC7541}}, a custom compression scheme which operates on key-value
pairs rather than text blocks.  HTTP/2 frame types which transport
headers always carry compressed blocks rather than a key-value
dictionary.

## Parallelism and Throttling

Because a client will often need each server to perform multiple
actions at once, HTTP requires the ability to deliver requests
in parallel and allow the server to respond to each request
as the actions complete.  In order to avoid overwhelming
either the transport or the server, HTTP also requires a
mechanism to limit the number of simultaneous requests
a client may have outstanding.

### HTTP/1.x and Multiple Connections

HTTP/1.0 used a very simple multi-request model -- each request
was made on a separate TCP connection, and all requests were
handled independently.  This had the drawback that TCP connection
setup was required with each request and flow control almost
never exited the slow-start phase, limiting performance.

In HTTP/1.1, connections are reused -- when the end of a response
has been received, a new request can be sent.  Management of
the connection was performed by the addition of new HTTP headers
which did not actually refer to the message but the underlying
transport (e.g. "Connection: close").

Throttling of simultaneous requests was fully in the realm of
implementations, which constrained themselves to opening only
a limited number of connections.  HTTP/1.1 originally recommended
two, but later implementations increased this to six by default,
and more under certain conditions.  Because these were fully
independent flows, TCP was unable to consider them as a group for
purposes of congestion control, leading to suboptimal behavior
on the network.

Servers which desired additional parallelism could game such
implementations by exposing resources under multiple hostnames,
causing the client implementations to open six connections
*to each hostname* and gain an arbitrary amount of parallelism,
to the detriment of functional congestion control.

There were further attempts to improve the use of TCP in HTTP/1.1.
HTTP Pipelining allowed the client to eliminate the round-trip that
was incurred between the end of the server's response to one request
and the server's receipt of the client's next request.  However,
pipelining suffers from head-of-line blocking since a request on a
different connection might complete sooner.  The client's inability
to predict the length of requested actions limited the usefulness
of pipelining.

HTTP Multiplexing allowed the use of a single TCP connection to
emit multiple requests, which the server could answer in any
order.  However, this was never broadly deployed because ###WHY NOT?###.

### HTTP/1.1 over SCTP

Because SCTP permits the use of multiple simultaneous streams
over a single connection, HTTP/1.1 could be mapped with relative
ease.  Instead of using separate TCP connections, SCTP flows
could be used to provide a multiplexing layer.  Each flow
was reused for new requests after the completion of a 
response, just as HTTP/1.1 used TCP connections.  This allowed
for better flow control performance, since the transport
could consider all flows together.

### HTTP/2 Framing Layer

HTTP/2 introduced a framing layer that incorporated the concept
of streams.  Because a very large number of idle streams
automatically exist at the beginning of each connection,
each stream can be used for a single request and response.
One stream is dedicated to the transport of control messages,
enabling a cleaner separation between metadata about the
connection from metadata about the separate messages within
the connection.

## Congestion Control

The transport is aware of each concurrent request in HTTP/1.1's
mappings to TCP and SCTP.  In TCP, because there is only one
request at a time, and in SCTP because each request occurs on a
separate flow.  This means that the transport's own congestion
control services are sufficient, even if sub-optimal in TCP's case
due to multiple independent connections.

Because HTTP/2's adaptation layer introduces a concurrency construct
above the transport, the adaptation layer must also introduce
a means of flow control to keep the concurrent transactions
from introducing head-of-line blocking above TCP.

## Reliabile delivery

There are many ways for a transport to provide reliable
delivery of messages. This may take the form of loss recovery,
where the loss of packets is detected and the corresponding
information retransmitted.  Alternately, a transport may
proactively send extra information so that the data stream
is tolerant to some loss -- the full message can be reconstructed
after receipt of a sufficient fraction of the transmission.

Because TCP and SCTP both provide reliable delivery mechanisms,
there was no need to introduce new service in this area for HTTP
mappings.  However, the adaptation layers of HTTP mappings
over UDP have needed to introduce this concept.

CoAP dedicates a portion of its message framing to indicating
whether a given message requires reliability or not.  If
reliable delivery is required, the recipient acknowledges
receipt and the sender continues to repeat the message
until the acknowledgement is received.  For non-idempotent
requests, this means keeping additional state about which
requests have already been processed.

Some applications above HTTP are able to provide their own
loss-recovery messages, and therefore do not actually require
the guarantees that HTTP provides.  HTTP over UDP Multicast
is targeted at such applications, and therefore does not
provide reliable delivery to applications above it.

## In-order delivery

The sequence numbers used to detect the partial loss of data
also permit TCP and SCTP to reassemble data in the order it
was originally sent.

HTTP/2 does not actually require a full
ordering, but TCP does not offer a way to relax its ordering
guarantees.  HTTP/2 has two ordering requirements:

  - All frames on a stream must be delivered to the
    application in order
  - All frames bearing header fragments must be
    delivered to HPACK in order

UDP mappings of HTTP must define mechanisms to restore the
original order of message fragments.  HTTPU(M) and the base form
of CoAP both do this by restricting messages to the size of
a single datagram, while {{I-D.ietf-core-block}} extends CoAP
to define an in-order delivery mechanism in the adaptation layer.

# Moving Forward

The networks over which we run TCP/IP today look nothing like the
networks for which TCP/IP was originally designed.  It is the
clean separation between TCP, IP, and the lower-layer protocols
which has enabled the continued usefulness of the higher-layer
protocols as the substrate has changed.

The goal is not merely architectural purity, but modularity.
HTTP has enjoyed a long life as a higher-layer protocol and is
useful to many varied applications.  As transports continue to
evolve, we will almost certainly find ourselves in the position
of defining a mapping of HTTP onto a new transpont once again.
With a clear understanding of the HTTP semantic layer and the
services it requires, we can better scope the requirements
of a new adaptation layer while reusing the components of
previous adaptation layers that provide the necessary service
well in existing implementations.

--- back

