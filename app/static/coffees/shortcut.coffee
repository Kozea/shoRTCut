options = window.options
debug = options?.debug

class Loggable
    log: ->
        if debug
            name = (if @ch? then @ch else @).constructor.name
            log_args = [name].concat Array.prototype.slice.call(arguments, 0)
            console.log.apply console, log_args

    error: ->
        if console?.error
            console.error.apply console, arguments
        else
            alert arguments[0]
        window.last_err_args = arguments


class Channel extends Loggable
    constructor: (@ch, @rtc) ->
        @log "Creating channel"
        @ch.onopen = @open.bind @
        @ch.onmessage = @message.bind @
        @ch.onerror = @fail.bind @
        @ch.onclose = @close.bind @

    open: ->
        log_args = ['open'].concat Array.prototype.slice.call(arguments, 0)
        @log.apply @, log_args

    close: ->
        log_args = ['close'].concat Array.prototype.slice.call(arguments, 0)
        @log.apply @, log_args

    fail: ->
        log_args = ['error'].concat Array.prototype.slice.call(arguments, 0)
        @error.apply @, log_args

    send: (cmd, data) ->
        type = cmd.constructor.name
        if type is 'String'
            if data
                message = "#{cmd}|#{data}"
            else
                message = cmd
            @log 'Sending', message
            @ch.send message
        else
            @log 'Sending', cmd
            @ch.send cmd

    message: (e) ->
        unless e.data
            @log 'Empty message'
            return
        message = e.data
        @log 'Receiving', message

        type = message.constructor.name
        if type is 'String'
            pipe = message.indexOf('|')
            if pipe > -1
                cmd = message.substr(0, pipe)
                data = message.substr(pipe + 1)
            else
                cmd = message
                data = ''
        else
            cmd = 'BINARY'
            data = message

        if cmd not of @
            @error "Unknown command #{cmd}", type, message
        else
            @[cmd](data)

    quit: ->
        @ch.close()


class WebSocket extends Channel
    ECHO: (message) ->
        @log message

    INIT: ->
        @rtc.init()

    START: ->
        @log 'Creating offer'
        @rtc.peer.offering()
        @rtc.caller()

    CALL: (message) ->
        @rtc.peer.remote_description new RTCSessionDescription JSON.parse message
        @rtc.peer.answering()
        @rtc.callee()

    ANSWER: (message) ->
        @rtc.peer.remote_description new RTCSessionDescription JSON.parse message

    ICE: (message) ->
        @rtc.ice_in new RTCIceCandidate JSON.parse message

    RESET: ->
        @rtc.reset()

    WAIT: ->

    FULL: ->
        alert("There's already 2 persons for this uuid")

class Peer extends Loggable
    _local_stream: null

    constructor: (@pc, @rtc) ->
        @pc.onicecandidate = @ice_out.bind @
        @pc.onaddstream = @remote_stream.bind @
        @pc.ondatachannel = @data_channel.bind @

    ice_in: (ice) ->
        @pc.addIceCandidate ice

    ice_out: (event) ->
        @log 'Got ice', event.candidate
        if event.candidate
            @rtc.ice_out JSON.stringify new RTCIceCandidate event.candidate

    offering: ->
        @log 'Offering'
        @pc.createOffer @caller_local_description.bind(@), @error.bind(@),
            mandatory:
                OfferToReceiveAudio: true
                OfferToReceiveVideo: true

    answering: ->
        @log 'Answering'
        @pc.createAnswer @callee_local_description.bind(@), @error.bind(@),
            mandatory:
                OfferToReceiveAudio: true
                OfferToReceiveVideo: true

    caller_local_description: (desc) ->
        @local_description desc
        @rtc.calling JSON.stringify(desc)

    callee_local_description: (desc) ->
        @local_description desc
        @rtc.answering JSON.stringify(desc)

    local_description: (desc) ->
        @log 'Got local description', desc
        @pc.setLocalDescription desc

    remote_description: (desc) ->
        @log 'Got remote description', desc
        @pc.setRemoteDescription desc

    offer_stream: (stream)->
        @log 'Offering ', stream
        @pc.addStream stream

    local_stream: (stream) ->
        @log 'Got local stream', stream
        @offer_stream(stream)
        @rtc.assign_local_stream_url URL.createObjectURL stream
        Peer::_local_stream = stream

    remote_stream: (event) ->
        @log 'Got remote stream', event.stream
        @rtc.assign_remote_stream_url URL.createObjectURL event.stream

    data_channel: (event) ->
        @log 'Got remote channel', event.channel
        if event.channel.label is 'Chat'
            @remote_chat_channel = new @rtc.RemoteChatChannel event.channel
        if event.channel.label is 'File'
            @remote_file_channel = new @rtc.RemoteFileChannel event.channel

    make_channel: ->
        @log 'Got local channel'
        @local_chat_channel = new @rtc.LocalChatChannel @pc.createDataChannel 'Chat'
        @local_file_channel = new @rtc.LocalFileChannel @pc.createDataChannel 'File'

    make_stream: ->
        @log 'Getting user media'
        if Peer::_local_stream
            @offer_stream Peer::_local_stream
        else
            getUserMedia
                audio: true
                video: true,
                @local_stream.bind(@),
                @error.bind(@)

    quit: ->
        @remote_chat_channel?.quit()
        @remote_file_channel?.quit()
        @local_chat_channel?.quit()
        @local_file_channel?.quit()
        @pc.close()


class ShoRTCut extends Loggable
    Peer: Peer
    Channel: Channel
    WebSocket: WebSocket

    constructor: (@options) ->
        @Peer = Peer
        @LocalChatChannel = Channel
        @LocalFileChannel = Channel
        @RemoteChatChannel = Channel
        @RemoteFileChannel = Channel
        @WebSocket = WebSocket

    start: ->
        @ws = new @WebSocket new window.WebSocket('wss://' + document.location.host + '/ws' + location.pathname), @

    init: ->
        @log 'Connecting'
        @connect()

    calling: (desc) ->
        @ws.send 'CALL', desc

    answering: (desc) ->
        @ws.send 'ANSWER', desc

    connect: ->
        @peer = new @Peer(new RTCPeerConnection(
            iceServers: [
                createIceServer('stun:stun.l.google.com:19302'),
                createIceServer('turn:' + options.turn_server,
                    options.turn_username,
                    options.turn_password)
            ],
            optional: [DtlsSrtpKeyAgreement: true]), @)
        @peer.make_stream()
        @peer.make_channel()
        @ws.send 'READY'

    ice_out: (ice) ->
        @ws.send 'ICE', ice

    ice_in: (ice) ->
        @peer.ice_in ice

    reset: ->
        @peer.quit()
        @connect()

    # Mandatory Overrides
    assign_local_stream_url: (url) ->
        @error 'You must override this method to set local stream url'

    assign_remote_stream_url: (url) ->
        @error 'You must override this method to set remote stream url'

    # Specific code caller/callee
    caller: ->

    callee: ->

# exports
@ShoRTCut = ShoRTCut
