#!/usr/bin/env python

try:
    from wdb.ext import add_w_builtin
    add_w_builtin()
except ImportError:
    pass

import tornado.httpserver
import tornado.options
import tornado.ioloop
import os

tornado.options.define("secret", default='secret', help="Secret")
tornado.options.define("debug", default=False, help="Debug mode")
tornado.options.define("host", default='shoRTCut.l', help="Server host")
tornado.options.define("port", default=3615, type=int, help="Server port")
tornado.options.define("turn_server", default='', help="TURN server")
tornado.options.define("turn_username", default='', help="TURN username")
tornado.options.define("turn_password", default='', help="TURN password")
tornado.options.define("ssl", default=False, help="Use SSL")
tornado.options.define("ssl_cert",
                       default=os.path.join(
                           os.path.dirname(__file__), 'server.pem'),
                       help="SSL cert file")
tornado.options.define("ssl_key",
                       default=os.path.join(
                           os.path.dirname(__file__), 'server.key'),
                       help="SSL key file")
tornado.options.define("ssl_ca",
                       default=os.path.join(
                           os.path.dirname(__file__), 'server.crt'),
                       help="SSL CA cert file")

tornado.options.parse_command_line()

import logging
from logging.handlers import SysLogHandler, SMTPHandler
log = logging.getLogger('shoRTCut')

if not tornado.options.options.debug:
    handler = SysLogHandler(
        address='/dev/log', facility=SysLogHandler.LOG_LOCAL1)
    handler.setLevel(logging.INFO)
    handler.setFormatter(
        logging.Formatter(
            'shoRTCut: %(name)s: %(levelname)s %(message)s'))

    smtp_handler = SMTPHandler(
        'smtp.keleos.fr',
        'no-reply@keleos.fr',
        'shoRTCut-errors@kozea.fr',
        'shoRTCut Exception')
    smtp_handler.setLevel(logging.ERROR)

    log.addHandler(handler)
    log.addHandler(smtp_handler)
    for logger in (
            'tornado.access',
            'tornado.application',
            'tornado.general'):
        logging.getLogger(logger).addHandler(handler)
        logging.getLogger(logger).addHandler(smtp_handler)

    log.setLevel(logging.WARNING)
else:
    log.setLevel(logging.DEBUG)

log.debug('Starting server')
ioloop = tornado.ioloop.IOLoop.instance()


from app import application
if tornado.options.options.ssl:
    tornado.httpserver.HTTPServer(application, ssl_options={
        'certfile': tornado.options.options.ssl_cert,
        'keyfile': tornado.options.options.ssl_key,
        'ca_certs': tornado.options.options.ssl_ca,
    }).listen(tornado.options.options.port)
    url = "https://%s:%d/*" % (
        tornado.options.options.host, tornado.options.options.port)
else:
    application.listen(tornado.options.options.port)
    url = "https://%s:%d/*" % (
        tornado.options.options.host, tornado.options.options.port)


if tornado.options.options.debug:
    try:
        from wsreload.client import sporadic_reload, watch
    except ImportError:
        log.debug('wsreload not found')
    else:
        sporadic_reload({'url': url})

        files = ['app/static/javascripts/',
                 'app/static/stylesheets/',
                 'app/templates/']
        watch({'url': url}, files, unwatch_at_exit=True)

log.debug('Starting loop')
ioloop.start()
