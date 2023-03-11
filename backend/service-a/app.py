#!/usr/bin/python3

from flask import Flask
import platform
import os
app = Flask(__name__)

# web page html content
webPageContent = """\
<hr>
<h3 style="text-align:center;">
Hello! This is the _Service-A_ application! It uses Python via Flask API!
</h3>
<hr>\
"""

@app.route('/')
def Hello():
    return webPageContent

if __name__ == '__main__':
    app.run(port=8080, host="0.0.0.0")
