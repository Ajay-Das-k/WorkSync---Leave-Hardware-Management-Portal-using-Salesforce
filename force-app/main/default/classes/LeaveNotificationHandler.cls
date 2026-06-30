public without sharing class LeaveNotificationHandler {

    public static void handleNotifications(List<Leave_Request__c> newRecords, Map<Id, Leave_Request__c> oldMap) {
        Set<Id> submittedIds = new Set<Id>();
        Set<Id> managerApprovedIds = new Set<Id>();
        Set<Id> hrApprovedIds = new Set<Id>();
        Set<Id> rejectedIds = new Set<Id>();
        Set<Id> cancelledIds = new Set<Id>(); // NEW: For Cancellations/Edits

        for (Leave_Request__c req : newRecords) {
            Leave_Request__c oldReq = (oldMap != null) ? oldMap.get(req.Id) : null;
            String oldStatus = (oldReq != null) ? oldReq.Status__c : '';
            String newStatus = req.Status__c;
            
            // 1. Leave Submitted
            if (newStatus == 'Submitted' && oldStatus != 'Submitted') {
                submittedIds.add(req.Id);
            }

            // 2. Approvals
            if (newStatus == 'Approved' && oldStatus != 'Approved') {
                managerApprovedIds.add(req.Id);
            }
            if (newStatus == 'HR_Approved' && oldStatus != 'HR_Approved') {
                hrApprovedIds.add(req.Id);
            }

            // 3. Rejections
            if (newStatus.contains('Rejected') && !oldStatus.contains('Rejected')) {
                rejectedIds.add(req.Id);
            }

            // 4. Cancellations / Edits (Shortened)
            if (newStatus == 'Cancelled' && oldStatus != 'Cancelled') {
                cancelledIds.add(req.Id);
            }
        }

        if (!submittedIds.isEmpty()) sendSubmittedEmails(submittedIds);
        if (!managerApprovedIds.isEmpty()) sendApprovalEmails(managerApprovedIds, false);
        if (!hrApprovedIds.isEmpty()) sendApprovalEmails(hrApprovedIds, true);
        if (!rejectedIds.isEmpty()) sendRejectionEmails(rejectedIds);
        if (!cancelledIds.isEmpty()) sendCancellationEmails(cancelledIds); // NEW
    }

    // Helper to get Org-Wide Email
    private static Id getOrgWideEmailId() {
        try {
            // Prefer an address that starts with 'HR' or 'Support', otherwise take the first verified one
            List<OrgWideEmailAddress> owa = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName LIKE 'HR%' OR Address LIKE 'hr%' LIMIT 1];
            if (!owa.isEmpty()) return owa[0].Id;
            
            owa = [SELECT Id FROM OrgWideEmailAddress LIMIT 1];
            return !owa.isEmpty() ? owa[0].Id : null;
        } catch (Exception e) { return null; }
    }

    private static void sendSubmittedEmails(Set<Id> recordIds) {
        List<Leave_Request__c> requests = [
            SELECT Id, Employee__c, Employee__r.Name, Leave_Type__c, Leave_Type__r.Name, From_Date__c, To_Date__c, Number_of_Days__c, 
                   Reason__c, Reporting_Manager__c, Reporting_Manager__r.Name, Manager_Approval_Comment__c
            FROM Leave_Request__c WHERE Id IN :recordIds
        ];
        
        Set<Id> mgrIds = new Set<Id>();
        for(Leave_Request__c r : requests) if(r.Reporting_Manager__c != null) mgrIds.add(r.Reporting_Manager__c);
        Map<Id, String> mgrEmails = getEmails(mgrIds);

        List<User> hrUsers = [SELECT Id, Email FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 10]; 
        
        // Fetch specific HR Contact (CT50) requested by user
        List<Contact> specializedHR = [SELECT Id, Email FROM Contact WHERE Employee_ID__c = 'CT50' LIMIT 1];
        String specializedHREmail = null;
        if (!specializedHR.isEmpty()) {
            specializedHREmail = specializedHR[0].Email;
        }

        EmailTemplate template = getTemplate('Leave_Submitted_Email');
        
        // Fallback Content
        String subject = '🔔 New Leave Request';
        String rawBody = '<html><body><p><b>A leave request has been submitted.</b></p><p>Employee: {!Leave_Request__c.Employee__r.Name}</p><p>Type: {!Leave_Request__c.Leave_Type__c}</p></body></html>';
        
        if (template != null) {
            subject = '🔔 New Leave Request – Action Required';
            rawBody = template.HtmlValue;
        } else {
             System.debug('Template Leave_Submitted_Email NOT found. Using Fallback.');
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        Id owaId = getOrgWideEmailId();

        for (Leave_Request__c req : requests) {
            String mgrEmail = mgrEmails.get(req.Reporting_Manager__c);
            
            // Customize for Work From Home
            String currentSubject = subject;
            String currentBody = rawBody;
            
            if (req.Leave_Type__r.Name != null && req.Leave_Type__r.Name.containsIgnoreCase('Work From Home')) {
                // User Requirement: NO 'Submitted' email for Work From Home. 
                // Only 'Approved' email is required.
                continue; 
            }

            if (mgrEmail != null) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{mgrEmail});
                mail.setSubject(currentSubject); 
                mail.setHtmlBody(renderBody(currentBody, req));
                if (owaId != null) mail.setOrgWideEmailAddressId(owaId);
                emails.add(mail);
            }

            // Notify System Admins
            for (User hr : hrUsers) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{hr.Email});
                mail.setSubject(currentSubject);
                mail.setHtmlBody(renderBody(currentBody, req));
                if (owaId != null) mail.setOrgWideEmailAddressId(owaId);
                emails.add(mail);
            }
            
            // Notify Specific HR (CT50)
            if (specializedHREmail != null) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{specializedHREmail});
                mail.setSubject(currentSubject);
                mail.setHtmlBody(renderBody(currentBody, req));
                if (owaId != null) mail.setOrgWideEmailAddressId(owaId);
                emails.add(mail);
            }
        }
        sendEmailsSafe(emails);
    }

    private static void sendApprovalEmails(Set<Id> recordIds, Boolean isHR) {
        List<Leave_Request__c> requests = [
            SELECT Id, Employee__c, Employee__r.Name, 
                   Reporting_Manager__c, Reporting_Manager__r.Name,
                   Leave_Type__c, Leave_Type__r.Name, From_Date__c, To_Date__c, Number_of_Days__c, Status__c,
                   Reason__c, Manager_Approval_Comment__c
            FROM Leave_Request__c WHERE Id IN :recordIds
        ];

        Set<Id> personIds = new Set<Id>();
        for(Leave_Request__c r : requests) {
            if(r.Employee__c != null) personIds.add(r.Employee__c);
            if(r.Reporting_Manager__c != null) personIds.add(r.Reporting_Manager__c);
        }
        Map<Id, String> emailMap = getEmails(personIds);

        String templateName = isHR ? 'Leave_HR_Approved' : 'Leave_Manager_Approved';
        
        EmailTemplate template = getTemplate(templateName);
        
        // Fallback Content
        String defaultSubject = '✅ Leave Request Approved';
        String defaultBody = '<html><body><p><b>Your leave request has been approved.</b></p><p>Employee: {!Leave_Request__c.Employee__r.Name}</p><p>Enjoy your leave!</p></body></html>';

        if (template != null) {
            if(isHR) defaultSubject = '✅ CONFIRMED – Your Leave is APPROVED';
            defaultBody = template.HtmlValue;
        } else {
            System.debug('Template ' + templateName + ' NOT found. Using Fallback.');
        }
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        Id owaId = getOrgWideEmailId();
        
        for (Leave_Request__c req : requests) {
            String empEmail = emailMap.get(req.Employee__c);
            
            // Check for WFH
            Boolean isWFH = (req.Leave_Type__r.Name != null && req.Leave_Type__r.Name.containsIgnoreCase('Work From Home'));
            
            String currentSubject = defaultSubject;
            String currentBody = defaultBody;

            // Custom WFH Logic
            if (isWFH) {
                // Determine subject
                // Unified Subject for WFH Approved
                currentSubject = 'Your Work From Home is Approved';

                // Refine Body Content
                if (currentBody.contains('Your leave request')) {
                    currentBody = currentBody.replace('Your leave request', 'Your Work From Home request');
                }
                
                // Replace "Confirmed by HR" with "Approved by Manager"
                currentBody = currentBody.replace('CONFIRMED</b> by HR', 'APPROVED</b> by Manager');
                currentBody = currentBody.replace('CONFIRMED by HR', 'Approved by Manager');

                // Replace footer text
                String wfhFooter = 'You can go ahead, but kindly ensure it doesn\'t affect your work or responsibilities. Thanks!';
                if (currentBody.contains('Enjoy your leave!')) {
                    currentBody = currentBody.replace('Enjoy your leave!', wfhFooter);
                } else if (!currentBody.contains(wfhFooter)) {
                     // If template doesn't have "Enjoy your leave!", append our message
                     currentBody += '<p>' + wfhFooter + '</p>';
                }
                
                // Consistency: Change signature from "HR Team" to "Manager"
                currentBody = currentBody.replace('HR Team', 'Manager');
            }

            // To Employee
            if (empEmail != null) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{empEmail});
                mail.setSubject(currentSubject);
                mail.setHtmlBody(renderBody(currentBody, req));
                if (owaId != null) mail.setOrgWideEmailAddressId(owaId);
                emails.add(mail);
            }
        }
        sendEmailsSafe(emails);
    }

    private static void sendRejectionEmails(Set<Id> recordIds) {
        List<Leave_Request__c> requests = [
            SELECT Id, Employee__c, Employee__r.Name,
                   Reporting_Manager__c, Reporting_Manager__r.Name,
                   Leave_Type__c, Leave_Type__r.Name, Manager_Approval_Comment__c,
                   From_Date__c, To_Date__c, Number_of_Days__c, Reason__c
            FROM Leave_Request__c WHERE Id IN :recordIds
        ];

        Set<Id> personIds = new Set<Id>();
        for(Leave_Request__c r : requests) {
            if(r.Employee__c != null) personIds.add(r.Employee__c);
        }
        Map<Id, String> emailMap = getEmails(personIds);
        
        EmailTemplate template = getTemplate('Leave_Manager_Rejected');
        
        String subject = '❌ Leave Request Rejected';
        String rawBody = '<html><body><p><b>Your leave request was rejected.</b></p><p>Employee: {!Leave_Request__c.Employee__r.Name}</p></body></html>';
        
        if (template != null) {
             rawBody = template.HtmlValue;
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        Id owaId = getOrgWideEmailId();

        for (Leave_Request__c req : requests) {
            String empEmail = emailMap.get(req.Employee__c);
            
            if (empEmail != null) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{empEmail});
                mail.setSubject(subject);
                mail.setHtmlBody(renderBody(rawBody, req));
                if (owaId != null) mail.setOrgWideEmailAddressId(owaId);
                emails.add(mail);
            }
        }
        sendEmailsSafe(emails);
    }

    // NEW METHOD: For Cancellation / Edit Confirmations (when status becomes 'Cancelled')
    private static void sendCancellationEmails(Set<Id> recordIds) {
        List<Leave_Request__c> requests = [
            SELECT Id, Employee__c, Employee__r.Name,
                   Leave_Type__c, Leave_Type__r.Name, 
                   From_Date__c, To_Date__c, Number_of_Days__c, Reason__c, Manager_Approval_Comment__c
            FROM Leave_Request__c WHERE Id IN :recordIds
        ];

        Set<Id> personIds = new Set<Id>();
        for(Leave_Request__c r : requests) {
            if(r.Employee__c != null) personIds.add(r.Employee__c);
        }
        Map<Id, String> emailMap = getEmails(personIds);
        
        // Use a generic template or hardcode if no specific cancellation template exists
        // Assuming we might not have a specific 'Leave_Cancelled' template on hand, using a formatted body.
        
        String subject = '⚠️ Leave Request Cancelled / Updated';
        String rawBody = '<html><body>'
            + '<p>Dear {!Leave_Request__c.Employee__r.Name},</p>'
            + '<p>Your leave request has been <b>Cancelled</b> or <b>Shortened</b> as requested.</p>'
            + '<p><b>Details:</b></p>'
            + '<ul>'
            + '<li>Type: {!Leave_Request__c.Leave_Type__c}</li>'
            + '<li>Dates: {!Leave_Request__c.From_Date__c} to {!Leave_Request__c.To_Date__c}</li>'
            + '</ul>'
            + '<p>If this was a partial cancellation, the dates above reflect the <b>cancelled portion</b>.</p>'
            + '<p>Regards,<br/>HR Team</p></body></html>';

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        Id owaId = getOrgWideEmailId();

        for (Leave_Request__c req : requests) {
            String empEmail = emailMap.get(req.Employee__c);
            
            if (empEmail != null) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{empEmail});
                mail.setSubject(subject);
                mail.setHtmlBody(renderBody(rawBody, req));
                if (owaId != null) mail.setOrgWideEmailAddressId(owaId);
                emails.add(mail);
            }
        }
        sendEmailsSafe(emails);
    }

    private static String renderBody(String htmlBody, Leave_Request__c req) {
        if(htmlBody == null) return '';
        String body = htmlBody;
        body = body.replace('{!Leave_Request__c.Employee__r.Name}', (req.Employee__r.Name != null ? req.Employee__r.Name : ''));
        
        // USE NAME INSTEAD OF ID
        body = body.replace('{!Leave_Request__c.Leave_Type__c}', (req.Leave_Type__r.Name != null ? req.Leave_Type__r.Name : ''));
        
        body = body.replace('{!Leave_Request__c.From_Date__c}', String.valueOf(req.From_Date__c));
        body = body.replace('{!Leave_Request__c.To_Date__c}', String.valueOf(req.To_Date__c));
        body = body.replace('{!Leave_Request__c.Number_of_Days__c}', (req.Number_of_Days__c != null ? String.valueOf(req.Number_of_Days__c) : '0'));
        body = body.replace('{!Leave_Request__c.Reason__c}', (req.Reason__c != null ? req.Reason__c : ''));
        body = body.replace('{!Leave_Request__c.Manager_Approval_Comment__c}', (req.Manager_Approval_Comment__c != null ? req.Manager_Approval_Comment__c : ''));
        
        // Backward compatibility for old templates
        body = body.replace('{!Leave_Request__c.Start_Date__c}', String.valueOf(req.From_Date__c));
        body = body.replace('{!Leave_Request__c.End_Date__c}', String.valueOf(req.To_Date__c));
        body = body.replace('{!Leave_Request__c.Total_Days__c}', (req.Number_of_Days__c != null ? String.valueOf(req.Number_of_Days__c) : '0'));
        body = body.replace('{!Leave_Request__c.Leave_Reason__c}', (req.Reason__c != null ? req.Reason__c : ''));
        body = body.replace('{!Leave_Request__c.Comments__c}', (req.Manager_Approval_Comment__c != null ? req.Manager_Approval_Comment__c : ''));

        body = body.replace('{!Recipient.Name}', 'User'); 
        return body;
    }
    
    private static Map<Id, String> getEmails(Set<Id> ids) {
        Map<Id, String> emails = new Map<Id, String>();
        if(ids.isEmpty()) return emails;
        
        for(Contact c : [SELECT Id, Email FROM Contact WHERE Id IN :ids]) {
            if(c.Email != null) emails.put(c.Id, c.Email);
        }
        for(User u : [SELECT Id, Email FROM User WHERE Id IN :ids]) {
            if(u.Email != null) emails.put(u.Id, u.Email);
        }
        return emails;
    }

    private static void sendEmailsSafe(List<Messaging.SingleEmailMessage> emails) {
        if(!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails, false);
            } catch(Exception e) {
                System.debug('Error sending emails: ' + e.getMessage());
            }
        }
    }
    
    // NEW Helper to safely get template
    private static EmailTemplate getTemplate(String developerName) {
        List<EmailTemplate> ts = [SELECT Id, HtmlValue FROM EmailTemplate WHERE DeveloperName = :developerName LIMIT 1];
        if (ts.isEmpty()) return null;
        return ts[0];
    }
}