FROM maven:3.6.3-openjdk-11 as base-layer

LABEL maintainer="preed@swri.org"

# Build the bag DB in a separate stage so that the final image doesn't need
# to have the maven build environment in it.

WORKDIR /app
COPY pom.xml .
RUN mvn -e -B dependency:resolve
COPY src ./src
RUN mvn -e -B package

FROM tomcat:9-jdk11

LABEL maintainer="preed@swri.org"

VOLUME ["/bags", "/root/.ros-bag-database/indexes", "/usr/local/tomcat/logs"]
EXPOSE 8080

# Install gcsfuse
ENV GCSFUSE_REPO gcsfuse-buster
RUN apt-get update && apt-get install --yes --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
  && echo "deb http://packages.cloud.google.com/apt $GCSFUSE_REPO main" \
    | tee /etc/apt/sources.list.d/gcsfuse.list \
  && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
  && apt-get update \
  && apt-get install --yes gcsfuse \
  && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 

# Need to manually install ffmpeg and perl for streaming video
RUN apt-get update \
    && apt-get install -y ffmpeg perl \
    && rm -rf /var/lib/apt/lists/*
RUN rm -rf /usr/local/tomcat/webapps/
COPY --from=base-layer /app/target/*.war /usr/local/tomcat/webapps/ROOT.war
COPY src/main/docker/entrypoint.sh /
COPY src/main/docker/server.xml /usr/local/tomcat/conf/server.xml

CMD ["/entrypoint.sh"]
