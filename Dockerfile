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
RUN apt-get update && \
    apt-get install -y openjdk-21-jdk-headless && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /opt/coldfusion/jre && \
    ln -s /usr/lib/jvm/java-21-openjdk-amd64 /opt/coldfusion/jre

# Bake everything in at build time so the classpath is fully resolved on boot, and uninstall admin UI/API packages
RUN /opt/coldfusion/cfusion/bin/cfpm.sh install postgresql,graphqlclient,ai,document,pdf,caching && \
    /opt/coldfusion/cfusion/bin/cfpm.sh uninstall administrator,adminapi || true

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

# Harden webroot, strip all static SQL/Markdown/Git/Docker metadata, remove /CFIDE completely,
# suppress Tomcat version/error banners in server.xml, disable CFAdminFilter 302 redirects in web.xml,
# and ensure all /CFIDE or missing requests return clean 404 JSON
RUN find /app -type f \( -name "*.sql" -o -name "*.md" -o -name "*.MD" -o -name "Dockerfile" -o -name "*.yaml" -o -name "*.yml" \) -delete && \
    rm -rf /app/.git /app/.gitignore /app/.dockerignore /app/.gcloudignore /app/.DS_Store \
           /opt/coldfusion/cfusion/wwwroot/CFIDE \
           /app/CFIDE && \
    mkdir -p /opt/coldfusion/cfusion/wwwroot/CFIDE/administrator /app/CFIDE/administrator && \
    for f in /opt/coldfusion/cfusion/wwwroot/CFIDE/adminnotinstalled.cfm \
             /opt/coldfusion/cfusion/wwwroot/CFIDE/index.cfm \
             /opt/coldfusion/cfusion/wwwroot/CFIDE/administrator/index.cfm \
             /app/CFIDE/adminnotinstalled.cfm \
             /app/CFIDE/index.cfm \
             /app/CFIDE/administrator/index.cfm; do \
        printf '<cfscript>cfheader(statusCode=404);cfcontent(type="application/json");writeOutput(serializeJson({"error":true,"message":"Not Found"}));abort;</cfscript>' > "$f"; \
    done && \
    if [ -f /opt/coldfusion/cfusion/runtime/conf/server.xml ]; then \
        sed -i 's|</Host>|        <Valve className="org.apache.catalina.valves.ErrorReportValve" showReport="false" showServerInfo="false" /></Host>|g' /opt/coldfusion/cfusion/runtime/conf/server.xml; \
    fi && \
    if [ -f /opt/coldfusion/cfusion/wwwroot/WEB-INF/web.xml ]; then \
        sed -i 's|<url-pattern>/CFIDE/administrator/\*</url-pattern>|<url-pattern>/__disabled_cfide_admin__/*</url-pattern>|g' /opt/coldfusion/cfusion/wwwroot/WEB-INF/web.xml; \
        sed -i 's|<url-pattern>/CFIDE/adminapi/\*</url-pattern>|<url-pattern>/__disabled_cfide_api__/*</url-pattern>|g' /opt/coldfusion/cfusion/wwwroot/WEB-INF/web.xml; \
        sed -i 's|<url-pattern>/CFIDE/main/ide\.cfm</url-pattern>|<url-pattern>/__disabled_rds_ide__</url-pattern>|g' /opt/coldfusion/cfusion/wwwroot/WEB-INF/web.xml; \
        sed -i 's|<url-pattern>/CFIDE/GraphData</url-pattern>|<url-pattern>/__disabled_graphdata__</url-pattern>|g' /opt/coldfusion/cfusion/wwwroot/WEB-INF/web.xml; \
        sed -i 's|<url-pattern>/CFIDE/GraphData\.cfm</url-pattern>|<url-pattern>/__disabled_graphdata_cfm__</url-pattern>|g' /opt/coldfusion/cfusion/wwwroot/WEB-INF/web.xml; \
        sed -i 's|<url-pattern>/rest/\*</url-pattern>|<url-pattern>/__disabled_rest__/*</url-pattern>|g' /opt/coldfusion/cfusion/wwwroot/WEB-INF/web.xml; \
        sed -i 's|<url-pattern>/flex2gateway/\*</url-pattern>|<url-pattern>/__disabled_flex2__/*</url-pattern>|g' /opt/coldfusion/cfusion/wwwroot/WEB-INF/web.xml; \
        sed -i 's|<url-pattern>/flashservices/gateway/\*</url-pattern>|<url-pattern>/__disabled_flash__/*</url-pattern>|g' /opt/coldfusion/cfusion/wwwroot/WEB-INF/web.xml; \
        sed -i 's|<url-pattern>/cfformgateway/\*</url-pattern>|<url-pattern>/__disabled_cfform__/*</url-pattern>|g' /opt/coldfusion/cfusion/wwwroot/WEB-INF/web.xml; \
        sed -i 's|<url-pattern>/WSRPProducer/\*</url-pattern>|<url-pattern>/__disabled_wsrp__/*</url-pattern>|g' /opt/coldfusion/cfusion/wwwroot/WEB-INF/web.xml; \
    fi && \
    if [ -d /opt/coldfusion/cfusion/wwwroot/WEB-INF/exception ]; then \
        for f in /opt/coldfusion/cfusion/wwwroot/WEB-INF/exception/*.cfm; do \
            printf '<cfscript>cfheader(statusCode=404);cfcontent(type="application/json");writeOutput(serializeJson({"error":true,"message":"Not Found"}));abort;</cfscript>' > "$f"; \
        done; \
    fi