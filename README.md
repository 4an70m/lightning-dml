# Lightning-dml
Component, which allows you to perform DML operations directly in lightning without using additional Apex controller. Much like `force:recordData`, but more Apex-like, component allows you to perform CRUD operations but with lists of records.
Included Apex Dml class, handles all the query logic and also checks the object for CRUD accessibility, as well as enforces FLS.

## Use-cases
When writing Lightning component, you might often run into a situation, when you need to call an Apex controller. Normally, you would write an Apex class for this which contains one-two methods: one for the query, the second one for a CRUD operation. This approach enforces us to have multiple tiny Apex controller classes, which serves extremely simple purposes, which flood your list of Apex classes and which requires to be covered by an Apex unit test.

The goal of the proposed approach is to eliminate this simple Apex controller classes, using lightning-dml component with a single test-covered Apex class and declaring DML operations on the client side.

## Security Concerns
While performing DML operations on the client side may seem unsafe, Salesforce provides means of ensuring that DML operation for the user is "legal". These are CRUD and FLS. Currently, Apex controller actions, called from lightning enforce neither CRUD nor FLS, so the Dml Apex class enforces them automatically, as well as it enforces sharing.

The idea is that if a user gains access to any DML operations through a browser, they will get access only to the content, they are allowed to, based on Permissions Sets, Profiles and Sharing. So it doesn't matter if the user opens this record through UI, or somehow will try to modify DML operations of the component in the browser. 

## Usage
To start using DML operations in Lightning simply include __dml__ component anywhere in your project. Make sure this component is loaded, before you use it, e.g. place it at the top of the component hierarchy.
```xml
<aura:component>
    <c:dml/>
    ...
    ...
</aura:component>
```
Now you may start performing client-side dml operations!

### Query:
Performs a single, with sharing query, enforcing CRUD and FLS. 
If an object is not available for the user `!isAccessible() || !isQueryable()`, an exception is thrown.
If a field is not available for the user - it is removed from the result. Same rules for the records in the subqueries.

___Method's signature___:
`dml.query({string} query)`

The method accepts a single dynamic SOQL-like query and follows the same limits of the dynamic SOQL.
The method returns a modified Promise object, which doesn't need to be covered with `$A.getCallback()`.
The result of the method - is a simple Array of JSON-serialized SObjects.

Example:
```javascript
yourFunction: function(cmp, evt, helper) {
    ...
    dml.query("SELECT Id FROM Account")
    .then(result => {
        console.log(result); //[{Id:"record_Id"}, ...]
    });
    ...
}
```

### Insert:
Performs a single DML operation of inserting a record or list of records in the database, enforcing CRUD and FLS. New Ids are returned as a part of the response. 
If an object is not available for the user `!isAccessible() || !isCreateable()`, an exception is thrown.
If a field is not available for the user - it is removed from the insert operation. 
If the operations fails somehow, the whole transactions is safePoint-guaranteed to be fully aborted.
___Method's signature:___
`dml.insert({object|object[]} sobjects, {boolean} isAllOrNothing = true)`

