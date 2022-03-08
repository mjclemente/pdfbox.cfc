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
      "longer": expandPath("./resources/pdfs/longer.pdf")
    };
  }

  function afterAll() {
    structDelete(variables, "pdfs");
  }

  /*********************************** BDD SUITES ***********************************/

  function run() {
    describe("pdfboxcfc", function() {
      beforeEach(function() {
      });

      afterEach(function() {
        variables.pdfbox.close();
        structDelete(variables, "pdfbox");
      });

      it("is using the expected version", function() {
        pdfbox = new pdfbox.pdfbox(variables.pdfs.friday);
        expect(pdfbox.getVersion()).toBe("2.0.19");
      });

      it("can count the number of pages", function() {
        pdfbox = new pdfbox.pdfbox(variables.pdfs.longer);
        expect(pdfbox.getNumberOfPages()).toBe(2);
      });


      describe("text extraction", function() {
        it("can extract full pdf text", function() {
          var nl = createObject("java", "java.lang.System").getProperty("line.separator");

          var expected = "Friday's Child #nl#Auden #nl#In memory of Dietrich Bonhoeffer #nl# #nl#He told us we were free to choose… #nl# #nl#";

          pdfbox = new pdfbox.pdfbox(variables.pdfs.friday);

          var text = pdfbox.getText();
          expect(text).toBe(expected);
        });
      });
    });
  }

}
