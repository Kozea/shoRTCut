import tornado.websocket
from collections import defaultdict
from app import url, Route
from uuid import uuid4


@url(r'/([^/]*)')
class Index(Route):
    def get(self, uid):
        if not uid:
            return self.redirect('/%s' % uuid4())
        return self.render('index.html')


@url(r'/ws/(.+)')
class WebSocket(Route, tornado.websocket.WebSocketHandler):
    websockets = defaultdict(list)

    @property
    def room(self):
        return WebSocket.websockets[self.id]

    @property
    def correspondent(self):
        return self.room[1 - self.room.index(self)]

    def open(self, uid):
        self.log.info('Websocket opened with id %s' % uid)
        self.id = uid.decode('utf-8')

        if len(self.room) >= 2:
            self.send('FULL')
        else:
            self.room.append(self)
            self.send('INIT')

    def send(self, message):
        self.log.debug('WS -> %s' % message)
        self.write_message(message)

    def on_message(self, message):
        self.log.debug('WS <- %s' % message)
        if '|' in message:
            pipe = message.index('|')
            cmd, data = message[:pipe], message[pipe + 1:]
        else:
            cmd, data = message, ''

        if cmd == 'READY':
            if len(self.room) == 2:
                # First to connect is the caller
                self.room[0].send('START')
            else:
                self.send('WAIT')

        elif cmd == 'STATUS':
            self.send('ECHO|Status: room: %r (ws: %r)' % (
                self.room, WebSocket.websockets))
        else:
            self.correspondent.send(message)

    def on_close(self):
        self.log.info('Websocket closed')
        self.room.remove(self)
        if len(self.room) == 1:
            self.room[0].send('RESET')
