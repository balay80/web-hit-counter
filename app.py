#!/usr/bin/env python3

from flask import Flask
from rediscluster import RedisCluster
import os


app = Flask(__name__)
startup_nodes = [{"host": os.getenv("REDIS_HOST"), "port": os.getenv("REDIS_PORT")}]
db = RedisCluster(startup_nodes=startup_nodes, decode_responses=True)


def get_hit_count():
    return db.incr('hits')


@app.route('/')
def hit():
    count = get_hit_count()
    return f"Holla!, we have hit {count} times"


if __name__ == "__main__":
    app.run(host="0.0.0.0", debug=True)
