# SkayoTT

> A simple, MQTT-like IoT protocol hosted on a simple NodeMCU

This protocol still has a lot of bugs! Do not use it in serious projects!



## Protocol Description

### Message Structure
- Always begins with a command (see [Commands](#commands))
- Then, if needed, a payload
- Then, if mulitple payloads, a seperator
- Then, if mulitple payloads, the next payload
- (And so on)
- At the end there will be a end character (every command has its own, see below)

### Commands:
0x01 - CONNECT      -> Client to Server  
0x02 - CONNACK      -> Server to Client  
0x03 - PUBLISH      -> Client to Server  
0x04 - PUBACK       -> Server to Client  
0x05 - SUBSCRIBE    -> Client to Server  
0x06 - SUBACK       -> Server to Client  
0x07 - UNSUBSCRIBE  -> Client to Server  
0x08 - UNSUBACK     -> Server to Client  
0x09 - DISCONNECT   -> Client to Server  
0x0b - SUBMSG       -> Server to Client  

### CONNECT:
Client - Sends 0x01 (CONNECT)  
Server - Answers with 0x02 (CONNACK), if connecting is allowed to connect, if not server will send a 0x00

### PUBLISH:
Client - Starts with 0x03 (PUBLISH)  
Client - Then the topic (just ASCII-characters)  
Client - Then seperates the topic and the message with 0x1a (PUBLISH_ENDTOPIC)  
Client - Then the message (again, just ASCII-characters)  
Client - Ends with 0x1b (PUBLISH_ENDMSG)  
Server - Confirmns with 0x04 (PUBACK), sends 0x00 if something went wrong

### SUBSCRIBE: 
Client - Starts with 0x05 (SUBSCRIBE)  
Client - Then the topic (just ASCII-characters)  
Client - Ends with 0x1c (SUBSCRIBE_ENDTOPIC)  
Server - Confirmns with 0x06 (SUBACK), sends 0x00 if something went wrong

### UNSUBSCRIBE:
Client - Starts with 0x07 (UNSUBSCRIBE)  
Client - Then the topic (just ASCII-characters)  
Client - Ends with 0x1d (UNSUBSCRIBE_ENDTOPIC)  
Server - Confirms with 0x08 (UNSUBACK), sends 0x00 if something went wrong

### DISCONNECT:
> Safe way of disconnecting from to server, if client does not disconnect and just closes the connection, he will be auto-removed the next time a message is published to a subscribed topic.

Client - Sends 0x09 (DISCONNECT)  
Server - Removes the client, does not confirm the command

### SUBMSG:
Server - Sends 0x0b (SUBMSG)  
Server - Then the topic of the message  
Server - Then seperates the topic and the message with 0x1e (SUBMSG_ENDTOPIC)  
Server - Then the published message  
Server - Ends with 0x1f (SUBMSG_ENDMSG)
