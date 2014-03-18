# GET adapter.js from https://webrtc.googlecode.com/svn/trunk/samples/js/base/adapter.js
chat = (text, type='text') ->
    $sb = $('.scrollback')
    $sb.append($('<div>')[type](text))
    $sb.stop(true, true).animate scrollTop: $sb.prop('scrollHeight') - $sb.height()

file_receiver = null
files = []

make_progress = (text, max) ->
    $('.progresses').append(
        $('<tr>')
            .append(
                $('<td>').text(text),
                $('<td>').append($progress = $('<progress>', max: max))))
    $progress

class TextChannel extends ShoRTCut::TextChannel
    open: ->
        super
        $input = $('input[name=local]')
            .attr('disabled', null)
            .on 'keyup', (e) =>
                if e.keyCode is 13 and $input.val()
                    @send 'CHAT', $input.val()
                    chat 'me   < ' + $input.val()
                    $input.val('')

    CHAT: (message) ->
        chat 'peer > ' + message

    ACK: ->
        return unless files.length
        file = files[0]
        @send "FILE|#{file.size},#{file.type},#{file.name}"

    ACCEPT: ->
        return unless files.length
        file = files[0]
        $progress = make_progress "Sending #{file.name}", 100
        new ShoRTCutHelpers::FileSender(
            file,
            @rtc.peer.binary_channel.send.bind(@rtc.peer.binary_channel),
            ->
                files.shift()
                chat "File sent."
            ,
            (p) ->
                $progress.val p
        )

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
            =>
                chat "Receiving file #{name} #{ShoRTCutHelpers::bytes size}"
                @send "ACCEPT"
            ,
            =>
                chat("peer > File: <a href=\"#{file_receiver.url()}\" download=\"#{file_receiver.name}\">#{file_receiver.name}</a>", 'html')
                @send 'CHAT', "File received ! (received #{ShoRTCutHelpers::bytes file_receiver.size})"
                file_receiver = null
                @send 'ACK'
            ,
            (p) -> $progress.val p
        )


    close: ->
        super
        $('input[name=local]')
            .attr('disabled', 'disabled')
            .off('keyup')


class BinaryChannel extends ShoRTCut::BinaryChannel
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
                if files.length and files.length == e.dataTransfer.files.length
                    file = files[0]
                    @rtc.peer.text_channel.send "FILE|#{file.size},#{file.type},#{file.name}"
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
        @TextChannel = TextChannel
        @BinaryChannel = BinaryChannel

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
    options = window.options
    debug = options?.debug

    rtctest = new RTCTest
        turn:
            server: options.turn_server
            username: options.turn_username
            password: options.turn_password
        debug: debug
        host: location.host
        path: location.pathname

    rtctest.start()
    chat 'Connecting...'
    window.rtc = rtctest
