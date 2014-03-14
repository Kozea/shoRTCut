# GET adapter.js from https://webrtc.googlecode.com/svn/trunk/samples/js/base/adapter.js
rfs = window.requestFileSystem || window.webkitRequestFileSystem
chunk_size = 16000
flush_length = 256000 / chunk_size

chunks = (size, chunk) ->
    for i in [0..size] by chunk
        [i, Math.min(i + chunk, size)]


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

        slices = chunks(file.size, chunk_size)
        len = slices.length
        console.log('sending ', slices.length)
        if file_reader
            console.error('Parallel read')
            return

        $('.progresses').append(
            $('<tr>')
                .append(
                    $('<td>').text("Sending #{file.name}"),
                    $('<td>').append($progress = $('<progress>', max: 100))))

        file_reader = new FileReader()
        file_reader.onload = (e) ->
            file_send e.target.result
            read()
        do read = ->
            slice = slices.shift()
            $progress.val(100 * (len - slices.length) / len)
            if slice
                [start, end] = slice
                file_reader.readAsArrayBuffer file.slice start, end
            else
                chat "File sent."
                file_send new ArrayBuffer(0)
                false


    FILE: (message) ->
        args = message.split(',')
        size = +args.shift()
        type = args.shift()
        name = args.join ','
        end = ->
            chat("peer > File: <a href=\"#{file_receiver.url()}\" download=\"#{file_receiver.name}\">#{file_receiver.name}</a>", 'html')
            chat_send 'CHAT', "File received ! (received #{bytes file_receiver.size})"
            file_receiver = null
            chat_send 'ACK'

        $('.progresses').append(
            $('<tr>')
                .append(
                    $('<td>').text("Receiving #{name}"),
                    $('<td>').append($progress = $('<progress>', max: size))))

        if rfs
            rfs(
                TEMPORARY,
                size,
                (fs) =>
                    chat "Receiving file #{name} #{bytes size}"
                    get_file = =>
                        fs.root.getFile(
                            name,
                            create: true
                            exclusive: true,
                            (entry) =>
                                file_receiver = new FileReceiver entry, name, size, type, end, $progress
                                chat_send "ACCEPT"
                            ,
                            @error.bind(@))
                    fs.root.getFile(
                        name,
                        create: false,
                        (entry) =>
                            console.log "Removing existing temp file #{name}"
                            entry.remove(
                                get_file,
                                @error.bind(@))
                        ,
                        get_file)
                ,
                @error.bind(@))
        else
            chat "Receiving file #{name} #{bytes size}"
            file_receiver = new FileBuilder name, size, type, end, $progress
            chat_send "ACCEPT"

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


class FileReceiver extends ShoRTCut::Loggable
    constructor: (@entry, @name, @size, @type, @end, @$progress) ->
        @flushing = false
        @parts = []
        @length = 0
        @callbacks = []

    add: (part) ->
        @parts.push part
        @length += part.byteLength
        @$progress.val(@length)
        if @parts.length >= flush_length or @length >= @size
            if @flushing
                parts = @parts
                @callbacks.push => @flush(parts)

            if @length >= @size
                @callbacks.push @end

            unless @flushing
                @flush(@parts)

             @parts = []

    flush: (parts) ->
        return unless parts.length

        if @flushing
            @error("Can't flush, already flushing")
        @flushing = true
        blob = new Blob parts, type: @type
        @entry.createWriter(
            (fw) =>
                fw.onwriteend = =>
                    @flushing = false
                    if @callbacks.length
                        @callbacks.shift()()
                fw.seek(fw.length)
                fw.write(blob)
            ,
            @error.bind(@))

    url: ->
        @entry.toURL()


class FileBuilder extends ShoRTCut::Loggable
    constructor: (@name, @size, @type, @end, @$progress) ->
        @parts = []
        @length = 0
        @expected = Math.ceil(@size / chunk_size)
        console.log 'expecting ', @expected

    add: (part) ->
        @parts.push part
        @length += part.byteLength
        @$progress.val(@length)
        if @length >= @size
            @end()

    url: ->
        URL.createObjectURL new Blob @parts, type: @type


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
                $('.filedrop').removeClass('hover')
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
        file_receiver.add part

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
