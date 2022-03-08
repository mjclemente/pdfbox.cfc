component {

  this.name               = "pdfboxcfc Tests";
  this.sessionManagement  = true;
  this.setClientCookies   = true;
  this.sessionTimeout     = createTimespan(0, 0, 15, 0);
  this.applicationTimeout = createTimespan(0, 0, 15, 0);

  testsPath                 = getDirectoryFromPath(getCurrentTemplatePath());
  this.mappings["/tests"]   = testsPath;
  rootPath                  = reReplaceNoCase(this.mappings["/tests"], "tests(\\|/)", "");
  this.mappings["/root"]    = rootPath;
  this.mappings["/pdfbox"]  = rootPath;
  this.mappings["/testbox"] = rootPath & "/testbox";

  this.javaSettings = {
    loadPaths              : directoryList(this.mappings["/pdfbox"] & "/lib", true, "array", "*jar"),
    loadColdFusionClassPath: true,
    reloadOnChange         : false,
  };

}
