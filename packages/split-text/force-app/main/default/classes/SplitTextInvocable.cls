public with sharing class SplitTextInvocable {
    public class SplitTextException extends Exception {
    }

    public class Input {
        @InvocableVariable(label='Text' required=true)
        public String text;

        @InvocableVariable(label='Delimiter')
        public String delimiter;
    }

    public class Output {
        @InvocableVariable(label='Values')
        public List<String> values;
    }

    @InvocableMethod(label='Split Text' category='Utilities')
    public static List<Output> execute(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (Input input : inputs) {
            Output output = new Output();
            output.values = splitText(input);
            results.add(output);
        }
        return results;
    }

    @TestVisible
    private static List<String> splitText(Input input) {
        if (input == null || String.isBlank(input.text)) {
            return new List<String>();
        }

        String delimiter;
        if (input.delimiter == null || input.delimiter == '') {
            delimiter = ';';
        } else {
            delimiter = input.delimiter.trim();
            if (String.isBlank(delimiter)) {
                throw new SplitTextException('Delimiter must not be blank.');
            }
        }

        List<String> values = new List<String>();
        for (String segment : input.text.split(Pattern.quote(delimiter))) {
            String trimmed = segment == null ? '' : segment.trim();
            if (String.isNotBlank(trimmed)) {
                values.add(trimmed);
            }
        }
        return values;
    }
}
