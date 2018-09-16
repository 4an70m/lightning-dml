/**
 * Created by User on 18.07.2018.
 */

public with sharing class Dml {

    @AuraEnabled
    public static List<SObject> query(String query) {
        return new SoqlValidator(query).secureQuery().getResults();
    }

    @AuraEnabled
    public static List<SObject> performUpdate(List<SObject> sobjects) {
        return new SoqlValidator(sobjects).secureUpdate().getResults();
    }

    public class SoqlValidator {

        private String soql;
        private List<SObject> results;

        public SoqlValidator(String soql) {
            this.soql = soql;
        }

        private SoqlValidator(List<SObject> sObjects) {
            this.results = sObjects;
        }

        public SoqlValidator secureQuery() {
            try {
                this.results = Database.query(this.soql);
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

        public SoqlValidator unsecuredQuery() {
            try {
                this.results = Database.query(this.soql);
            } catch (Exception ex) {
                System.debug(ex.getStackTraceString());
                System.debug(ex.getMessage());
                throw new AuraHandledException(ex.getMessage());
            }
            return this;
        }

        public SoqlValidator secureUpdate() {
            try {
                if (this.results.isEmpty()) {
                    return this;
                }
                this.results = new SObjectUpdateValidator(this.results).getValidateResult();
                System.debug(this.results);
                Database.update(this.results);
            } catch (Exception ex) {
                System.debug(ex.getStackTraceString());
                System.debug(ex.getMessage());
                throw new AuraHandledException(ex.getMessage());
            }
            return this;
        }

        public SoqlValidator unsecuredUpdate() {
            try {
                System.debug(this.results);
                Database.update(this.results);
            } catch (Exception ex) {
                System.debug(ex.getStackTraceString());
                System.debug(ex.getMessage());
                throw new AuraHandledException(ex.getMessage());
            }
            return this;
        }

        public List<SObject> getResults() {
            return this.results;
        }
    }

    public abstract class SObjectValidator {

        private List<SObject> sObjectsToValidate;
        private SObjectType sObjectType;
        private DescribeSObjectResult describedSObjectType;

        public SObjectValidator(List<SObject> sobjectsToValidate) {
            this.sObjectsToValidate = sobjectsToValidate;
            System.debug(sobjectsToValidate);
            this.sObjectType = sobjectsToValidate.getSObjectType();
            if (this.sObjectType == null && !this.sObjectsToValidate.isEmpty()) {
                this.sObjectType = this.sObjectsToValidate[0].getSObjectType();
            }
            System.debug(this.sObjectType);
            this.describedSObjectType = this.sObjectType.getDescribe();
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

        public SObjectReadValidator(List<SObject> sobjectsToValidate) {
            super(sobjectsToValidate);
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

    public class SObjectUpdateValidator extends SObjectValidator {

        public SObjectUpdateValidator(List<SObject> sobjectsToValidate) {
            super(sobjectsToValidate);
        }

        protected override void checkObjectAccess() {
            if (!this.describedSObjectType.isAccessible() || !this.describedSObjectType.isUpdateable()) {
                throw new System.NoAccessException();
            }
        }

        protected override void checkFieldsAccess() {
            List<SObject> result = new List<SObject>();
            Map<String, SObjectField> sobjectFields = this.describedSObjectType.fields.getMap();
            for (SObject sobj : this.sObjectsToValidate) {
                result.add(this.validateSobject(sobj, sobjectFields));
            }
            this.sObjectsToValidate = result;
        }

        private SObject validateSobject(SObject sobj, Map<String, SObjectField> sobjectFields) {
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
            String typeName = this.describedSObjectType.getName();
            Type sobjectType = Type.forName(typeName);
            return (SObject) JSON.deserialize(JSON.serialize(sobjectPopulatedFields), sobjectType);
        }
    }
}