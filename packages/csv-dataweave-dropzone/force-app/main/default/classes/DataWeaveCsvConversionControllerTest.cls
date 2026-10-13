@IsTest
private class DataWeaveCsvConversionControllerTest {
    private static final String TEST_SCRIPT = 'CsvDataWeaveDropzoneTest';
    private static final String SAMPLE_CSV =
        'first_name,last_name,email\nA,B,a@example.com';

    @IsTest
    static void convertCsvReturnsRows() {
        Test.startTest();
        List<SObject> rows = DataWeaveCsvConversionController.convertCsv(
            TEST_SCRIPT,
            'Contact',
            SAMPLE_CSV
        );
        Test.stopTest();

        Assert.areEqual(1, rows.size());
        Contact contactRow = (Contact) rows[0];
        Assert.areEqual('A', contactRow.FirstName);
        Assert.areEqual('B', contactRow.LastName);
        Assert.areEqual('a@example.com', contactRow.Email);
    }

    @IsTest
    static void convertCsvWrapsServiceErrorsAsAuraHandled() {
        Boolean threwAura = false;
        Test.startTest();
        try {
            DataWeaveCsvConversionController.convertCsv(null, 'Contact', SAMPLE_CSV);
        } catch (AuraHandledException ex) {
            threwAura = true;
            Assert.isTrue(String.isNotBlank(ex.getMessage()));
        }
        Test.stopTest();
        Assert.isTrue(threwAura, 'Expected AuraHandledException');
    }
}
