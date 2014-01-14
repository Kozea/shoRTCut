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
        if message == 'caller':
            self.caller = self
        elif message == 'callee':
            self.callee = self
        elif message == 'status':
            self.write_message('ECHO!Status: caller: %r callee: %r' % (
                self.caller, self.callee))

    def on_close(self):
        log.info('Websocket closed')


