const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const OBJECTS = ['Leave_Type__c', 'Leave_Balance__c', 'Leave_Request__c'];
const OUTPUT_DIR = path.join(__dirname, '..', 'extracted_data');

if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

function runCommand(command) {
    try {
        const stdout = execSync(command, { maxBuffer: 10 * 1024 * 1024, encoding: 'utf-8' });
        return stdout;
    } catch (error) {
        console.error(`Error running command: ${command}`);
        console.error(error.message);
        if (error.stdout) console.error(`stdout: ${error.stdout}`);
        if (error.stderr) console.error(`stderr: ${error.stderr}`);
        throw error;
    }
}

function main() {
    console.log('Starting data export for Salesforce Leave App objects...');
    
    // 1. Export Custom Objects
    for (const sobject of OBJECTS) {
        console.log(`\n--- Processing SObject: ${sobject} ---`);
        
        console.log(`Describing ${sobject}...`);
        const describeRaw = runCommand(`sf sobject describe --sobject ${sobject} --json`);
        const describeData = JSON.parse(describeRaw);
        
        if (!describeData.result || !describeData.result.fields) {
            console.error(`Failed to describe ${sobject} - result or fields missing.`);
            continue;
        }
        
        const queryableFields = describeData.result.fields
            .filter(f => f.type !== 'address' && f.type !== 'location')
            .map(f => f.name);
            
        console.log(`Found ${queryableFields.length} queryable fields on ${sobject}.`);
        
        const soqlQuery = `SELECT ${queryableFields.join(', ')} FROM ${sobject}`;
        
        console.log(`Querying records...`);
        const queryResultRaw = runCommand(`sf data query -q "${soqlQuery}" --json`);
        const queryResult = JSON.parse(queryResultRaw);
        
        let records = [];
        if (queryResult.result && queryResult.result.records) {
            records = queryResult.result.records;
        } else if (queryResult.result) {
            records = queryResult.result;
        }
        
        console.log(`Retrieved ${records.length} records for ${sobject}.`);
        
        const outputFile = path.join(OUTPUT_DIR, `${sobject}.json`);
        fs.writeFileSync(outputFile, JSON.stringify(records, null, 2), 'utf-8');
        console.log(`Saved ${records.length} records to ${outputFile}`);
    }

    // 2. Export Employee Contacts
    console.log(`\n--- Processing SObject: Contact (Employees) ---`);
    console.log(`Describing Contact...`);
    const contactDescribeRaw = runCommand(`sf sobject describe --sobject Contact --json`);
    const contactDescribeData = JSON.parse(contactDescribeRaw);
    
    if (contactDescribeData.result && contactDescribeData.result.fields) {
        const contactFields = contactDescribeData.result.fields
            .filter(f => f.type !== 'address' && f.type !== 'location')
            .map(f => f.name);
            
        console.log(`Found ${contactFields.length} queryable fields on Contact.`);
        
        const contactQuery = `SELECT ${contactFields.join(', ')} FROM Contact WHERE Employee_Type__c != null`;
        
        console.log(`Querying Employee Contacts...`);
        const contactResultRaw = runCommand(`sf data query -q "${contactQuery}" --json`);
        const contactResult = JSON.parse(contactResultRaw);
        
        let contactRecords = [];
        if (contactResult.result && contactResult.result.records) {
            contactRecords = contactResult.result.records;
        } else if (contactResult.result) {
            contactRecords = contactResult.result;
        }
        
        console.log(`Retrieved ${contactRecords.length} Employee Contact records.`);
        const contactOutputFile = path.join(OUTPUT_DIR, `Employee_Contact.json`);
        fs.writeFileSync(contactOutputFile, JSON.stringify(contactRecords, null, 2), 'utf-8');
        console.log(`Saved Employee Contacts to ${contactOutputFile}`);
    } else {
        console.error('Failed to describe Contact.');
    }
    
    console.log('\nData export completed successfully.');
}

main();
