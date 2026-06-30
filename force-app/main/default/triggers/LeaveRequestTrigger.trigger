trigger LeaveRequestTrigger on Leave_Request__c (after insert, after update) {
    LeaveNotificationHandler.handleNotifications(Trigger.new, Trigger.oldMap);
}