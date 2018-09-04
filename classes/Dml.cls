/**
 * Created by User on 18.07.2018.
 */

public with sharing class Dml {

    @AuraEnabled
    public static List<SObject> query(String query) {
        return Database.query(query);
    }

    @AuraEnabled
    public static List<SObject> performUpdate(List<SObject> sobjects) {
        Database.update(sobjects);
        return sobjects;
    }
    
    public class SoqlValidator {
        
        private String soql;
        private List<SObject> results;
        
        public SoqlValidator(String soql) {
            this.soql = soql;
        }
        
        public void testRunSoql() {
            try {
                this.runSoql();
            } catch(Exception ex) {
                throw new AuraHandledException(ex.getMessage());
            }
        }
        
        public List<SObject> getResults() {
            return this.results;
        }
        
        private void runSoql() {
            List<SObject> queriedObjects = Database.query(this.soql);
            if (queriedObjects.isEmpty()) {
                this.results = queriedObjects;
                return;
            }
            SObjectType querriedSObjectType = queriedObjects.getSObjectType();
            DescribeSObjectResult describedSObjectType = querriedSObjectType.getDescribe();
            if (!describedSObjectType.isAccessible() || !describedSObjectType.isQueryable()) {
                throw new System.NoAccessException();
            }
        }
        
	}
}