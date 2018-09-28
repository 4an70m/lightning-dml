/**
     MIT License

     Copyright (c) 2018 Oleksii Fisher

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
({
    /**
     * Function that builds the dml object.
     *
     * @param cmp
     * @param helper
     * @returns object for dml operations
     */
    buildDmlObject: function (cmp, helper) {
        return {
            /**
             * Performs query dml operation based on the query param.
             *
             * @example
             * dml.query('SELECT Id FROM Account')
             * .then($A.getCallback(result => {
             *     console.log(result); //[{Id='record_Id'}, ...]
             * }))
             * .reject($A.getCallback(result => {
             *     console.log(result); //full response
             *     //to get errors use result.getErrors();
             * }));
             *
             * @param {string} query - normal apex-like dynamic SOQL query
             * @returns {Promise<any>} - promise with response or error
             */
            query: (query) => {
                return new Promise($A.getCallback((resolve, reject) => {
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
                    $A.enqueueAction(action);
                }))
            },

            /**
             * Performs insert dml with a single record or list of sobjects.
             * Allows you to perform insert with all or partial success with isAllOrNothing param.
             *
             * @example
             * dml.insert(new SObject("Account", {"field1": value1, "field2": value2...}))
             * .then($A.getCallback(result => {
             *     console.log(result); //returns DmlResult object - type: DML_INSERT
             * }))
             * .reject($A.getCallback(result => {
             *     console.log(result); //full response
             *     //to get errors use result.getErrors();
             * }));
             *
             * @param {object|object[]} sobjects - a single record or a list of JSON-like SObjects
             * @param {boolean} isAllOrNothing - defines if dml operation should be aborted, when on of the records failed to be inserted
             * @returns {Promise<any>} - promise with response or error
             */
            insert: (sobjects, isAllOrNothing = true) => {
                return new Promise($A.getCallback((resolve, reject) => {
                    const action = cmp.get("c.dmlInsert");
                    if (!$A.util.isArray(sobjects)) {
                        sobjects = [sobjects];
                    }
                    sobjects = JSON.stringify(sobjects);
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

            /**
             * Performs update dml with a single record or list of sobjects. Sobjects must have an Id specified.
             * Allows you to perform update with all or partial success with isAllOrNothing param.
             *
             * @example
             * dml.update(new SObject("Account", {"Id": record_Id, "field1": value1...}))
             * .then($A.getCallback(result => {
             *     console.log(result); //returns DmlResult object - type: DML_UPDATE
             * }))
             * .reject($A.getCallback(result => {
             *     console.log(result); //full response
             *     //to get errors use result.getErrors();
             * }));
             *
             * @param {object|object[]} sobjects - a single record or a list of JSON-like SObjects
             * @param {boolean} isAllOrNothing - defines if dml operation should be aborted, when on of the records failed to be updated
             * @returns {Promise<any>} - promise with response or error
             */
            update: (sobjects, isAllOrNothing = true) => {
                return new Promise($A.getCallback((resolve, reject) => {
                    const action = cmp.get("c.dmlUpdate");
                    if (!$A.util.isArray(sobjects)) {
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

            /**
             * Performs upsert dml operation with a single record or list of sobjects.
             * Allows you to perform upsert with all or partial success with isAllOrNothing param.
             *
             * @example
             * let sobjectToInsert = new SObject("Account", {"Id": record_Id, "field1": value1...});
             * let sobjectToUpsert = new SObject("Account", {"field1": value1, "field2": value2...});
             * dml.upsert([sobjectToInsert, sobjectToUpsert])
             * .then($A.getCallback(result => {
             *     console.log(result); //returns DmlResult object - type: DML_UPSERT
             * }))
             * .reject($A.getCallback(result => {
             *     console.log(result); //full response
             *     //to get errors use result.getErrors();
             * }));
             *
             *
             * @param {object|object[]} sobjects - a single record or a list of JSON-like SObjects
             * @param {boolean} isAllOrNothing - defines if dml operation should be aborted, when on of the records failed to be upserted
             * @returns {Promise<any>} - promise with response or error
             */
            upsert: (sobjects, isAllOrNothing = true) => {
                return new Promise($A.getCallback((resolve, reject) => {
                    const action = cmp.get("c.dmlUpsert");
                    if (!$A.util.isArray(sobjects)) {
                        sobjects = [sobjects];
                    }
                    sobjects = JSON.stringify(sobjects);
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

            /**
             * Performs delete dml operation with a single record, list of sobjects, single string id or list of string ids.
             * Allows you to perform delete with all or partial success with isAllOrNothing param.
             *
             * @example
             * let stringIdToDelete = "record_Id";
             * let sobjectToDelete1 = {"id": "record_Id"};
             * let sobjectToDelete2 = {"Id": "record_Id"};
             * let sobjectToDelete3 = new SObject("Account", {"Id": "record_id"});
             * dml.upsert([stringIdToDelete, sobjectToDelete1, sobjectToDelete2, sobjectToDelete3])
             * .then($A.getCallback(result => {
             *     console.log(result); //returns DmlResult object - type: DML_DELETE
             * }))
             * .reject($A.getCallback(result => {
             *     console.log(result); //full response
             *     //to get errors use result.getErrors();
             * }));
             *
             * @param {object|object[]} sobjects - a single record or a list of JSON-like SObjects
             * @param {boolean} isAllOrNothing - defines if dml operation should be aborted, when on of the records failed to be delete
             * @returns {Promise<any>} - promise with response or error
             */
            delete: (sobjects, isAllOrNothing = true) => {
                return new Promise($A.getCallback((resolve, reject) => {
                    const action = cmp.get("c.dmlDelete");
                    if (!$A.util.isArray(sobjects)) {
                        sobjects = [sobjects];
                    }
                    sobjects = sobjects.map(sobject => {
                        if (typeof sobject === "string") {
                            return sobject;
                        } else if (typeof sobject === "object") {
                            if (sobject.hasOwnProperty("id")) {
                                return sobject.id;
                            } else if (sobject.hasOwnProperty("Id")) {
                                return sobject.Id;
                            }
                        }
                    });
                    let uniqueIds = [];
                    sobjects.forEach(sobject => {
                        if (!$A.util.isUndefinedOrNull(sobject) && !uniqueIds.includes(sobject)) {
                            uniqueIds.push(sobject);
                        }
                    });
                    sobjects = uniqueIds.map(uniqueId => { return {Id: uniqueId};});
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

    /**
     * Function, which builds an apex-friendly sobject based on the type.
     * It's a convenient wrapper function, which allows to create SObjects
     * more naturally.
     *
     * Because of this function instead of writing:
     * let mySobject = {{"attributes": {"type": "Account"}}, "field1": value, "field2": value...};
     *
     * You may write like this:
     * @example
     * let mySobject = new SObject("Account", {"field1": value, "field2": value...});
     * Or
     * @example
     * let mySobject = SObject("Account", {"field1": value, "field2": value...});
     *
     *
     * @param {string} sobjectType - name of sobject type
     * @param {object} fields - object with field name - values
     * @returns {string} sobject - json object, with assigned sobject type
     */
    buildNewSobjectFunction: function(sobjectType, fields) {
        return Object.assign({"attributes": {"type": sobjectType}}, fields);
    },

    handleExceptionToast: function (response, helper) {
        let errorMessage = helper.extractErrorMessage(response);
        console.log(errorMessage);
        let toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            title: "Dml operation failed",
            message: errorMessage,
            duration: 7000,
            type: "error",
            mode: "dismissible"
        });
        toastEvent.fire();
    },

    extractErrorMessage: function (response) {
        let errorMessage = "Unexpected error";
        let state = response.getState();
        if (state === "INCOMPLETE") {
            errorMessage = "Operation was not completed";
        } else if (state === "ERROR") {
            let errors = response.getError();
            if (errors && errors[0] && errors[0].message) {
                errorMessage = errors[0].message;
            }
        }
        return errorMessage;
    }
})