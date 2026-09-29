@IsTest
private class GetPicklistValuesInvocableTest {
    @IsTest
    static void testExecute_returnsActivePicklistValues_whenFieldIsPicklist() {
        GetPicklistValuesInvocable.Input input = new GetPicklistValuesInvocable.Input();
        input.objectApiName = 'Account';
        input.fieldApiName = 'Rating';

        Test.startTest();
        List<GetPicklistValuesInvocable.Output> results = GetPicklistValuesInvocable.execute(
            new List<GetPicklistValuesInvocable.Input>{ input }
        );
        Test.stopTest();

        Assert.areEqual(1, results.size());
        List<GetPicklistValuesInvocable.PicklistOption> options = results[0].picklistValues;
        Assert.areEqual(3, options.size());

        Set<String> values = new Set<String>();
        for (GetPicklistValuesInvocable.PicklistOption option : options) {
            values.add(option.value);
            Assert.isTrue(option.isActive);
        }
        Assert.isTrue(values.containsAll(new Set<String>{ 'Hot', 'Warm', 'Cold' }));
    }

    @IsTest
    static void testExecute_throws_whenFieldUnknown() {
        GetPicklistValuesInvocable.Input input = new GetPicklistValuesInvocable.Input();
        input.objectApiName = 'Account';
        input.fieldApiName = 'Not_A_Real_Field__c';

        Test.startTest();
        try {
            GetPicklistValuesInvocable.execute(new List<GetPicklistValuesInvocable.Input>{ input });
            Assert.fail('Expected a PicklistFieldException when the field is unknown.');
        } catch (GetPicklistValuesInvocable.PicklistFieldException e) {
            // expected
        }
        Test.stopTest();
    }

    @IsTest
    static void testExecute_throws_whenObjectUnknown() {
        GetPicklistValuesInvocable.Input input = new GetPicklistValuesInvocable.Input();
        input.objectApiName = 'Not_A_Real_Object__c';
        input.fieldApiName = 'Rating';

        Test.startTest();
        try {
            GetPicklistValuesInvocable.execute(new List<GetPicklistValuesInvocable.Input>{ input });
            Assert.fail('Expected a PicklistFieldException when the SObject is unknown.');
        } catch (GetPicklistValuesInvocable.PicklistFieldException e) {
            // expected
        }
        Test.stopTest();
    }

    @IsTest
    static void testExecute_throws_whenFieldIsNotAPicklist() {
        GetPicklistValuesInvocable.Input input = new GetPicklistValuesInvocable.Input();
        input.objectApiName = 'Account';
        input.fieldApiName = 'Name';

        Test.startTest();
        try {
            GetPicklistValuesInvocable.execute(new List<GetPicklistValuesInvocable.Input>{ input });
            Assert.fail('Expected a PicklistFieldException when the field is not a picklist.');
        } catch (GetPicklistValuesInvocable.PicklistFieldException e) {
            // expected
        }
        Test.stopTest();
    }

    @IsTest
    static void testExecute_throws_whenObjectApiNameBlank() {
        GetPicklistValuesInvocable.Input input = new GetPicklistValuesInvocable.Input();
        input.objectApiName = null;
        input.fieldApiName = 'Rating';

        Test.startTest();
        try {
            GetPicklistValuesInvocable.execute(new List<GetPicklistValuesInvocable.Input>{ input });
            Assert.fail('Expected a PicklistFieldException when objectApiName is blank.');
        } catch (GetPicklistValuesInvocable.PicklistFieldException e) {
            // expected
        }
        Test.stopTest();
    }

    @IsTest
    static void testExecute_throws_whenFieldApiNameBlank() {
        GetPicklistValuesInvocable.Input input = new GetPicklistValuesInvocable.Input();
        input.objectApiName = 'Account';
        input.fieldApiName = '';

        Test.startTest();
        try {
            GetPicklistValuesInvocable.execute(new List<GetPicklistValuesInvocable.Input>{ input });
            Assert.fail('Expected a PicklistFieldException when fieldApiName is blank.');
        } catch (GetPicklistValuesInvocable.PicklistFieldException e) {
            // expected
        }
        Test.stopTest();
    }

    /**
     * ConnectApi methods are not supported in data-siloed tests ("ConnectApi methods are not
     * supported in data siloed tests" is the exact runtime error without this), so this is the
     * one test that exercises the real ConnectApi.RecordUi.getPicklistValuesByRecordType call
     * instead of the Schema-only path. Uses standard Account/AccountSource and PersonAccount.
     */
    @IsTest(SeeAllData=true)
    static void testExecute_returnsRecordTypeScopedValues_whenRecordTypeDeveloperNameProvided() {
        GetPicklistValuesInvocable.Input input = new GetPicklistValuesInvocable.Input();
        input.objectApiName = 'Account';
        input.fieldApiName = 'AccountSource';
        input.recordTypeDeveloperName = 'PersonAccount';

        Test.startTest();
        List<GetPicklistValuesInvocable.Output> results = GetPicklistValuesInvocable.execute(
            new List<GetPicklistValuesInvocable.Input>{ input }
        );
        Test.stopTest();

        Assert.areEqual(1, results.size());
        List<GetPicklistValuesInvocable.PicklistOption> options = results[0].picklistValues;
        Assert.isTrue(options.size() > 0, 'Expected at least one picklist value for AccountSource.');

        for (GetPicklistValuesInvocable.PicklistOption option : options) {
            Assert.isTrue(String.isNotBlank(option.value));
            Assert.isTrue(String.isNotBlank(option.label));
            Assert.isTrue(option.isActive);
        }
    }

    @IsTest
    static void testExecute_throws_whenRecordTypeDeveloperNameUnknown() {
        GetPicklistValuesInvocable.Input input = new GetPicklistValuesInvocable.Input();
        input.objectApiName = 'Account';
        input.fieldApiName = 'Rating';
        input.recordTypeDeveloperName = 'Not_A_Real_Record_Type';

        Test.startTest();
        try {
            GetPicklistValuesInvocable.execute(new List<GetPicklistValuesInvocable.Input>{ input });
            Assert.fail('Expected a PicklistFieldException when the record type is unknown.');
        } catch (GetPicklistValuesInvocable.PicklistFieldException e) {
            // expected
        }
        Test.stopTest();
    }

    @IsTest
    static void testExecute_bulkSafety_multipleInputs() {
        GetPicklistValuesInvocable.Input ratingInput = new GetPicklistValuesInvocable.Input();
        ratingInput.objectApiName = 'Account';
        ratingInput.fieldApiName = 'Rating';

        GetPicklistValuesInvocable.Input accountSourceInput = new GetPicklistValuesInvocable.Input();
        accountSourceInput.objectApiName = 'Account';
        accountSourceInput.fieldApiName = 'AccountSource';

        Test.startTest();
        List<GetPicklistValuesInvocable.Output> results = GetPicklistValuesInvocable.execute(
            new List<GetPicklistValuesInvocable.Input>{ ratingInput, accountSourceInput }
        );
        Test.stopTest();

        Assert.areEqual(2, results.size());
        Assert.areEqual(3, results[0].picklistValues.size());
        Assert.isTrue(results[1].picklistValues.size() > 0);
    }
}
