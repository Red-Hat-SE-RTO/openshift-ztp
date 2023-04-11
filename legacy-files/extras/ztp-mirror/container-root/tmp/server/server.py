import http.server
import socketserver
import json
import urllib.request
import os


PORT = 8080
DIRECTORY = "/tmp/server"
JSON_CONFIG = "/tmp/server/config/config.json"

## Read in the config JSON file
f = open(JSON_CONFIG)

# returns JSON object as a dictionary
data = json.load(f)

# Iterating through the json list
for i in data['assets']:
    print('Beginning file download...' + i['src_url'])

    file_dir, file_name = os.path.split(i['target_path'])

    # Create the directory if it doesn't exist
    if not os.path.exists(file_dir):
        os.makedirs(file_dir)

    # Download the file if it doesn't exist
    if not os.path.isfile(i['target_path']):
        urllib.request.urlretrieve(i['src_url'], i['target_path'])

# Closing file
f.close()

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)


with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print("serving at port", PORT)
    httpd.serve_forever()