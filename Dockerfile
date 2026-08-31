# Start from the official Adobe ColdFusion base image (version 2025.0.8)
# FROM adobecoldfusion/coldfusion2025:2025.0.8
FROM adobecoldfusion/coldfusion:latest

# Modules needed for POC to work
# ENV installModules="postgresql,graphqlclient,ai,document,pdf"

# Required so cfpm can execute during the docker build phase
ENV acceptEULA="YES"

# FIX: Force Java's native HttpClient to use HTTP/1.1 to prevent Cloud Run network hangs
ENV JAVA_TOOL_OPTIONS="-Djdk.httpclient.HttpClient.version=HTTP_1_1"

# Install standard OpenJDK 21 to get full JRE modules (like java.net.http)
# Adobe ColdFusion built in AI features were not working in Cloud Run due to errors around java.net.http.module and 
# to bypass this install OpenJDK.
RUN apt-get update && \
    apt-get install -y openjdk-21-jdk-headless && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /opt/coldfusion/jre && \
    ln -s /usr/lib/jvm/java-21-openjdk-amd64 /opt/coldfusion/jre

# Bake everything in at build time so the classpath is fully resolved on boot
RUN /opt/coldfusion/cfusion/bin/cfpm.sh install postgresql,graphqlclient,ai,document,pdf,caching

# ---  Download and install BigQuery JDBC Drivers ---
# We use a temporary directory to extract the drivers, then move the necessary JARs to ACF's lib folder.
# Note: The URL below is for the current Google BigQuery JDBC driver. 
# You may want to pin this to a specific version for production stability.
RUN mkdir -p /tmp/bqdriver && \
    curl -k -L https://storage.googleapis.com/simba-bq-release/jdbc/SimbaJDBCDriverforGoogleBigQuery42_1.5.4.1008.zip -o /tmp/bqdriver/bqdriver.zip && \
    unzip /tmp/bqdriver/bqdriver.zip -d /tmp/bqdriver && \
    cp /tmp/bqdriver/*.jar /opt/coldfusion/cfusion/lib/ && \
    rm -rf /tmp/bqdriver

# Copy your application's code (CFM, CFC, etc.)
COPY . /app