This is a DummAssSimple POE client (das_POE_client.pl)

Language: Perl (v5.14)

This script will connect to a POE type server using Yaml as the data exchange method. It is intended
for a limited and structured request-response between the client and the server.

It is not intended to be asynchronous. The POE servers of interest to this client provide configuration
information to the client(s) so the configuration process of the client must wait for the new info
before moving to the next (or main) task. 

The script pulls in the POE Reference filter to use with Yaml. This can be easily changed to a text line filter.
Note: The POE filter seems to work very well pulling data from the server, but not so well pushing data at the server.
The method 'format_POE_Yaml_send' takes care of formatting the send data so the POE server can understand the data
request.

No claims about the goodness of the code are made. If you don't like my coding style, then feel free to re-write it.
