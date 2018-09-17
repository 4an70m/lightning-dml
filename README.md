# Lightnig-dml
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
    .then($A.getCallback(result => {
        console.log(result);
    }));
    ...
}
```

__Update__:
```js
yourFunction: function(cmp, evt, helper) {
    ...
     dml.update({Id: "someId", Name: "New name"})
    .then($A.getCallback(result => {
        console.log(result);
    }));
    ...
}
```

### Todos

 - Add other actions of CRUD (upsert, delete)
 - Add CRUD actions result response
 - Refactor apex class
 - Update reject error message
 - Update readme
 - Add apex tests

License
----

MIT
