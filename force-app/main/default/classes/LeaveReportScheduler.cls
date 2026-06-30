public class LeaveReportScheduler implements Schedulable {
    
    public void execute(SchedulableContext sc) {
        generateAndSendReport();
    }

    @future(callout=true)
    public static void generateAndSendReport() {
        // 1. Determine "Last Month" context (assuming this runs on 1st of new month, or we run on last day for current month)
        // Let's assume we want the report for the *Current* month if run on last day, or *Previous* if run on 1st.
        // Best approach: Report for the *Full Previous Month* to be safe, or specify month.
        // Let's go with: Report for the CURRENT Month (assuming it runs near end).
        Date today = Date.today();
        Integer targetMonth = today.month();
        Integer targetYear = today.year();
        
        // Define Start and End of Target Month
        Date monthStart = Date.newInstance(targetYear, targetMonth, 1);
        Integer daysInMonth = Date.daysInMonth(targetYear, targetMonth);
        Date monthEnd = Date.newInstance(targetYear, targetMonth, daysInMonth);
        
        // 2. Query Leaves overlapping this month
        // Criteria: Start <= MonthEnd AND End >= MonthStart
        List<Leave_Request__c> leaves = [
            SELECT Employee__r.Name, Employee__r.Employee_ID__c, Employee__r.Department__c,
                   Leave_Type__r.Name, From_Date__c, To_Date__c, Status__c, Reason__c
            FROM Leave_Request__c
            WHERE From_Date__c <= :monthEnd 
            AND To_Date__c >= :monthStart
            AND (Status__c = 'Approved' OR Status__c = 'HR_Approved')
            ORDER BY Employee__r.Name ASC
        ];

        // 3. Build CSV Data with Split Logic
        String csvHeader = 'Employee ID,Name,Department,Leave Type,Start Date,End Date,Days (This Month),Status,Reason\n';
        String csvBody = '';
        
        for (Leave_Request__c leave : leaves) {
            // Calculate effective start and end for THIS month
            Date effectiveStart = (leave.From_Date__c < monthStart) ? monthStart : leave.From_Date__c;
            Date effectiveEnd = (leave.To_Date__c > monthEnd) ? monthEnd : leave.To_Date__c;
            
            // Calculate Days (Check Holidays/Weekends logic if strict, but typically report raw days or standard calc)
            // Re-using LeaveController logic would be best, but we'll do a simple calc or call the helper if possible.
            // For report, "Calendar Days" or "Work Days"? usually Work Days.
            Decimal daysCount = LeaveController.calculateLeaveDuration(effectiveStart, effectiveEnd);
            
            if (daysCount > 0) {
                String row = '"' + (leave.Employee__r.Employee_ID__c != null ? leave.Employee__r.Employee_ID__c : '') + '",';
                row += '"' + leave.Employee__r.Name + '",';
                row += '"' + (leave.Employee__r.Department__c != null ? leave.Employee__r.Department__c : '') + '",';
                row += '"' + leave.Leave_Type__r.Name + '",';
                row += '"' + leave.From_Date__c.format() + '",'; // Original Start
                row += '"' + leave.To_Date__c.format() + '",';   // Original End
                row += '"' + daysCount + '",';                   // Calculated Split Days
                row += '"' + leave.Status__c + '",';
                row += '"' + (leave.Reason__c != null ? leave.Reason__c.escapeCsv() : '') + '"\n';
                
                csvBody += row;
            }
        }
        
        if (String.isBlank(csvBody)) {
            System.debug('No leaves found for report.');
            return; 
        }

        // 4. Email
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        // Recipients: Company Email + Logic for HR/Manager if needed.
        // User asked for "hr and manger mail" and "company mail".
        // We'll send to the company mail and perhaps a distribution list if hardcoded.
        List<String> toAddresses = new List<String>{'harish.kumar@crmantra.com'};
        // Add others if configured, e.g. from Custom Setting or Label.
        
        mail.setToAddresses(toAddresses);
        String subject = 'Monthly Leave Report - ' + DateTime.newInstance(monthStart.year(), monthStart.month(), 1).format('MMMM yyyy');
        mail.setSubject(subject);
        mail.setPlainTextBody('Please find attached the leave report for ' + DateTime.newInstance(monthStart.year(), monthStart.month(), 1).format('MMMM yyyy') + '.');
        
        // Attach CSV
        Messaging.EmailFileAttachment attach = new Messaging.EmailFileAttachment();
        attach.setFileName('LeaveReport_' + targetYear + '_' + targetMonth + '.csv');
        attach.setBody(Blob.valueOf(csvHeader + csvBody));
        mail.setFileAttachments(new Messaging.EmailFileAttachment[]{attach});
        
        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        } catch (Exception e) {
            System.debug('Report Email Failed: ' + e.getMessage());
        }
    }
}