/**
* pdfbox.cfc
* Copyright 2018 Matthew Clemente
* Licensed under MIT (https://github.com/mjclemente/pdfbox.cfc/blob/master/LICENSE)
*/
component output="false" displayname="pdfbox.cfc"  {

  /**
  * @hint
  * @src must be the absolute path to an on-disk pdf file
  */
  public any function init( required string src ) {

    variables.src = src;
    variables.hasMetadata = true;

    var fileInputStream = getFileInputStream( src );
    var reader = getPDDocument();
    variables.pdf = reader.load( fileInputStream );

    variables.additionalDocuments = [];

    return this;
  }

  /**
  * https://pdfbox.apache.org/docs/2.0.8/javadocs/org/apache/pdfbox/text/PDFTextStripper.html
  * @hint returns the text extracted from the pdf document.
  */
  public any function getText() {
    var stripper = createObject( 'java', 'org.apache.pdfbox.text.PDFTextStripper' ).init();
    stripper.setSortByPosition( true );
    return stripper.getText( variables.pdf );
  }

  /**
  * https://pdfbox.apache.org/docs/2.0.8/javadocs/org/apache/pdfbox/tools/PDFText2HTML.html
  * @hint returns the text extracted from the pdf, wrapped in simple html
  */
  public any function getTextAsHtml() {
    var stripper = stripper = createObject( 'java', 'org.apache.pdfbox.tools.PDFText2HTML' ).init();
    return stripper.getText( variables.pdf );
  }

  /**
  * https://memorynotfound.com/apache-pdfbox-adding-meta-data-pdf-document/
  * https://svn.apache.org/viewvc/pdfbox/trunk/examples/src/main/java/org/apache/pdfbox/examples/pdmodel/ExtractMetadata.java?view=markup
  * @hint Set the document title in metadata and document information
  */
  public any function setTitle( required string title ) {
    if ( variables.hasMetadata )
      throw( 'Existing metadata must be removed before new metadata can be set.' );

    var documentInfo = variables.pdf.getDocumentInformation();
    documentInfo.setTitle( title );

    var XMPMetadata = createObject( 'java', 'org.apache.xmpbox.XMPMetadata' );
    var metadata = XMPMetadata.createXMPMetadata();

    var dcSchema = metadata.createAndAddDublinCoreSchema();
    dcSchema.setTitle( title );

    var serializer = createObject( 'java', 'org.apache.xmpbox.xml.XmpSerializer' );
    var baos = createObject( 'java', 'java.io.ByteArrayOutputStream' ).init();
    serializer.serialize( metadata, baos, true );
    var metadataStream = createObject( 'java', 'org.apache.pdfbox.pdmodel.common.PDMetadata' ).init( variables.pdf );
    metadataStream.importXMPMetadata( baos.toByteArray() );
    variables.pdf.getDocumentCatalog().setMetadata( metadataStream );

    return this;
  }

  /**
  * https://stackoverflow.com/questions/14454387/pdfbox-how-to-flatten-a-pdf-form#19723539
  * @hint Flattens any forms on the pdf
  * Note that data in XFA forms is not visible after this process. Chrome/Firefox/Safari/Preview no longer support XFA PDFs; the format seems to be on its way out and is only supported by Adobe (via Acrobat) and IE. Adobe ColdFusion does not allow cfpdf's 'sanitize' action on PDFs with XFA content.
  */
  public any function flatten() {

    var PDAcroForm = variables.pdf.getDocumentCatalog().getAcroForm();

    if ( !isNull( PDAcroForm ) )
      PDAcroForm.flatten();

    return this;
  }

  /**
  * https://pdfbox.apache.org/docs/2.0.8/javadocs/org/apache/pdfbox/pdmodel/interactive/annotation/PDAnnotation.html
  * @hint returns all annotations within the pdf as an array; the type of each object returned is PDAnnotation, so you'll need to look at the javadocs for that to see what methods are available
  */
  public array function listAnnotations() {
    var annotations = [];
    var pages = variables.pdf.getPages();
    var iterator = pages.iterator();

    while( iterator.hasNext() ) {
      var page = iterator.next();
      annotations.append( page.getAnnotations(), true );
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
  public any function removeAnnotations( boolean preserveForm = true ) {
    var pages = variables.pdf.getPages();
    var iterator = pages.iterator();

    while( iterator.hasNext() ) {
      var page = iterator.next();

      if ( !preserveForm ) {
        page.setAnnotations( javaCast( 'null', '' ) );
      } else {
        var annotations = [];
        var annotationIterator = page.getAnnotations().iterator();

        while( annotationIterator.hasNext() ) {
          var annotation = annotationIterator.next();
          if ( annotation.getSubtype() == 'Widget' ) {
            annotations.append( annotation );
          }
        }
        page.setAnnotations( annotations );
      }
    }
    return this;
  }

  /**
  * https://stackoverflow.com/questions/17019960/extract-embedded-files-from-pdf-using-pdfbox-in-net-application
  * https://github.com/Valuya/fontbox/blob/master/examples/src/main/java/org/apache/pdfbox/examples/pdmodel/EmbeddedFiles.java
  * @hint Removes embedded files
  */
  public any function removeEmbeddedFiles() {
    var documentTree = createObject( 'java', 'org.apache.pdfbox.pdmodel.PDDocumentNameDictionary' ).init( variables.pdf.getDocumentCatalog() );
    var fileTreeNode = documentTree.getEmbeddedFiles();
    if ( !isNull( fileTreeNode ) )
      fileTreeNode.getCOSObject().clear();
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
    var documentTree = createObject( 'java', 'org.apache.pdfbox.pdmodel.PDDocumentNameDictionary' ).init( variables.pdf.getDocumentCatalog() );
    var jsTreeNode = documentTree.getJavaScript();
    if ( !isNull( jsTreeNode ) )
      jsTreeNode.getCOSObject().clear();
    return this;
  }

  /**
  * https://pdfbox.apache.org/docs/2.0.8/javadocs/org/apache/pdfbox/pdmodel/interactive/action/PDDocumentCatalogAdditionalActions.html
  * @hint Removes the actions that can be triggered on open, before close, before/after printing, and before/after saving
  */
  public any function removeDocumentJavaScriptActions() {

    var catalog = variables.pdf.getDocumentCatalog();
    catalog.setOpenAction( javaCast( 'null', '' ) );

    var actions = catalog.getActions();
    actions.setDP( javaCast( 'null', '' ) );
    actions.setDS( javaCast( 'null', '' ) );
    actions.setWC( javaCast( 'null', '' ) );
    actions.setWP( javaCast( 'null', '' ) );
    actions.setWS( javaCast( 'null', '' ) );

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

    if ( !isNull( PDAcroForm ) ) {
      var iterator = PDAcroForm.getFieldIterator();

      while( iterator.hasNext() ) {
        var formField = iterator.next();
        var formFieldActions = formField.getActions();

        if ( !isNull( formFieldActions ) ) {
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
    var pages = variables.pdf.getPages();
    var iterator = pages.iterator();

    while( iterator.hasNext() ) {
      var page = iterator.next();

      var annotationIterator = page.getAnnotations().iterator();

      while( annotationIterator.hasNext() ) {
        var annotation = annotationIterator.next();

        if ( annotation.getSubtype() == 'Link' ) {

          var action = annotation.getAction();
          if ( !isNull( action ) && action.getSubType() == 'JavaScript' ) {
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
    documentInfo.setAuthor( javaCast( 'null', '' ) ); //dcSchema addCreator()
    documentInfo.setCreationDate( javaCast( 'null', '' ) );
    documentInfo.setCreator( javaCast( 'null', '' ) );
    documentInfo.setKeywords( javaCast( 'null', '' ) );
    documentInfo.setModificationDate( javaCast( 'null', '' ) );
    documentInfo.setProducer( javaCast( 'null', '' ) ); //i.e. Acrobat Pro DC
    documentInfo.setSubject( javaCast( 'null', '' ) ); //description
    documentInfo.setTitle( javaCast( 'null', '' ) );
    documentInfo.setTrapped( javaCast( 'null', '' ) );

    var XMPMetadata = createObject( 'java', 'org.apache.xmpbox.XMPMetadata' );
    var metadata = XMPMetadata.createXMPMetadata();

    var serializer = createObject( 'java', 'org.apache.xmpbox.xml.XmpSerializer' );
    var baos = createObject( 'java', 'java.io.ByteArrayOutputStream' ).init();
    serializer.serialize( metadata, baos, true );
    var metadataStream = createObject( 'java', 'org.apache.pdfbox.pdmodel.common.PDMetadata' ).init( variables.pdf );
    metadataStream.importXMPMetadata( baos.toByteArray() );
    variables.pdf.getDocumentCatalog().setMetadata( metadataStream );

    variables.hasMetadata = false;

    return this;
  }

  /**
  * https://lists.apache.org/thread.html/801ea985610d3adf51cb69103729797af3a745a9364bc3f442f80384@%3Cusers.pdfbox.apache.org%3E
  * @hint If there is an embedded search index, this removes it (at least instances of an embedded searches that I've seen)
  */
  public any function removeEmbeddedIndex() {
    var searchIndex = variables.pdf.getDocumentCatalog().getCOSObject().getItem( "PieceInfo" );
    if ( !isNull( searchIndex ) )
      searchIndex.clear();

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
    .removeMetaData();

    return this;
  }

  /**
  * @hint Add a page or pages to the end of the pdf.
  * @pdfPages must be either the absolute path to a pdf file on disk, or a coldfusion pdf object
  */
  public any function addPages( required any pdfPages ) {
    var reader = getPDDocument();

    if ( isSimpleValue( pdfPages ) && fileExists( pdfPages ) && fileGetMimeType( pdfPages ) == 'application/pdf' ) {

      var tempPdf = reader.load( getFileInputStream( pdfPages ) );

    } else if ( isPDFObject( pdfPages ) ) {

      var tempPdf = reader.load( pdfPages );

    } else {

      reader.close();
      throw( 'The argument passed to #getFunctionCalledName()# is not valid. It should either be the absolute path to a valid pdf file, or ColdFusion pdf object.' );
    }

    var pages = tempPdf.getPages();

    var iterator = pages.iterator();

    while ( iterator.hasNext() ) {
      var page = iterator.next();
      variables.pdf.addPage( page );

    }

    //save it to the array for closing later
    variables.additionalDocuments.append( tempPdf );

    return this;
  }

  /**
  * @hint By default, the file is saved to the same path that it was loaded from.
  *
  * Note that saving the document also automatically closes the instance of the PDDocument that was created, so it should be the last thing you do with this object.
  *
  * @dest Override the path to save the modified pdf to a new location. If the destination does not exist, it is created automatically
  */
  public void function save( string dest = "" ) {

    if ( dest.len() ) {
      var directory = GetDirectoryFromPath( dest );

      if ( !directoryExists( directory ) )
        directoryCreate( directory );
    }

    variables.pdf.save( dest.len() ? dest : variables.src );
    close();
  }

  /**
  * @hint pdf documents that are opened need to be closed. Calling save() will close them automatically, but if you're working with them in some other way, you'll need to manually close them.
  */
  public void function close() {
    variables.pdf.close();

    for ( var tempPdf in variables.additionalDocuments ) {
      tempPdf.close();
    }
    variables.additionalDocuments = [];
  }

  private any function getFileInputStream( required string src ) {
    return createObject( "java", "java.io.FileInputStream" ).init(
      javaCast( "string", src )
    );
  }

  private any function getPDDocument() {
    return createObject( 'java', 'org.apache.pdfbox.pdmodel.PDDocument' );
  }

}