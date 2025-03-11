# pdfbox.cfc <!-- omit in toc -->
Utilize the PDFBox Java library to manipulate PDFs with CFML.

_This is an early stage project. Feel free to use the issue tracker to report bugs or suggest improvements._

__Why not just use `cfpdf` and `cfdocument`?__

CFML's built in methods have their place - if they work for you, keep using them.

PDFBox's performance is generally faster that CFML's built in functions, particularly for extracting text. It provides more fine-grained control and insight into the underlying structures and data that make up a PDF (forms, links, javascript, metadata, etc.). Some PDF functionality is restricted to certain ColdFusion versions and engines, while PDFBox functions the same across engines and versions, providing flexibility in a codebase.

## Table of Contents <!-- omit in toc -->
- [Getting Started](#getting-started)
  - [Reference Manual](#reference-manual)
  - [Requirements](#requirements)
  - [Disclaimer](#disclaimer)
- [Questions](#questions)
- [Contributing](#contributing)

## Getting Started
Instances of `pdfbox.cfc` are created by passing it the absolute path to a PDF document or a PDF file input stream; the component then provides methods for working with that PDF. It's not a singleton, so it shouldn't be stored in a permanent scope; you need to instantiate `pdfbox.cfc` for each PDF you're working with.

```cfc
pdf = new pdfbox( src = 'absolute/path/to/pdf' );
```

Once created, `pdfbox.cfc` provides a growing list of actions you can take on the PDF. For example:

```cfc
//Extract Text
text = pdf.getText();

//Flatten a form
pdf.flatten();

//Save a copy of the edited pdf
pdf.save( expandPath( "./output/flattened.pdf" ) );
```

### Reference Manual
#### `getText()`
Returns the text extracted from the PDF document.

#### `getPageText( required numeric startpage, numeric endpage = 0 )`
Returns the text extracted from specific pages of the pdf document. The `endpage` argument defaults to the same as the `startpage` if not provided.

#### `getTextAsHtml()`
Returns the text extracted from the PDF, wrapped in simple html. The underlying class used is [PDFText2HTML](https://pdfbox.apache.org/docs/2.0.8/javadocs/org/apache/pdfbox/tools/PDFText2HTML.html).

#### `drawRectangle( required numeric page, required numeric x, required numeric y, required numeric width, required numeric height, numeric lineWidth = 2, string color = "black")`
Draws a rectangle on the PDF at given coordinates.

#### `flatten()`
Flattens any forms on the pdf.

__Note__: Data in XFA forms is not visible after this process. Chrome/Firefox/Safari/Preview no longer support XFA PDFs; the format seems to be on its way out and is only supported by Adobe (via Acrobat) and IE. Adobe ColdFusion does not allow cfpdf's 'sanitize' action on PDFs with XFA content.

#### `listAnnotations()`
Returns all annotations within the pdf as an array; the type of each object returned is [PDAnnotation](https://pdfbox.apache.org/docs/2.0.8/javadocs/org/apache/pdfbox/pdmodel/interactive/annotation/PDAnnotation.html), so you'll need to look at the javadocs for that to see what methods are available.

#### `removeAnnotations()`
Strips out comments and other annotations.

__Note__: Form fields are made visible/usable via annotations (as I understand it); consequently, removing all annotations renders forms, effectively, invisible and unusable, though the markup remains present (visible via a PDF Debugger). The default behavior of `pdfbox.cfc`, therefore, is to leave annotations related to forms present, so that the forms remain functional. While you can remove form annotations by setting `preserveForm = false`, the better approach is to use `flatten()`.

Additionally, be aware that links are a type of annotation ([PDAnnotationLink](https://pdfbox.apache.org/docs/2.0.8/javadocs/org/apache/pdfbox/pdmodel/interactive/annotation/PDAnnotationLink.html)) so they're removed by this method.

#### `removeEmbeddedFiles()`
Removes embedded files.

#### `removeJavaScript()`
Attempts to remove all javascript from the PDF. Javascript can appear in a lot of places; this tackles the standard locations. If more are found, they'll be incorporated here.

#### `removeEmbeddedJavaScript()`
Removes the javascript embedded in the document itself.

#### `removeDocumentJavaScriptActions()`
Removes the actions that can be triggered on open, before close, before/after printing, and before/after saving.

#### `removeFormFieldActions()`
Removes actions embedded in the form fields ( triggered onFocus, onBlur, etc )

#### `removeLinkActions()`
Removes actions embedded in the links ( triggered onFocus, onBlur, etc )

#### `removeMetaData()`
Removes metadata from the document.

#### `removeEmbeddedIndex()`
If there is an embedded search index, this removes it (at least instances of an embedded searches that I've encountered).

#### `removeBookmarks()`
Removes the document outline (bookmarks)

#### `sanitize()`
Modeled after `cfpdf`'s "sanitize" action, this runs all data removal methods on the PDF. As new methods are added to the component, they'll be added here as well. Please be aware that I'm not a PDF expert and make no claims that this is a comprehensive sanitization. Sensitive data may remain in the PDF, even after running this method.

#### `addPages( required any pdfPages )`
Add a page or pages to the end of the PDF. The `pdfPages` argument must be either the absolute path to a pdf file on disk, or a ColdFusion PDF object like those created via `cfdocument`.

#### `splitPages( required string dest, required numeric startpage, required numeric endpage )`
Split pages from the source pdf into a separate file. The `dest` argument provides the location for the new file. The `startpage` is the first page to include in the new file, up to and including the `endpage`.

#### `save( string dest = "" )`
By default, this saves the PDF to the same path that it was loaded from. You can use the `dest` argument to save the modified PDF to a new location. If the destination does not exist, it is created automatically. Note that the `dest` argument is required in order to save PDFs loaded from file input streams.

__Note__: For convenience, saving the document also automatically closes the PDFBox instance that was created, so it should be the last thing you do with this object.

#### `close()`
PDFBox instances that opened also need to be closed. While calling `save()` will close them automatically, if you're just extracting data from a PDF, it's preferable to just manually close it using this method.

#### `getVersion()`
Returns the version of the underlying PDFBox Java library being used.

#### `getAcroForm()`
If present, this returns the Acroform object. I haven't put this to any use yet. It's more a placeholder for future development.

#### `getEmbeddedFiles()`
If the pdf includes embedded files, this returns them as a struct.

#### `hasEmbeddedSearchIndex()`
Checks to see if an embedded search index can be found in the pdf. This includes the same disclaimer as `removeEmbeddedIndex()` - that is, it checks the places that I've seen embedded search indexes. If different search index locations are found, it will be updated.

#### `getDocumentOutlineTitles()`
Returns an array of with the titles for the document outline sections (bookmarks). I only added this to make it easier to confirm that the outline was being removed via `removeBookmarks()`


#### Other Methods Not Mentioned Here
For methods not explicity provided, this project uses `onMissingMethod()` to invoke the underlying PDFBox library class for `PDDocument`, which is its in-memory representation of the PDF document, documented [here](https://pdfbox.apache.org/docs/2.0.13/javadocs/org/apache/pdfbox/pdmodel/PDDocument.html). Consequently, you can utilize some of the methods provided by PDFBox directly. For example, `pdfbox.getNumberOfPages()` will return the number of pages the document has; it does this by delegating to the [`getNumberOfPages()`](https://pdfbox.apache.org/docs/2.0.13/javadocs/org/apache/pdfbox/pdmodel/PDDocument.html#getNumberOfPages--) method in the `PDDocument` class.

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

#### Lucee CFML Specific Jar Option

When using `pdfbox.cfc` with Lucee CFML, you have the option to provide the directory that contains the PDFBox .jar files when initializing the object:

```cfc
  classpath = expandPath( "/path/to/pdfbox/jars" );

  // will use the PDFBox jars in the class path provided
  pdf = new pdfbox( src = 'absolute/path/to/pdf', classpath );
```

This can be helpful if you want to avoid using `this.javaSettings` (for example, because of [LDEV-2516](https://luceeserver.atlassian.net/browse/LDEV-2516)).

To be clear, this approach 1) is not possible with Adobe ColdFusion, 2) is not required for Lucee, and 3) when used with Lucee, means that you do *not* need to add the .jars to your `<cf_root>/lib` directory or `this.javasettings`.

### Disclaimer
PDFs can be suprisingly complex; the [spec for the PDF document format](https://www.adobe.com/content/dam/acom/en/devnet/acrobat/pdfs/pdf_reference_1-7.pdf) available online is, no joke, 1,300 pages. While I've browsed it, I am not an expert. As a consequence, you should verify that this component doing what you expect, particularly when it comes to the data sanitization methods. Metadata, javascript, and other functionality and information can be encoded in a range of places within a PDF. As I learn about and encounter examples of these, I'm happy to address them with this component, insofar as it's possible with the underlying PDFBox library.

## Questions
For questions that aren't about bugs, feel free to hit me up on the [CFML Slack Channel](http://cfml-slack.herokuapp.com); I'm @mjclemente. You'll likely get a much faster response than creating an issue here.

## Contributing
:+1::tada: First off, thanks for taking the time to contribute! :tada::+1:

Before putting the work into creating a PR, I'd appreciate it if you opened an issue. That way we can discuss the best way to implement changes/features, before work is done.

Changes should be submitted as Pull Requests on the `develop` branch.
