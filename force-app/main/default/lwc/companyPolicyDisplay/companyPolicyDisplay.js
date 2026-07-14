import { LightningElement, track, api } from "lwc";
import COMPANY_LOGO from "@salesforce/resourceUrl/CompanyLogo";
import getCompanyPolicy from "@salesforce/apex/CompanyPolicyController.getCompanyPolicy";

export default class CompanyPolicyDisplay extends LightningElement {
  logoUrl = COMPANY_LOGO;
  @track policyContent = "";
  @track isLoading = true;

  connectedCallback() {
    this.loadPolicy();
  }

  @api
  refresh() {
    this.loadPolicy();
  }

  loadPolicy() {
    this.isLoading = true;
    getCompanyPolicy()
      .then((result) => {
        this.policyContent = result.Content__c;
      })
      .catch((error) => {
        console.error("Error loading policy:", error);
      })
      .finally(() => {
        this.isLoading = false;
      });
  }
}
