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

    // Helper to safely get values from the server scope
    function getSafeServerInfo(scope, key, defaultValue="Unknown") {
        if (structKeyExists(server, scope) && structKeyExists(server[scope], key)) {
            return server[scope][key];
        }
        return defaultValue;
    }

    // 1. Adobe ColdFusion Version
    cfName = getSafeServerInfo("coldfusion", "productname", "ColdFusion");
    cfVer = getSafeServerInfo("coldfusion", "productversion", "");
    engineInfo = trim(cfName & " " & cfVer);

    // 2. OS Information
    osName = getSafeServerInfo("os", "name");
    osArch = getSafeServerInfo("os", "arch", "");
    osInfo = trim(osName & " " & (len(osArch) ? "(" & osArch & ")" : ""));

    response = {
        "success": true,
        "info": {
            "cf_version": engineInfo,
            "os_version": osInfo
        }
    };

    writeOutput(serializeJson(response));
</cfscript>