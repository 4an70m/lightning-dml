/**
 * Created by User on 18.07.2018.
 */

public with sharing class Dml {

    @AuraEnabled
    public static List<SObject> dmlQuery(String query) {
        return new SoqlValidator(query).secureQuery().getResults();
    }

    @AuraEnabled
    public static List<SObject> dmlInsert(String sObjects, Boolean isAllOrNothing) {
        List<SObject> parsedObjects = (List<SObject>)JSON.deserializeStrict(sObjects, List<SObject>.class);
        return new SoqlValidator(parsedObjects).secureInsert(isAllOrNothing).getResults();
    }

    @AuraEnabled
    public static List<SObject> dmlUpdate(List<SObject> sObjects, Boolean isAllOrNothing) {
        return new SoqlValidator(sObjects).secureUpdate(isAllOrNothing).getResults();
    }

    @AuraEnabled
    public static List<SObject> dmlUpsert(List<SObject> sObjects, Boolean isAllOrNothing) {
        return null;
    }

    @AuraEnabled
    public static List<SObject> dmlDelete(List<SObject> sObjects, Boolean isAllOrNothing) {
        return null;
    }

    public class SoqlValidator {

        private String queryString;
        private List<SObject> results;

        public SoqlValidator(String soql) {
            this.queryString = soql;
        }

        private SoqlValidator(List<SObject> sObjects) {
            this.results = sObjects;
        }

        public SoqlValidator secureQuery() {
            try {
                this.results = Database.query(this.queryString);
                if (this.results.isEmpty()) {
                    return this;
                }
                new SObjectReadValidator(this.results).validate();
            } catch (Exception ex) {
                System.debug(ex.getStackTraceString());
                System.debug(ex.getMessage());
                throw new AuraHandledException(ex.getMessage());
            }
            return this;
        }

        public SoqlValidator secureInsert(Boolean isAllOrNothing) {
            Savepoint savepoint = Database.setSavepoint();
            try {
                if (this.results.isEmpty()) {
                    return this;
                }
                this.results = new SObjectInsertValidator(this.results).getValidateResult();
                Database.insert(this.results, isAllOrNothing);
            } catch (Exception ex) {
                Database.rollback(savepoint);
                System.debug(ex.getStackTraceString());
                System.debug(ex.getMessage());
                throw new AuraHandledException(ex.getMessage());
            }
            return this;
        }

        public SoqlValidator secureUpdate(Boolean isAllOrNothing) {
            Savepoint savepoint = Database.setSavepoint();
            try {
                if (this.results.isEmpty()) {
                    return this;
                }
                this.results = new SObjectUpdateValidator(this.results).getValidateResult();
                Database.update(this.results, isAllOrNothing);
            } catch (Exception ex) {
                Database.rollback(savepoint);
                System.debug(ex.getStackTraceString());
                System.debug(ex.getMessage());
                throw new AuraHandledException(ex.getMessage());
            }
            return this;
        }

        public SoqlValidator secureUpsert(Boolean isAllOrNothing) {
            return this;
        }

        public SoqlValidator secureDelete(Boolean isAllOrNothing) {
            return this;
        }

        public List<SObject> getResults() {
            return this.results;
        }
    }

    public abstract class SObjectValidator {

        private List<SObject> sObjectsToValidate;

        public SObjectValidator() {
        }

        public SObjectValidator(List<SObject> sObjectsToValidate) {
            this.sObjectsToValidate = sObjectsToValidate;
        }

        public virtual void validate() {
            this.checkObjectAccess();
            this.checkFieldsAccess();
        }

        public virtual List<SObject> getValidateResult() {
            this.checkObjectAccess();
            this.checkFieldsAccess();
            return this.sObjectsToValidate;
        }

        protected abstract void checkObjectAccess();
        protected abstract void checkFieldsAccess();

        protected Map<String, ChildRelationship> getChildRelationshipsByName(DescribeSObjectResult describedSObjectType) {
            Map<String, ChildRelationship> result = new Map<String, ChildRelationship>();
            List<ChildRelationship> childRelationships = describedSObjectType.getChildRelationships();
            for (ChildRelationship childRelationship : childRelationships) {
                result.put(childRelationship.getRelationshipName(), childRelationship);
            }
            return result;
        }
    }

    public class SObjectReadValidator extends SObjectValidator {

        private SObjectType sObjectType;
        private DescribeSObjectResult describedSObjectType;

        public SObjectReadValidator(List<SObject> sObjectsToValidate) {
            super(sObjectsToValidate);
            System.debug(sObjectsToValidate);
            this.sObjectType = sObjectsToValidate.getSObjectType();
            if (this.sObjectType == null && !this.sObjectsToValidate.isEmpty()) {
                this.sObjectType = this.sObjectsToValidate[0].getSObjectType();
            }
            System.debug(this.sObjectType);
            this.describedSObjectType = this.sObjectType.getDescribe();
        }

        protected override void checkObjectAccess() {
            if (!this.describedSObjectType.isAccessible() || !this.describedSObjectType.isQueryable()) {
                throw new System.NoAccessException();
            }
        }

        protected override void checkFieldsAccess() {
            Map<String, SObjectField> sobjectFields = this.describedSObjectType.fields.getMap();
            Map<String, ChildRelationship> childRelationshipsByName = this.getChildRelationshipsByName(describedSObjectType);
            for (SObject sobj : this.sObjectsToValidate) {
                this.validateSobject(sobj, sobjectFields, childRelationshipsByName);
            }
        }

        private void validateSobject(SObject sobj, Map<String, SObjectField> sobjectFields, Map<String, ChildRelationship> childRelationshipsByName) {
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
                    new SObjectReadValidator(sobj.getSObjects(fieldName)).validate();
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

    public class SObjectInsertValidator extends SObjectValidator {

        public SObjectInsertValidator(List<SObject> sObjectsToValidate) {
            super(sObjectsToValidate);
        }

        protected override void checkObjectAccess() {
            for (SObject sobj : this.sObjectsToValidate) {
                DescribeSObjectResult sobjectDescribe = sobj.getSObjectType().getDescribe();
                if (!sobjectDescribe.isAccessible() || !sobjectDescribe.isCreateable()) {
                    throw new System.NoAccessException();
                }
            }
        }

        protected override void checkFieldsAccess() {
            List<SObject> result = new List<SObject>();
            for (SObject sobj : this.sObjectsToValidate) {
                result.add(this.validateSobject(sobj));
            }
            this.sObjectsToValidate = result;
        }

        private SObject validateSobject(SObject sobj) {
            Map<String, SObjectField> sobjectFields = sobj.getSObjectType().getDescribe().fields.getMap();
            Map<String, Object> sobjectPopulatedFields = new Map<String, Object>(sobj.getPopulatedFieldsAsMap());
            for (String fieldName : sobjectPopulatedFields.keySet()) {
                System.debug('Field Name: ' + fieldName);
                SObjectField sobjectField = sobjectFields.get(fieldName);
                DescribeFieldResult fieldDescribe = sobjectField.getDescribe();
                if (sobjectField == null) {
                    System.debug('Invalid field: ' + fieldName);
                    throw new AuraHandledException('Invalid field: ' + fieldName);
                } else if (!fieldDescribe.isAccessible() || !fieldDescribe.isCreateable()) {
                    System.debug('Not creatable field: ' + fieldName);
                    sobjectPopulatedFields.remove(fieldName);
                    continue;
                }
                System.debug('Creatable field: ' + fieldName);
            }
            Type sobjectType = Type.forName(sobj.getSObjectType().getDescribe().getName());
            return (SObject) JSON.deserialize(JSON.serialize(sobjectPopulatedFields), sobjectType);
        }
    }

    public class SObjectUpdateValidator extends SObjectValidator {

        public SObjectUpdateValidator(List<SObject> sObjectsToValidate) {
            super(sObjectsToValidate);
        }

        protected override void checkObjectAccess() {
            for (SObject sobj : this.sObjectsToValidate) {
                DescribeSObjectResult sobjectDescribe = sobj.getSObjectType().getDescribe();
                if (!sobjectDescribe.isAccessible() || !sobjectDescribe.isQueryable()) {
                    throw new System.NoAccessException();
                }
            }
        }

        protected override void checkFieldsAccess() {
            List<SObject> result = new List<SObject>();
            for (SObject sobj : this.sObjectsToValidate) {
                result.add(this.validateSobject(sobj));
            }
            this.sObjectsToValidate = result;
        }

        private SObject validateSobject(SObject sobj) {
            Map<String, SObjectField> sobjectFields = sobj.getSObjectType().getDescribe().fields.getMap();
            Map<String, Object> sobjectPopulatedFields = new Map<String, Object>(sobj.getPopulatedFieldsAsMap());
            for (String fieldName : sobjectPopulatedFields.keySet()) {
                System.debug('Field Name: ' + fieldName);
                SObjectField sobjectField = sobjectFields.get(fieldName);
                DescribeFieldResult fieldDescribe = sobjectField.getDescribe();
                if (sobjectField == null) {
                    System.debug('Invalid field: ' + fieldName);
                    throw new AuraHandledException('Invalid field: ' + fieldName);
                } else if (!fieldDescribe.isAccessible() || !fieldDescribe.isUpdateable()) {
                    if (fieldDescribe.isExternalId() || fieldDescribe.getName() == 'Id') {
                        continue;
                    }
                    System.debug('Not updatable field: ' + fieldName);
                    sobjectPopulatedFields.remove(fieldName);
                    continue;
                }
                System.debug('Updatable field: ' + fieldName);
            }
            Type sobjectType = Type.forName(sobj.getSObjectType().getDescribe().getName());
            return (SObject) JSON.deserialize(JSON.serialize(sobjectPopulatedFields), sobjectType);
        }
    }
}