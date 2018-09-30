# Lightning-dml
Component, which allows you to perform dml operations in lightning without using additional apex controller. Much like force:recordData, but more apex-like, component allows you to perform CRUD but with lists of records.
Included apex Dml class, which handles all the query logic, also checks object for accessibility, as well as enforces FLS.

# Usage
Include __dml__ component enywhere in you project (but make sure this component is loaded, before you use it).
```js
<c:dml/>
```
Start performing dml operations!

__Query__:
```js
yourFunction: function(cmp, evt, helper) {
    ...
    dml.query("SELECT Id FROM Account")
    .then(result => {
        console.log(result);
    });
    ...
}
```

__Insert__:
```js
yourFunction: function(cmp, evt, helper) {
    ...
    let accountToInsert = new SObject("Account", {Name: "Test"});
    dml.insert(accountToInsert)
    .then(result => {
        console.log(result);
    });
    ...
}
```

__Update__:
```js
yourFunction: function(cmp, evt, helper) {
    ...
    let accountToUpdate = new SObject("Account", {Name: "New name", Id: "record_Id"});
    dml.update(accountToUpdate)
    .then(result => {
        console.log(result);
    });
    ...
}
```

__Usert__:
```js
yourFunction: function(cmp, evt, helper) {
    ...
    let accountToInsert = new SObject("Account", {Name: "Test"});
    let accountToUpdate = new SObject("Account", {Id: "record_Id", Name: "Test"});
    dml.upsert([accountToUpdate, accountToInsert])
    .then(result => {
        console.log(result);
    });
    ...
}
```

__Delete__:
```js
yourFunction: function(cmp, evt, helper) {
    ...
    let accountsToDelete = ["recordId", {Id: "record_Id"}, {id: "record_Id"}];
    dml.delete(accountsToDelete)
    .then(result => {
        console.log(result);
    });
    ...
}
```

### Todos

 - Add other actions of CRUD (aggregate functions?) (95%)
 - Refactor apex class (75%)
 - Update readme (65%)
 - Add Apex tests (95%)
 - Add JS Docs (75%)
 - Build packages
 - Add JS tests (?)

License
----

MIT
