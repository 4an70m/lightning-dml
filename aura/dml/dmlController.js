/**
 * Created by User on 16.07.2018.
 */
({
    doInit: function (cmp, evt, helper) {
        cmp.get("v.context").dml = {
            query: (query) => {
                return new Promise($A.getCallback(function(resolve, reject) {
                    const [a, b] = arguments;
                    let action = cmp.get("c.query");
                    action.setParams({"query": query});
                    action.setCallback(this, result => {
                        resolve(result.getReturnValue());
                    });
                    $A.enqueueAction(action);
                }));
            },

            update: (sobjects) => {
                return new Promise($A.getCallback(function(resolve, reject) {
                    let action = cmp.get("c.performUpdate");
                    action.setParams({"sobjects": sobjects});
                    action.setCallback(this, result => {
                        resolve(result.getReturnValue());
                    });
                    $A.enqueueAction(action);
                }));
            }
        };
    }
})