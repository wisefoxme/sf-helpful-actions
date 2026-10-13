@IsTest
private class DataWeaveCsvConversionServiceTest {
    private static final String TEST_SCRIPT = 'CsvDataWeaveDropzoneTest';
    private static final String SAMPLE_CSV =
        'first_name,last_name,email\nCodey,The Bear,codey@salesforce.com';

    @IsTest
    static void convertReturnsContactRows() {
        Test.startTest();
        List<SObject> rows = DataWeaveCsvConversionService.convert(
            TEST_SCRIPT,
            'Contact',
            SAMPLE_CSV
        );
        Test.stopTest();

        Assert.areEqual(1, rows.size(), 'Expected one Contact row');
        Contact contactRow = (Contact) rows[0];
        Assert.areEqual('Codey', contactRow.FirstName);
        Assert.areEqual('The Bear', contactRow.LastName);
        Assert.areEqual('codey@salesforce.com', contactRow.Email);
    }

    @IsTest
    static void convertBlankScriptNameThrows() {
        Boolean threw = false;
        try {
            DataWeaveCsvConversionService.convert(null, 'Contact', SAMPLE_CSV);
        } catch (DataWeaveCsvConversionService.ConversionException ex) {
            threw = true;
            Assert.isTrue(ex.getMessage().contains('script API name'));
        }
        Assert.isTrue(threw, 'Expected ConversionException for blank script name');
    }

    @IsTest
    static void convertInvalidScriptNameCharactersThrows() {
        Boolean threw = false;
        try {
            DataWeaveCsvConversionService.convert(
                '../evil',
                'Contact',
                SAMPLE_CSV
            );
        } catch (DataWeaveCsvConversionService.ConversionException ex) {
            threw = true;
            Assert.isTrue(ex.getMessage().contains('invalid characters'));
        }
        Assert.isTrue(threw, 'Expected ConversionException for invalid script name');
    }

    @IsTest
    static void convertUnknownObjectThrows() {
        Boolean threw = false;
        try {
            DataWeaveCsvConversionService.convert(
                TEST_SCRIPT,
                'NotARealObject__c',
                SAMPLE_CSV
            );
        } catch (DataWeaveCsvConversionService.ConversionException ex) {
            threw = true;
            Assert.isTrue(ex.getMessage().contains('Unknown target object'));
        }
        Assert.isTrue(threw, 'Expected ConversionException for unknown object');
    }

    @IsTest
    static void convertEmptyCsvThrows() {
        Boolean threw = false;
        try {
            DataWeaveCsvConversionService.convert(TEST_SCRIPT, 'Contact', '   ');
        } catch (DataWeaveCsvConversionService.ConversionException ex) {
            threw = true;
            Assert.isTrue(ex.getMessage().contains('empty'));
        }
        Assert.isTrue(threw, 'Expected ConversionException for empty CSV');
    }

    @IsTest
    static void convertCsvTooLargeThrows() {
        String hugeCsv = 'a'.repeat(DataWeaveCsvConversionService.MAX_CSV_LENGTH + 1);
        Boolean threw = false;
        try {
            DataWeaveCsvConversionService.convert(
                TEST_SCRIPT,
                'Contact',
                hugeCsv
            );
        } catch (DataWeaveCsvConversionService.ConversionException ex) {
            threw = true;
            Assert.isTrue(ex.getMessage().contains('maximum allowed size'));
        }
        Assert.isTrue(threw, 'Expected ConversionException for oversized CSV');
    }

    @IsTest
    static void convertWrongTargetObjectTypeThrows() {
        Boolean threw = false;
        try {
            DataWeaveCsvConversionService.convert(
                TEST_SCRIPT,
                'Account',
                SAMPLE_CSV
            );
        } catch (DataWeaveCsvConversionService.ConversionException ex) {
            threw = true;
            Assert.isTrue(
                ex.getMessage().contains('expected Account'),
                'Message: ' + ex.getMessage()
            );
        }
        Assert.isTrue(threw, 'Expected ConversionException for type mismatch');
    }

    @IsTest
    static void convertMissingScriptThrows() {
        Boolean threw = false;
        try {
            DataWeaveCsvConversionService.convert(
                'NoSuchDataWeaveScript_xyz',
                'Contact',
                SAMPLE_CSV
            );
        } catch (DataWeaveCsvConversionService.ConversionException ex) {
            threw = true;
            Assert.isTrue(ex.getMessage().contains('DataWeave conversion failed'));
        }
        Assert.isTrue(threw, 'Expected ConversionException for missing script');
    }
}
