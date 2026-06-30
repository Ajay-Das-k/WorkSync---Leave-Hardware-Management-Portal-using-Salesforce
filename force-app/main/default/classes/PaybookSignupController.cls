public without sharing class PaybookSignupController {
    
    @AuraEnabled
    public static SignupResult registerEmployee(String firstName, String lastName, String email, 
                                                 String employeeId, String password, String confirmPassword,
                                                 String department, String employeeType, String joiningDate,
                                                 String gender, String mobile, String birthdate) {
        SignupResult result = new SignupResult();
        
        try {
            
            // Validation - ALL REQUIRED (including new critical ones)
            if (String.isBlank(firstName) || String.isBlank(lastName) || String.isBlank(email) || 
                String.isBlank(employeeId) || String.isBlank(password) || String.isBlank(employeeType) ||
                String.isBlank(joiningDate) || String.isBlank(gender)) {
                result.success = false;
                result.message = 'Please fill all required fields (Gender is required for Maternity logic)';
                return result;
            }
            
            // Password validation
            if (password.length() < 6) {
                result.success = false;
                result.message = 'Password must be at least 6 characters';
                return result;
            }
            
            if (password != confirmPassword) {
                result.success = false;
                result.message = 'Passwords do not match';
                return result;
            }
            
            // Check if Employee ID already exists
            List<Contact> existingContacts = [SELECT Id FROM Contact 
                                              WHERE Employee_ID__c = :employeeId LIMIT 1];
            
            if (!existingContacts.isEmpty()) {
                result.success = false;
                result.message = 'Employee ID already registered. Please login instead.';
                return result;
            }
            
            // Check if Email already exists
            List<Contact> emailCheck = [SELECT Id FROM Contact WHERE Email = :email LIMIT 1];
            
            if (!emailCheck.isEmpty()) {
                result.success = false;
                result.message = 'Email already registered. Please login instead.';
                return result;
            }

            // Validate Employee Type (picklist values)
            List<String> validEmployeeTypes = new List<String>{'Permanent', 'Probation'};
            if (!validEmployeeTypes.contains(employeeType)) {
                result.success = false;
                result.message = 'Invalid Employee Type selected';
                return result;
            }
            
            // Validate and parse dates
            Date joiningDateObj;
            Date birthdateObj;
            try {
                joiningDateObj = Date.valueOf(joiningDate);
                if (String.isNotBlank(birthdate)) {
                    birthdateObj = Date.valueOf(birthdate);
                }
            } catch (Exception e) {
                result.success = false;
                result.message = 'Invalid date format';
                return result;
            }
            
            // Create new Contact record with REQUIRED fields
            Contact newContact = new Contact(
                FirstName = firstName,
                LastName = lastName,
                Email = email,
                Employee_ID__c = employeeId,
                Password_Hash__c = password,
                Is_Active__c = true,
                Portal_Access_Type__c = 'Employee',
                Department__c = String.isNotBlank(department) ? department : null,
                Employee_Type__c = employeeType,
                Joining_Date__c = joiningDateObj,
                
                // New Fields
                Gender__c = gender, // Assumed Custom Field based on context
                MobilePhone = mobile,
                Birthdate = birthdateObj,
                ReportsToId = null, // Manager assignment removed from signup form
                
                // Default Grants (User requested "Identify who can app leave")
                // Assuming defaults are TRUE for everyone initially
                Can_Apply_Casual__c = true,
                Can_Apply_Sick__c = true,
                Can_Apply_Marriage__c = true,
                Can_Apply_Bereavement__c = true
                // Can_Apply_Maternity__c is calculated formula
            );
            
            insert newContact;
            
            // Assign default leave balances
            List<Leave_Type__c> leaveTypes = [SELECT Id, Name FROM Leave_Type__c WHERE Is_Active__c = true];
            List<Leave_Balance__c> balancesToInsert = new List<Leave_Balance__c>();
            
            for (Leave_Type__c lt : leaveTypes) {
                Decimal defaultBalance = 0;
                String typeName = lt.Name;
                
                if (typeName.containsIgnoreCase('Annual') || typeName.containsIgnoreCase('Earned')) {
                    defaultBalance = 20;
                } else if (typeName.containsIgnoreCase('Casual')) {
                    if (String.isNotBlank(employeeType) && employeeType.equalsIgnoreCase('Probation')) {
                        defaultBalance = 0;
                    } else {
                        defaultBalance = 12;
                    }
                } else if (typeName.containsIgnoreCase('Sick')) {
                    defaultBalance = 6;
                } else if (typeName.containsIgnoreCase('Maternity')) {
                    defaultBalance = (String.isNotBlank(gender) && gender.equalsIgnoreCase('Female')) ? 180 : 0;
                } else if (typeName.containsIgnoreCase('Paternity')) {
                    defaultBalance = (String.isNotBlank(gender) && gender.equalsIgnoreCase('Male')) ? 5 : 0;
                } else if (typeName.containsIgnoreCase('Bereavement')) {
                    defaultBalance = 5;
                }
                
                // Do not create balance record if 0 for gender-specific leaves? 
                // Better to create with 0 so they see it but can't use it (or validation blocks it).
                
                balancesToInsert.add(new Leave_Balance__c(
                    Employee__c = newContact.Id,
                    Leave_Type__c = lt.Id,
                    Opening_Balance__c = defaultBalance,
                    Used__c = 0,
                    Year__c = System.today().year(),
                    Pending__c = 0,
                    Carried_Forward__c = 0,
                    Status__c = 'Active'
                ));
            }

            
            if (!balancesToInsert.isEmpty()) {
                insert balancesToInsert;
            }
            
            result.success = true;
            result.message = 'Account created successfully! Please login.';
            result.contactId = newContact.Id;
            
        } catch (DmlException e) {
            result.success = false;
            result.message = 'Error creating account: ' + e.getMessage();
            System.debug('Signup Error: ' + e.getStackTraceString());
        } catch (Exception e) {
            result.success = false;
            result.message = 'An error occurred: ' + e.getMessage();
            System.debug('Exception: ' + e.getStackTraceString());
        }
        
        return result;
    }
    
    public class SignupResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String contactId;
    }
}