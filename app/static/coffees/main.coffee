# GET adapter.js from https://webrtc.googlecode.com/svn/trunk/samples/js/base/adapter.js

chat = (text) ->
    $sb = $('.scrollback')
    $sb.append($('<div>').text(text))
    $sb.stop(true, true).animate scrollTop: $sb.prop('scrollHeight') - $sb.height()

send = null

class RemoteChannel extends ShoRTCut::Channel
    constructor: ->
        super
        send = @send.bind @

    open: ->
        super
        chat 'Connected'

    close: ->
        super
        chat 'Connection closed.'

class LocalChannel extends ShoRTCut::Channel
    constructor: ->
        super

    open: ->
        super
        $('input[name=local]').attr('disabled', null).on 'keyup', (e) ->
            if e.keyCode is 13 and $(this).val()
                send 'CHAT', $(this).val()
                chat 'me   < ' + $(this).val()
                $(this).val('')

    CHAT: (message) ->
        chat 'peer > ' + message

    close: ->
        super
        $('input[name=local]').attr('disabled', 'disabled').off 'keyup'

class RTCTest extends ShoRTCut
    constructor: ->
        super
        @LocalChannel = LocalChannel
        @RemoteChannel = RemoteChannel

    assign_local_stream_url: (url) ->
        $('video.local').attr 'src', url

    assign_remote_stream_url: (url) ->
        $('video.remote').attr 'src', url

$ ->
    rtctest = new RTCTest()
    rtctest.start()
    chat 'Connecting...'
