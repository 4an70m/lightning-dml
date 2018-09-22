/**
 * Created by 4an70 on 9/16/2018.
 */
({
    buildDmlObject: function(cmp, helper) {
        return {
            query: (query, isStorable = false, isBackground = false) => {
                return new Promise($A.getCallback(function (resolve, reject) {
                    const action = cmp.get("c.dmlQuery");
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
                    if (isStorable) {
                        action.setStorable();
                    }
                    if (isBackground) {
                        action.setBackground();
                    }
                    $A.enqueueAction(action);
                }))
            },

            update: (sobjects, isAllOrNothing = true) => {
                return new Promise($A.getCallback(function (resolve, reject) {
                    const action = cmp.get("c.dmlUpdate");
                    if (!(sobjects instanceof Array)) {
                        sobjects = [sobjects];
                    }
                    action.setParams({"sObjects": sobjects, "isAllOrNothing": isAllOrNothing});
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
            },

            insert: (sobjects, isAllOrNothing = true) => {
                return new Promise($A.getCallback(function (resolve, reject) {
                    const action = cmp.get("c.dmlInsert");
                    if (!(sobjects instanceof Array)) {
                        sobjects = [sobjects];
                    }
                    sobjects = JSON.stringify(sobjects);
                    console.log(sobjects);
                    action.setParams({"sObjects": sobjects, "isAllOrNothing": isAllOrNothing});
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
            },

            upsert: (sobjects, isAllOrNothing = true) => {
                return new Promise($A.getCallback(function (resolve, reject) {
                    const action = cmp.get("c.dmlUpsert");
                    if (!(sobjects instanceof Array)) {
                        sobjects = [sobjects];
                    }
                    action.setParams({"sObjects": sobjects, "isAllOrNothing": isAllOrNothing});
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
            },

            delete: (sobjects, isAllOrNothing = true) => {
                return new Promise($A.getCallback(function (resolve, reject) {
                    const action = cmp.get("c.dmlDelete");
                    if (!(sobjects instanceof Array)) {
                        sobjects = [sobjects];
                    }
                    if (sobjects.every(item => {return typeof item === "string"})) {
                        sobjects = sobjects.map(sobjectId => {return {Id: sobjectId}});
                    }
                    action.setParams({"sObjects": sobjects, "isAllOrNothing": isAllOrNothing});
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