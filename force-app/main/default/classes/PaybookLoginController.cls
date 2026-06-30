public without sharing class PaybookLoginController {
    
    @AuraEnabled
    public static LoginResult authenticateEmployee(String employeeId, String password) {
        LoginResult result = new LoginResult();
        
        try {
            // Search for Contact by Employee_ID__c field
            List<Contact> employees = [SELECT Id, FirstName, LastName, Email, Phone, MobilePhone,
                                              MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry,
                                              Department, Department__c, Title, Password_Hash__c, Is_Active__c, Portal_Access_Type__c,
                                              Is_Probation__c, Employee_Type__c, Joining_Date__c
                                       FROM Contact 
                                       WHERE Employee_ID__c = :employeeId 
                                       LIMIT 1];
            
            if (employees.isEmpty()) {
                result.success = false;
                result.message = 'Employee ID not found. Please check your ID.';
                return result;
            }
            
            Contact emp = employees[0];
            
            // Check if employee is active
            if (!emp.Is_Active__c) {
                result.success = false;
                result.message = 'Your account is inactive. Please contact HR.';
                return result;
            }
            
            // Verify password
            if (emp.Password_Hash__c == null || emp.Password_Hash__c != password) {
                result.success = false;
                result.message = 'Invalid password. Please try again.';
                return result;
            }
            
            // Determine user role from Portal_Access_Type__c field
            String userRole = 'Employee'; // Default
            
            if (emp.Portal_Access_Type__c != null) {
                if (emp.Portal_Access_Type__c.contains('Manager')) {
                    userRole = 'Manager';
                } else if (emp.Portal_Access_Type__c.contains('HR')) {
                    userRole = 'HR Admin';
                } else {
                    userRole = 'Employee';
                }
            }
            
            // Return success with user details
            result.success = true;
            result.message = 'Login successful';
            result.userRole = userRole;
            result.contactId = emp.Id;
            result.employeeId = employeeId;
            result.employeeName = emp.FirstName + ' ' + emp.LastName;
            result.firstName = emp.FirstName;
            result.lastName = emp.LastName;
            result.email = emp.Email;
            result.phone = emp.Phone;
            result.mobile = emp.MobilePhone;
            result.title = emp.Title;
            result.department = emp.Department__c;
            
            
            result.isProbation = emp.Is_Probation__c;
            result.employeeType = emp.Employee_Type__c;
            
            // Calculate Years of Experience
            if (emp.Joining_Date__c != null) {
                Integer days = emp.Joining_Date__c.daysBetween(System.today());
                if (days < 30) {
                    result.yearsOfExperience = 'New Joiner';
                } else if (days < 365) {
                    Integer months = days / 30;
                    result.yearsOfExperience = months + ' Months';
                } else {
                    Decimal years = Decimal.valueOf(days) / 365.25;
                    result.yearsOfExperience = years.setScale(1) + ' Years';
                }
            } else {
                result.yearsOfExperience = 'N/A';
            }
            
        } catch (Exception e) {
            result.success = false;
            result.message = 'Login error: ' + e.getMessage();
            System.debug('Login Exception: ' + e.getStackTraceString());
        }
        
        return result;
    }
    
    @AuraEnabled
    public static LoginResult getContactDetails(String contactId) {
        LoginResult result = new LoginResult();
        try {
            Contact emp = [SELECT Id, FirstName, LastName, Email, Phone, MobilePhone,
                                  Title, Password_Hash__c, Is_Active__c, Portal_Access_Type__c,
                                  Is_Probation__c, Employee_Type__c, Employee_ID__c,
                                  Joining_Date__c, Gender__c, Birthdate, Department__c, 
                                  ReportsTo.Name
                           FROM Contact 
                           WHERE Id = :contactId 
                           LIMIT 1];
            
            result.success = true;
            result.contactId = emp.Id;
            result.employeeId = emp.Employee_ID__c;
            result.employeeName = emp.FirstName + ' ' + emp.LastName;
            result.firstName = emp.FirstName;
            result.lastName = emp.LastName;
            result.email = emp.Email;
            result.phone = emp.Phone;
            result.mobile = emp.MobilePhone;
            result.title = emp.Title;
            result.department = emp.Department__c; // Use custom field
            
            result.joiningDate = emp.Joining_Date__c;
            result.gender = emp.Gender__c;
            result.birthdate = emp.Birthdate;
            result.reportsTo = emp.ReportsTo.Name;

            result.isProbation = emp.Is_Probation__c;
            result.employeeType = emp.Employee_Type__c;
            
            // Calculate Years of Experience
            if (emp.Joining_Date__c != null) {
                Integer days = emp.Joining_Date__c.daysBetween(System.today());
                if (days < 30) {
                    result.yearsOfExperience = 'New Joiner';
                } else if (days < 365) {
                    Integer months = days / 30;
                    result.yearsOfExperience = months + ' Months';
                } else {
                    Decimal years = Decimal.valueOf(days) / 365.25;
                    result.yearsOfExperience = years.setScale(1) + ' Years';
                }
            } else {
                result.yearsOfExperience = 'N/A';
            }
            
            // Determine role again just in case
            String userRole = 'Employee'; 
            if (emp.Portal_Access_Type__c != null) {
                if (emp.Portal_Access_Type__c.contains('Manager')) {
                    userRole = 'Manager';
                } else if (emp.Portal_Access_Type__c.contains('HR')) {
                    userRole = 'HR Admin';
                }
            }
            result.userRole = userRole;
            
        } catch (Exception e) {
            result.success = false;
            result.message = 'Error fetching details: ' + e.getMessage();
        }
        return result;
    }
    
    @AuraEnabled
    public static Boolean updateEmployeeProfile(String contactId, Map<String, Object> updates) {
        try {
            Contact emp = [SELECT Id FROM Contact WHERE Id = :contactId LIMIT 1];
            
            if (updates.containsKey('email')) emp.Email = (String)updates.get('email');
            if (updates.containsKey('phone')) emp.Phone = (String)updates.get('phone');
            if (updates.containsKey('mobile')) emp.MobilePhone = (String)updates.get('mobile');
            if (updates.containsKey('password')) {
                String newPass = (String)updates.get('password');
                if (String.isNotBlank(newPass)) {
                    emp.Password_Hash__c = newPass;
                }
            }
            
            update emp;
            return true;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating profile: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean resetPassword(String employeeId, String email, String newPassword) {
        try {
            List<Contact> employees = [SELECT Id FROM Contact 
                                     WHERE Employee_ID__c = :employeeId 
                                     AND Email = :email 
                                     LIMIT 1];
            
            if (employees.isEmpty()) {
                return false;
            }
            
            Contact emp = employees[0];
            emp.Password_Hash__c = newPassword;
            update emp;
            return true;
        } catch (Exception e) {
            throw new AuraHandledException('Error resetting password: ' + e.getMessage());
        }
    }
    
    public class LoginResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String userRole;
        @AuraEnabled public String contactId;
        @AuraEnabled public String employeeId;
        @AuraEnabled public String employeeName;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String mobile;
        @AuraEnabled public String title;
        @AuraEnabled public String department;
        @AuraEnabled public Date joiningDate;
        @AuraEnabled public String gender;
        @AuraEnabled public Date birthdate;
        @AuraEnabled public String reportsTo;
        @AuraEnabled public Boolean isProbation;
        @AuraEnabled public String employeeType;
        @AuraEnabled public String yearsOfExperience;
    }
}