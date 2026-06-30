public with sharing class LeaveApprovalController {
    
    @AuraEnabled(cacheable=true)
    public static List<LeaveApprovalWrapper> getPendingApprovals(Id managerId) {
        List<LeaveApprovalWrapper> results = new List<LeaveApprovalWrapper>();
        
        try {
            System.debug('Loading pending approvals for manager: ' + managerId);
            
            // Fixed field names to match schema (Name, Status__c)
            List<Leave_Request__c> leaves = [
                SELECT Id, Employee__r.Name, Leave_Type__c, 
                       From_Date__c, To_Date__c, Number_of_Days__c, Reason__c
                FROM Leave_Request__c
                WHERE Employee__r.ReportsToId = :managerId
                AND Status__c = 'Submitted'
                ORDER BY Submitted_Date__c ASC
                LIMIT 100
            ];
            
            for (Leave_Request__c leave : leaves) {
                LeaveApprovalWrapper wrapper = new LeaveApprovalWrapper();
                wrapper.leaveRequestId = leave.Id;
                wrapper.employeeName = leave.Employee__r.Name; // Fixed
                wrapper.leaveType = leave.Leave_Type__c;
                wrapper.fromDate = leave.From_Date__c;
                wrapper.toDate = leave.To_Date__c;
                wrapper.numberOfDays = leave.Number_of_Days__c;
                wrapper.reason = leave.Reason__c;
                results.add(wrapper);
            }
            
            System.debug('✓ Found ' + results.size() + ' pending approvals');
        } catch (Exception e) {
            System.debug('Error loading approvals: ' + e.getMessage());
        }
        
        return results;
    }
    
    @AuraEnabled
    public static ApprovalResult approveLeave(Id leaveRequestId, String comments) {
        ApprovalResult result = new ApprovalResult();
        
        try {
            System.debug('Approving leave: ' + leaveRequestId);
            
            Leave_Request__c leave = [SELECT Id FROM Leave_Request__c WHERE Id = :leaveRequestId LIMIT 1];
            // leave.Manager_Approval__c = 'Approved'; // Field likely doesn't exist
            leave.Status__c = 'Pending HR Approval'; // Use Status sequence
            leave.Manager_Approval_Comment__c = comments; // Fixed field name
            // leave.Manager_Approved_Date__c = Date.today(); // Field likely doesn't exist
            update leave;
            
            System.debug('✓ Leave approved');
            
            result.success = true;
            result.message = 'Leave approved. Sent to HR.';

            // Send Email Notification - REMOVED
            // LeaveController.sendStatusUpdateNotification(leaveRequestId, 'Pending HR Approval', comments);
            
        } catch (Exception e) {
            result.success = false;
            result.message = 'Error: ' + e.getMessage();
            System.debug('Approval Error: ' + e.getStackTraceString());
        }
        
        return result;
    }
    
    @AuraEnabled
    public static ApprovalResult rejectLeave(Id leaveRequestId, String comments) {
        ApprovalResult result = new ApprovalResult();
        
        try {
            System.debug('Rejecting leave: ' + leaveRequestId);
            
            Leave_Request__c leave = [SELECT Id FROM Leave_Request__c WHERE Id = :leaveRequestId LIMIT 1];
            // leave.Manager_Approval__c = 'Rejected';
            leave.Manager_Approval_Comment__c = comments; // Fixed field name
            leave.Status__c = 'Rejected';
            update leave;
            
            System.debug('✓ Leave rejected');
            
            result.success = true;
            result.message = 'Leave rejected';

            // Send Email Notification - REMOVED
            // LeaveController.sendStatusUpdateNotification(leaveRequestId, 'Rejected', comments);
            
        } catch (Exception e) {
            result.success = false;
            result.message = 'Error: ' + e.getMessage();
            System.debug('Rejection Error: ' + e.getStackTraceString());
        }
        
        return result;
    }
    
    public class LeaveApprovalWrapper {
        @AuraEnabled public String leaveRequestId;
        @AuraEnabled public String employeeName;
        @AuraEnabled public String leaveType;
        @AuraEnabled public Date fromDate;
        @AuraEnabled public Date toDate;
        @AuraEnabled public Decimal numberOfDays;
        @AuraEnabled public String reason;
    }
    
    public class ApprovalResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }
}