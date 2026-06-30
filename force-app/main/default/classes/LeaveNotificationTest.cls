@isTest
public class LeaveNotificationTest {
    
    @testSetup
    static void setupData() {
        // Create Contacts
        Contact manager = new Contact(LastName = 'Manager', Email = 'manager@test.com');
        insert manager;
        
        Contact employee = new Contact(LastName = 'Employee', Email = 'employee@test.com');
        insert employee;
        
        // Create Leave Type
        Leave_Type__c lt = new Leave_Type__c(Name = 'Casual Leave', Is_Active__c = true);
        insert lt;

        // Create HR User (Mocking by Profile)
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User hrUser = new User(
            Alias = 'hradmin', Email='hr@test.com', 
            EmailEncodingKey='UTF-8', LastName='HR', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='hradmin' + DateTime.now().getTime() + '@test.com'
        );
        insert hrUser;
    }

    @isTest
    static void testLeaveSubmission() {
        Contact emp = [SELECT Id FROM Contact WHERE Email = 'employee@test.com' LIMIT 1];
        Contact mgr = [SELECT Id FROM Contact WHERE Email = 'manager@test.com' LIMIT 1];
        Leave_Type__c lt = [SELECT Id FROM Leave_Type__c LIMIT 1];

        Test.startTest();
        Leave_Request__c req = new Leave_Request__c(
            Employee__c = emp.Id,
            Reporting_Manager__c = mgr.Id,
            From_Date__c = Date.today().addDays(1),
            To_Date__c = Date.today().addDays(3),
            Reason__c = 'Vacation',
            Status__c = 'Submitted', 
            Leave_Type__c = lt.Id
        );
        insert req;
        Test.stopTest();
    }
    
    @isTest
    static void testManagerApproval() {
        Contact emp = [SELECT Id FROM Contact WHERE Email = 'employee@test.com' LIMIT 1];
        Contact mgr = [SELECT Id FROM Contact WHERE Email = 'manager@test.com' LIMIT 1];
        Leave_Type__c lt = [SELECT Id FROM Leave_Type__c LIMIT 1];
        
        Leave_Request__c req = new Leave_Request__c(
            Employee__c = emp.Id,
            Reporting_Manager__c = mgr.Id,
            From_Date__c = Date.today(),
            To_Date__c = Date.today(),
            Reason__c = 'Sick',
            Status__c = 'Submitted',
            Leave_Type__c = lt.Id
        );
        insert req;

        Test.startTest();
        req.Status__c = 'Approved';
        update req;
        Test.stopTest();
    }

    @isTest
    static void testHRApproval() {
        Contact emp = [SELECT Id FROM Contact WHERE Email = 'employee@test.com' LIMIT 1];
        Leave_Type__c lt = [SELECT Id FROM Leave_Type__c LIMIT 1];
        
        Leave_Request__c req = new Leave_Request__c(
            Employee__c = emp.Id,
            From_Date__c = Date.today(),
            To_Date__c = Date.today(),
            Status__c = 'Approved', // Pre-state
            Leave_Type__c = lt.Id
        );
        insert req;

        Test.startTest();
        req.Status__c = 'HR_Approved';
        update req;
        Test.stopTest();
    }

    @isTest
    static void testRejection() {
        Contact emp = [SELECT Id FROM Contact WHERE Email = 'employee@test.com' LIMIT 1];
        Leave_Type__c lt = [SELECT Id FROM Leave_Type__c LIMIT 1];
        
        Leave_Request__c req = new Leave_Request__c(
            Employee__c = emp.Id,
            From_Date__c = Date.today(),
            To_Date__c = Date.today(),
            Status__c = 'Submitted',
            Leave_Type__c = lt.Id
        );
        insert req;

        Test.startTest();
        req.Status__c = 'Manager_Rejected';
        req.Manager_Approval_Comment__c = 'Not valid';
        update req;
        Test.stopTest();
    }
}