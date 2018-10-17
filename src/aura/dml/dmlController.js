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
     * Init function, which writes dml object and SObject function to global window.
     * Allows access to both object and method without any additional namespaces:
     * @example
     * yourFunction: function(cmp, evt, helper) {
     *     ...
     *     let newAccount = new SObject(...);
     *     dml.insert(...)
     *     ...
     *
     * @param cmp
     * @param evt
     * @param helper
     */
    doInit: function (cmp, evt, helper) {
        if ($A.util.isUndefinedOrNull(window.dml)) {
            Object.defineProperty(window, 'dml', {
                writable: false,
                configurable: false,
                enumerable: false,
                value: helper.buildDmlObject(cmp, helper)
            });
        }
        if ($A.util.isUndefinedOrNull(window.SObject)) {
            Object.defineProperty(window, 'SObject', {
                writable: false,
                configurable: false,
                enumerable: false,
                value: helper.buildNewSobjectFunction
            });
        }
    }
})