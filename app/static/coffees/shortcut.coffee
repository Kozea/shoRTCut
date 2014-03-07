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
        if data
            message = "#{cmd}|#{data}"
        else
            message = cmd
        @log 'Sending', message
        @ch.send message

    message: (e) ->
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
            @error "Unknown command #{cmd}"
        else
            @[cmd](data)

    quit: ->
        @ch.close()


class WebSocket extends Channel
    ECHO: (message) ->
        @log message

    INIT: ->
        @rtc.user_media()

    START: ->
        @log 'Creating offer'
        @rtc.peer.offering()

    CALL: (message) ->
        @rtc.peer.remote_description new RTCSessionDescription JSON.parse message
        @rtc.peer.answering()

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
        @pc.onaddstream = @stream.bind @
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

    stream: (event) ->
        @log 'Got remote stream', event.stream
        @rtc.assign_remote_stream_url URL.createObjectURL(event.stream)

    data_channel: (event) ->
        @log 'Got remote channel', event.channel
        @remote_channel = new @rtc.RemoteChannel event.channel

    make_channel: ->
        @log 'Got local channel'
        @local_channel = new @rtc.LocalChannel @pc.createDataChannel Math.random.toString()

    quit: ->
        @remote_channel?.quit()
        @local_channel?.quit()
        @pc.close()


class ShoRTCut extends Loggable
    Peer: Peer
    Channel: Channel
    WebSocket: WebSocket

    constructor: (@options) ->
        @Peer = Peer
        @LocalChannel = Channel
        @RemoteChannel = Channel
        @WebSocket = WebSocket

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

# exports
@ShoRTCut = ShoRTCut
