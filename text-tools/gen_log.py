import random

ips = [f"10.0.0.{i}" for i in range(1, 21)]
paths = ["/", "/login", "/api/users", "/api/orders", "/static/app.js"]
methods = ["GET", "POST"]
statuses = [200, 301, 404, 500]
weights = [70, 5, 15, 10]

with open("access.log", "w") as f:
    for _ in range(1000):
        ip = random.choice(ips)
        method = random.choice(methods)
        path = random.choice(paths)
        status = random.choices(statuses, weights=weights)[0]
        size = random.randint(100, 5000)
        minute = random.randint(0, 59)
        second = random.randint(0, 59)
        f.write(
            f'{ip} - - [22/Nov/2026:13:{minute:02d}:{second:02d} +0000] '
            f'"{method} {path} HTTP/1.1" {status} {size} "-" "curl/8.0"\n'
        )
