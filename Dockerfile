FROM eclipse-temurin:17-jdk-jammy AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends ant \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .
RUN ant -q build

FROM existdb/existdb:latest

# Deploy the built package automatically when eXist-db starts.
COPY --from=builder /src/build/canonical-greekLit-0.1.xar /exist/autodeploy/

# Render routes traffic to this container port.
EXPOSE 8080
