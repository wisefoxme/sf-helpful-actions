@IsTest
private class GetRecordTypeIdInvocableTest {
    @IsTest
    static void testExecute_returnsRecordTypeId_whenRecordTypeExists() {
        GetRecordTypeIdInvocable.Input input = new GetRecordTypeIdInvocable.Input();
        input.objectApiName = 'Account';
        input.recordTypeDeveloperName = 'PersonAccount';

        Test.startTest();
        List<GetRecordTypeIdInvocable.Output> results = GetRecordTypeIdInvocable.execute(
            new List<GetRecordTypeIdInvocable.Input>{ input }
        );
        Test.stopTest();

        Id expected = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();
        Assert.areEqual(1, results.size());
        Assert.areEqual(expected, results[0].recordTypeId);
    }

    @IsTest
    static void testExecute_throws_whenRecordTypeDeveloperNameUnknown() {
        GetRecordTypeIdInvocable.Input input = new GetRecordTypeIdInvocable.Input();
        input.objectApiName = 'Account';
        input.recordTypeDeveloperName = 'DoesNotExist';

        Test.startTest();
        try {
            GetRecordTypeIdInvocable.execute(new List<GetRecordTypeIdInvocable.Input>{ input });
            Assert.fail('Expected a RecordTypeNotFoundException when the record type does not exist.');
        } catch (GetRecordTypeIdInvocable.RecordTypeNotFoundException e) {
            // expected
        }
        Test.stopTest();
    }

    @IsTest
    static void testExecute_throws_whenObjectApiNameUnknown() {
        GetRecordTypeIdInvocable.Input input = new GetRecordTypeIdInvocable.Input();
        input.objectApiName = 'Not_A_Real_Object__c';
        input.recordTypeDeveloperName = 'PersonAccount';

        Test.startTest();
        try {
            GetRecordTypeIdInvocable.execute(new List<GetRecordTypeIdInvocable.Input>{ input });
            Assert.fail('Expected a RecordTypeNotFoundException when the SObject is unknown.');
        } catch (GetRecordTypeIdInvocable.RecordTypeNotFoundException e) {
            // expected
        }
        Test.stopTest();
    }

    @IsTest
    static void testExecute_throws_whenObjectApiNameBlank() {
        GetRecordTypeIdInvocable.Input input = new GetRecordTypeIdInvocable.Input();
        input.objectApiName = null;
        input.recordTypeDeveloperName = 'PersonAccount';

        Test.startTest();
        try {
            GetRecordTypeIdInvocable.execute(new List<GetRecordTypeIdInvocable.Input>{ input });
            Assert.fail('Expected a RecordTypeNotFoundException when objectApiName is blank.');
        } catch (GetRecordTypeIdInvocable.RecordTypeNotFoundException e) {
            // expected
        }
        Test.stopTest();
    }

    @IsTest
    static void testExecute_throws_whenRecordTypeDeveloperNameBlank() {
        GetRecordTypeIdInvocable.Input input = new GetRecordTypeIdInvocable.Input();
        input.objectApiName = 'Account';
        input.recordTypeDeveloperName = '';

        Test.startTest();
        try {
            GetRecordTypeIdInvocable.execute(new List<GetRecordTypeIdInvocable.Input>{ input });
            Assert.fail('Expected a RecordTypeNotFoundException when recordTypeDeveloperName is blank.');
        } catch (GetRecordTypeIdInvocable.RecordTypeNotFoundException e) {
            // expected
        }
        Test.stopTest();
    }

    @IsTest
    static void testExecute_bulkSafety_multipleInputs() {
        GetRecordTypeIdInvocable.Input firstInput = new GetRecordTypeIdInvocable.Input();
        firstInput.objectApiName = 'Account';
        firstInput.recordTypeDeveloperName = 'PersonAccount';

        GetRecordTypeIdInvocable.Input secondInput = new GetRecordTypeIdInvocable.Input();
        secondInput.objectApiName = 'Account';
        secondInput.recordTypeDeveloperName = 'PersonAccount';

        Test.startTest();
        List<GetRecordTypeIdInvocable.Output> results = GetRecordTypeIdInvocable.execute(
            new List<GetRecordTypeIdInvocable.Input>{ firstInput, secondInput }
        );
        Test.stopTest();

        Id expectedAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();

        Assert.areEqual(2, results.size());
        Assert.areEqual(expectedAccountRecordTypeId, results[0].recordTypeId);
        Assert.areEqual(expectedAccountRecordTypeId, results[1].recordTypeId);
    }
}
