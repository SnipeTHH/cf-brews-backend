<cfscript>
    cfheader(statusCode=200);
    cfheader(name="Content-Type", value="application/json");
    writeOutput(serializeJson({
        "status": "ok",
        "service": "cf-brews-api"
    }));
</cfscript>