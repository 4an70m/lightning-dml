/**
 * Created by User on 16.07.2018.
 */
({
    doInit: function (cmp, evt, helper) {
        window.dml = {
            query: (query) =>
                new Promise($A.getCallback(function (resolve, reject) {
                    const action = cmp.get("c.query");
                    action.setParams({"query": query});
                    action.setCallback(this, result => {
                        resolve(result.getReturnValue());
                    });
                    $A.enqueueAction(action);
                })),

            update: (sobjects) => {
                return new Promise($A.getCallback(function (resolve, reject) {
                    const action = cmp.get("c.performUpdate");
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