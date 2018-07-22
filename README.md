# pdfbox.cfc
Utilize the PDFBox Java library to manipulate PDFs with CFML

## Table of Contents

- [Getting Started](#getting-started)
- [Reference Manual](#reference-manual)
- [Requirements](#requirements)

### Getting Started
TODO

### Reference Manual
TODO

### Requirements

This component depends on the .jar files contained in the `/lib` directory. All of these files can be downloaded from https://pdfbox.apache.org/download.cgi

There are two ways that you can include them in your project.

1. Include the files in your `<cf_root>/lib` directory. You will need to restart the ColdFusion server.
2. Use `this.javaSettings` in your Application.cfc to load the .jar files. Just specify the directory that you place them in; something along the lines of

	```cfc
  	this.javaSettings = {
    	loadPaths = [ '.\path\to\jars\' ]
  	};
	```