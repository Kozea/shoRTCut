import tornado.websocket
from app import url, Route
from logging import getLogger

log = getLogger('apparatus')

@url(r'/(caller|callee)?')
class Index(Route):
    def get(self, type):
        return self.render('index.html')


@url(r'/ws')
class WebSocket(Route, tornado.websocket.WebSocketHandler):
    caller = None
    callee = None

    def open(self):
        log.info('Websocket opened')

    def on_message(self, message):
        log.debug('Websocket %s' % message)
        if '|' in message:
            pipe = message.index('|')
            cmd, data = message[:pipe], message[pipe + 1:]
        else:
            cmd, data = message, ''

        if cmd == 'IAM':
            if data == 'caller':
                WebSocket.caller = self
            elif  data == 'callee':
                WebSocket.callee = self
            if WebSocket.callee and WebSocket.caller:
                WebSocket.caller.write_message('GO')

        elif cmd == 'STATUS':
            self.write_message('ECHO|Status: caller: %r callee: %r' % (
                WebSocket.caller, WebSocket.callee))
        else:
            if WebSocket.caller == self:
                log.info('Caller -> Callee : %s' % message)
                WebSocket.callee and WebSocket.callee.write_message(message)
            if WebSocket.callee == self:
                log.info('Callee <- Callee : %s' % message)
                WebSocket.caller and WebSocket.caller.write_message(message)

    def on_close(self):
        log.info('Websocket closed')
        if self == WebSocket.caller:
            WebSocket.caller = None
        if self == WebSocket.callee:
            WebSocket.callee = None


