# GET adapter.js from https://webrtc.googlecode.com/svn/trunk/samples/js/base/adapter.js
chunks = (size, chunk) ->
    for i in [0..size] by chunk
        [i, Math.min(i + chunk, size)]


chat = (text, type='text') ->
    $sb = $('.scrollback')
    $sb.append($('<div>')[type](text))
    $sb.stop(true, true).animate scrollTop: $sb.prop('scrollHeight') - $sb.height()

chat_send = null
file_send = null

class RemoteChatChannel extends ShoRTCut::Channel
    constructor: ->
        super
        chat_send = @send.bind @

    open: ->
        super
        chat 'Chat Connected'

    close: ->
        super
        chat 'Chat Connection closed.'

class LocalChatChannel extends ShoRTCut::Channel
    constructor: ->
        super

    open: ->
        super
        $('input[name=local]')
            .attr('disabled', null)
            .on 'keyup', (e) ->
                if e.keyCode is 13 and $(this).val()
                    chat_send 'CHAT', $(this).val()
                    chat 'me   < ' + $(this).val()
                    $(this).val('')

    CHAT: (message) ->
        chat 'peer > ' + message

    close: ->
        super
        $('input[name=local]')
            .attr('disabled', 'disabled')
            .off('keyup')


class RemoteFileChannel extends ShoRTCut::Channel
    constructor: ->
        super
        file_send = @send.bind @

    open: ->
        super
        chat 'File Connected'

    close: ->
        super
        chat 'File Connection closed.'


class FileBuilder
    constructor: (@name, @type) ->
        @parts = []

    append: (part) ->
        @parts.push part

    url: ->
        URL.createObjectURL new Blob @parts, type: @type

class LocalFileChannel extends ShoRTCut::Channel
    constructor: ->
        super

    open: ->
        super
        $('.filedrop')
            .addClass('active')
            .on 'dragover', (e) ->
                $(this).addClass('hover')
                e = e.originalEvent
                e.stopPropagation()
                e.preventDefault()
                e.dataTransfer.dropEffect = 'copy'
                false
            .on 'dragleave', (e) ->
                $(this).removeClass('hover')
            .on 'drop', (e) ->
                $(this).removeClass('hover')
                e = e.originalEvent
                e.stopPropagation()
                e.preventDefault()
                return unless $(this).hasClass('active')
                files = e.dataTransfer.files
                file = files[0]
                slices = chunks(file.size, 1024 * 10)
                # Rewrite when blob is supported through datachannel
                file_send "FILE|#{file.size},#{file.type},#{slices.length},#{file.name}"
                file_reader = new FileReader()
                file_reader.onload = (e) ->
                    file_send e.target.result
                    read()
                do read = ->
                    slice = slices.shift()
                    if slice
                        [start, end] = slice
                        file_reader.readAsArrayBuffer file.slice start, end
                    else
                        file_send "DONE"
                false

    FILE: (message) ->
        return unless $('.filedrop').hasClass('active')
        $(this).removeClass('active')
        if @file_builder
            @error 'Already receiving', @file_builder
            return
        args = message.split(',')
        size = args.shift()
        type = args.shift()
        len = args.shift()
        name = args.join ','
        chat "Receiving file #{name} of size #{size} (#{len} parts expected)"
        @file_builder = new FileBuilder name, type

    BINARY: (message) ->
        @file_builder.append message

    DONE: ->
        chat("peer > File: <a href=\"#{@file_builder.url()}\" download=\"#{@file_builder.name}\">#{@file_builder.name}</a>", 'html')
        chat_send 'CHAT', 'File sent !'
        $('.filedrop').addClass('active')
        @file_builder = null

    close: ->
        super
        $('.filedrop')
            .removeClass('active')
            .off('dragover')
            .off('dragleave')
            .off('drop')

class RTCTest extends ShoRTCut
    constructor: ->
        super
        @LocalChatChannel = LocalChatChannel
        @RemoteChatChannel = RemoteChatChannel
        @LocalFileChannel = LocalFileChannel
        @RemoteFileChannel = RemoteFileChannel

    assign_local_stream_url: (url) ->
        chat 'Local video connected'
        $('video.local').attr 'src', url

    assign_remote_stream_url: (url) ->
        chat 'Remote video connected'
        $('video.remote').attr 'src', url

    reset: ->
        super
        chat '--'
        chat 'Reset'
        chat '--'

    caller: ->
        $('h1').text('shoRTCut - caller')

    callee: ->
        $('h1').text('shoRTCut - callee')

$ ->
    rtctest = new RTCTest()
    rtctest.start()
    chat 'Connecting...'
    window.rtc = rtctest
