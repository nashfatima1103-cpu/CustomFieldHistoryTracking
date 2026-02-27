public class AuditRecordCreation {
    /**
     * Created by Nashra Fatima for Audit Object record creation.
     */

    /**
     * Entry point for recording audit trail for field changes
     */
    public static void recordUpdated(List<sObject> list_newRecord, List<sObject> list_oldRecord, String str_objectName) {
        try {
            System.debug('In AuditRecordCreation.recordUpdated');

            Set<String> trackedFields = getTrackedFields(str_objectName);
            if (trackedFields.isEmpty()) return;

            Map<String, Schema.SObjectField> fieldMap = getFieldMap(str_objectName);
            if (fieldMap == null) return;

            Map<String, Set<Id>> lookupIdsMap = new Map<String, Set<Id>>();
            List<Map<String, Object>> changedFields = collectChanges(list_newRecord, list_oldRecord, trackedFields, fieldMap, lookupIdsMap);

            Map<Id, String> lookupLabels = resolveLookupLabels(lookupIdsMap);
            List<Audit__c> audits = buildAuditRecords(changedFields, lookupLabels, str_objectName);

            if (!audits.isEmpty()) {
                insert audits;
            }
        } catch (Exception ex) {
            System.debug('Audit creation failed: ' + ex.getMessage());
        }
    }

    /**
     * Load tracked fields from custom metadata for the given object
     */
    private static Set<String> getTrackedFields(String objectName) {
        Set<String> fields = new Set<String>();
        for (Audit_Values__mdt meta : [SELECT Field_Name__c FROM Audit_Values__mdt WHERE Object__c = :objectName]) {
            if (String.isNotBlank(meta.Field_Name__c)) {
                fields.add(meta.Field_Name__c);
            }
        }
        return fields;
    }

    /**
     * Retrieve field metadata map for the target object
     */
    private static Map<String, Schema.SObjectField> getFieldMap(String objectName) {
        try {
            return Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap();
        } catch (Exception e) {
            System.debug('Invalid object name passed: ' + objectName);
            return null;
        }
    }

    /**
     * Collect changed fields and identify lookup references to resolve
     */
    private static List<Map<String, Object>> collectChanges(
        List<sObject> newRecords,
        List<sObject> oldRecords,
        Set<String> trackedFields,
        Map<String, Schema.SObjectField> fieldMap,
        Map<String, Set<Id>> lookupIdsMap
    ) {
        List<Map<String, Object>> changes = new List<Map<String, Object>>();

        for (Integer i = 0; i < newRecords.size(); i++) {
            sObject newRec = newRecords[i];
            sObject oldRec = oldRecords[i];
            Id recordId = (Id)newRec.get('Id');

            for (String fieldName : trackedFields) {
                if (!fieldMap.containsKey(fieldName)) continue;

                Object oldValue = oldRec.get(fieldName);
                Object newValue = newRec.get(fieldName);

                Boolean isChanged = (oldValue == null && newValue != null) ||
                                    (oldValue != null && !oldValue.equals(newValue));

                if (!isChanged) continue;

                Schema.DisplayType fieldType = fieldMap.get(fieldName).getDescribe().getType();
                String relatedObjectName = null;

                if (fieldType == Schema.DisplayType.REFERENCE) {
                    List<Schema.SObjectType> relatedTypes = fieldMap.get(fieldName).getDescribe().getReferenceTo();
                    if (!relatedTypes.isEmpty()) {
                        relatedObjectName = relatedTypes[0].getDescribe().getName();

                        if (oldValue != null) {
                            if (!lookupIdsMap.containsKey(relatedObjectName)) {
                                lookupIdsMap.put(relatedObjectName, new Set<Id>());
                            }
                            lookupIdsMap.get(relatedObjectName).add((Id)oldValue);
                        }
                        if (newValue != null) {
                            if (!lookupIdsMap.containsKey(relatedObjectName)) {
                                lookupIdsMap.put(relatedObjectName, new Set<Id>());
                            }
                            lookupIdsMap.get(relatedObjectName).add((Id)newValue);
                        }
                    }
                }

                changes.add(new Map<String, Object>{
                    'FieldName' => fieldName,
                    'OldValue' => oldValue,
                    'NewValue' => newValue,
                    'FieldType' => fieldType,
                    'RecordId' => recordId,
                    'RelatedObject' => relatedObjectName
                });
            }
        }
        return changes;
    }

    /**
     * Run SOQLs in bulk to resolve lookup record labels
     */
    private static Map<Id, String> resolveLookupLabels(Map<String, Set<Id>> objectToIds) {
        Map<Id, String> labelMap = new Map<Id, String>();

        for (String objectName : objectToIds.keySet()) {
            Set<Id> ids = objectToIds.get(objectName);
            if (ids.isEmpty()) continue;

            try {
                String query = 'SELECT Id, Name FROM ' + objectName + ' WHERE Id IN :ids';
                List<sObject> results = Database.query(query);
                for (sObject rec : results) {
                    labelMap.put(rec.Id, String.valueOf(rec.get('Name')));
                }
            } catch (Exception e) {
                System.debug('Lookup label query failed for object ' + objectName + ': ' + e.getMessage());
            }
        }
        return labelMap;
    }

    /**
     * Construct the Audit__c records based on field changes
     */
    private static List<Audit__c> buildAuditRecords(List<Map<String, Object>> changes, Map<Id, String> labelMap, String objectName) {
        List<Audit__c> audits = new List<Audit__c>();
        //Map<String, String> objectToAuditField = getObjectToAuditFieldMap();

        for (Map<String, Object> change : changes) {
            try {
                Audit__c audit = new Audit__c();
                String fieldName = (String)change.get('FieldName');
                Object oldValue = change.get('OldValue');
                Object newValue = change.get('NewValue');
                Schema.DisplayType fieldType = (Schema.DisplayType)change.get('FieldType');
                Id recordId = (Id)change.get('RecordId');
                String relatedObjectName = (String)change.get('RelatedObject');

                audit.Record_Id__c = recordId;
                audit.Object__c = objectName;
                audit.Field_Name__c = fieldName;
                audit.Modified_Date__c = System.now();
                audit.Modified_By__c = UserInfo.getUserId();

                if (fieldType == Schema.DisplayType.REFERENCE) {
                    audit.Old_Value_Lookup_ID__c = oldValue != null ? String.valueOf(oldValue) : null;
                    audit.New_Value_Lookup_ID__c = newValue != null ? String.valueOf(newValue) : null;
                    audit.Old_Value__c = oldValue != null ? labelMap.get((Id)oldValue) : null;
                    audit.New_Value__c = newValue != null ? labelMap.get((Id)newValue) : null;
                } else {
                    audit.Old_Value__c = oldValue != null ? String.valueOf(oldValue) : null;
                    audit.New_Value__c = newValue != null ? String.valueOf(newValue) : null;
                }
                audits.add(audit);
            } catch (Exception e) {
                System.debug('Failed to build audit record: ' + e.getMessage());
            }
        }
        return audits;
    }  
} 
