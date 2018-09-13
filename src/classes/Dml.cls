/**
 * Created by User on 18.07.2018.
 */

public with sharing class Dml {

    @AuraEnabled
    public static List<SObject> query(String query) {
        return Database.query(query);
    }

    @AuraEnabled
    public static List<SObject> performUpdate(List<SObject> sobjects) {
        Database.update(sobjects);
        return sobjects;
    }
    
    public class SoqlValidator {
        
        private String soql;
        private List<SObject> results;
        
        public SoqlValidator(String soql) {
            this.soql = soql;
        }
        
        public void testRunSoql() {
            try {
                this.runSoql();
            } catch(Exception ex) {
                throw new AuraHandledException(ex.getMessage());
            }
        }
        
        public List<SObject> getResults() {
            return this.results;
        }

        private void runSoql() {
            List<SObject> queriedObjects = Database.query(this.soql);
            if (queriedObjects.isEmpty()) {
                this.results = queriedObjects;
                return;
            }
            this.checkAccess(queriedObjects);
        }

        private void checkAccess(List<SObject> queriedObjects) {
            SObjectType queriedSObjectType = queriedObjects.getSObjectType();
            DescribeSObjectResult describedSObjectType = queriedSObjectType.getDescribe();
            if (!describedSObjectType.isAccessible() || !describedSObjectType.isQueryable()) {
                throw new System.NoAccessException();
            }
            Map<String, SObjectField> sobjectFields = describedSObjectType.fields.getMap();
            Map<String, ChildRelationship> childRelationshipsByName = this.getChildRelationshipsByName(describedSObjectType);
            for (SObject sobj : queriedObjects) {
                Map<String, Object> sobjectPopulatedFields = sobj.getPopulatedFieldsAsMap();
                for (String fieldName : sobjectPopulatedFields.keySet()) {
                    System.debug('Field Name: ' + fieldName);
                    SObjectField sobjectField = sobjectFields.get(fieldName);
                    if (sobjectField == null) {
                        ChildRelationship childRelationship = childRelationshipsByName.get(fieldName);
                        if (childRelationship == null) {
                            System.debug('No child relationship: ' + fieldName);
                            continue;
                        }
                        System.debug('Child relationship: ' + fieldName);
                        System.debug(childRelationship.getChildSObject());
                        System.debug(childRelationship);
                        this.checkAccess(sobj.getSObjects(fieldName));
                        continue;
                    } else if (!sobjectField.getDescribe().isAccessible()) {
                        System.debug('Not accessible field: ' + fieldName);
                        sobj.put(sobjectField, null);
                        continue;
                    }
                    System.debug('Accessible field: ' + fieldName);
                }
            }
        }

        private Map<String, ChildRelationship> getChildRelationshipsByName(DescribeSObjectResult describedSObjectType) {
            Map<String, ChildRelationship> result = new Map<String, ChildRelationship>();
            List<ChildRelationship> childRelationships = describedSObjectType.getChildRelationships();
            for (ChildRelationship childRelationship : childRelationships) {
                result.put(childRelationship.getRelationshipName(), childRelationship);
            }
            return result;
        }
	}
}