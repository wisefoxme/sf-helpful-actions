import { createElement } from "@lwc/engine-dom";
import CsvDataWeaveDropzone from "c/csvDataWeaveDropzone";
import convertCsv from "@salesforce/apex/DataWeaveCsvConversionController.convertCsv";

jest.mock(
  "@salesforce/apex/DataWeaveCsvConversionController.convertCsv",
  () => ({
    default: jest.fn()
  }),
  { virtual: true }
);

describe("c-csv-data-weave-dropzone", () => {
  let fileReaderOnload;

  beforeEach(() => {
    convertCsv.mockReset();
    fileReaderOnload = null;

    jest.spyOn(global, "FileReader").mockImplementation(() => ({
      readAsText() {
        fileReaderOnload = this.onload;
      },
      get result() {
        return "name\nAlice";
      }
    }));
  });

  afterEach(() => {
    jest.restoreAllMocks();
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  function createComponent(props = {}) {
    const element = createElement("c-csv-data-weave-dropzone", {
      is: CsvDataWeaveDropzone
    });
    Object.assign(element, props);
    document.body.appendChild(element);
    return element;
  }

  function startCsvUpload(element) {
    Object.assign(element, {
      scriptApiName: "CsvDataWeaveDropzoneTest",
      targetObjectApiName: "Contact"
    });

    const file = new File(["name\nAlice"], "contacts.csv", {
      type: "text/csv"
    });
    const input = element.shadowRoot.querySelector('input[type="file"]');
    Object.defineProperty(input, "files", { value: [file] });
    input.dispatchEvent(new CustomEvent("change"));
  }

  function beginConversionWithoutCompleting(element) {
    convertCsv.mockImplementation(() => new Promise(() => {}));
    startCsvUpload(element);
    expect(fileReaderOnload).not.toBeNull();
    fileReaderOnload.call({ result: "name\nAlice" });
  }

  describe("validate", () => {
    it("blocks when conversion is in progress", () => {
      const element = createComponent({ uploadRequired: true });
      beginConversionWithoutCompleting(element);

      const result = element.validate();

      expect(result.isValid).toBe(false);
      expect(result.errorMessage).toBe("CSV conversion is still in progress.");
    });

    it("blocks when there is a conversion error", () => {
      const element = createComponent({
        errorMessage: "CSV conversion failed."
      });

      const result = element.validate();

      expect(result.isValid).toBe(false);
      expect(result.errorMessage).toBe("CSV conversion failed.");
    });

    describe("when upload is required", () => {
      it("blocks when no file has been converted and uploadRequired is true", () => {
        const element = createComponent({ uploadRequired: true });

        const result = element.validate();

        expect(result.isValid).toBe(false);
        expect(result.errorMessage).toBe(
          "Upload and convert a CSV file before continuing."
        );
      });

      it("blocks when no file has been converted and uploadRequired is unset", () => {
        const element = createComponent();

        const result = element.validate();

        expect(result.isValid).toBe(false);
        expect(result.errorMessage).toBe(
          "Upload and convert a CSV file before continuing."
        );
      });

      it("allows continue after a successful conversion", () => {
        const element = createComponent({
          uploadRequired: true,
          isComplete: true
        });

        expect(element.validate()).toEqual({ isValid: true });
      });
    });

    describe("when upload is not required", () => {
      it("allows continue without a converted file", () => {
        const element = createComponent({ uploadRequired: false });

        expect(element.validate()).toEqual({ isValid: true });
      });

      it("still blocks while conversion is in progress", () => {
        const element = createComponent({ uploadRequired: false });
        beginConversionWithoutCompleting(element);

        const result = element.validate();

        expect(result.isValid).toBe(false);
        expect(result.errorMessage).toBe(
          "CSV conversion is still in progress."
        );
      });

      it("still blocks after a failed conversion attempt", () => {
        const element = createComponent({
          uploadRequired: false,
          errorMessage: "Invalid CSV format."
        });

        const result = element.validate();

        expect(result.isValid).toBe(false);
        expect(result.errorMessage).toBe("Invalid CSV format.");
      });

      it("allows continue after a successful conversion", () => {
        const element = createComponent({
          uploadRequired: false,
          isComplete: true
        });

        expect(element.validate()).toEqual({ isValid: true });
      });
    });
  });
});
