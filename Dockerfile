# Stage 1: Build
FROM debian:bullseye AS webminerpool-build

ENV DONATION_LEVEL=0.03

RUN apt-get update && \
    apt-get install -y build-essential mono-complete git make ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

RUN sed -ri "s/^(.*DonationLevel = )[0-9]\.[0-9]{2}/\1${DONATION_LEVEL}/" /src/server/Server/DevDonation.cs

RUN cd /src/hash_cn/libhash && make

RUN cd /src/server && xbuild Server.sln /p:Configuration=Release_Server /p:Platform="any CPU"

# Stage 2: Runtime
FROM debian:bullseye

RUN apt-get update && apt-get install -y mono-runtime ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /webminerpool

COPY --from=webminerpool-build /src/server/Server/bin/Release_Server/server.exe /webminerpool/
COPY --from=webminerpool-build /src/server/Server/bin/Release_Server/pools.json /webminerpool/
COPY --from=webminerpool-build /src/hash_cn/libhash/libhash.so /webminerpool/

# Add this line to copy certificate.pfx (ensure it is present in your project directory)
COPY certificate.pfx /webminerpool/

EXPOSE 8080 8181 8000

ENTRYPOINT ["mono", "/webminerpool/server.exe"]
