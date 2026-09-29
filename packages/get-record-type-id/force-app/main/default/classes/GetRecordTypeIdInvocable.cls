public with sharing class GetRecordTypeIdInvocable {
    public class RecordTypeNotFoundException extends Exception {
    }

    public class Input {
        @InvocableVariable(label='SObject API Name' required=true)
        public String objectApiName;

        @InvocableVariable(label='Record Type Developer Name' required=true)
        public String recordTypeDeveloperName;
    }

    public class Output {
        @InvocableVariable(label='Record Type ID')
        public Id recordTypeId;
    }

    @InvocableMethod(label='Get Record Type ID' category='Utilities')
    public static List<Output> execute(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (Input input : inputs) {
            Output output = new Output();
            output.recordTypeId = resolveRecordTypeId(input);
            results.add(output);
        }
        return results;
    }

    @TestVisible
    private static Id resolveRecordTypeId(Input input) {
        if (input == null || String.isBlank(input.objectApiName) || String.isBlank(input.recordTypeDeveloperName)) {
            throw new RecordTypeNotFoundException(
                'SObject API Name and Record Type Developer Name must both be provided.'
            );
        }

        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(input.objectApiName.toLowerCase());
        if (objectType == null) {
            throw new RecordTypeNotFoundException('Unknown SObject "' + input.objectApiName + '".');
        }

        Schema.RecordTypeInfo recordTypeInfo = objectType.getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get(input.recordTypeDeveloperName);
        if (recordTypeInfo == null) {
            throw new RecordTypeNotFoundException(
                'No record type named "' + input.recordTypeDeveloperName +
                '" exists for SObject "' + input.objectApiName + '".'
            );
        }

        return recordTypeInfo.getRecordTypeId();
    }
}
