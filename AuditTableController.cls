public with sharing class AuditTableController {

    @AuraEnabled(cacheable=true)
    public static List<Audit__c> getAuditRecords(String recordId) {
        return [
            SELECT
                Id,
                Field_Name__c,
                New_Value__c,
                New_Value_Lookup_ID__c,
                Old_Value__c,
                Old_Value_Lookup_ID__c,
                Modified_By__c,
                Modified_By__r.Name,
                Modified_Date__c,
                Record_Id__c
            FROM Audit__c
            WHERE Record_Id__c = :recordId
            ORDER BY Modified_Date__c DESC
        ];
    }
}
