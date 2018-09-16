/**
 * Created by 4an70 on 9/16/2018.
 */
({
    buildDmlObject: function(cmp, helper) {
        return {
            query: (query) => {
                return new Promise($A.getCallback(function (resolve, reject) {
                    const action = cmp.get("c.query");
                    action.setParams({"query": query});
                    action.setCallback(this, result => {
                        let state = result.getState();
                        if (state === "SUCCESS") {
                            resolve(result.getReturnValue());
                        } else {
                            if (cmp.get("v.showErrorToast")) {
                                helper.handleExceptionToast(result, helper);
                            }
                            reject(result);
                        }
                    });
                    $A.enqueueAction(action);
                }))
            },

            update: (sobjects) => {
                return new Promise($A.getCallback(function (resolve, reject) {
                    const action = cmp.get("c.performUpdate");
                    if (!(sobjects instanceof Array)) {
                        sobjects = [sobjects];
                    }
                    action.setParams({"sobjects": sobjects});
                    action.setCallback(this, result => {
                        let state = result.getState();
                        if (state === "SUCCESS") {
                            resolve(result.getReturnValue());
                        } else {
                            if (cmp.get("v.showErrorToast")) {
                                helper.handleExceptionToast(result, helper);
                            }
                            reject(result);
                        }
                    });
                    $A.enqueueAction(action);
                }));
            }
        };
    },

    handleExceptionToast: function(response, helper) {
        let errorMessage = helper.extractErrorMessage(response);
        console.log(errorMessage);
        let toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            title : "Dml operation failed",
            message: errorMessage,
            duration: 7000,
            type: "error",
            mode: "dismissible"
        });
        toastEvent.fire();
    },

    extractErrorMessage: function(response) {
        let errorMessage = "Unexpected error";
        let state = response.getState();
        if (state === "INCOMPLETE") {
            errorMessage = "Operation was not completed";
        } else if (state === "ERROR"){
            let errors = response.getError();
            if (errors && errors[0] && errors[0].message) {
                errorMessage = errors[0].message;
            }
        }
        return errorMessage;
    }
})