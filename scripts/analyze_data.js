const fs = require('fs');
const path = require('path');

const DATA_DIR = path.join(__dirname, '..', 'extracted_data');

function loadJSON(filename) {
    const filePath = path.join(DATA_DIR, filename);
    if (!fs.existsSync(filePath)) {
        return [];
    }
    return JSON.parse(fs.readFileSync(filePath, 'utf-8'));
}

function main() {
    const leaveTypes = loadJSON('Leave_Type__c.json');
    const leaveBalances = loadJSON('Leave_Balance__c.json');
    const leaveRequests = loadJSON('Leave_Request__c.json');

    console.log('=== DATA ANALYSIS SUMMARY ===\n');

    // 1. Leave Types
    console.log(`--- Leave Types (${leaveTypes.length} total) ---`);
    leaveTypes.forEach(t => {
        console.log(`- ${t.Name} (${t.Leave_Type_Code__c}): Quota=${t.Annual_Quota__c}, RequiresApproval=${t.Requires_Manager_Approval__c}`);
    });
    console.log();

    // 2. Leave Balances
    console.log(`--- Leave Balances (${leaveBalances.length} total) ---`);
    const uniqueBalanceEmployees = new Set(leaveBalances.map(b => b.Employee__c));
    console.log(`Unique Employees with Balances: ${uniqueBalanceEmployees.size}`);
    
    // Status distribution
    const balanceStatusCounts = {};
    leaveBalances.forEach(b => {
        const status = b.Status__c || 'N/A';
        balanceStatusCounts[status] = (balanceStatusCounts[status] || 0) + 1;
    });
    console.log('Status Distribution:');
    Object.entries(balanceStatusCounts).forEach(([k, v]) => console.log(`  - ${k}: ${v}`));
    console.log();

    // 3. Leave Requests
    console.log(`--- Leave Requests (${leaveRequests.length} total) ---`);
    const uniqueRequestEmployees = new Set(leaveRequests.map(r => r.Employee__c));
    console.log(`Unique Employees making Requests: ${uniqueRequestEmployees.size}`);
    
    // Status distribution
    const requestStatusCounts = {};
    leaveRequests.forEach(r => {
        const status = r.Status__c || 'N/A';
        requestStatusCounts[status] = (requestStatusCounts[status] || 0) + 1;
    });
    console.log('Status Distribution:');
    Object.entries(requestStatusCounts).forEach(([k, v]) => console.log(`  - ${k}: ${v}`));
    
    // Reason distribution (top 5)
    const reasons = {};
    leaveRequests.forEach(r => {
        if (r.Reason__c) {
            reasons[r.Reason__c] = (reasons[r.Reason__c] || 0) + 1;
        }
    });
    console.log('Top Reasons for Leave:');
    Object.entries(reasons)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5)
        .forEach(([k, v]) => console.log(`  - "${k}": ${v}`));
}

main();
