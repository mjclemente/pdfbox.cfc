/**
 * pdfbox.cfc
 * Copyright 2018-2022 Matthew Clemente
 * Licensed under MIT (https://github.com/mjclemente/pdfbox.cfc/blob/master/LICENSE)
 */
component output="false" displayname="pdfbox.cfc" {

  /**
   * @hint
   * @src must be the absolute path to an on-disk pdf file or a file input stream
   * @classPath a Lucee specific option; provide the path to a directory containing the PDFBox class files.
   */
  public any function init(required any src, string classPath = "") {
    variables.serverVersion = server.keyExists("lucee") ? "Lucee" : "ColdFusion";

    if( variables.serverVersion != "Lucee" && len(arguments.classPath) ){
      throw("Sorry, the option to provide a class path to the PDFBox jars is only available with Lucee CFML.");
    }

    variables.classPath = arguments.classPath;

    variables.src = isSimpleValue(arguments.src)
     ? arguments.src
     : "";

    variables.hasMetadata = true;

    var buffered_file = isSimpleValue(src)
     ? getRandomAccessReadBufferedFile(src)
     : src;

    variables.pdf    = getPDDocument(buffered_file);

    variables.additionalDocuments = [];

    return this;
  }

  public string function getVersion() {
    return createObjectHelper("org.apache.pdfbox.util.Version").getVersion();
  }

  /**
   * https://pdfbox.apache.org/docs/2.0.8/javadocs/org/apache/pdfbox/text/PDFTextStripper.html
   * @hint returns the text extracted from the pdf document.
   */
  public any function getText() {
    var stripper = createObjectHelper("org.apache.pdfbox.text.PDFTextStripper").init();
    stripper.setSortByPosition(true);

    // https://github.com/mjclemente/pdfbox.cfc/issues/2
    try {
      return stripper.getText(variables.pdf);
    } catch( any e ){
      var stderr = createObject("java", "java.lang.System").err;
      stderr.println("Pdfbox.cfc cannot getText(): #e.message#");
      return "";
    }
  }

  /**
   * https://pdfbox.apache.org/docs/2.0.8/javadocs/org/apache/pdfbox/text/PDFTextStripper.html
   * @hint returns the text extracted from specific pages of the pdf document.
   */
  public any function getPageText(required numeric startpage, numeric endpage = 0) {
    var stripper = createObjectHelper("org.apache.pdfbox.text.PDFTextStripper").init();
    stripper.setSortByPosition(true);
    stripper.setStartPage(startpage);
    if( endpage ){
      stripper.setEndPage(endpage);
    } else {
      stripper.setEndPage(startpage);
    }

    return stripper.getText(variables.pdf);
  }

  /**
   * https://pdfbox.apache.org/docs/2.0.8/javadocs/org/apache/pdfbox/tools/PDFText2HTML.html
   * @hint returns the text extracted from the pdf, wrapped in simple html
   */
  public any function getTextAsHtml() {
    var stripper = createObjectHelper("org.apache.pdfbox.tools.PDFText2HTML").init();
    return stripper.getText(variables.pdf);
  }

  /**
   * https://memorynotfound.com/apache-pdfbox-adding-meta-data-pdf-document/
   * https://svn.apache.org/viewvc/pdfbox/trunk/examples/src/main/java/org/apache/pdfbox/examples/pdmodel/ExtractMetadata.java?view=markup
   * @hint Set the document title in metadata and document information
   */
  public any function setTitle(required string title) {
    if( variables.hasMetadata ) throw("Existing metadata must be removed before new metadata can be set.");

    var documentInfo = variables.pdf.getDocumentInformation();
    documentInfo.setTitle(title);

    var XMPMetadata = createObjectHelper("org.apache.xmpbox.XMPMetadata");
    var metadata    = XMPMetadata.createXMPMetadata();

    var dcSchema = metadata.createAndAddDublinCoreSchema();
    dcSchema.setTitle(title);

    var serializer = createObjectHelper("org.apache.xmpbox.xml.XmpSerializer");
    var baos       = createObject("java", "java.io.ByteArrayOutputStream").init();
    serializer.serialize(metadata, baos, true);
    var metadataStream = createObjectHelper("org.apache.pdfbox.pdmodel.common.PDMetadata").init(variables.pdf);
    metadataStream.importXMPMetadata(baos.toByteArray());
    variables.pdf.getDocumentCatalog().setMetadata(metadataStream);

    return this;
  }

    /**
   * @hint x and y coordinates here are assumed to be given from the top left corner of the page
   * @color options are black, yellow, blue, or red for now
   */
  public any function drawRectangle(
    required numeric page,
    required numeric x,
    required numeric y,
    required numeric width,
    required numeric height,
    numeric lineWidth = 2,
    string color = "black"
  ) {
    // pdfbox uses 0-based indexing, so we need to subtract 1 from the page number
    var page = variables.pdf.getPage(arguments.page - 1);
    var contentStream = createObjectHelper("org.apache.pdfbox.pdmodel.PDPageContentStream").init(variables.pdf, page, true, true);
    contentStream.setLineWidth(arguments.lineWidth);

    // we need to adjust because pdfbox calculates y from the bottom of the page
    var pageHeight = page.getMediaBox().getHeight();
    var adjustedY = pageHeight - arguments.y - arguments.height;

    contentStream.addRect(arguments.x, adjustedY, arguments.width, arguments.height)

    if( arguments.color == "black") {
      contentStream.setStrokingColor(createObject("java", "java.awt.Color").init(0, 0, 0));
    } else if (arguments.color == "yellow") {
      contentStream.setStrokingColor(createObject("java", "java.awt.Color").init(1, 1, 0));
    } else if (arguments.color == "blue") {
      contentStream.setStrokingColor(createObject("java", "java.awt.Color").init(0, 0, 1));
    } else if (arguments.color == "red") {
      contentStream.setStrokingColor(createObject("java", "java.awt.Color").init(1, 0, 0));
    }

    contentStream.stroke();
    contentStream.close();

    return this;
  }

  /**
   * https://stackoverflow.com/questions/14454387/pdfbox-how-to-flatten-a-pdf-form#19723539
   * @hint Flattens any forms on the pdf
   * Note that data in XFA forms is not visible after this process. Chrome/Firefox/Safari/Preview no longer support XFA PDFs; the format seems to be on its way out and is only supported by Adobe (via Acrobat) and IE. Adobe ColdFusion does not allow cfpdf's 'sanitize' action on PDFs with XFA content.
   */
  public any function flatten() {
    var PDAcroForm = variables.pdf.getDocumentCatalog().getAcroForm();

    if( !isNull(PDAcroForm) ) PDAcroForm.flatten();

    return this;
  }

  public any function getAcroForm() {
    return variables.pdf.getDocumentCatalog().getAcroForm();
  }

  public any function listXFAElements() {
    var PDAcroForm   = variables.pdf.getDocumentCatalog().getAcroForm();
    var documentXML  = PDAcroForm.getXFA().getDocument();
    var dataElements = documentXML.getElementsByTagName("xfa:data");
    return dataElements;
  }

  public array function getDocumentOutlineTitles() {
    var outline         = [];
    var documentOutline = variables.pdf.getDocumentCatalog().getDocumentOutline();
    if( isNull(documentOutline) ){
      return outline;
    }
    var current = documentOutline.getFirstChild();
    while( !isNull(current) ){
      outline.append(current.getTitle());
      current = current.getNextSibling();
    }

    return outline;
  }

  public any function removeBookmarks() {
    variables.pdf.getDocumentCatalog().setDocumentOutline(javacast("null", 0));
    return this;
  }

  /**
   * https://pdfbox.apache.org/docs/2.0.8/javadocs/org/apache/pdfbox/pdmodel/interactive/annotation/PDAnnotation.html
   * @hint returns all annotations within the pdf as an array; the type of each object returned is PDAnnotation, so you'll need to look at the javadocs for that to see what methods are available
   */
  public array function listAnnotations() {
    var annotations = [];
    var pages       = variables.pdf.getPages();
    var iterator    = pages.iterator();

    while( iterator.hasNext() ){
      var page = iterator.next();
      annotations.append(page.getAnnotations(), true);
    }

    return annotations;
  }

  /**
   * https://stackoverflow.com/questions/32741468/how-to-delete-annotations-in-pdf-file-using-pdfbox
   * https://lists.apache.org/thread.html/d5b5f7a1d07d4eb9c515054ae7e87bdf4aefb3f138b235f82297401d@%3Cusers.pdfbox.apache.org%3E
   * @hint Strips out comments and other annotations
   * Form fields are made visible/usable via annotations (as I understand it); consequently, removing all annotations renders forms, effectively, invisible and unusable, though the markup remains present (visible via the Debugger). The default behavior, therefore, is to leave annotations related to forms present, so that the forms remain functional. While you can remove form annotations by setting preserveForm = false, the better approach is to use flatten().
   * Reminder: Added links are a type of annotation (PDAnnotationLink) so they're removed by this method
   */
  public any function removeAnnotations(boolean preserveForm = true) {
    var pages    = variables.pdf.getPages();
    var iterator = pages.iterator();

    while( iterator.hasNext() ){
      var page = iterator.next();

      if( !preserveForm ){
        page.setAnnotations(javacast("null", ""));
      } else {
        var annotations        = [];
        var annotationIterator = page.getAnnotations().iterator();

        while( annotationIterator.hasNext() ){
          var annotation = annotationIterator.next();
          if( annotation.getSubtype() == "Widget" ){
            annotations.append(annotation);
          }
        }
        page.setAnnotations(annotations);
      }
    }
    return this;
  }

  /**
   * https://stackoverflow.com/a/36285275
   */
  public struct function getEmbeddedFiles() {
    var catalog      = variables.pdf.getDocumentCatalog();
    var documentTree = catalog.getNames();
    if( !isNull(documentTree) ){
      var embeddedFiles = documentTree.getEmbeddedFiles().getNames();
    }
    return !isNull(embeddedFiles) ? embeddedFiles : {};
  }

  /**
   * https://stackoverflow.com/questions/17019960/extract-embedded-files-from-pdf-using-pdfbox-in-net-application
   * https://github.com/Valuya/fontbox/blob/master/examples/src/main/java/org/apache/pdfbox/examples/pdmodel/EmbeddedFiles.java
   * @hint Removes embedded files
   */
  public any function removeEmbeddedFiles() {
    var catalog      = variables.pdf.getDocumentCatalog();
    var documentTree = catalog.getNames();
    if( !isNull(documentTree) ){
      var fileTreeNode = documentTree.getEmbeddedFiles();
      if( !isNull(fileTreeNode) ) fileTreeNode.getCOSObject().clear();
    }
    return this;
  }

  /**
   * @hint Attempts to remove all javascript from the pdf. Javascript can appear in a lot of places; this tackles the standard locations. If more are found, they'll be incorporated here.
   */
  public any function removeJavaScript() {
    removeEmbeddedJavaScript();

    removeDocumentJavaScriptActions();

    removeFormFieldActions();

    removeLinkActions();

    return this;
  }

  /**
   * @hint Removes the javascript embedded in the document itself
   */
  public any function removeEmbeddedJavaScript() {
    var catalog      = variables.pdf.getDocumentCatalog();
    var documentTree = catalog.getNames();
    if( !isNull(documentTree) ){
      var jsTreeNode = documentTree.getJavaScript();
      if( !isNull(jsTreeNode) ) jsTreeNode.getCOSObject().clear();
    }
    return this;
  }

  /**
   * https://pdfbox.apache.org/docs/2.0.8/javadocs/org/apache/pdfbox/pdmodel/interactive/action/PDDocumentCatalogAdditionalActions.html
   * @hint Removes the actions that can be triggered on open, before close, before/after printing, and before/after saving
   */
  public any function removeDocumentJavaScriptActions() {
    var catalog = variables.pdf.getDocumentCatalog();
    catalog.setOpenAction(javacast("null", ""));

    var actions = catalog.getActions();
    actions.setDP(javacast("null", ""));
    actions.setDS(javacast("null", ""));
    actions.setWC(javacast("null", ""));
    actions.setWP(javacast("null", ""));
    actions.setWS(javacast("null", ""));

    return this;
  }

  /**
   * https://pdfbox.apache.org/docs/2.0.8/javadocs/org/apache/pdfbox/pdmodel/interactive/action/PDFormFieldAdditionalActions.html
   * There may be another class this need to address: PDAnnotationAdditionalActions (but I'm not sure exactly how these actions are differ from those handled here).
   * For reference and future examination, PDAnnotationAdditionalActions is returned by PDAnnotationWidget (https://pdfbox.apache.org/docs/2.0.8/javadocs/org/apache/pdfbox/pdmodel/interactive/annotation/PDAnnotationWidget.html), which is the annotation type related to form fields.
   * @hint removes actions embedded in the form fields ( triggered onFocus, onBlur, etc )
   */
  public any function removeFormFieldActions() {
    var PDAcroForm = variables.pdf.getDocumentCatalog().getAcroForm();

    if( !isNull(PDAcroForm) ){
      var iterator = PDAcroForm.getFieldIterator();

      while( iterator.hasNext() ){
        var formField        = iterator.next();
        var formFieldActions = formField.getActions();

        if( !isNull(formFieldActions) ){
          formFieldActions.getCOSObject().clear();
        }
      }
    }

    return this;
  }

  /**
   * https://pdfbox.apache.org/docs/2.0.8/javadocs/org/apache/pdfbox/pdmodel/interactive/annotation/PDAnnotationLink.html
   * @hint removes actions embedded in the links ( triggered onFocus, onBlur, etc )
   */
  public any function removeLinkActions() {
    var pages    = variables.pdf.getPages();
    var iterator = pages.iterator();

    while( iterator.hasNext() ){
      var page = iterator.next();

      var annotationIterator = page.getAnnotations().iterator();

      while( annotationIterator.hasNext() ){
        var annotation = annotationIterator.next();

        if( annotation.getSubtype() == "Link" ){
          var action = annotation.getAction();
          if( !isNull(action) && action.getSubType() == "JavaScript" ){
            action.getCOSObject().clear();
          }
        }
      }
    }
    return this;
  }

  /**
   * @hint Removes metadata from the document
   *
   * Reference: metadata is stored in two separate locations in a document:
   * The Info (Document Information) - likely a key value pairing.
   * The XMP XML
   * Different PDF readers, when displaying document information may give preference to different sources. For example, Preview may read the "Author A" from Document Information, while Acrobat may ignore that and read dc:creator element from the XML and display "Author B".
   * Using the PDFDebugger bundled with PDFBox, via `java -jar pdfbox-app-2.0.11.jar PDFDebugger -viewstructure example.pdf` will provide an accurate view of both Document Information and XML metadata, and so is preferable to pdf readers
   *
   */
  public any function removeMetaData() {
    var documentInfo = variables.pdf.getDocumentInformation();
    documentInfo.setAuthor(javacast("null", "")); // dcSchema addCreator()
    documentInfo.setCreationDate(javacast("null", ""));
    documentInfo.setCreator(javacast("null", ""));
    documentInfo.setKeywords(javacast("null", ""));
    documentInfo.setModificationDate(javacast("null", ""));
    documentInfo.setProducer(javacast("null", "")); // i.e. Acrobat Pro DC
    documentInfo.setSubject(javacast("null", "")); // description
    documentInfo.setTitle(javacast("null", ""));
    documentInfo.setTrapped(javacast("null", ""));

    var XMPMetadata = createObjectHelper("org.apache.xmpbox.XMPMetadata");
    var metadata    = XMPMetadata.createXMPMetadata();

    var serializer = createObjectHelper("org.apache.xmpbox.xml.XmpSerializer");
    var baos       = createObject("java", "java.io.ByteArrayOutputStream").init();
    serializer.serialize(metadata, baos, true);
    var metadataStream = variables.pdf.getDocumentCatalog().getMetadata();
    if( !isNull(metadataStream) ){
      metadataStream.importXMPMetadata(baos.toByteArray());
      variables.pdf.getDocumentCatalog().setMetadata(metadataStream);
    }

    variables.hasMetadata = false;

    return this;
  }

  /**
   * Useful for inspecting structure: https://pdfux.com/inspect-pdf/
   * This is based on the search indexes that I've seen and may not locate them all. Would be happy to see other examples
   */
  public boolean function hasEmbeddedSearchIndex() {
    var searchIndex = variables.pdf
      .getDocumentCatalog()
      .getCOSObject()
      .getItem("PieceInfo");
    if( isNull(searchIndex) ){
      return false;
    }

    var indexName   = createObjectHelper("org.apache.pdfbox.cos.COSName").getPDFName("SearchIndex");
    var indexObject = searchIndex.getItem(indexName);
    return !isNull(indexObject);
  }

  /**
   * https://lists.apache.org/thread.html/801ea985610d3adf51cb69103729797af3a745a9364bc3f442f80384@%3Cusers.pdfbox.apache.org%3E
   * https://www.mail-archive.com/users@pdfbox.apache.org/msg10246.html
   * @hint If there is an embedded search index, this removes it (***at least instances of an embedded searches that I've seen****)
   */
  public any function removeEmbeddedIndex() {
    var searchIndex = variables.pdf
      .getDocumentCatalog()
      .getCOSObject()
      .getItem("PieceInfo");
    if( !isNull(searchIndex) && structKeyExists(searchIndex, "clear") ){
      searchIndex.clear();
    }
    if( !isNull(searchIndex) ){
      var indexName = createObjectHelper("org.apache.pdfbox.cos.COSName").getPDFName("SearchIndex");
      searchIndex.removeItem(indexName);
    }

    return this;
  }

  /**
   * @hint Runs all data removal methods on the pdf. As new methods are added to the component, they'll be added here as well. Please be aware that sensitive data may remain in the pdf, even after running this method.
   */
  public any function sanitize() {
    flatten()
      .removeAnnotations()
      .removeEmbeddedFiles()
      .removeJavaScript()
      .removeEmbeddedIndex()
      .removeMetaData()
      .removeBookmarks();

    return this;
  }

  /**
   * @hint Add a page or pages to the end of the pdf.
   * @pdfPages must be either the absolute path to a pdf file on disk, or a coldfusion pdf object
   */
  public any function addPages(required any pdfPages) {
    if( isSimpleValue(pdfPages) && fileExists(pdfPages) && fileGetMimeType(pdfPages) == "application/pdf" ){
      var tempPdf = getPDDocument(getRandomAccessReadBufferedFile(pdfPages));
    } else if( isPDFObject(pdfPages) ){
      var tempPdf = getPDDocument(pdfPages);
    } else {
      throw(
        "The argument passed to #getFunctionCalledName()# is not valid. It should either be the absolute path to a valid pdf file, or ColdFusion pdf object."
      );
    }

    var pages = tempPdf.getPages();

    var iterator = pages.iterator();

    while( iterator.hasNext() ){
      var page = iterator.next();
      variables.pdf.addPage(page);
    }

    // save it to the array for closing later
    variables.additionalDocuments.append(tempPdf);

    return this;
  }

  /**
  * @hint extracts a range of pages from the pdf and saves them to a new file
  */
  public void function splitPages(required string dest, required numeric startpage, required numeric endpage ){

    if( arguments.startpage < 1 || arguments.endpage > variables.pdf.getNumberOfPages() ){
      close();
      throw("The start and end page numbers must be within the range of the pdf document (#variables.pdf.getNumberOfPages()# pages).");
    }

    var pages       = variables.pdf.getPages();
    var iterator    = pages.iterator();

    var newPdf = getPDDocument();

    var count = 0;
    while( iterator.hasNext() ){
      var page = iterator.next();
      count++;
      if( count >= arguments.startPage && count <= arguments.endPage ){
        newPdf.addPage(page);
      }
    }

    newPdf.save(dest);

    newPdf.close();
  }

  /**
   * @hint By default, the file is saved to the same path that it was loaded from.
   *
   * Note that saving the document also automatically closes the instance of the PDDocument that was created, so it should be the last thing you do with this object.
   *
   * @dest Override the path to save the modified pdf to a new location. If the destination does not exist, it is created automatically
   */
  public void function save(string dest = "") {
    if( dest.len() ){
      var directory = getDirectoryFromPath(dest);

      if( !directoryExists(directory) ) directoryCreate(directory);
    }

    if( !dest.len() && !variables.src.len() )
      throw("You must provide a destination in order to save a pdf file input stream.");

    variables.pdf.save(dest.len() ? dest : variables.src);

    close();
  }

  /**
   * @hint pdf documents that are opened need to be closed. Calling save() will close them automatically, but if you're working with them in some other way, you'll need to manually close them.
   */
  public void function close() {
    variables.pdf.close();

    for( var tempPdf in variables.additionalDocuments ){
      tempPdf.close();
    }
    variables.additionalDocuments = [];
  }

  private any function getFileInputStream(required string src) {
    return createObject("java", "java.io.FileInputStream").init(javacast("string", src));
  }

  private any function getRandomAccessReadBufferedFile(required string src) {
    return createObject("java", "org.apache.pdfbox.io.RandomAccessReadBufferedFile").init(javacast("string", src));
  }

  private any function getPDDocument(required any fileInputStream) {
    var loader = createObjectHelper("org.apache.pdfbox.Loader");
     return loader.loadPDF(fileInputStream);
  }

  /**
   * @hint Enables us to pass a specific class path when using Lucee
   */
  private any function createObjectHelper(required string classname) {
    if( hasClassPath() ){
      return createObject(
        "java",
        classname,
        directoryList(
          expandPath(variables.classPath),
          true,
          "path",
          "",
          "",
          "file"
        )
      );
    } else {
      if( variables.serverVersion == "ColdFusion" ){
        return createObject("java", classname);
      } else {
        // right now we're handling lucee the same as ACF, but leaving this here in case we need to do something different later
        return createObject("java", classname);
      }
    }
  }

  private boolean function hasClassPath() {
    return len(variables.classPath);
  }

  public any function onMissingMethod(missingMethodName, missingMethodArguments) {
    var methodArguments = [];
    for( var index in missingMethodArguments ){
      methodArguments.append(missingMethodArguments[index]);
    }
    try {
      var result = invoke(variables.pdf, missingMethodName, methodArguments);
    } catch( any e ){
      result = e;
    }

    if( !isNull(result) ){
      return result;
    }
  }

}
