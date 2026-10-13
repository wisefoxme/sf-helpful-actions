/**
 * @description Aura/LWC entry point for CSV-to-SObject conversion via DataWeave.
 */
public with sharing class DataWeaveCsvConversionController {
    /**
     * @description Converts uploaded CSV text using the configured DataWeave script.
     * @param dataWeaveScriptApiName Deployed .dwl API name.
     * @param targetObjectApiName Expected SObject type API name for output rows.
     * @param csvContent CSV file body (not stored server-side beyond this transaction).
     * @return Converted SObject rows (no DML).
     */
    @AuraEnabled
    public static List<SObject> convertCsv(
        String dataWeaveScriptApiName,
        String targetObjectApiName,
        String csvContent
    ) {
        try {
            return DataWeaveCsvConversionService.convert(
                dataWeaveScriptApiName,
                targetObjectApiName,
                csvContent
            );
        } catch (DataWeaveCsvConversionService.ConversionException ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }
}
