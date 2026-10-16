/* eslint-disable @lwc/lwc/no-api-reassignments -- Flow output @api properties are updated in place. */
import { LightningElement, api } from "lwc";
import { FlowAttributeChangeEvent } from "lightning/flowSupport";
import convertCsv from "@salesforce/apex/DataWeaveCsvConversionController.convertCsv";

const DEFAULT_MAX_FILE_SIZE_BYTES = 3500000;
const DEFAULT_SUCCESS_MESSAGE_TEMPLATE =
  "$0 record(s) loaded. Data is ready for the flow (not saved to Salesforce).";
const DEFAULT_FAILURE_MESSAGE_TEMPLATE = "$0";

export default class CsvDataWeaveDropzone extends LightningElement {
  @api scriptApiName;
  @api targetObjectApiName;
  @api label = "Upload CSV";
  @api helpText;
  @api uploadRequired;
  @api maxFileSizeBytes = DEFAULT_MAX_FILE_SIZE_BYTES;
  @api successMessageTemplate = DEFAULT_SUCCESS_MESSAGE_TEMPLATE;
  @api failureMessageTemplate = DEFAULT_FAILURE_MESSAGE_TEMPLATE;

  @api convertedRecords = [];
  @api errorMessage;
  @api recordCount = 0;
  @api isComplete = false;

  isProcessing = false;
  dragActive = false;

  get dropzoneClass() {
    return this.dragActive ? "dropzone dropzone_active" : "dropzone";
  }

  get showHelpText() {
    return Boolean(this.helpText);
  }

  get hasError() {
    return Boolean(this.errorMessage);
  }

  get showSuccess() {
    return this.isComplete && !this.hasError;
  }

  get displaySuccessMessage() {
    return this.formatMessage(
      this.successMessageTemplate,
      DEFAULT_SUCCESS_MESSAGE_TEMPLATE,
      this.recordCount
    );
  }

  get displayFailureMessage() {
    return this.formatMessage(
      this.failureMessageTemplate,
      DEFAULT_FAILURE_MESSAGE_TEMPLATE,
      this.errorMessage
    );
  }

  formatMessage(template, defaultTemplate, mergeValue) {
    const source =
      template && String(template).trim() ? template : defaultTemplate;
    return String(source).replace(/\$0/g, String(mergeValue ?? ""));
  }

  handleDragOver(event) {
    event.preventDefault();
    this.dragActive = true;
  }

  handleDragLeave() {
    this.dragActive = false;
  }

  handleDrop(event) {
    event.preventDefault();
    this.dragActive = false;
    const files = event.dataTransfer?.files;
    if (files && files.length > 0) {
      this.processFile(files[0]);
    }
  }

  handleFileInputChange(event) {
    const files = event.target.files;
    if (files && files.length > 0) {
      this.processFile(files[0]);
    }
    event.target.value = null;
  }

  handleBrowseClick() {
    this.template.querySelector('input[type="file"]')?.click();
  }

  processFile(file) {
    if (!file) {
      return;
    }
    if (!this.isCsvFile(file)) {
      this.setFailure("Please upload a CSV file.");
      return;
    }
    if (file.size > this.maxFileSizeBytes) {
      this.setFailure(
        `File is too large. Maximum size is ${this.maxFileSizeBytes} bytes.`
      );
      return;
    }
    if (!this.scriptApiName || !this.targetObjectApiName) {
      this.setFailure(
        "DataWeave script API name and target object API name must be configured in the flow."
      );
      return;
    }

    this.isProcessing = true;
    const reader = new FileReader();
    reader.onload = () => {
      const csvText = typeof reader.result === "string" ? reader.result : "";
      this.runConversion(csvText);
    };
    reader.onerror = () => {
      this.isProcessing = false;
      this.setFailure("Could not read the selected file.");
    };
    reader.readAsText(file);
  }

  isCsvFile(file) {
    const name = (file.name || "").toLowerCase();
    const type = (file.type || "").toLowerCase();
    return (
      name.endsWith(".csv") ||
      type === "text/csv" ||
      type === "application/vnd.ms-excel"
    );
  }

  runConversion(csvText) {
    convertCsv({
      dataWeaveScriptApiName: this.scriptApiName,
      targetObjectApiName: this.targetObjectApiName,
      csvContent: csvText
    })
      .then((records) => {
        const rows = records || [];
        this.convertedRecords = rows;
        this.recordCount = rows.length;
        this.errorMessage = null;
        this.isComplete = true;
        this.publishOutputs();
      })
      .catch((error) => {
        const message =
          error?.body?.message || error?.message || "CSV conversion failed.";
        this.setFailure(message);
      })
      .finally(() => {
        this.isProcessing = false;
      });
  }

  setFailure(message) {
    this.convertedRecords = [];
    this.recordCount = 0;
    this.isComplete = false;
    this.errorMessage = message;
    this.publishOutputs();
  }

  publishOutputs() {
    this.dispatchEvent(
      new FlowAttributeChangeEvent("convertedRecords", this.convertedRecords)
    );
    this.dispatchEvent(
      new FlowAttributeChangeEvent("recordCount", this.recordCount)
    );
    this.dispatchEvent(
      new FlowAttributeChangeEvent("isComplete", this.isComplete)
    );
    this.dispatchEvent(
      new FlowAttributeChangeEvent("errorMessage", this.errorMessage)
    );
  }

  @api
  validate() {
    if (this.isProcessing) {
      return {
        isValid: false,
        errorMessage: "CSV conversion is still in progress."
      };
    }
    if (this.hasError) {
      return {
        isValid: false,
        errorMessage: this.errorMessage
      };
    }
    if (this.uploadRequired === false) {
      return { isValid: true };
    }
    if (!this.isComplete) {
      return {
        isValid: false,
        errorMessage: "Upload and convert a CSV file before continuing."
      };
    }
    return { isValid: true };
  }
}
