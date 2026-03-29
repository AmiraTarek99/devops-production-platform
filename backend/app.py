from flask import Flask, jsonify
from flask_cors import CORS
import os, socket

app = Flask(__name__)
CORS(app)

@app.route("/api/health")
def health():
    return jsonify({"status": "healthy", "service": "backend"}), 200

@app.route("/api/ready")
def ready():
    return jsonify({"status": "ready"}), 200

@app.route("/api/info")
def info():
    return jsonify({
        "service":     "backend-api",
        "version":     os.getenv("APP_VERSION", "1.0.0"),
        "environment": os.getenv("ENV", "production"),
        "hostname":    socket.gethostname(),
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
