/**
 * This tests the BDD functionality in TestBox. This is CF10+, Lucee4.5+
 */
component extends="testbox.system.BaseSpec" {

  /*********************************** LIFE CYCLE Methods ***********************************/

  function beforeAll() {
    variables["pdfs"] = {
      "friday" : expandPath("./resources/pdfs/friday.pdf"),
      "blank"  : expandPath("./resources/pdfs/blank.pdf"),
      "issue2" : expandPath("./resources/pdfs/issue2.pdf"),
      "testing": expandPath("./resources/pdfs/testing.pdf"),
      "longer" : expandPath("./resources/pdfs/longer.pdf"),
      "split" : expandPath("./resources/pdfs/goblin.pdf")
    };
    variables["nl"]     = createObject("java", "java.lang.System").getProperty("line.separator");
    variables["tmpDir"] = "./resources/tmp/";
  }

  function afterAll() {
    directoryDelete(expandPath(variables.tmpDir), true);
    structDelete(variables, "pdfs");
    structDelete(variables, "nl");
    structDelete(variables, "tmpDir");
  }

  /*********************************** BDD SUITES ***********************************/

  function run() {
    describe("pdfboxcfc", function() {
      beforeEach(function() {
      });

      afterEach(function() {
        if( variables.keyExists("initial_pdfbox") ){
          variables.initial_pdfbox.close();
          structDelete(variables, "initial_pdfbox");
        }
        if( variables.keyExists("pdfbox") ){
          variables.pdfbox.close();
          structDelete(variables, "pdfbox");
        }
      });

      it("is using the expected version", function() {
        pdfbox = new pdfbox.pdfbox(variables.pdfs.friday);
        expect(pdfbox.getVersion()).toBe("2.0.30");
      });

      it("can count the number of pages", function() {
        pdfbox = new pdfbox.pdfbox(variables.pdfs.longer);
        expect(pdfbox.getNumberOfPages()).toBe(2);
      });


      describe("text extraction", function() {
        it("can extract full pdf text", function() {
          var expected = "Friday's Child #nl#Auden #nl#In memory of Dietrich Bonhoeffer #nl# #nl#He told us we were free to choose… #nl# #nl#";

          pdfbox = new pdfbox.pdfbox(variables.pdfs.friday);

          var text = pdfbox.getText();
          expect(text).toBe(expected);
        });

        it("can extract text from a single page", function() {
          var expected = "Anna Karenina #nl#Tolstoy #nl#Happy families are all alike; every unhappy family is unhappy in its own way. #nl#";

          pdfbox = new pdfbox.pdfbox(variables.pdfs.longer);

          var text = pdfbox.getPageText(2);
          expect(text).toBe(expected);
        });

        it("can extract text as html", function() {
          pdfbox = new pdfbox.pdfbox(variables.pdfs.friday);

          var text = pdfbox.getTextAsHtml();
          expect(text).toInclude("DOCTYPE html PUBLIC");
          expect(text).toInclude("<body>");
          expect(text).toInclude("<p>Friday's Child #nl#Auden #nl#</p>");
          expect(text).toInclude("</html>");
        });

        // pdfbox 2.0.30 is able to handle the defective pdf we have. If we encounter another, we can re-add this test
        // it("returns an empty string when extracting text from a defective pdf (issue ##2)", function() {
        //   var expected = "";

        //   pdfbox = new pdfbox.pdfbox(variables.pdfs.issue2);

        //   var text = pdfbox.getText();
        //   expect(text).toBe(expected);
        // });

      });

      describe("pdf creation", function() {

        it("can add pages", function() {
          var initial_pdfbox     = new pdfbox.pdfbox(variables.pdfs.blank);
          var initial_page_count = initial_pdfbox.getNumberOfPages();
          var cfPdfObject        = "";

          cfdocument(format = "PDF", name = "cfPdfObject") {
            writeOutput("<h1>HI!</h1><p>Am I visible</p><br><p>AHHHH AHHH AHHH AHH AHHH AHHHHHHHAHHHHHH</p>");
          };

          initial_pdfbox.addPages(cfPdfObject);
          initial_pdfbox.addPages(cfPdfObject);
          var destination = expandPath("#tmpDir#addedpage-#getFileFromPath(variables.pdfs.blank)#");

          // closes file automatically
          initial_pdfbox.save(destination);

          pdfbox = new pdfbox.pdfbox(destination);

          var final_page_count = pdfbox.getNumberOfPages();
          pdfbox.close();
          expect(initial_page_count).toBe(1);
          expect(final_page_count).toBe(3);
        });

        it("can split pdfs", function() {
          var initial_pdfbox     = new pdfbox.pdfbox(variables.pdfs.split);
          var initial_page_count = initial_pdfbox.getNumberOfPages();

          var destination = expandPath("#tmpDir#split-#getFileFromPath(variables.pdfs.split)#");

          initial_pdfbox.splitPages(destination,2,4);

          initial_pdfbox.close();

          pdfbox = new pdfbox.pdfbox(destination);

          var final_page_count = pdfbox.getNumberOfPages();
          var text = pdfbox.getPageText(1);
          pdfbox.close();
          expect(initial_page_count).toBe(14);
          expect(final_page_count).toBe(3);
          expect(text).toInclude("We must not look at goblin men,");
        });

      });

      describe("sanitization", function() {
        it("does not error when sanitizing pdfs without embedded files, metadata, etc.", function() {
          initial_pdfbox    = new pdfbox.pdfbox(variables.pdfs.friday);
          var embeddedFiles = initial_pdfbox.getEmbeddedFiles();

          expect(embeddedFiles.keyArray().len()).toBe(0);

          initial_pdfbox.sanitize();

          var destination = expandPath("#tmpDir#cleansanitize-#getFileFromPath(variables.pdfs.friday)#");
          initial_pdfbox.save(destination);

          pdfbox = new pdfbox.pdfbox(destination);

          var final_embeddedFiles = pdfbox.getEmbeddedFiles();

          expect(final_embeddedFiles.keyArray().len()).toBe(0);
        });

        it("can remove annotations, preserving forms", function() {
          initial_pdfbox = new pdfbox.pdfbox(variables.pdfs.testing);
          var annotions  = initial_pdfbox.listAnnotations();
          initial_pdfbox.removeAnnotations(preserveForm = true);

          var destination = expandPath("#tmpDir#withoutannotations-#getFileFromPath(variables.pdfs.testing)#");
          initial_pdfbox.save(destination);

          pdfbox = new pdfbox.pdfbox(destination);

          var final_annotations = pdfbox.listAnnotations();

          expect(annotions.len()).toBe(14);
          expect(final_annotations.len()).toBe(3);
        });

        it("can remove all annotations", function() {
          initial_pdfbox = new pdfbox.pdfbox(variables.pdfs.testing);
          var annotions  = initial_pdfbox.listAnnotations();
          initial_pdfbox.removeAnnotations(preserveForm = false);

          var destination = expandPath("#tmpDir#withoutannotations-#getFileFromPath(variables.pdfs.testing)#");
          initial_pdfbox.save(destination);

          pdfbox = new pdfbox.pdfbox(destination);

          var final_annotations = pdfbox.listAnnotations();

          expect(annotions.len()).toBe(14);
          expect(final_annotations.len()).toBe(0);
        });

        it("can remove embedded files", function() {
          initial_pdfbox    = new pdfbox.pdfbox(variables.pdfs.testing);
          var embeddedFiles = initial_pdfbox.getEmbeddedFiles();

          expect(embeddedFiles.keyArray().len()).toBe(2);

          initial_pdfbox.removeEmbeddedFiles();

          var destination = expandPath("#tmpDir#withoutfiles-#getFileFromPath(variables.pdfs.testing)#");
          initial_pdfbox.save(destination);

          pdfbox = new pdfbox.pdfbox(destination);

          var final_embeddedFiles = pdfbox.getEmbeddedFiles();

          expect(final_embeddedFiles.keyArray().len()).toBe(0);
        });

        it("can locate an embedded search index", function() {
          pdfbox = new pdfbox.pdfbox(variables.pdfs.testing);

          var hasEmbeddedIndex = pdfBox.hasEmbeddedSearchIndex();
          expect(hasEmbeddedIndex).toBeTrue();
        });

        it("does not find an embedded search index when one is not present", function() {
          pdfbox = new pdfbox.pdfbox(variables.pdfs.friday);

          var hasEmbeddedIndex = pdfBox.hasEmbeddedSearchIndex();
          expect(hasEmbeddedIndex).toBeFalse();
        });

        it("can remove embedded search indexes", function() {
          initial_pdfbox       = new pdfbox.pdfbox(variables.pdfs.testing);
          var hasEmbeddedIndex = initial_pdfbox.hasEmbeddedSearchIndex();

          expect(hasEmbeddedIndex).toBeTrue();

          initial_pdfbox.removeEmbeddedIndex();

          var destination = expandPath("#tmpDir#withoutindex-#getFileFromPath(variables.pdfs.testing)#");
          initial_pdfbox.save(destination);

          pdfbox = new pdfbox.pdfbox(destination);

          var final_hasEmbeddedIndex = pdfbox.hasEmbeddedSearchIndex();

          expect(final_hasEmbeddedIndex).toBeFalse();
        });

        it("can return document outline titles", function() {
          pdfbox = new pdfbox.pdfbox(variables.pdfs.testing);

          var outline = pdfBox.getDocumentOutlineTitles();
          expect(outline.len()).toBe(2);
        });

        it("does not return outline titles when there is no outline", function() {
          pdfbox = new pdfbox.pdfbox(variables.pdfs.friday);

          var outline = pdfBox.getDocumentOutlineTitles();
          expect(outline.len()).toBe(0);
        });

        it("can remove the document outline (bookmarks)", function() {
          initial_pdfbox = new pdfbox.pdfbox(variables.pdfs.testing);
          var outline    = initial_pdfbox.getDocumentOutlineTitles();

          expect(outline.len()).toBe(2);

          initial_pdfbox.removeBookmarks();

          var destination = expandPath("#tmpDir#withoutbookmarks-#getFileFromPath(variables.pdfs.testing)#");
          initial_pdfbox.save(destination);

          pdfbox = new pdfbox.pdfbox(destination);

          var final_outline = pdfbox.getDocumentOutlineTitles();

          expect(final_outline.len()).toBe(0);
        });

        it("can remove metadata", function() {
          initial_pdfbox = new pdfbox.pdfbox(variables.pdfs.testing);
          var doc_info   = initial_pdfbox.getDocumentInformation();

          expect(doc_info.getTitle()).toBe("I'm for Testing");
          expect(doc_info.getAuthor()).toBe("Test Author Name");
          expect(doc_info.getCreationDate().get(doc_info.getCreationDate().YEAR)).toBe("2018");
          expect(doc_info.getModificationDate().get(doc_info.getModificationDate().YEAR)).toBe("2018");
          expect(doc_info.getProducer()).toBe("Acrobat Pro DC 18.11.20055");

          initial_pdfbox.removeMetaData();

          var destination = expandPath("#tmpDir#withoutmetadata-#getFileFromPath(variables.pdfs.testing)#");
          initial_pdfbox.save(destination);

          pdfbox = new pdfbox.pdfbox(destination);

          var final_doc_info = pdfbox.getDocumentInformation();

          expect(final_doc_info.getTitle()).toBeNull();
          expect(final_doc_info.getAuthor()).toBeNull();
          expect(final_doc_info.getCreationDate()).toBeNull();
          expect(final_doc_info.getModificationDate()).toBeNull();
          expect(final_doc_info.getProducer()).toBeNull();
        });
      });
    });
  }

}
