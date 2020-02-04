--[[
        Info.lua
--]]

return {
    appName = "Reportamus",
    author = "Rob Cole",
    authorsWebsite = "www.robcole.com",
    donateUrl = "http://www.robcole.com/Rob/Donate",
    platforms = { 'Windows', 'Mac' },
    pluginId = "com.robcole.lightroom.Reportamus",
    xmlRpcUrl = "http://www.robcole.com/Rob/_common/cfpages/XmlRpc.cfm",
    LrPluginName = "rc Reportamus",
    LrSdkMinimumVersion = 3.0,
    LrSdkVersion = 5.0,
    LrPluginInfoUrl = "http://www.robcole.com/Rob/ProductsAndServices/ReportamusLrPlugin",
    LrPluginInfoProvider = "ReportamusManager.lua",
    LrToolkitIdentifier = "com.robcole.Reportamus",
    LrInitPlugin = "Init.lua",
    LrShutdownPlugin = "Shutdown.lua",
    LrMetadataTagsetFactory = "Tagsets.lua",
    LrHelpMenuItems = {
    {
        title = "General Help",
        file = "mHelp.lua",
    },
    },
    LrExportMenuItems = {
        {
            title = "Keyword &Report",
            file = "mKeywordReport.lua",
        },
    },
    VERSION = { display = "1.3    Build: 2013-08-12 13:51:14" },
}
