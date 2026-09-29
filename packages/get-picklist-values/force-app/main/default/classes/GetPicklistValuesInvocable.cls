public with sharing class GetPicklistValuesInvocable {
    public class PicklistFieldException extends Exception {
    }

    public class PicklistOption {
        @InvocableVariable(label='Label')
        public String label;
        @InvocableVariable(label='Value')
        public String value;
        @InvocableVariable(label='Is Active')
        public Boolean isActive;
        @InvocableVariable(label='Is Default')
        public Boolean isDefaultValue;
    }

    public class Input {
        @InvocableVariable(label='SObject API Name' required=true)
        public String objectApiName;

        @InvocableVariable(label='Field API Name' required=true)
        public String fieldApiName;

        @InvocableVariable(label='Record Type Developer Name')
        public String recordTypeDeveloperName;
    }

    public class Output {
        @InvocableVariable(label='Picklist Values')
        public List<PicklistOption> picklistValues;
    }

    @InvocableMethod(label='Get Picklist Values' category='Utilities')
    public static List<Output> execute(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (Input input : inputs) {
            Output output = new Output();
            output.picklistValues = resolvePicklistOptions(input);
            results.add(output);
        }
        return results;
    }

    @TestVisible
    private static List<PicklistOption> resolvePicklistOptions(Input input) {
        if (input == null || String.isBlank(input.objectApiName) || String.isBlank(input.fieldApiName)) {
            throw new PicklistFieldException('SObject API Name and Field API Name must both be provided.');
        }

        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(input.objectApiName.toLowerCase());
        if (objectType == null) {
            throw new PicklistFieldException('Unknown SObject "' + input.objectApiName + '".');
        }

        Schema.SObjectField field = objectType.getDescribe().fields.getMap().get(input.fieldApiName.toLowerCase());
        if (field == null) {
            throw new PicklistFieldException(
                'Unknown field "' + input.fieldApiName + '" on SObject "' + input.objectApiName + '".'
            );
        }

        Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
        if (
            fieldDescribe.getType() != Schema.DisplayType.PICKLIST &&
            fieldDescribe.getType() != Schema.DisplayType.MULTIPICKLIST
        ) {
            throw new PicklistFieldException(
                'Field "' + input.fieldApiName + '" on SObject "' + input.objectApiName + '" is not a picklist field.'
            );
        }

        if (String.isNotBlank(input.recordTypeDeveloperName)) {
            return resolvePicklistOptionsForRecordType(objectType, fieldDescribe, input);
        }

        List<PicklistOption> options = new List<PicklistOption>();
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            options.add(toPicklistOption(entry));
        }
        return options;
    }

    /**
     * Uses ConnectApi.RecordUi, unlike the plain Schema describe path, because
     * Schema.DescribeFieldResult.getPicklistValues() always reflects the "master" value set and
     * cannot be scoped to a specific record type's restricted picklist values.
     */
    private static List<PicklistOption> resolvePicklistOptionsForRecordType(
        Schema.SObjectType objectType,
        Schema.DescribeFieldResult fieldDescribe,
        Input input
    ) {
        Schema.RecordTypeInfo recordTypeInfo = objectType.getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get(input.recordTypeDeveloperName);
        if (recordTypeInfo == null) {
            throw new PicklistFieldException(
                'No record type named "' + input.recordTypeDeveloperName +
                '" exists for SObject "' + input.objectApiName + '".'
            );
        }

        ConnectApi.PicklistValuesCollection collection = ConnectApi.RecordUi.getPicklistValuesByRecordType(
            input.objectApiName,
            recordTypeInfo.getRecordTypeId()
        );

        ConnectApi.PicklistValues picklistForField = findPicklistForField(collection, fieldDescribe.getName());
        if (picklistForField == null) {
            throw new PicklistFieldException(
                'Field "' + input.fieldApiName + '" on SObject "' + input.objectApiName +
                '" has no picklist values for record type "' + input.recordTypeDeveloperName + '".'
            );
        }

        // Unlike Schema.PicklistEntry, ConnectApi.PicklistValue has no per-entry active flag
        // (only active values are ever returned) and the default is a single reference on the
        // outer PicklistValues, not a per-entry boolean.
        String defaultValue = picklistForField.defaultValue?.value;
        List<PicklistOption> options = new List<PicklistOption>();
        for (ConnectApi.PicklistValue entry : picklistForField.values) {
            PicklistOption option = new PicklistOption();
            option.label = entry.label;
            option.value = entry.value;
            option.isActive = true;
            option.isDefaultValue = entry.value == defaultValue;
            options.add(option);
        }
        return options;
    }

    private static ConnectApi.PicklistValues findPicklistForField(
        ConnectApi.PicklistValuesCollection collection,
        String fieldApiName
    ) {
        if (collection == null || collection.picklistFieldValues == null) {
            return null;
        }
        for (String key : collection.picklistFieldValues.keySet()) {
            if (key.equalsIgnoreCase(fieldApiName)) {
                return collection.picklistFieldValues.get(key);
            }
        }
        return null;
    }

    private static PicklistOption toPicklistOption(Schema.PicklistEntry entry) {
        PicklistOption option = new PicklistOption();
        option.label = entry.getLabel();
        option.value = entry.getValue();
        option.isActive = entry.isActive();
        option.isDefaultValue = entry.isDefaultValue();
        return option;
    }
}
