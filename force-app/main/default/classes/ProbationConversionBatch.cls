public class ProbationConversionBatch implements Database.Batchable<sObject> {
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        // Pick up TWO groups:
        //   1. Probation employees who have completed 6 months (need conversion + balance grant)
        //   2. Permanent employees whose Casual Leave Opening_Balance__c is still 0
        //      (already converted before the balance-update logic existed)
        Date sixMonthsAgo = Date.today().addMonths(-6);
        
        // Pre-fetch Permanent employees with 0 Casual Leave balance to avoid nested semi-join SOQL restriction
        Set<Id> permanentIdsWithZeroBalance = new Set<Id>();
        for (Leave_Balance__c bal : [
            SELECT Employee__c FROM Leave_Balance__c 
            WHERE Leave_Type__r.Name LIKE '%Casual%' 
            AND Opening_Balance__c = 0
            AND Year__c = :Date.today().year()
            AND Employee__r.Employee_Type__c = 'Permanent'
        ]) {
            permanentIdsWithZeroBalance.add(bal.Employee__c);
        }

        return Database.getQueryLocator([
            SELECT Id, Name, Employee_Type__c, Joining_Date__c 
            FROM Contact 
            WHERE (
                (Employee_Type__c = 'Probation' AND Joining_Date__c <= :sixMonthsAgo)
                OR
                (Id IN :permanentIdsWithZeroBalance)
            )
        ]);
    }

    public void execute(Database.BatchableContext BC, List<Contact> scope) {
        List<Contact> employeesToConvert = new List<Contact>();
        List<Id> employeeIds = new List<Id>();
        
        for (Contact c : scope) {
            if (c.Employee_Type__c == 'Probation') {
                // Convert to Permanent
                // Note: Is_Probation__c is a formula field that auto-calculates from Employee_Type__c
                c.Employee_Type__c = 'Permanent';
                employeesToConvert.add(c);
                System.debug('Converting to Permanent: ' + c.Name + ' (' + c.Id + ')');
            } else {
                System.debug('Fixing leave balance for already-Permanent: ' + c.Name + ' (' + c.Id + ')');
            }
            // Always include in IDs list to fix/grant the Casual Leave balance
            employeeIds.add(c.Id);
        }
        
        if (!employeesToConvert.isEmpty()) {
            update employeesToConvert;
        }
        
        if (!employeeIds.isEmpty()) {
            // Get 'Casual Leave' Type ID
            List<Leave_Type__c> ltList = [SELECT Id FROM Leave_Type__c WHERE Name LIKE '%Casual%' LIMIT 1];
            
            if (!ltList.isEmpty()) {
                Id casualTypeId = ltList[0].Id;
                
                // Find existing Casual Leave balance records with Opening_Balance__c = 0
                List<Leave_Balance__c> balances = [SELECT Id, Employee__c, Opening_Balance__c, Year__c
                                                   FROM Leave_Balance__c 
                                                   WHERE Employee__c IN :employeeIds 
                                                   AND Leave_Type__c = :casualTypeId
                                                   AND Opening_Balance__c = 0]; // Only fix still-zero balances
                
                List<Leave_Balance__c> balancesToSave = new List<Leave_Balance__c>();
                Set<Id> employeesWithRecord = new Set<Id>();
                
                for (Leave_Balance__c bal : balances) {
                    bal.Opening_Balance__c = 12; // Grant standard 12 days for permanent employee
                    balancesToSave.add(bal);
                    employeesWithRecord.add(bal.Employee__c);
                    System.debug('Updating Casual Leave Opening_Balance to 12 for: ' + bal.Employee__c);
                }
                
                // For employees with NO balance record at all, create one
                for (Id empId : employeeIds) {
                    if (!employeesWithRecord.contains(empId)) {
                        // Check there is no record with a positive balance already (don't overwrite)
                        Integer existingCount = [SELECT Count() FROM Leave_Balance__c 
                                                WHERE Employee__c = :empId 
                                                AND Leave_Type__c = :casualTypeId 
                                                AND Opening_Balance__c > 0];
                        if (existingCount == 0) {
                            balancesToSave.add(new Leave_Balance__c(
                                Employee__c = empId,
                                Leave_Type__c = casualTypeId,
                                Opening_Balance__c = 12,
                                Used__c = 0,
                                Year__c = Date.today().year(),
                                Status__c = 'Active'
                            ));
                            System.debug('Creating new Casual Leave balance record for: ' + empId);
                        }
                    }
                }
                
                if (!balancesToSave.isEmpty()) {
                    upsert balancesToSave;
                }
            }
        }
    }

    public void finish(Database.BatchableContext BC) {
        System.debug('Probation Conversion Batch Completed. All eligible employees converted and Casual Leave balances fixed.');
    }
}