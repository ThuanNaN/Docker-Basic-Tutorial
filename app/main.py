from fastapi import FastAPI

app = FastAPI(title="Docker Basic Tutorial")

@app.get("/")
def home():
    return """<!DOCTYPE html>
<html>
<head><title>Docker Basic Tutorial</title></head>
<body>
<h1>Hello from Docker! Tutorial app</h1>
<p>Built with Docker Engine 29.7.2 + Compose v5.4.0</p>
</body>
</html>"""

@app.get("/health")
def health():
    return {"status": "OK"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
