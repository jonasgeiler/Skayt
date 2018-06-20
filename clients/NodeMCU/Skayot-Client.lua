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



-- Skayot-Client --
Skayot_Client = net.createConnection()
Skayot_callbacks = {}
Skayot_query = {}
Skayot_issending = false

Skayot_Client:on("sent", function(server, payload)
    print("Sent.")
    Skayot_issending = false

    for n,nextBuffer in pairs(Skayot_query) do
        print("\nSending buffer from query:")
        sendBuffer(nextBuffer)
        table.remove(Skayot_query, n)
        break
    end
end)

Skayot_Client:on("receive", function(server, payload)
    local hex = parsePayload(payload)

    if hex[1] == protocol.CONNACK then
        print("Connection accepted!")
        Skayot_callbacks.connnect()
    elseif hex[1] == protocol.PUBACK then
        print("Published successfully!")
    elseif hex[1] == protocol.SUBACK then
        print("Subscribed successfully!")
    elseif hex[1] == protocol.UNSUBACK then
        print("Unsubscribed successfully!")
    elseif hex[1] == protocol.SUBMSG then

        local topic, msg = "", ""
    
        local topicEnd = false
        for _,char in pairs(hex) do
            local skip = false
            if char == protocol.SUBMSG_ENDTOPIC then
                topicEnd = true
                skip = true
            end

            if char == protocol.SUBMSG then
                skip = true
            end
            
            if char == protocol.SUBMSG_ENDMSG then
                break
            end

            if not skip then
                if not topicEnd then
                    topic = topic .. string.char(char)
                else
                    msg = msg .. string.char(char)
                end
            end
        end

        print("Received message: ", topic, msg)

        Skayot_callbacks.message(topic, msg)
        
    elseif hex[1] == protocol.ZERO then
        print("Something failed")
    end
end)

Skayot_Client:on("disconnection", function()
    print("Disconnected.")
end)

Skayot_Client:on("connection", function()
    print("Connecting...")
    send_connect()
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

    print("Receive:", out)
    return hex
end

function sendBuffer(buffer)
    if Skayot_issending == false then
        print("\nSending", buffer, string.byte(buffer, 1, -1))
        Skayot_Client:send(buffer)
        Skayot_issending = true
    else
        print("Buffer added to query.")
        table.insert(Skayot_query, buffer)
    end
end

function send_connect()
    local buffer = ""
    buffer = buffer .. string.char(protocol.CONNECT)

    sendBuffer(buffer)
end

function skayot_connect(ip, onconnect)
    Skayot_callbacks.connnect = onconnect
    Skayot_Client:connect(2470, ip)
end

function skayot_disconnect()
    Skayot_Client:close()
end

function skayot_publish(topic, message)
    local buffer = ""
    buffer = buffer .. string.char(protocol.PUBLISH)
    buffer = buffer .. topic
    buffer = buffer .. string.char(protocol.PUBLISH_ENDTOPIC)
    buffer = buffer .. message
    buffer = buffer .. string.char(protocol.PUBLISH_ENDMSG)

    sendBuffer(buffer)
end

function skayot_subscribe(topic, onsubscribe)
    local buffer = ""
    buffer = buffer .. string.char(protocol.SUBSCRIBE)
    buffer = buffer .. topic
    buffer = buffer .. string.char(protocol.SUBSCRIBE_ENDTOPIC)

    sendBuffer(buffer)
end

function skayot_unsubscribe(topic)
    local buffer = ""
    buffer = buffer .. string.char(protocol.UNSUBSCRIBE)
    buffer = buffer .. topic
    buffer = buffer .. string.char(protocol.UNSUBSCRIBE_ENDTOPIC)

    sendBuffer(buffer)
end

function skayot_onmessage(callback)
    Skayot_callbacks.message = callback
end



-- DEMO --
--[[
skayot_connect("192.168.1.110", function()
    skayot_subscribe("light/1")
    skayot_subscribe("light/2")

    gpio.mode(0, gpio.OUTPUT)
    gpio.mode(4, gpio.OUTPUT)
    gpio.write(0, gpio.HIGH)
    gpio.write(4, gpio.HIGH)

    skayot_onmessage(function(topic, message)
        local pin, val
    
        if topic == "light/1" then
            pin = 0
        elseif topic == "light/2" then
            pin = 4
        else
            return
        end

        if message == "ON" then
            val = gpio.LOW
        elseif message == "OFF" then
            val = gpio.HIGH
        else
            return
        end

        gpio.write(pin, val)
    end)
end)
]]--