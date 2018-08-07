component {

  this.title = "pdfbox.cfc";
  this.author = "Matthew J. Clemente";
  this.webURL = "https://github.com/mjclemente/pdfbox.cfc";
  this.description = "Utilize the PDFBox Java library to manipulate PDFs.";

  function configure(){
    settings = {};
  }

  function onLoad(){
    binder.map( "pdfbox@pdfboxcfc" )
      .to( "#moduleMapping#.pdfbox" );
  }

}