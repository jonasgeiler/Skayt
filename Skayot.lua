-- Protocol Constants --
protocol = {}

-- Commands
protocol.CONNECT     = 0x01
protocol.CONNACK     = 0x02
protocol.PUBLISH     = 0x03
protocol.PUBACK      = 0x04
protocol.SUBSCRIBE   = 0x05
protocol.SUBACK      = 0x06
protocol.UNSUBSCRIBE = 0x07
protocol.UNSUBACK    = 0x08
protocol.DISCONNECT  = 0x09
protocol.SUBMSG      = 0x0b -- Not 0x0a because 0x0a is a newline character and widely used

-- Breakpoints
protocol.PUBLISH_ENDTOPIC     = 0x1a
protocol.PUBLISH_ENDMSG       = 0x1b
protocol.SUBSCRIBE_ENDTOPIC   = 0x1c
protocol.UNSUBSCRIBE_ENDTOPIC = 0x1d
protocol.SUBMSG_ENDTOPIC      = 0x1e
protocol.SUBMSG_ENDMSG        = 0x1f

-- Other
protocol.ZERO = 0x00



-- Skayot-Server --
pcall(function() Skayot_Server:close() end) -- Close old server if still open

Skayot_Server = net.createServer()

clients = {}

Skayot_Server:listen(2470, function(conn)
    conn:on("connection", function(client, payload)
        print("Connection")
    end)

    conn:on("receive", function(client, payload)
        local hex = parsePayload(payload)
        
        if hex[1] == protocol.CONNECT then
            connect(client)
        elseif hex[1] == protocol.DISCONNECT then
            disconnect(client)
        elseif hex[1] == protocol.SUBSCRIBE then
            if hex[#hex] == protocol.SUBSCRIBE_ENDTOPIC then
                subscribe(client, hex)
            end
        elseif hex[1] == protocol.PUBLISH then
            if hex[#hex] == protocol.PUBLISH_ENDMSG then
                publish(client, hex)
            end
        elseif hex[1] == protocol.UNSUBSCRIBE then
            if hex[#hex] == protocol.UNSUBSCRIBE_ENDTOPIC then
                unsubscribe(client, hex)
            end
        else 
            print("Unknown Command.")
            print("Sending: ", protocol.ZERO)
            client:send(string.char(protocol.ZERO))
        end
    end)
    
    conn:on("sent", function(client)
        print("Sent.")
    end)
end)

function parsePayload(payload)
    hex = {}
    out = ""
    
    for c=1,#payload do
        local char = payload:sub(c,c)
        local charNum = string.byte(char)
        hex[#hex+1] = charNum
        out = out .. encoder.toHex(char) .. " "
    end

    print("\nReceive:", out)
    return hex
end

function hexToString(hex)
    str = ""
    
    for _,char in pairs(hex) do
        str = str .. string.char(char)
    end

    return str
end

function getID(client)
    local port, ip = client:getpeer()
    return ip..':'..port
end

function hasSubscribed(client, topic)
    for _,subTopic in pairs(client.subscribed) do
        if subTopic == topic then
            return true
        end
    end

    return false
end

function newClient(client)
    local id = getID(client)
    
    print("New client: ", id)

    local newClient = {}
    newClient.id = id
    newClient.buffer = ""
    newClient.subscribed = {}
    newClient.instance = client

    clients[#clients+1] = newClient

    return true
end

function removeClient(client)
    local id = getID(client)

    for num,c in pairs(clients) do
        if c.id == id then
            print("Remove client: ", id)
            clients[num] = nil
            return true
        end
    end

    return false
end

function subscribeClient(client, topic)
    local id = getID(client)

    for num,c in pairs(clients) do
        if c.id == id then
            print("Subscribe client", id, "to topic", topic)
            table.insert(clients[num].subscribed, topic)
            return true
        end
    end

    return false
end

function publishClient(client, topic, msg)
    local id = getID(client)

    buffer = ""
    buffer = buffer .. string.char(protocol.SUBMSG)
    buffer = buffer .. topic
    buffer = buffer .. string.char(protocol.SUBMSG_ENDTOPIC)
    buffer = buffer .. msg
    buffer = buffer .. string.char(protocol.SUBMSG_ENDMSG)

    for num,c in pairs(clients) do
        if hasSubscribed(clients[num], topic) then
            -- Check if the client is still connected
            if clients[num].instance and clients[num].instance:getpeer() then
                if clients[num].id ~= id then
                    print("Sending message to ", clients[num].id)
                    clients[num].instance:send(buffer)
                end
            else
                -- Remove/Disconnect the client
                clients[num] = nil
            end
        end
    end

    return true
end

function unsubscribeClient(client, topic)
    local id = getID(client)

    for num,c in pairs(clients) do
        if c.id == id then
            local removed = false

            for num,sub in pairs(clients[num].subscribed) do
                if sub == topic then
                    print("Unubscribe client", id, "from topic", topic)
                    table.remove(clients[num].subscribed, num)
                    removed = true
                end
            end

            return removed
        end
    end

    return false
end

function connect(client)
    print("CMD: Connect")

    success = newClient(client)

    if success then
        print("Connection accepted.")
        print("Sending: ", protocol.CONNACK)
        client:send(string.char(protocol.CONNACK))
    else
        print("Connection declined.")
        print("Sending: ", protocol.ZERO)
        client:send(string.char(protocol.ZERO))
    end
end

function disconnect(client)
    print("CMD: Disconnect")

    success = removeClient(client)

    if success then
        print("Successfully Disconnected.")
    else 
        print("Error while disconnecting")
    end
end

function subscribe(client, payload)
    print("CMD: Subscribe")

    payload[1] = nil
    payload[#payload] = nil

    local topic = hexToString(payload)

    print("Topic: ", topic)

    success = subscribeClient(client, topic)

    if success then
        print("Successfully subscribed!")
        print("Sending: ", protocol.SUBACK)
        client:send(string.char(protocol.SUBACK))
    else
        print("Subscribe failed.")
        print("Sending: ", protocol.ZERO)
        client:send(string.char(protocol.ZERO))
    end
end

function publish(client, payload)
    print("CMD: Publish")

    payload[1] = nil
    payload[#payload] = nil

    local topic, msg = "", ""

    local topicEnd = false
    for _,char in pairs(payload) do
        if char == protocol.PUBLISH_ENDTOPIC then
            topicEnd = true
        else
            if not topicEnd then
                topic = topic .. string.char(char)
            else
                msg = msg .. string.char(char)
            end
        end
    end

    print("Topic: ", topic)
    print("Message: ", msg)

    success = publishClient(client, topic, msg)

    if success then
        print("Successfully published!")
        print("Sending: ", protocol.PUBACK)
        client:send(string.char(protocol.PUBACK))
    else
        print("Publish failed.")
        print("Sending: ", protocol.ZERO)
        client:send(string.char(protocol.ZERO))
    end
end

function unsubscribe(client, payload)
    print("CMD: Unsubscribe")

    payload[1] = nil
    payload[#payload] = nil

    local topic = hexToString(payload)

    print("Topic: ", topic)

    success = unsubscribeClient(client, topic)

    if success then
        print("Successfully unsubscribed!")
        print("Sending: ", protocol.UNSUBACK)
        client:send(string.char(protocol.UNSUBACK))
    else
        print("Unsubscribe failed.")
        print("Sending: ", protocol.ZERO)
        client:send(string.char(protocol.ZERO))
    end
end


