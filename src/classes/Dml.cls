/**
    MIT License

    Copyright (c) 2017 Oleksii Fisher

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
*/

public with sharing class Dml {

    public enum DmlType {DML_INSERT, DML_UPDATE, DML_UPSERT, DML_DELETE}

    @AuraEnabled
    public static List<SObject> dmlQuery(String query) {
        return new SoqlValidator(query).secureQuery().getResults();
    }

    @AuraEnabled
    public static DmlResult dmlInsert(String sObjects, Boolean isAllOrNothing) {
        List<SObject> parsedObjects = (List<SObject>)JSON.deserializeStrict(sObjects, List<SObject>.class);
        return new SoqlValidator(parsedObjects).secureInsert(isAllOrNothing).getDmlResult();
    }

    @AuraEnabled
    public static DmlResult dmlUpdate(List<SObject> sObjects, Boolean isAllOrNothing) {
        return new SoqlValidator(sObjects).secureUpdate(isAllOrNothing).getDmlResult();
    }

    @AuraEnabled
    public static DmlResult dmlUpsert(String sObjects, Boolean isAllOrNothing) {
        List<SObject> parsedObjects = (List<SObject>)JSON.deserializeStrict(sObjects, List<SObject>.class);
        return new SoqlValidator(parsedObjects).secureUpsert(isAllOrNothing).getDmlResult();
    }

    @AuraEnabled
    public static DmlResult dmlDelete(List<SObject> sObjects, Boolean isAllOrNothing) {
        return new SoqlValidator(sObjects).secureDelete(isAllOrNothing).getDmlResult();
    }

    public class SoqlValidator {

        private String queryString;
        private List<SObject> results;
        private DmlResult dmlResult;

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
            this.dmlResult = new DmlResult(DmlType.DML_INSERT);
            Savepoint savepoint = Database.setSavepoint();
            try {
                if (this.results.isEmpty()) {
                    return this;
                }
                this.results = new SObjectInsertValidator(this.results).getValidatedResult();
                Map<SObjectType, List<SObject>> sobjectsGroupedByType = this.groupSobjectsByType(this.results);
                for (List<SObject> sobjectsToInsert : sobjectsGroupedByType.values()) {
                    this.dmlResult.addDmlResults(sobjectsToInsert, Database.insert(sobjectsToInsert, isAllOrNothing));
                }
                this.dmlResult.records = this.results;
            } catch (Exception ex) {
                Database.rollback(savepoint);
                System.debug(ex.getStackTraceString());
                System.debug(ex.getMessage());
                throw new AuraHandledException(ex.getMessage());
            }
            return this;
        }

        public SoqlValidator secureUpdate(Boolean isAllOrNothing) {
            this.dmlResult = new DmlResult(DmlType.DML_UPDATE);
            Savepoint savepoint = Database.setSavepoint();
            try {
                if (this.results.isEmpty()) {
                    return this;
                }
                this.results = new SObjectUpdateValidator(this.results).getValidatedResult();
                Map<SObjectType, List<SObject>> sobjectsGroupedByType = this.groupSobjectsByType(this.results);
                for (List<SObject> sobjectsToUpdate : sobjectsGroupedByType.values()) {
                    this.dmlResult.addDmlResults(sobjectsToUpdate, Database.update(sobjectsToUpdate, isAllOrNothing));
                }
                this.dmlResult.records = this.results;
            } catch (Exception ex) {
                Database.rollback(savepoint);
                System.debug(ex.getStackTraceString());
                System.debug(ex.getMessage());
                throw new AuraHandledException(ex.getMessage());
            }
            return this;
        }

        public SoqlValidator secureUpsert(Boolean isAllOrNothing) {
            this.dmlResult = new DmlResult(DmlType.DML_UPSERT);
            Savepoint savepoint = Database.setSavepoint();
            try {
                if (this.results.isEmpty()) {
                    return this;
                }
                List<SObject> sobjectsToInsert = this.getSobjectsToInsert(this.results);
                List<SObject> sObjectsToUpdate = this.getSobjectsToUpdate(this.results);
                sobjectsToInsert = new SObjectInsertValidator(sobjectsToInsert).getValidatedResult();
                sObjectsToUpdate = new SObjectUpdateValidator(sObjectsToUpdate).getValidatedResult();
                this.results = new List<SObject>();
                this.results.addAll(sobjectsToInsert);
                this.results.addAll(sObjectsToUpdate);
                Map<SObjectType, List<SObject>> sobjectsGroupedByType = this.groupSobjectsByType(this.results);
                for (List<SObject> sobjectsToUpsert : sobjectsGroupedByType.values()) {
                    this.dmlResult.addDmlResults(sobjectsToUpsert, Database.upsert(sobjectsToUpsert, isAllOrNothing));
                }
                this.dmlResult.records = this.results;

            } catch (Exception ex) {
                Database.rollback(savepoint);
                System.debug(ex.getStackTraceString());
                System.debug(ex.getMessage());
                throw new AuraHandledException(ex.getMessage());
            }
            return this;
        }

        public SoqlValidator secureDelete(Boolean isAllOrNothing) {
            this.dmlResult = new DmlResult(DmlType.DML_DELETE);
            Savepoint savepoint = Database.setSavepoint();
            try {
                if (this.results.isEmpty()) {
                    return this;
                }
                this.results = new SObjectDeleteValidator(this.results).getValidatedResult();
                Map<SObjectType, List<SObject>> sobjectsGroupedByType = this.groupSobjectsByType(this.results);
                for (List<SObject> sobjectsToDelete : sobjectsGroupedByType.values()) {
                    this.dmlResult.addDmlResults(sobjectsToDelete, Database.delete(sobjectsToDelete, isAllOrNothing));
                }
                this.dmlResult.records = this.results;
            } catch (Exception ex) {
                Database.rollback(savepoint);
                System.debug(ex.getStackTraceString());
                System.debug(ex.getMessage());
                throw new AuraHandledException(ex.getMessage());
            }
            return this;
        }

        public List<SObject> getResults() {
            return this.results;
        }

        public DmlResult getDmlResult() {
            return this.dmlResult;
        }

        private Map<SObjectType, List<SObject>> groupSobjectsByType(List<SObject> sObjects) {
            Map<SObjectType, List<SObject>> result = new Map<SObjectType, List<SObject>>();
            for (SObject sobj : sObjects) {
                SObjectType sobjType = sobj.getSObjectType();
                if (!result.containsKey(sobjType)) {
                    result.put(sobjType, this.buildTypedList(sobjType));
                }
                result.get(sobjType).add(sobj);
            }
            return result;
        }

        private List<SObject> buildTypedList(SObjectType listType) {
            return (List<SObject>) Type.forName('List<' + listType + '>').newInstance();
        }

        private List<SObject> getSobjectsToInsert(List<SObject> sobjects) {
            List<SObject> result = new List<SObject>();
            for (SObject sobj : sobjects) {
                if (String.isEmpty(sobj.Id)) {
                    result.add(sobj);
                }
            }
            return result;
        }

        private List<SObject> getSobjectsToUpdate(List<SObject> sobjects) {
            List<SObject> result = new List<SObject>();
            for (SObject sobj : sobjects) {
                if (String.isNotEmpty(sobj.Id)) {
                    result.add(sobj);
                }
            }
            return result;
        }
    }

    public abstract class SObjectValidator {

        private List<SObject> sObjectsToValidate;

        public SObjectValidator(List<SObject> sObjectsToValidate) {
            this.sObjectsToValidate = sObjectsToValidate;
        }

        public virtual void validate() {
            this.checkObjectAccess();
            this.checkFieldsAccess();
        }

        public virtual List<SObject> getValidatedResult() {
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
            this.sObjectType = sObjectsToValidate.getSObjectType();
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
                    throw new AuraHandledException(System.StatusCode.INVALID_FIELD + ': ' + fieldName);
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
                if (!sobjectDescribe.isAccessible() || !sobjectDescribe.isUpdateable()) {
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
                    throw new AuraHandledException(System.StatusCode.INVALID_FIELD + ': ' + fieldName);
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

    public class SObjectDeleteValidator extends SObjectValidator {

        public SObjectDeleteValidator(List<SObject> sObjectsToValidate) {
            super(sObjectsToValidate);
        }

        protected override void checkObjectAccess() {
            for (SObject sobj : this.sObjectsToValidate) {
                DescribeSObjectResult sobjectDescribe = sobj.getSObjectType().getDescribe();
                if (!sobjectDescribe.isAccessible() || !sobjectDescribe.isDeletable()) {
                    throw new System.NoAccessException();
                }
            }
        }

        protected override void checkFieldsAccess() {
        }
    }

    public class DmlResult {

        @AuraEnabled public String dmlType;
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public List<SObject> records;
        @AuraEnabled public List<DmlRecordResult> dmlRecordResults;

        public DmlResult(DmlType type) {
            this.dmlType = type.name();
            this.records = new List<SObject>();
            this.dmlRecordResults = new List<DmlRecordResult>();
            this.isSuccess = true;
        }

        public void addDmlResults(List<SObject> sobjectsToInsert, List<Database.SaveResult> saveResults) {
            for (Integer i = 0; i < sobjectsToInsert.size(); i++) {
                this.dmlRecordResults.add(new DmlRecordResult(sobjectsToInsert[i], saveResults[i]));
            }
            this.recalculateIsSuccess();
        }

        public void addDmlResults(List<SObject> sobjectsToUpdate, List<Database.UpsertResult> saveResults) {
            for (Integer i = 0; i < sobjectsToUpdate.size(); i++) {
                this.dmlRecordResults.add(new DmlRecordResult(sobjectsToUpdate[i], saveResults[i]));
            }
            this.recalculateIsSuccess();
        }

        public void addDmlResults(List<SObject> sobjectsToDelete, List<Database.DeleteResult> saveResults) {
            for (Integer i = 0; i < sobjectsToDelete.size(); i++) {
                this.dmlRecordResults.add(new DmlRecordResult(sobjectsToDelete[i], saveResults[i]));
            }
            this.recalculateIsSuccess();
        }

        private void recalculateIsSuccess() {
            if (!this.isSuccess) {
                return;
            }
            for (DmlRecordResult dmlRecordResult : this.dmlRecordResults) {
                if (!dmlRecordResult.isSuccess) {
                    this.isSuccess = false;
                    break;
                }
            }
        }
    }

    public class DmlRecordResult {

        @AuraEnabled public Id id;
        @AuraEnabled public SObject record;
        @AuraEnabled public Boolean isCreated;
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public List<DmlError> errors;

        public DmlRecordResult(SObject record, Database.SaveResult saveResult) {
            this.record = record;
            this.id = saveResult.getId();
            this.isSuccess = saveResult.isSuccess();
            this.isCreated = saveResult.isSuccess();
            this.errors = this.convertErrors(saveResult.getErrors());
        }

        public DmlRecordResult(SObject record, Database.UpsertResult updateResult) {
            this.record = record;
            this.isCreated = updateResult.isCreated();
            this.id = updateResult.getId();
            this.isSuccess = updateResult.isSuccess();
            this.errors = this.convertErrors(updateResult.getErrors());
        }

        public DmlRecordResult(SObject record, Database.DeleteResult deleteResult) {
            this.record = record;
            this.id = deleteResult.getId();
            this.isCreated = false;
            this.isSuccess = deleteResult.isSuccess();
            this.errors = this.convertErrors(deleteResult.getErrors());
        }

        private List<DmlError> convertErrors(List<Database.Error> errors) {
            List<DmlError> result = new List<DmlError>();
            for (Database.Error error : errors) {
                result.add(new DmlError(error));
            }
            return result;
        }
    }

    public class DmlError {

        @AuraEnabled public  List<String> fields;
        @AuraEnabled public  String message;
        @AuraEnabled public  StatusCode statusCode;

        public DmlError(Database.Error error) {
            this.fields = error.getFields();
            this.message = error.getMessage();
            this.statusCode = error.getStatusCode();
        }
    }
}