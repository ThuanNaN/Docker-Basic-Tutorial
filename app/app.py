from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return """<!DOCTYPE html>
<html>
<head><title>Docker Basic Tutorial</title></head>
<body>
<h1>Hello from Docker! Tutorial app</h1>
<p>Built with Docker Engine 29.7.2 + Compose v5.4.0</p>
</body>
</html>"""

@app.route("/health")
def health():
    return "OK", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
