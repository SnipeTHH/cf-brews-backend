<cfscript>
/**
 * ========================================================================
 * API ENDPOINT: SYSTEM INFO (ADOBE COLDFUSION)
 * ========================================================================
 *
 * PURPOSE: Returns basic server information to display in the sidebar footer.
 *
 * ========================================================================
 */

    response = {
        "success": true,
        "info": {
            "cf_version": "CF-Brews Runtime v1.0",
            "os_version": "Cloud Run Container"
        }
    };

    writeOutput(serializeJson(response));
</cfscript>