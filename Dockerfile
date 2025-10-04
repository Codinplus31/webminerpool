# Stage 1: Build
FROM debian:bullseye AS webminerpool-build

ENV DONATION_LEVEL=0.03

# Install dependencies for native build and Mono
RUN apt-get update && \
    apt-get install -y build-essential mono-complete git make ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

# Modify DonationLevel in source
RUN sed -ri "s/^(.*DonationLevel = )[0-9]\.[0-9]{2}/\1${DONATION_LEVEL}/" /src/server/Server/DevDonation.cs

# Build native library
RUN cd /src/hash_cn/libhash && make

# Build .NET server using xbuild (Mono's build tool)
RUN cd /src/server && xbuild Server.sln /p:Configuration=Release_Server /p:Platform="any CPU"

# Stage 2: Runtime
FROM debian:bullseye

# Install Mono runtime for running .NET executable
RUN apt-get update && apt-get install -y mono-runtime ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /webminerpool

# Copy built artifacts from build stage
COPY --from=webminerpool-build /src/server/Server/bin/Release_Server/server.exe /webminerpool/
COPY --from=webminerpool-build /src/server/Server/bin/Release_Server/pools.json /webminerpool/
COPY --from=webminerpool-build /src/hash_cn/libhash/libhash.so /webminerpool/

# Optional: Copy entrypoint script if you have one
# COPY entrypoint.sh /entrypoint.sh
# RUN chmod +x /entrypoint.sh

EXPOSE 8080

# Use entrypoint.sh if present, otherwise run the server directly
# ENTRYPOINT ["/entrypoint.sh"]
ENTRYPOINT ["mono", "/webminerpool/server.exe"]
