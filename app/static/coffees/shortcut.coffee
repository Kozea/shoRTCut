options = window.options
debug = options?.debug

class Loggable
    log: ->
        if debug
            name = @constructor.name
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
            @ch.send cmd

    message: (e) ->
        unless e.data
            @log 'Empty message'
            return

        message = e.data

        @log 'Receiving', message
        pipe = message.indexOf('|')
        if pipe > -1
            cmd = message.substr(0, pipe)
            data = message.substr(pipe + 1)
        else
            cmd = message
            data = ''

        if cmd not of @
            @error "Unknown command #{cmd}", message
        else
            @[cmd](data)

    quit: ->
        @ch.close()


class TextChannel extends Channel

class BinaryChannel extends Channel
    constructor: (@ch, @rtc) ->
        @ch.binaryType = 'arraybuffer'
        super(@ch, @rtc)
        @sendBuffer = []

    message: (e) ->
        if e.data is "\x02"
            @log 'Start of text ?!'
        else
            @binary(e.data)

    send: (ab) ->
        if ab
            @sendBuffer.push ab

        try
            _ab = @sendBuffer.shift()
            @ch.send _ab
        catch
            @sendBuffer.unshift _ab
            setTimeout @send.bind(@), 100

class WebSocket extends Channel
    ECHO: (message) ->
        @log message

    INIT: ->
        @rtc.user_media()

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
    constructor: (@pc, @rtc) ->
        @pc.onicecandidate = @ice_out.bind @
        @pc.onaddstream = @remote_stream.bind @
        @pc.ondatachannel = @data_channel.bind @
        @pc.addStream @rtc.local_stream

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

    remote_stream: (event) ->
        @log 'Got remote stream', event.stream
        @rtc.assign_remote_stream_url URL.createObjectURL event.stream

    data_channel: (event) ->
        @log 'Got remote channel', event.channel
        if event.channel.label is 'text'
            @remote_text_channel = new @rtc.RemoteTextChannel event.channel
        if event.channel.label is 'binary'
            @remote_binary_channel = new @rtc.RemoteBinaryChannel event.channel

    make_channel: ->
        @log 'Got local channel'
        @local_text_channel = new @rtc.LocalTextChannel @pc.createDataChannel 'text', {}
        @local_binary_channel = new @rtc.LocalBinaryChannel @pc.createDataChannel 'binary', {}

    quit: ->
        @remote_text_channel?.quit()
        @remote_binary_channel?.quit()
        @local_text_channel?.quit()
        @local_binary_channel?.quit()
        @pc.close()


class ShoRTCut extends Loggable
    Loggable: Loggable

    Channel: Channel
    Peer: Peer
    TextChannel: Channel
    BinaryChannel: BinaryChannel
    WebSocket: WebSocket

    constructor: (@options) ->
        @Peer = Peer
        @WebSocket = WebSocket

        @LocalTextChannel = TextChannel
        @RemoteTextChannel = TextChannel

        @LocalBinaryChannel = BinaryChannel
        @RemoteBinaryChannel = BinaryChannel

    start: ->
        @ws = new @WebSocket new window.WebSocket('wss://' + document.location.host + '/ws' + location.pathname), @

    user_media: ->
        @log 'Getting user media'
        window.getUserMedia
            audio: true
            video: true,
            @init.bind(@)
            @error.bind(@)

    init: (stream) ->
        @log 'Assigning local stream', stream
        @assign_local_stream_url URL.createObjectURL stream
        @local_stream = stream
        @log 'Connecting'
        @connect()
        @ws.send 'READY'

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
        @peer.make_channel()

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