The method accepts any JSON-like representation of the SObject or a list of them. Due to the limitations, JSON-like SObject must include the type attribute. Example:
```javascript
    let accountToInsert = {"attributes": {"type": "Account"}, "field1": value1, ...};
```
For the sake of convinience, _dml_ component includes a small ___SObject()___ function to simplfiy the process of creating JSON-like SObjects (both variants are eqvivalent):
```javascript
    let accountToInsert = new SObject("Account", {"field1": value1, ...});
    let accountToInsert2 = SObject("Account", {"field1": value1, ...});
```
Second parameter of the method - `isAllOrNothing` accepts a boolean value and determines if the opeartion should have a partial success, or not.
The method returns a modified Promise object, which doesn't need to be covered with `$A.getCallback()`.
The result of the method is complex object - JSON version of Apex class __Dml.DmlResult__ (see [Dml result](#dml-result)).
Example:
```javascript
yourFunction: function(cmp, evt, helper) {
    ...
    let accountToInsert = new SObject("Account", {Name: "Test"});
    dml.insert(accountToInsert)
    .then(result => {
        console.log(result); //Dml.DmlResult object
    });
    ...
}
```

### Update:
Performs a single DML operation of updating a record or list of records in the database, enforcing CRUD and FLS.
If an object is not available for the user `!isAccessible() || !isUpdateable()`, an exception is thrown.
If a field is not available for the user - it is removed from the update operation. 
If the operations fails somehow, the whole transactions is safePoint-guaranteed to be fully aborted.
___Method's signature:___
`dml.update({object|object[]} sobjects, {boolean} isAllOrNothing = true)`

The method accepts any JSON-like representation of the SObject or a list of them. 
As the records for update have Ids, Apex doesn't require JSON objects to have type parameter specified.
Example:
```javascript
    let accountToUpdate = {"Id": "record_Id", "field1": value1, ...};
```
Second parameter of the method - `isAllOrNothing` accepts a boolean value and determines if the opeartion should have a partial success, or not.
The method returns a modified Promise object, which doesn't need to be covered with `$A.getCallback()`.
The result of the method is complex object - JSON version of Apex class __Dml.DmlResult__ (see [Dml result](#dml-result)).
Exmaple:
```javascript
yourFunction: function(cmp, evt, helper) {
    ...
    let accountToUpdate = new SObject("Account", {Name: "New name", Id: "record_Id"});
    let accountToUpdate2 = {Name: "New name", Id: "record_Id"};
    dml.update([accountToUpdate, accountToUpdate2])
    .then(result => {
        console.log(result); //Dml.DmlResult object
    });
    ...
}
```
### Upsert:
Performs a single dml operation of upserting a record or list of records in the database, enforcing CRUD and FLS.
If an object is not available for the user `!isAccessible() || !isUpdateable()` or `!isAccessible() || !isCreatable()` - based on the type of operation performed on the record, an exception is thrown.
If a field is not available for the user - it is removed from the upsert operation. 
If the operations fails somehow, the whole transactions is safePoint-guaranteed to be fully aborted.
___Method's signature:___
`dml.upsert({object|object[]} sobjects, {boolean} isAllOrNothing = true)`

The method accepts any JSON-like representation of the SObject or a list of them. 
All the records in the upsert call, either to be inserted or to be updated, must be type-specific.
Example:
```javascript
    let accountToUpsert1_insert = {"attributes": {"type": "Account"}, "field1": value1, ...};
    let accountToInsert2_update = new SObject("Account", {"Id": "record_Id", "field1": value1, ...});
    let accountToInsert3_insert = SObject("Account", {"field1": value1, ...});
```
Second parameter of the method - `isAllOrNothing` accepts a boolean value and determines if the opeartion should have a partial success, or not.
The method returns a modified Promise object, which doesn't need to be covered with `$A.getCallback()`.
The result of the method is complex object - JSON version of Apex class __Dml.DmlResult__ (see [Dml result](#dml-result)).

Example:
```javascript
yourFunction: function(cmp, evt, helper) {
    ...
    let accountToInsert = new SObject("Account", {Name: "Test"});
    let accountToUpdate = new SObject("Account", {Id: "record_Id", Name: "Test"});
    dml.upsert([accountToUpdate, accountToInsert])
    .then(result => {
        console.log(result); //Dml.DmlResult object
    });
    ...
}
```

### Delete:
Performs a single DML operation of deleting records in the database, enforcing CRUD.
If an object is not available for the user `!isAccessible() || !isDeletable()`, an exception is thrown.
If the operations fails somehow, the whole transactions is safePoint-guaranteed to be fully aborted.
___Method's signature:___
`dml.delete({string|object|string[]|object[]} sobjects, {boolean} isAllOrNothing = true)`

The method accepts any JSON-like representation of the SObject with specified Id, list of them, string Id, list of them or any combination of these parameters in the list. 
Example:
```javascript
    let accountToDelet1 = "record_Id";
    let accountToDelet2 = {"Id": "record_Id"};
    let accountToDelete3 = SObject("Account", {"Id": "record_Id"});
    let accountToDelete4 = new SObject("Account", {"Id": "record_Id"});
```
Second parameter of the method - `isAllOrNothing` accepts a boolean value and determines if the opeartion should have a partial success, or not.
The method returns a modified Promise object, which doesn't need to be covered with `$A.getCallback()`.
The result of the method is complex object - JSON version of Apex class __Dml.DmlResult__ (see [Dml result](#dml-result)).

Example:
```javascript
yourFunction: function(cmp, evt, helper) {
    ...
    let accountToDelete1 = "record_Id";
    let accountToDelete2 = {"Id": "record_Id"};
    let accountToDelete3 = SObject("Account", {"Id": "record_Id"});
    let accountToDelete4 = new SObject("Account", {"Id": "record_Id"});
    dml.delete([accountToDelete1, accountToDelete2, accountToDelete3, accountToDelete4])
    .then(result => {
        console.log(result); //Dml.DmlResult object
    });
    ...
}
```
## Dml result
DmlResult is the object, you receive as the result of dml operations: insert, update, upsert or delete. The object is represented in Apex by three classes: _Dml.DmlResult, Dml.DmlRecordResult, Dml.DmlError_.
Example JSON structure:
```javascript
{
    //dmlRecordResults - list of results for each issued record. Object is equivalent to Database.UpsertResult
    "dmlRecordResults":[{
        "errors":[], //list of errors, equivalent to Database.Error class
        "id":"record_Id",
        "isCreated":true, //specifies if the record was created, or updated
        "isSuccess":true 
        "record":{"Id":"record_id","Name":"Test"} 
    }],
    "dmlType":"DML_INSERT", //specifies the type of dml operation
    "isSuccess":true, //specifies if dml operations for all the records were successful
    "records":[{"Id":"record_id","Name":"Test"}] //list of all records in the dml operation
}
```

## Implementation details
Lightning-dml consists of a single component, named __dml__ and two Apex classes: __Dml.cmp__ and __DmlTest.cmp__.
__dml__ component writes two functions into page's window object:
- dml
- SObject

_window.dml_ object works as a namespace for all the DML functions.
_window.SObject_ is a function, which helps to construct typed SObject-like JSON object.

Class _Dml.cls_ works as a namespace and as a public interface for all the public dml methods and classes. The public interface consists of several @AuraEnabled methods:
- public static List<SObject> dmlQuery(String query)
- public static DmlResult dmlInsert(String sObjects, Boolean isAllOrNothing)
- public static DmlResult dmlUpdate(List<SObject> sObjects, Boolean isAllOrNothing)
- public static DmlResult dmlUpsert(String sObjects, Boolean isAllOrNothing)
- public static DmlResult dmlDelete(List<SObject> sObjects, Boolean isAllOrNothing)

Methods _dmlUpdate_ and _dmlUpsert_ accepts String sObjects parameter because it explicitly parses the JSON String, retrieved from lightning component to List<SObject>. 

Inner classes of _Dml.cls_ are separated in several groups:
- Public interface for SObjectValidations: 
    - SoqlValidator
- _SObjectValidator_ abstract class and it's derivatives:
    - SObjectReadValidator
    - SObjectInsertValidator
    - SObjectUpdateValidator
    - SObjectDeleteValidator
- Classes for handling dml results:
    - DmlResult
    - DmlRecordResult
    - DmlError

Also, there's one enumeration with a list of DML types - _DmlType_, used in _DmlResult_ class.

## Known issues
 - Count query not supported due to CRUD and FLS check limitations
 - Aggregation queries are not yet implemented
 
## Todos

 - Add other actions of CRUD (aggregate functions?) (95%)
 - Refactor Apex class (75%)
 - Update readme (90%)
 - Add Apex tests (95%)
 - Add JS Docs (75%)
 - Add setBackground() capability
 - Build packages
 - Add JS tests (?)

License
----

MIT
