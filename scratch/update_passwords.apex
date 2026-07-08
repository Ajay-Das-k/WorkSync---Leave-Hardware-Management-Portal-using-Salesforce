Contact hrAdmin = [SELECT Id, Password_Hash__c FROM Contact WHERE Employee_ID__c = 'CT50' LIMIT 1];
hrAdmin.Password_Hash__c = 'Welcome@HR50';
update hrAdmin;
System.debug('HR Admin password updated to Welcome@HR50');

Contact manager = [SELECT Id, Password_Hash__c FROM Contact WHERE Employee_ID__c = 'CT01' LIMIT 1];
manager.Password_Hash__c = 'Welcome@Manager01';
update manager;
System.debug('Manager password updated to Welcome@Manager01');
