# GET adapter.js from https://webrtc.googlecode.com/svn/trunk/samples/js/base/adapter.js
chat = (text, type='text') ->
    $sb = $('.scrollback')
    $sb.append($('<div>')[type](text))
    $sb.stop(true, true).animate scrollTop: $sb.prop('scrollHeight') - $sb.height()

chat_send = null
file_send = null
file_receiver = null
files = []

bytes = (size) ->
    i = -1
    byteUnits = [" kB", " MB", " GB", " TB", "PB", "EB", "ZB", "YB"]
    loop
        size /= 1000
        i++
        break unless size > 1000
    Math.max(size, 0.1).toFixed(1) + byteUnits[i]


make_progress = (text, max) ->
    $('.progresses').append(
        $('<tr>')
            .append(
                $('<td>').text(text),
                $('<td>').append($progress = $('<progress>', max: max))))
    $progress

class RemoteTextChannel extends ShoRTCut::TextChannel
    constructor: ->
        super
        chat_send = @send.bind @

    open: ->
        super
        chat 'Chat Connected'

    close: ->
        super
        chat 'Chat Connection closed.'

class LocalTextChannel extends ShoRTCut::TextChannel
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

    ACK: ->
        return unless files.length
        file = files[0]
        chat_send "FILE|#{file.size},#{file.type},#{file.name}"

    ACCEPT: ->
        return unless files.length
        file = files.shift()
        $progress = make_progress "Sending #{file.name}", 100
        new ShoRTCutHelpers::FileSender file, file_send, (-> chat "File sent."), ((p) -> $progress.val p)

    FILE: (message) ->
        args = message.split(',')
        size = +args.shift()
        type = args.shift()
        name = args.join ','

        $progress = make_progress "Receiving #{name}", size
        FileReceiver = ShoRTCutHelpers::getFileReceiver()
        file_receiver = new FileReceiver(
            name,
            size,
            type,
            ->
                chat "Receiving file #{name} #{bytes size}"
                chat_send "ACCEPT"
            ,
            ->
                chat("peer > File: <a href=\"#{file_receiver.url()}\" download=\"#{file_receiver.name}\">#{file_receiver.name}</a>", 'html')
                chat_send 'CHAT', "File received ! (received #{bytes file_receiver.size})"
                file_receiver = null
                chat_send 'ACK'
            ,
            (p) -> $progress.val p
        )


    close: ->
        super
        $('input[name=local]')
            .attr('disabled', 'disabled')
            .off('keyup')


class RemoteBinaryChannel extends ShoRTCut::BinaryChannel
    constructor: ->
        super
        file_send = @send.bind @

    open: ->
        super
        chat 'File Connected'

    close: ->
        super
        chat 'File Connection closed.'


class LocalBinaryChannel extends ShoRTCut::BinaryChannel
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
            .on 'drop', (e) =>
                return unless $('.filedrop').hasClass('active')
                $('.filedrop').removeClass('hover').removeClass('active')
                setTimeout ->
                    $('.filedrop').addClass('active')
                , 500
                e = e.originalEvent
                e.stopPropagation()
                e.preventDefault()
                for file in e.dataTransfer.files
                    unless file in files
                        files.push file
                if files.length
                    file = files[0]
                    chat_send "FILE|#{file.size},#{file.type},#{file.name}"
                false

    binary: (part) ->
        file_receiver?.add part

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
        @LocalTextChannel = LocalTextChannel
        @RemoteTextChannel = RemoteTextChannel
        @LocalBinaryChannel = LocalBinaryChannel
        @RemoteBinaryChannel = RemoteBinaryChannel

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
