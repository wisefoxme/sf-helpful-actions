@IsTest
private class SplitTextInvocableTest {
    @IsTest
    static void testExecute_splitsOnDelimiter() {
        SplitTextInvocable.Input input = new SplitTextInvocable.Input();
        input.text = 'a;b;c';
        input.delimiter = ';';

        Test.startTest();
        List<SplitTextInvocable.Output> results = SplitTextInvocable.execute(
            new List<SplitTextInvocable.Input>{ input }
        );
        Test.stopTest();

        Assert.areEqual(1, results.size());
        Assert.areEqual(new List<String>{ 'a', 'b', 'c' }, results[0].values);
    }

    @IsTest
    static void testExecute_trimsAndOmitsEmptySegments() {
        SplitTextInvocable.Input input = new SplitTextInvocable.Input();
        input.text = ' a ; b ;; c ';
        input.delimiter = ';';

        Test.startTest();
        List<SplitTextInvocable.Output> results = SplitTextInvocable.execute(
            new List<SplitTextInvocable.Input>{ input }
        );
        Test.stopTest();

        Assert.areEqual(new List<String>{ 'a', 'b', 'c' }, results[0].values);
    }

    @IsTest
    static void testExecute_usesDefaultDelimiterWhenBlank() {
        SplitTextInvocable.Input input = new SplitTextInvocable.Input();
        input.text = 'x;y';
        input.delimiter = null;

        Test.startTest();
        List<SplitTextInvocable.Output> results = SplitTextInvocable.execute(
            new List<SplitTextInvocable.Input>{ input }
        );
        Test.stopTest();

        Assert.areEqual(new List<String>{ 'x', 'y' }, results[0].values);
    }

    @IsTest
    static void testExecute_returnsSingleValueWhenNoDelimiterInText() {
        SplitTextInvocable.Input input = new SplitTextInvocable.Input();
        input.text = 'only';
        input.delimiter = ';';

        Test.startTest();
        List<SplitTextInvocable.Output> results = SplitTextInvocable.execute(
            new List<SplitTextInvocable.Input>{ input }
        );
        Test.stopTest();

        Assert.areEqual(new List<String>{ 'only' }, results[0].values);
    }

    @IsTest
    static void testExecute_returnsEmptyListWhenTextBlank() {
        SplitTextInvocable.Input input = new SplitTextInvocable.Input();
        input.text = '';
        input.delimiter = ';';

        Test.startTest();
        List<SplitTextInvocable.Output> results = SplitTextInvocable.execute(
            new List<SplitTextInvocable.Input>{ input }
        );
        Test.stopTest();

        Assert.areEqual(0, results[0].values.size());
    }

    @IsTest
    static void testExecute_treatsDelimiterAsLiteralNotRegex() {
        SplitTextInvocable.Input input = new SplitTextInvocable.Input();
        input.text = '1.2.3';
        input.delimiter = '.';

        Test.startTest();
        List<SplitTextInvocable.Output> results = SplitTextInvocable.execute(
            new List<SplitTextInvocable.Input>{ input }
        );
        Test.stopTest();

        Assert.areEqual(new List<String>{ '1', '2', '3' }, results[0].values);
    }

    @IsTest
    static void testExecute_throws_whenDelimiterWhitespaceOnly() {
        SplitTextInvocable.Input input = new SplitTextInvocable.Input();
        input.text = 'a;b';
        input.delimiter = '   ';

        Test.startTest();
        try {
            SplitTextInvocable.execute(new List<SplitTextInvocable.Input>{ input });
            Assert.fail('Expected a SplitTextException when delimiter is whitespace only.');
        } catch (SplitTextInvocable.SplitTextException e) {
            // expected
        }
        Test.stopTest();
    }

    @IsTest
    static void testExecute_bulkSafety_multipleInputs() {
        SplitTextInvocable.Input first = new SplitTextInvocable.Input();
        first.text = 'one;two';
        first.delimiter = ';';

        SplitTextInvocable.Input second = new SplitTextInvocable.Input();
        second.text = 'alpha';
        second.delimiter = ',';

        Test.startTest();
        List<SplitTextInvocable.Output> results = SplitTextInvocable.execute(
            new List<SplitTextInvocable.Input>{ first, second }
        );
        Test.stopTest();

        Assert.areEqual(2, results.size());
        Assert.areEqual(new List<String>{ 'one', 'two' }, results[0].values);
        Assert.areEqual(new List<String>{ 'alpha' }, results[1].values);
    }
}
