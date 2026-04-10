FROM eclipse-temurin:17-jdk-jammy AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends ant wget \
    && rm -rf /var/lib/apt/lists/*

# Install GraalVM JavaScript engine for Ant
RUN mkdir -p /usr/share/ant/lib && \
    wget -O /usr/share/ant/lib/js-23.1.0.jar https://repo1.maven.org/maven2/org/graalvm/js/js/23.1.0/js-23.1.0.jar && \
    wget -O /usr/share/ant/lib/js-scriptengine-23.1.0.jar https://repo1.maven.org/maven2/org/graalvm/js/js-scriptengine/23.1.0/js-scriptengine-23.1.0.jar

WORKDIR /src
COPY . .
RUN ant -q build

FROM existdb/existdb:latest

COPY --from=builder /src/build/canonical-greekLit-0.1.xar /exist/autodeploy/

EXPOSE 8080
