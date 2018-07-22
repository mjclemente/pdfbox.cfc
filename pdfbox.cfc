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
  * //https://stackoverflow.com/questions/14454387/pdfbox-how-to-flatten-a-pdf-form#19723539
  * @hint Flattens any forms on the pdf
  */
  public any function flatten() {

    var PDAcroForm = variables.pdf.getDocumentCatalog().getAcroForm();

    if ( !isNull( PDAcroForm ) )
      PDAcroForm.flatten();

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