type = null
ws = null
peer = null
local_stream = null
servers = []

error = (error) ->
    console.log 'Error', error

assign_local_stream = (stream) ->
    console.log 'Got local stream', stream
    $('video.local').attr 'src', URL.createObjectURL(stream)
    local_stream = stream
    connect()
    ws.send('READY')

connect = ->
    peer = new RTCPeerConnection
        iceServers: [
            createIceServer('stun:stun.l.google.com:19302'),
            createIceServer('turn:' + options.turn_server + '?transport=udp',
                options.turn_username,
                options.turn_password)
        ]
    ,
        optional: [DtlsSrtpKeyAgreement: true]

    peer.addStream local_stream
    peer.onicecandidate = (event) ->
        console.log 'Got ice', event.candidate
        return unless event.candidate
        ws.send 'ICE|' + JSON.stringify(new RTCIceCandidate(event.candidate))

    peer.onaddstream = (event) ->
        console.log 'Got remote stream', event.stream
        $('video.remote').attr 'src', URL.createObjectURL(event.stream)



ws_message = (event) ->
    message = event.data
    pipe = message.indexOf('|')
    if pipe > -1
        cmd = message.substr(0, pipe)
        data = message.substr(pipe + 1)
    else
        cmd = message
        data = ''

    switch cmd
        when 'ECHO'
            console.log data

        when 'INIT'
            getUserMedia
                audio: true
                video: true,
                assign_local_stream
                error

        when 'START'
            console.log 'Creating offer'
            peer.createOffer (desc) ->
                console.log 'Local desc', desc
                peer.setLocalDescription desc
                ws.send 'CALL|' + JSON.stringify(desc)
            , error
            , mandatory:
                OfferToReceiveAudio: true
                OfferToReceiveVideo: true

        when 'CALL'
            peer.setRemoteDescription(new RTCSessionDescription(JSON.parse(data)))
            peer.createAnswer (desc) ->
                console.log 'Local desc', desc
                peer.setLocalDescription desc
                ws.send 'ANSWER|' + JSON.stringify(desc)
            , error
            , mandatory:
                OfferToReceiveAudio: true
                OfferToReceiveVideo: true

        when 'ANSWER'
            peer.setRemoteDescription(new RTCSessionDescription(JSON.parse(data)))

        when 'ICE'
            peer.addIceCandidate(new RTCIceCandidate(JSON.parse(data)))

        when 'RESET'
            peer.close()
            connect(local_stream)

        when 'WAIT'
            console.log('WAIT')

        when 'FULL'
            alert("There's already 2 persons for this uuid")

$ ->
    ws = new WebSocket 'wss://' + document.location.host + '/ws' + location.pathname
    ws.onopen = -> console.log "WebSocket open", arguments
    ws.onclose = -> console.log "WebSocket closed", arguments
    ws.onerror = -> console.log "WebSocket error", arguments
    ws.onmessage = ws_message
