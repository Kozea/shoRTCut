rfs = window.requestFileSystem || window.webkitRequestFileSystem
chunk_size = 16000


class FileHelper extends ShoRTCut::Loggable
    chunks: (size) ->
        for i in [0..size] by chunk_size
            [i, Math.min(i + chunk_size, size)]


class FileSender extends FileHelper
    constructor: (@file, @send, @end, @progress) ->
        @reader = new FileReader()
        @reader.onload = (e) =>
            @send e.target.result
            @read()
        @slices = @chunks file.size
        @length = @slices.length
        @read()

    read: ->
        slice = @slices.shift()
        @progress? 100 * (@length - @slices.length) / @length
        if slice
            [start, end] = slice
            @reader.readAsArrayBuffer @file.slice start, end
        else
            @end()
            false


class FileReceiver extends FileHelper
    constructor: (@name, @size, @type, @ready, @end, @progress) ->
        @parts = []
        @length = 0

    add: (part) ->
        @parts.push part
        @length += part.byteLength
        @progress? @length

    url: ->
        'about:blank'

class DiskFileReceiver extends FileReceiver
    flush_length: 16

    constructor: ->
        super
        @flushing = false
        @callbacks = []
        rfs(
            TEMPORARY,
            @size,
            (fs) =>
                get_file = =>
                    fs.root.getFile(
                        @name,
                        create: true
                        exclusive: true,
                        (@entry) =>
                            @entry.createWriter(
                                (@fw) =>
                                    @fw.onwriteend = =>
                                        @flushing = false
                                        @callbacks?.shift()?()
                                    @ready()
                            , @error.bind(@))
                        , @error.bind(@))
                fs.root.getFile(
                    @name,
                    create: false,
                    (entry) =>
                        entry.remove(
                            get_file,
                            @error.bind(@))
                    , get_file)
            , @error.bind(@))

    add: (part) ->
        super
        if @parts.length >= DiskFileReceiver::flush_length or @length >= @size
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
        @fw.seek @fw.length
        @fw.write new Blob parts, type: @type

    url: ->
        @entry.toURL()


class MemoryFileReceiver extends FileReceiver
    constructor: ->
        super
        @ready()

    add: (part) ->
        super
        if @length >= @size
            @end()

    url: ->
        URL.createObjectURL new Blob @parts, type: @type


getFileReceiver = ->
    if rfs then DiskFileReceiver else MemoryFileReceiver


bytes = (size) ->
    i = -1
    byteUnits = 'kMGTPEZY'
    loop
        size /= 1000
        i++
        break unless size > 1000
    "#{Math.max(size, 0.1).toFixed(1)} #{byteUnits[i] or '?'}B"


class ShoRTCutHelpers
    FileSender: FileSender
    FileReceiver: FileReceiver
    DiskFileReceiver: DiskFileReceiver
    MemoryFileReceiver: MemoryFileReceiver
    getFileReceiver: getFileReceiver
    bytes: bytes

@ShoRTCutHelpers = ShoRTCutHelpers
