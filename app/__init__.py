# -*- coding: utf-8 -*-
# Copyright (C) 2013 by Florian Mounier, Kozea
# This file is part of shoRTCut, licensed under a 3-clause BSD license.

import os
import tornado.web
import tornado.options
import tornado.web
from logging import getLogger

log = getLogger('shoRTCut')


application = tornado.web.Application(
    debug=tornado.options.options.debug,
    cookie_secret=tornado.options.options.secret,
    static_path=os.path.join(os.path.dirname(__file__), "static"),
    template_path=os.path.join(os.path.dirname(__file__), "templates")
)


class url(object):
    def __init__(self, url):
        self.url = url

    def __call__(self, cls):
        application.add_handlers(
            r'.*$',
            (tornado.web.url(self.url, cls, name=cls.__name__),)
        )
        return cls


class Route(tornado.web.RequestHandler):
    @property
    def log(self):
        return log


import app.routes
