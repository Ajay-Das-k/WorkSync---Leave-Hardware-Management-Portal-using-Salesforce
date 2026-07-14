public without sharing class CompanyPolicyController {
  @AuraEnabled
  public static Company_Policy__c getCompanyPolicy() {
    try {
      List<Company_Policy__c> policies = [
        SELECT Id, Name, Content__c
        FROM Company_Policy__c
        LIMIT 1
      ];
      if (!policies.isEmpty()) {
        return policies[0];
      }

      // Create default policy record if none exists
      Company_Policy__c defaultPolicy = new Company_Policy__c(
        Name = 'Standard Company Leave Policy',
        Content__c = getDefaultPolicyContent()
      );
      insert defaultPolicy;
      return defaultPolicy;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching company policy: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled
  public static Boolean updateCompanyPolicy(String recordId, String content) {
    try {
      Company_Policy__c policy = new Company_Policy__c(
        Id = recordId,
        Content__c = content
      );
      update policy;
      return true;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error updating company policy: ' + e.getMessage()
      );
    }
  }

  private static String getDefaultPolicyContent() {
    return '<section class="slds-m-bottom_large">' +
      '    <h2>1. Purpose</h2>' +
      '    <p>This circular defines the leave structure, entitlements, rules, and compliance requirements applicable to employees, ensuring uniformity and smooth functioning across the organization.</p>' +
      '</section>' +
      '<section class="slds-m-bottom_large">' +
      '    <h2>2. General Leave Framework</h2>' +
      '    <p>The Company recognizes the importance of work–life balance and provides a structured leave framework. All staff on the company payroll and in continuous service are entitled to leave and corresponding wages.</p>' +
      '    <ul>' +
      '         <li>Leave is calculated on a calendar year basis (January to December).</li>' +
      '        <li>Leave will <b>not</b> be carried forward to the next year.</li>' +
      '        <li>Annual leave entitlement will be credited in the first month of each calendar year.</li>' +
      '        <li>Sanction of leave is at the discretion of Management.</li>' +
      '        <li><b>Half-day leave:</b>' +
      '            <ul>' +
      '                <li>Morning Session: 10:30 AM – 1:30 PM</li>' +
      '                <li>Afternoon Session: 2:30 PM – 7:30 PM</li>' +
      '            </ul>' +
      '        </li>' +
      '    </ul>' +
      '</section>' +
      '<section class="slds-m-bottom_large">' +
      '    <h2>3. Probation Period Leave Entitlement</h2>' +
      '    <p>All newly hired employees are placed on a probation period of six (6) months.</p>' +
      '    <ul>' +
      '        <li>During probation: Eligible for <b>0.5 Sick Leave</b> per month (pro-rata).</li>' +
      '        <li>No other type of leave is permitted.</li>' +
      '        <li>Additional leaves will be calculated as Loss of Pay (LOP).</li>' +
      '    </ul>' +
      '</section>' +
      '<section class="slds-m-bottom_large">' +
      '    <h2>4. Leave Entitlement After Probation</h2>' +
      '    <div class="slds-m-bottom_medium slds-p-left_large">' +
      '        <h3>4.1 Casual Leave (CL)</h3>' +
      '        <p>Designed for short-term personal needs or urgent matters.</p>' +
      '        <ul>' +
      '            <li><b>Entitlement:</b> 12 days/year (1 day/month).</li>' +
      '            <li><b>Notice:</b> Inform Reporting Manager/HR at least 2 days in advance.</li>' +
      '            <li><b>Policy:</b> Max 2 consecutive days. Leaving office early 3 times a month = 0.5 Day CL/LOP.</li>' +
      '            <li>Cannot be carried forward or encashed.</li>' +
      '        </ul>' +
      '    </div>' +
      '    <div class="slds-m-bottom_medium slds-p-left_large">' +
      '        <h3>4.2 Sick Leave (SL)</h3>' +
      '        <p>For illness or medical appointments.</p>' +
      '        <ul>' +
      '            <li><b>Entitlement:</b> 6 days/year (0.5 day/month).</li>' +
      '            <li>Medical certificate required for absence exceeding 2 consecutive days.</li>' +
      '            <li>Cannot be carried forward or encashed.</li>' +
      '        </ul>' +
      '    </div>' +
      '    <div class="slds-m-bottom_medium slds-p-left_large">' +
      '        <h3>4.3 Marriage Leave</h3>' +
      '        <ul>' +
      '            <li><b>Entitlement:</b> 5 days of paid leave.</li>' +
      '            <li><b>Eligibility:</b> Minimum 6 months of continuous service.</li>' +
      '        </ul>' +
      '    </div>' +
      '</section>' +
      '<section class="slds-m-bottom_large">' +
      '    <h2>5. Loss of Pay (LOP) Conditions</h2>' +
      '    <ul>' +
      '        <li>Absent without leave or prior approval.</li>' +
      '        <li>Availing leave during notice period.</li>' +
      '        <li>Failing to report to duty after sanctioned leave.</li>' +
      '        <li>Leaving early/Coming late more than 2 times a month.</li>' +
      '    </ul>' +
      '</section>' +
      '<section class="slds-m-bottom_large">' +
      '    <h2>6. Compensatory Off (Comp-Off)</h2>' +
      '    <ul>' +
      '        <li>For work on Sundays/Public Holidays due to emergency (with approval).</li>' +
      '        <li>Must be availed within 21 days.</li>' +
      '        <li>Half-day work does not qualify.</li>' +
      '    </ul>' +
      '</section>' +
      '<section class="slds-m-bottom_large">' +
      '    <h2>7. Maternity Leave Policy</h2>' +
      '    <ul>' +
      '        <li><b>Eligibility:</b> Women employees with min. 6 months service.</li>' +
      '        <li><b>Duration:</b> 26 weeks (182 days) for first two children.</li>' +
      '        <li><b>Miscarriage:</b> 6 weeks unpaid leave.</li>' +
      '        <li><b>Notice:</b> Apply 3 months prior to expected delivery.</li>' +
      '    </ul>' +
      '</section>' +
      '<section class="slds-m-bottom_large">' +
      '    <h2>8. Paternity Leave Policy</h2>' +
      '    <ul>' +
      '        <li><b>Eligibility:</b> Male employees with min. 6 months service.</li>' +
      '        <li><b>Duration:</b> 3 weeks (Paid) within 30 days of childbirth.</li>' +
      '        <li><b>Notice:</b> Apply 1 week in advance.</li>' +
      '    </ul>' +
      '</section>' +
      '<section class="slds-m-bottom_large">' +
      '    <h2>9. Bereavement Leave Policy</h2>' +
      '    <ul>' +
      '        <li><b>Scope:</b> Death of immediate family member (Parents/Spouse/Child).</li>' +
      '        <li><b>Duration:</b> 5 days paid leave.</li>' +
      '        <li>Evidence (Death Certificate) may be required.</li>' +
      '    </ul>' +
      '</section>' +
      '<section class="slds-m-bottom_large">' +
      '    <h2>10. Notice Period Leave Policy</h2>' +
      '    <ul>' +
      '        <li>No paid leaves (CL/SL) allowed during notice period. All leaves treat as LOP.</li>' +
      '        <li>Absconding (3 days no show) leads to immediate termination.</li>' +
      '    </ul>' +
      '</section>' +
      '<div class="slds-box slds-theme_shade slds-theme_alert-texture">' +
      '    <h2>Compliance</h2>' +
      '    <p>Non-compliance or misuse may result in disciplinary action. Use leaves responsibly.</p>' +
      '</div>';
  }
}
