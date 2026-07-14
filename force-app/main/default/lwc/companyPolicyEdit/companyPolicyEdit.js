import { LightningElement, track } from "lwc";
import getCompanyPolicy from "@salesforce/apex/CompanyPolicyController.getCompanyPolicy";
import updateCompanyPolicy from "@salesforce/apex/CompanyPolicyController.updateCompanyPolicy";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import LightningAlert from "lightning/alert";

export default class CompanyPolicyEdit extends LightningElement {
  @track recordId;
  @track policyContent = "";
  @track isLoading = true;
  @track isSaving = false;

  connectedCallback() {
    this.loadPolicy();
  }

  loadPolicy() {
    this.isLoading = true;
    getCompanyPolicy()
      .then((result) => {
        this.recordId = result.Id;
        this.policyContent = result.Content__c;
      })
      .catch((error) => {
        console.error("Error loading policy:", error);
        this.showToast(
          "Error",
          "Failed to load policy: " +
            (error.body ? error.body.message : error.message),
          "error"
        );
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleContentChange(event) {
    this.policyContent = event.target.value;
  }

  handleSave() {
    this.isSaving = true;
    updateCompanyPolicy({
      recordId: this.recordId,
      content: this.policyContent
    })
      .then(() => {
        this.showToast(
          "Success",
          "Company Policy updated successfully.",
          "success"
        );
        // Dispatch event to parent in case it wants to refresh views
        this.dispatchEvent(new CustomEvent("policysaved"));
      })
      .catch((error) => {
        console.error("Error saving policy:", error);
        LightningAlert.open({
          message: error.body ? error.body.message : error.message,
          theme: "error",
          label: "Error Saving Policy"
        });
      })
      .finally(() => {
        this.isSaving = false;
      });
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
