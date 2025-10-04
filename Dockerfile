FROM debian:bullseye AS webminerpool-build

ENV DONATION_LEVEL=0.03

RUN apt-get update && \
    apt-get install -y build-essential mono-complete git make ca-certificates python3 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

RUN sed -ri "s/^(.*DonationLevel = )[0-9]\.[0-9]{2}/\1${DONATION_LEVEL}/" /src/server/Server/DevDonation.cs
RUN cd /src/hash_cn/libhash && make
RUN cd /src/server && xbuild Server.sln /p:Configuration=Release_Server /p:Platform="any CPU"

FROM debian:bullseye
RUN apt-get update && apt-get install -y mono-runtime ca-certificates python3 && rm -rf /var/lib/apt/lists/*

WORKDIR /webminerpool
COPY --from=webminerpool-build /src/server/Server/bin/Release_Server/server.exe /webminerpool/
COPY --from=webminerpool-build /src/server/Server/bin/Release_Server/pools.json /webminerpool/
COPY --from=webminerpool-build /src/hash_cn/libhash/libhash.so /webminerpool/
COPY certificate.pfx /webminerpool/

EXPOSE 8080 8181

# Create a healthcheck HTTP server script
RUN echo "from http.server import HTTPServer, BaseHTTPRequestHandler\nclass Handler(BaseHTTPRequestHandler):\n    def do_GET(self):\n        if self.path == '/health':\n            self.send_response(200)\n            self.end_headers()\n            self.wfile.write(b'OK')\n        else:\n            self.send_response(404)\n            self.end_headers()\nHTTPServer(('0.0.0.0', 8080), Handler).serve_forever()" > /webminerpool/healthcheck.py

# Entrypoint: run health HTTP server in background, then main server
CMD python3 /webminerpool/healthcheck.py & mono /webminerpool/server.exe
