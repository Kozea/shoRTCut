#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright (C) 2014 by Florian Mounier, Kozea
# This file is part of webrtc, licensed under a 3-clause BSD licens

"""
webrtc - WebRTC Websocket signalling server implementation
"""

from setuptools import find_packages, setup

# Use a time-based version number with ridiculous precision as pip in tox
# does not reinstall the same version.
import datetime
VERSION = "git-" + datetime.datetime.now().isoformat()

options = dict(
    name="webrtc",
    version=VERSION,
    description="WebRTC Websocket signalling server implementation",
    long_description=__doc__,
    author="Florian Mounier - Kozea",
    author_email="florian.mounier@kozea.fr",
    license="BSD",
    platforms="Any",
    packages=find_packages(),
    scripts=["webrtc.py"],
    package_data={
        'app': ['static/javascripts/*.js',
                'static/stylesheets/*.css',
                'static/stylesheets/bootstrap/*.css',
                'static/stylesheets/font/*',
                'templates/*.html']
    },
    install_requires=['tornado'],
    classifiers=[
        "Development Status :: WIP",
        "Intended Audience :: Public",
        "License :: OSI Approved :: BSD License",
        "Operating System :: Linux",
        "Programming Language :: Python :: 3.3"])

setup(**options)
