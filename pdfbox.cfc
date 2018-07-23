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

    var fileInputStream = getFileInputStream( src );
    var reader = getPDDocument();
    variables.pdf = reader.load( fileInputStream );

    return this;
  }

  /**
  * https://stackoverflow.com/questions/14454387/pdfbox-how-to-flatten-a-pdf-form#19723539
  * @hint Flattens any forms on the pdf
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

    return this;
  }

  /**
  * @hint Removes the javascript embedded in the document itself
  */
  public any function removeEmbeddedJavaScript() {
    var documentTree = createObject( 'java', 'org.apache.pdfbox.pdmodel.PDDocumentNameDictionary' ).init( variables.pdf.getDocumentCatalog() );
    var jsTreeNode = documentTree.getJavaScript();
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