import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import {
  getRelatedListInfo,
  getRelatedListRecords,
  getRelatedListCount
} from "lightning/uiRelatedListApi";
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import {
  deleteRecord,
  getFieldValue,
  getFieldDisplayValue
} from "lightning/uiRecordApi";
import { refreshApex } from "@salesforce/apex";
import {
  registerRefreshHandler,
  unregisterRefreshHandler
} from "lightning/refresh";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import LightningConfirm from "lightning/confirm";

const DEFAULT_ICON = "standard:default";
const MAX_COUNT = 2000;

// "…/img/icon/t4v35/standard/contact_120.png" -> "standard:contact"
const ICON_URL_PATTERN =
  /\/(standard|custom|utility|action)\/([a-z0-9_]+?)(?:_\d+)?\.(?:png|svg)$/i;

function reduceError(error) {
  const body = error?.body;
  if (Array.isArray(body)) {
    return body.map((e) => e.message).join(", ");
  }
  return body?.message || error?.message || "Unknown error";
}

export default class InfiniteRelatedList extends NavigationMixin(
  LightningElement
) {
  @api recordId;
  @api objectApiName;
  @api relatedListId;
  @api titleOverride;
  @api iconOverride;
  @api pageSize = 50;
  @api height = 400;

  info;
  columns = [];
  rows = [];
  count;
  countHasMore = false;
  nextPageToken;
  // null (not undefined) so the records wire runs for the first page.
  pageToken = null;
  isLoadingMore = false;
  errorMessage;
  childObjectInfo;

  recordsById = new Map();
  firstPageResult;
  countResult;
  refreshHandlerId;

  connectedCallback() {
    this.refreshHandlerId = registerRefreshHandler(
      this,
      this.handleRefresh.bind(this)
    );
  }

  disconnectedCallback() {
    unregisterRefreshHandler(this.refreshHandlerId);
  }

  // ---- Wires ----

  @wire(getRelatedListInfo, {
    parentObjectApiName: "$objectApiName",
    relatedListId: "$relatedListId"
  })
  wiredInfo({ data, error }) {
    if (data) {
      this.info = data;
      this.columns = this.buildColumns();
      this.errorMessage = undefined;
    } else if (error) {
      this.errorMessage = reduceError(error);
    }
  }

  // Wait for the related list info, so the first request already has the
  // column fields.
  get recordsParentId() {
    return this.info ? this.recordId : undefined;
  }

  get childObjectApiName() {
    return this.info?.listReference?.objectApiName;
  }

  get displayColumns() {
    return this.info?.displayColumns || [];
  }

  // optionalFields, so a field the user can't see doesn't fail the request.
  get optionalFields() {
    const fields = new Set();
    this.displayColumns.forEach((col) => {
      fields.add(`${this.childObjectApiName}.${col.fieldApiName}`);
      if (col.lookupId && col.lookupId !== "Id") {
        fields.add(`${this.childObjectApiName}.${col.lookupId}`);
      }
    });
    return [...fields];
  }

  @wire(getRelatedListRecords, {
    parentRecordId: "$recordsParentId",
    relatedListId: "$relatedListId",
    optionalFields: "$optionalFields",
    pageSize: "$pageSize",
    pageToken: "$pageToken"
  })
  wiredRecords(result) {
    const { data, error } = result;
    if (error) {
      this.errorMessage = reduceError(error);
      this.isLoadingMore = false;
      return;
    }
    if (!data) {
      return;
    }
    // The first page replaces the list; later pages are merged in by Id.
    if (!this.pageToken) {
      this.firstPageResult = result;
      this.recordsById = new Map();
    }
    data.records.forEach((record) =>
      this.recordsById.set(record.id, this.toRow(record))
    );
    this.rows = [...this.recordsById.values()];
    this.nextPageToken = data.nextPageToken;
    this.isLoadingMore = false;
    this.errorMessage = undefined;
  }

  @wire(getRelatedListCount, {
    parentRecordId: "$recordId",
    relatedListId: "$relatedListId",
    maxCount: MAX_COUNT
  })
  wiredCount(result) {
    this.countResult = result;
    if (result.data) {
      this.count = result.data.count;
      this.countHasMore = result.data.hasMore;
    }
  }

  // The child object's permissions decide which row actions are shown.
  @wire(getObjectInfo, { objectApiName: "$childObjectApiName" })
  wiredChildObjectInfo({ data }) {
    if (data) {
      this.childObjectInfo = data;
    }
  }

  // ---- View ----

  get title() {
    return this.titleOverride || this.info?.label || "";
  }

  get iconName() {
    if (this.iconOverride) {
      return this.iconOverride;
    }
    const iconUrl =
      this.info?.themeInfo?.iconUrl ||
      this.childObjectInfo?.themeInfo?.iconUrl ||
      "";
    const match = ICON_URL_PATTERN.exec(iconUrl);
    return match ? `${match[1].toLowerCase()}:${match[2]}` : DEFAULT_ICON;
  }

  get countLabel() {
    if (this.count === undefined) {
      return "";
    }
    return `(${this.count}${this.countHasMore ? "+" : ""})`;
  }

  get hasMore() {
    return !!this.nextPageToken;
  }

  get isFirstLoad() {
    return !this.firstPageResult;
  }

  get isEmpty() {
    return this.rows.length === 0;
  }

  get containerStyle() {
    return `height: ${this.height}px;`;
  }

  buildColumns() {
    const columns = this.displayColumns.map((col, index) => {
      const key = `c${index}`;
      if (col.lookupId) {
        return {
          label: col.label,
          fieldName: `${key}_url`,
          type: "url",
          typeAttributes: { label: { fieldName: key }, target: "_self" }
        };
      }
      if (col.dataType?.toLowerCase() === "boolean") {
        return { label: col.label, fieldName: key, type: "boolean" };
      }
      return { label: col.label, fieldName: key, type: "text" };
    });
    columns.push({
      type: "action",
      typeAttributes: { rowActions: this.getRowActions }
    });
    return columns;
  }

  toRow(record) {
    const row = { Id: record.id };
    this.displayColumns.forEach((col, index) => {
      const key = `c${index}`;
      const field = `${this.childObjectApiName}.${col.fieldApiName}`;
      const value = getFieldValue(record, field);
      if (col.dataType?.toLowerCase() === "boolean") {
        row[key] = value;
        return;
      }
      row[key] = getFieldDisplayValue(record, field) ?? value;
      if (col.lookupId) {
        const id =
          col.lookupId === "Id"
            ? record.id
            : getFieldValue(
                record,
                `${this.childObjectApiName}.${col.lookupId}`
              );
        row[`${key}_url`] = id ? `/${id}` : undefined;
      }
    });
    return row;
  }

  // ---- Infinite scroll ----

  handleLoadMore() {
    if (this.isLoadingMore || !this.nextPageToken) {
      return;
    }
    this.isLoadingMore = true;
    this.pageToken = this.nextPageToken;
  }

  // ---- Refresh ----

  handleRefresh() {
    return this.reload().then(() => true);
  }

  async reload() {
    this.nextPageToken = undefined;
    this.pageToken = null;
    await Promise.all([
      this.firstPageResult && refreshApex(this.firstPageResult),
      this.countResult && refreshApex(this.countResult)
    ]);
  }

  // ---- Row actions ----

  get rowActions() {
    const actions = [{ label: "View", name: "view" }];
    if (this.childObjectInfo?.updateable) {
      actions.push({ label: "Edit", name: "edit" });
    }
    if (this.childObjectInfo?.deletable) {
      actions.push({ label: "Delete", name: "delete" });
    }
    return actions;
  }

  // Arrow function: the datatable calls it without this component as `this`.
  getRowActions = (row, done) => {
    done(this.rowActions);
  };

  handleRowAction(event) {
    const { action, row } = event.detail;
    if (action.name === "delete") {
      this.deleteRow(row.Id);
    } else {
      this.navigateToRecord(row.Id, action.name);
    }
  }

  navigateToRecord(recordId, actionName) {
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId,
        objectApiName: this.childObjectApiName,
        actionName
      }
    });
  }

  async deleteRow(recordId) {
    const confirmed = await LightningConfirm.open({
      label: "Delete record",
      message: "Are you sure you want to delete this record?",
      theme: "warning"
    });
    if (!confirmed) {
      return;
    }
    try {
      await deleteRecord(recordId);
      this.recordsById.delete(recordId);
      this.rows = [...this.recordsById.values()];
      if (this.countResult) {
        refreshApex(this.countResult);
      }
      this.toast("Record deleted", "", "success");
    } catch (error) {
      this.toast("Couldn't delete the record", reduceError(error), "error");
    }
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
