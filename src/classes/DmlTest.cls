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

@IsTest
public without sharing class DmlTest {

    private static final Integer ACCOUNT_NUMBER = 10;
    private static final Integer CONTACT_NUMBER = 2;
    private static final String PRIVATE_OBJECT = 'Contact';
    private static final String PRIVATE_FIELD = 'Description';

    @TestSetup
    public static void initData() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < ACCOUNT_NUMBER; i++) {
            accounts.add(makeAccount(i));
        }
        insert accounts;

        List<Contact> contacts = new List<Contact>();
        for (Account account : accounts) {
            for (Integer i = 0; i < CONTACT_NUMBER; i++) {
                contacts.add(makeContact(i, account.Id));
            }
        }
        insert contacts;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert makeNewRestrictedUser();
        }
    }

    //Secure Insert Tests
    /*
        Query normal user - several records
     */
    @IsTest
    public static void secureQueryTest1Success() {
        List<Account> accounts = Dml.dmlQuery('SELECT Id, Name FROM Account');
        System.assertEquals(ACCOUNT_NUMBER, accounts.size());
    }

    /*
        Query normal user - no results
     */
    @IsTest
    public static void secureQueryTest2Success() {
        delete [SELECT Id FROM Account];
        List<Account> accounts = Dml.dmlQuery('SELECT Id FROM Account');
        System.assert(accounts.isEmpty());
    }

    /*
        Query normal user - inner select
     */
    @IsTest
    public static void secureQueryTest3Success() {
        List<Account> accounts = Dml.dmlQuery('SELECT Id, (SELECT Id FROM Contacts) FROM Account');
        List<Contact> contacts = new List<Contact>();
        for (Account account : accounts) {
            System.debug(account.Contacts);
            contacts.addAll(account.Contacts);
        }
        System.assertEquals((ACCOUNT_NUMBER * CONTACT_NUMBER), contacts.size());
    }

    /*
        Query restricted user - restricted field
     */
    @IsTest
    public static void secureQueryTest4Success() {
        List<Contact> contacts = Dml.dmlQuery('SELECT Id, ' + PRIVATE_FIELD + ' FROM ' + PRIVATE_OBJECT);
        System.assertEquals((ACCOUNT_NUMBER * CONTACT_NUMBER), contacts.size());
        for (Contact contact : contacts) {
            System.assertNotEquals(null, contact.Description);
        }
        List<User> restrictedUser = [SELECT Id FROM User WHERE LastName = 'UserForPermissionTesting'];
        if (restrictedUser.isEmpty()) {
            System.assert(false);
        }
        System.runAs(restrictedUser[0]) {
            contacts = Dml.dmlQuery('SELECT Id, ' + PRIVATE_FIELD + ' FROM ' + PRIVATE_OBJECT);
            System.assertEquals((ACCOUNT_NUMBER * CONTACT_NUMBER), contacts.size());
            for (Contact contact : contacts) {
                System.assertEquals(null, contact.get(PRIVATE_FIELD));
            }
        }
    }

    /*
        Query - invalid query
     */
    @IsTest
    public static void secureQueryTest1Fail() {
        Exception expectedException = null;
        try {
            List<Account> accounts = Dml.dmlQuery('Test');
        } catch (Exception ex) {
            expectedException = ex;
        }
        System.assertNotEquals(null, expectedException);
    }

    /*
        Query - invalid field
     */
    @IsTest
    public static void secureQueryTest2Fail() {
        Exception expectedException = null;
        try {
            List<Account> accounts = Dml.dmlQuery('SELECT Id, Non_existant_field__c FROM Account');
        } catch (Exception ex) {
            expectedException = ex;
        }
        System.assertNotEquals(null, expectedException);
    }

    //Secure Insert Tests
    /*
        Insert - normal user
    */
    @IsTest
    public static void secureInsertTest1Success() {
        List<Account> accountsToInsert = new List<Account>();
        accountsToInsert.add(makeAccount(122));
        Dml.DmlResult dmlResults = Dml.dmlInsert(JSON.serialize(accountsToInsert), true);

        System.assert(dmlResults.isSuccess);
        System.assertEquals(Dml.DmlType.DML_INSERT.name(), dmlResults.dmlType);
        System.assertEquals(1, dmlResults.records.size());
        System.assertNotEquals(null, dmlResults.records[0].Id);
        System.assertEquals(1, dmlResults.dmlRecordResults.size());
        System.assert(dmlResults.dmlRecordResults[0].isSuccess);
        System.assertNotEquals(null, dmlResults.dmlRecordResults[0].record.Id);

        List<Account> insertedAccounts = [SELECT Id FROM Account WHERE Id = :dmlResults.records[0].Id];
        System.assertEquals(1, insertedAccounts.size());
    }

    /*
        Insert - restricted user - no fls access - all or nothing
     */
    @IsTest
    public static void secureInsertTest1Fail() {
        List<User> restrictedUser = [SELECT Id FROM User WHERE LastName = 'UserForPermissionTesting'];
        if (restrictedUser.isEmpty()) {
            System.assert(false);
        }
        System.runAs(restrictedUser[0]) {
            Account account = makeAccount(122);
            insert account;
            List<Contact> contactToInsert = new List<Contact>();
            contactToInsert.add(makeContact(122, account.Id));

            Exception expectedException = null;
            try {
                Dml.dmlInsert(JSON.serialize(contactToInsert), true);
            } catch (Exception ex) {
                expectedException = ex;
            }
            System.assertNotEquals(null, expectedException);
        }
    }

    /*
        Insert - restricted user - no fls access - partila success
     */
    @IsTest
    public static void secureInsertTest2Fail() {
        List<User> restrictedUser = [SELECT Id FROM User WHERE LastName = 'UserForPermissionTesting'];
        if (restrictedUser.isEmpty()) {
            System.assert(false);
        }
        System.runAs(restrictedUser[0]) {
            Account account = makeAccount(122);
            insert account;
            List<Contact> contactToInsert = new List<Contact>();
            contactToInsert.add(makeContact(122, account.Id));

            Exception expectedException = null;
            try {
                Dml.DmlResult dmlResults = Dml.dmlInsert(JSON.serialize(contactToInsert), false);
                System.assert(!dmlResults.isSuccess);
                System.assertEquals(Dml.DmlType.DML_INSERT.name(), dmlResults.dmlType);
                System.assertEquals(1, dmlResults.records.size());
                System.assertNotEquals(null, dmlResults.records[0].Id);
                System.assertEquals(1, dmlResults.dmlRecordResults.size());
                System.assert(!dmlResults.dmlRecordResults[0].isSuccess);
                System.assertNotEquals(null, dmlResults.dmlRecordResults[0].record.Id);
                System.assertEquals(null, ((Contact) dmlResults.records[0]).Description);
                System.assertEquals(null, ((Contact) dmlResults.dmlRecordResults[0].record).Description);

                List<Contact> insertedContacts = [SELECT Id FROM Contact WHERE Id = :dmlResults.records[0].Id];
                System.assert(insertedContacts.isEmpty());
            } catch (Exception ex) {
                expectedException = ex;
            }
            System.assertNotEquals(null, expectedException);
        }
    }

    //Secure Update Tests
    /*
       Update - normal user
    */
    @IsTest
    public static void secureUpdateTest1Success() {
        final String NEW_ACCOUNT_NAME = 'NewAccountName';
        List<Account> accountsToUpdate = [SELECT Id, Name FROM Account LIMIT 1];
        accountsToUpdate[0].Name = NEW_ACCOUNT_NAME;
        Dml.DmlResult dmlResults = Dml.dmlUpdate(accountsToUpdate, true);

        System.assert(dmlResults.isSuccess);
        System.assertEquals(Dml.DmlType.DML_UPDATE.name(), dmlResults.dmlType);
        System.assertEquals(1, dmlResults.records.size());
        System.assertEquals(NEW_ACCOUNT_NAME, ((Account) dmlResults.records[0]).Name);
        System.assertEquals(1, dmlResults.dmlRecordResults.size());
        System.assert(dmlResults.dmlRecordResults[0].isSuccess);
        System.assertEquals(NEW_ACCOUNT_NAME, ((Account) dmlResults.dmlRecordResults[0].record).Name);

        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Id = :dmlResults.records[0].Id];
        System.assertEquals(1, insertedAccounts.size());
        System.assertEquals(NEW_ACCOUNT_NAME, insertedAccounts[0].Name);
    }

    /*
        Update - restricted user - no object update access - all or nothing
    */
    @IsTest
    public static void secureUpdateTest1Fail() {
        final String NEW_CONTACT_NAME = 'NewContactName';
        List<User> restrictedUser = [SELECT Id FROM User WHERE LastName = 'UserForPermissionTesting'];
        if (restrictedUser.isEmpty()) {
            System.assert(false);
        }
        System.runAs(restrictedUser[0]) {
            List<Contact> contactsToUpdate = [SELECT Id, LastName FROM Contact LIMIT 1];
            contactsToUpdate[0].LastName = NEW_CONTACT_NAME;

            Exception expectedException = null;
            try {
                Dml.dmlUpdate(contactsToUpdate, true);
            } catch (Exception ex) {
                expectedException = ex;
            }
            System.assertNotEquals(null, expectedException);
        }
    }

    /*
        Update - restricted user - no object update access - partila success
    */
    @IsTest
    public static void secureUpdateTest2Fail() {
        final String NEW_CONTACT_NAME = 'NewContactName';
        List<User> restrictedUser = [SELECT Id FROM User WHERE LastName = 'UserForPermissionTesting'];
        if (restrictedUser.isEmpty()) {
            System.assert(false);
        }
        System.runAs(restrictedUser[0]) {
            List<Contact> contactsToUpdate = [SELECT Id, LastName FROM Contact LIMIT 1];
            contactsToUpdate[0].LastName = NEW_CONTACT_NAME;

            Exception expectedException = null;
            try {
                Dml.dmlUpdate(contactsToUpdate, false);
            } catch (Exception ex) {
                expectedException = ex;
            }
            System.assertNotEquals(null, expectedException);
        }
    }

    //Secure Upsert Tests
    /*
        Upsert - normal user - new record
    */
    @IsTest
    public static void secureUpsertTest1Success() {
        List<Account> accountsToUpsert = new List<Account>();
        accountsToUpsert.add(makeAccount(122));
        Dml.DmlResult dmlResults = Dml.dmlUpsert(JSON.serialize(accountsToUpsert), true);

        System.assert(dmlResults.isSuccess);
        System.assertEquals(Dml.DmlType.DML_UPSERT.name(), dmlResults.dmlType);
        System.assertEquals(1, dmlResults.records.size());
        System.assertNotEquals(null, dmlResults.records[0].Id);
        System.assertEquals(1, dmlResults.dmlRecordResults.size());
        System.assert(dmlResults.dmlRecordResults[0].isSuccess);
        System.assertNotEquals(null, dmlResults.dmlRecordResults[0].record.Id);

        List<Account> insertedAccounts = [SELECT Id FROM Account WHERE Id = :dmlResults.records[0].Id];
        System.assertEquals(1, insertedAccounts.size());
    }

    /*
        Upsert - normal user - update record
    */
    @IsTest
    public static void secureUpsertTest2Success() {
        final String NEW_ACCOUNT_NAME = 'NewAccountName';
        List<Account> accountsToUpsert = [SELECT Id, Name FROM Account LIMIT 1];
        accountsToUpsert[0].Name = NEW_ACCOUNT_NAME;
        Dml.DmlResult dmlResults = Dml.dmlUpsert(JSON.serialize(accountsToUpsert), true);

        System.assert(dmlResults.isSuccess);
        System.assertEquals(Dml.DmlType.DML_UPSERT.name(), dmlResults.dmlType);
        System.assertEquals(1, dmlResults.records.size());
        System.assertEquals(NEW_ACCOUNT_NAME, ((Account) dmlResults.records[0]).Name);
        System.assertEquals(1, dmlResults.dmlRecordResults.size());
        System.assert(dmlResults.dmlRecordResults[0].isSuccess);
        System.assertEquals(NEW_ACCOUNT_NAME, ((Account) dmlResults.dmlRecordResults[0].record).Name);

        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Id = :dmlResults.records[0].Id];
        System.assertEquals(1, insertedAccounts.size());
        System.assertEquals(NEW_ACCOUNT_NAME, insertedAccounts[0].Name);
    }

    /*
        Upsert - normal user - one update, one insert
    */
    @IsTest
    public static void secureUpsertTest3Success() {
        final String NEW_ACCOUNT_NAME = 'NewAccountName';
        List<Account> accountsToUpsert = [SELECT Id, Name FROM Account LIMIT 1];
        accountsToUpsert.add(makeAccount(122));
        accountsToUpsert[0].Name = NEW_ACCOUNT_NAME;
        accountsToUpsert[1].Name = NEW_ACCOUNT_NAME;
        Dml.DmlResult dmlResults = Dml.dmlUpsert(JSON.serialize(accountsToUpsert), true);

        System.assert(dmlResults.isSuccess);
        System.assertEquals(Dml.DmlType.DML_UPSERT.name(), dmlResults.dmlType);
        System.assertEquals(2, dmlResults.records.size());
        System.assertEquals(NEW_ACCOUNT_NAME, ((Account) dmlResults.records[0]).Name);
        System.assertEquals(NEW_ACCOUNT_NAME, ((Account) dmlResults.records[1]).Name);
        System.assertEquals(2, dmlResults.dmlRecordResults.size());
        System.assert(dmlResults.dmlRecordResults[0].isSuccess);
        System.assert(dmlResults.dmlRecordResults[1].isSuccess);
        System.assertEquals(NEW_ACCOUNT_NAME, ((Account) dmlResults.dmlRecordResults[0].record).Name);
        System.assertEquals(NEW_ACCOUNT_NAME, ((Account) dmlResults.dmlRecordResults[1].record).Name);

        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Id = :dmlResults.records[0].Id OR Id = :dmlResults.records[1].Id];
        System.assertEquals(2, insertedAccounts.size());
        System.assertEquals(NEW_ACCOUNT_NAME, insertedAccounts[0].Name);
        System.assertEquals(NEW_ACCOUNT_NAME, insertedAccounts[1].Name);
    }

    /*
        Upsert - restricted user - no crud access - all or nothing
    */
    @IsTest
    public static void secureUpsertTest1Fail() {
        List<User> restrictedUser = [SELECT Id FROM User WHERE LastName = 'UserForPermissionTesting'];
        if (restrictedUser.isEmpty()) {
            System.assert(false);
        }
        System.runAs(restrictedUser[0]) {
            Account account = makeAccount(122);
            insert account;
            List<Contact> contactToInsert = new List<Contact>();
            contactToInsert.add(makeContact(122, account.Id));

            Exception expectedException = null;
            try {
                Dml.dmlInsert(JSON.serialize(contactToInsert), true);
            } catch (Exception ex) {
                expectedException = ex;
            }
            System.assertNotEquals(null, expectedException);
        }
    }

    /*
        Upsert - restricted user - no crud access - partila success
    */
    @IsTest
    public static void secureUpsertTest2Fail() {
        List<User> restrictedUser = [SELECT Id FROM User WHERE LastName = 'UserForPermissionTesting'];
        if (restrictedUser.isEmpty()) {
            System.assert(false);
        }
        System.runAs(restrictedUser[0]) {
            Account account = makeAccount(122);
            insert account;
            List<Contact> contactToInsert = new List<Contact>();
            contactToInsert.add(makeContact(122, account.Id));

            Exception expectedException = null;
            try {
                Dml.DmlResult dmlResults = Dml.dmlInsert(JSON.serialize(contactToInsert), false);
                System.assert(!dmlResults.isSuccess);
                System.assertEquals(Dml.DmlType.DML_INSERT.name(), dmlResults.dmlType);
                System.assertEquals(1, dmlResults.records.size());
                System.assertNotEquals(null, dmlResults.records[0].Id);
                System.assertEquals(1, dmlResults.dmlRecordResults.size());
                System.assert(!dmlResults.dmlRecordResults[0].isSuccess);
                System.assertNotEquals(null, dmlResults.dmlRecordResults[0].record.Id);
                System.assertEquals(null, ((Contact) dmlResults.records[0]).Description);
                System.assertEquals(null, ((Contact) dmlResults.dmlRecordResults[0].record).Description);

                List<Contact> insertedContacts = [SELECT Id FROM Contact WHERE Id = :dmlResults.records[0].Id];
                System.assert(insertedContacts.isEmpty());
            } catch (Exception ex) {
                expectedException = ex;
            }
            System.assertNotEquals(null, expectedException);
        }
    }

    //Secure Delete Tests
    /*
        Delete normal user
     */
    @IsTest
    public static void secureDeleteTest1Success() {
        List<Account> accounts = [SELECT Id FROM Account];
        Dml.DmlResult dmlResults = Dml.dmlDelete(accounts, true);
        System.assert(dmlResults.isSuccess);
        System.assertEquals(Dml.DmlType.DML_DELETE.name(), dmlResults.dmlType);
        System.assertEquals(ACCOUNT_NUMBER, dmlResults.records.size());
        System.assertEquals(ACCOUNT_NUMBER, dmlResults.dmlRecordResults.size());
        for (Dml.DmlRecordResult dmlRecordResult : dmlResults.dmlRecordResults) {
            System.assert(dmlRecordResult.isSuccess);
        }

        List<Account> deletedAccounts = [SELECT Id FROM Account];
        System.assert(deletedAccounts.isEmpty());
    }

    /*
        Delete - restricted user - private crud - all or nothing
    */
    @IsTest
    public static void secureDeleteTest1Fail() {
        List<User> restrictedUser = [SELECT Id FROM User WHERE LastName = 'UserForPermissionTesting'];
        if (restrictedUser.isEmpty()) {
            System.assert(false);
        }
        System.runAs(restrictedUser[0]) {
            List<Account> accounts = [SELECT Id FROM Account];
            Exception expectedException = null;
            try {
                Dml.dmlDelete(accounts, true);
            } catch (Exception ex) {
                expectedException = ex;
            }
            System.assertNotEquals(null, expectedException);
        }
    }

    /*
        Delete - restricted user - private crud - partila success
    */
    @IsTest
    public static void secureDeleteTest2Fail() {
        List<User> restrictedUser = [SELECT Id FROM User WHERE LastName = 'UserForPermissionTesting'];
        if (restrictedUser.isEmpty()) {
            System.assert(false);
        }
        System.runAs(restrictedUser[0]) {
            List<Account> accounts = [SELECT Id FROM Account];
            Exception expectedException = null;
            try {
                Dml.dmlDelete(accounts, false);
            } catch (Exception ex) {
                expectedException = ex;
            }
            System.assertNotEquals(null, expectedException);
        }
    }


    //Utility methods
    private static Account makeAccount(Integer i) {
        Account result = new Account();
        result.Name = 'Test-' + i;
        return result;
    }

    private static Contact makeContact(Integer i, Id accountId) {
        Contact result = new Contact();
        result.LastName = 'Test-' + i + accountId;
        result.AccountId = accountId;
        result.put(PRIVATE_FIELD, 'Test-' + i + accountId);
        return result;
    }

    private static User makeNewRestrictedUser() {
        Id profileId = buildRestrictedProfileFls();
        String seed = 't' + String.valueOf((Math.random() * 10000).intValue());
        User result = new User();
        result.LastName = 'UserForPermissionTesting';
        result.Username = seed + '@.example.com';
        result.ProfileId = profileId;
        result.Email = seed + '@example.com';
        result.Alias = 'alias' + seed.substring(3);
        result.TimeZoneSidKey = 'America/Los_Angeles';
        result.LocaleSidKey = 'en_US';
        result.LanguageLocaleKey = 'en_US';
        result.EmailEncodingKey = 'UTF-8';
        return result;
    }

    private static Id buildRestrictedProfileFls() {
        List<PermissionSet> permissionSets = getReadOnlyPermissionSet();
        if (permissionSets.isEmpty()) {
            return null;
        }
        PermissionSet readonlyPermissionsSet = permissionSets[0];
        buildPrivateFls(readonlyPermissionsSet);
        return readonlyPermissionsSet.ProfileId;
    }

    private static void buildPrivateFls(PermissionSet readonlyPermissionsSet) {
        FieldPermissions result = null;
        if (readonlyPermissionsSet.FieldPerms.isEmpty()) {
            result = makePrivateFieldPermission(readonlyPermissionsSet.Id);
        } else {
            result = makePrivateFieldPermission(readonlyPermissionsSet.FieldPerms[0]);
        }
        upsert result;
    }

    private static List<PermissionSet> getReadOnlyPermissionSet() {
        String fieldName = PRIVATE_OBJECT + '.' + PRIVATE_FIELD;
        return [
                SELECT Id
                    , ProfileId
                    , (
                        SELECT Id
                            , Field
                            , SobjectType
                            , PermissionsRead
                            , PermissionsEdit
                            , ParentId
                        FROM FieldPerms
                        WHERE SobjectType = :PRIVATE_OBJECT
                            AND Field = :fieldName
                    ) , (
                        SELECT Id
                            , SobjectType
                            , PermissionsRead
                            , PermissionsEdit
                            , PermissionsCreate
                            , PermissionsDelete
                        FROM ObjectPerms
                        WHERE SobjectType = :PRIVATE_OBJECT
                )
                FROM PermissionSet
                WHERE IsOwnedByProfile = true
                AND Profile.Name = 'Read Only'
        ];
    }

    public static FieldPermissions makePrivateFieldPermission(Id permissionSetId) {
        FieldPermissions result = new FieldPermissions();
        result.Field =  PRIVATE_OBJECT + '.' + PRIVATE_FIELD;
        result.SobjectType = PRIVATE_OBJECT;
        result.PermissionsEdit = false;
        result.PermissionsRead = false;
        result.ParentId = permissionSetId;
        return result;
    }

    private static FieldPermissions makePrivateFieldPermission(FieldPermissions fieldPermission) {
        fieldPermission.PermissionsEdit = false;
        fieldPermission.PermissionsRead = false;
        return fieldPermission;
    }
}