/**
 * @description Converts CSV text to in-memory SObjects via a deployed DataWeave script.
 * Scripts must declare `input records application/csv` and accept optional `targetObjectApiName`.
 * No DML is performed.
 */
public with sharing class DataWeaveCsvConversionService {
    @TestVisible
    private static final Integer MAX_CSV_LENGTH = 3500000;

    @TestVisible
    private static final Pattern SCRIPT_NAME_PATTERN = Pattern.compile(
        '^[A-Za-z0-9_]+$'
    );

    /**
     * @description Runs the named DataWeave script against CSV content.
     * @param dataWeaveScriptApiName API name of the .dwl resource (no path or extension).
     * @param targetObjectApiName API name of the expected output SObject type.
     * @param csvContent Raw CSV file body as UTF-8 text.
     * @return In-memory SObject rows produced by the script (not persisted).
     */
    public static List<SObject> convert(
        String dataWeaveScriptApiName,
        String targetObjectApiName,
        String csvContent
    ) {
        validateScriptApiName(dataWeaveScriptApiName);
        validateTargetObjectApiName(targetObjectApiName);
        validateCsvContent(csvContent);

        Map<String, Object> payload = new Map<String, Object>{
            'records' => csvContent,
            'targetObjectApiName' => targetObjectApiName
        };

        List<SObject> rows;
        try {
            DataWeave.Script script = DataWeave.Script.createScript(
                dataWeaveScriptApiName
            );
            DataWeave.Result dwResult = script.execute(payload);
            Object value = dwResult.getValue();
            if (value == null) {
                rows = new List<SObject>();
            } else if (value instanceof List<SObject>) {
                rows = (List<SObject>) value;
            } else {
                throw new ConversionException(
                    'DataWeave script must return a list of SObjects (application/apex output).'
                );
            }
        } catch (ConversionException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new ConversionException(
                'DataWeave conversion failed: ' + ex.getMessage()
            );
        }

        assertRowsMatchTargetType(rows, targetObjectApiName);
        return rows;
    }

    private static void validateScriptApiName(String dataWeaveScriptApiName) {
        if (String.isBlank(dataWeaveScriptApiName)) {
            throw new ConversionException(
                'DataWeave script API name is required.'
            );
        }
        if (!SCRIPT_NAME_PATTERN.matcher(dataWeaveScriptApiName).matches()) {
            throw new ConversionException(
                'DataWeave script API name contains invalid characters.'
            );
        }
    }

    private static void validateTargetObjectApiName(
        String targetObjectApiName
    ) {
        if (String.isBlank(targetObjectApiName)) {
            throw new ConversionException(
                'Target object API name is required.'
            );
        }
        Schema.SObjectType objectType = Schema.getGlobalDescribe()
            .get(targetObjectApiName);
        if (objectType == null) {
            throw new ConversionException(
                'Unknown target object: ' + targetObjectApiName
            );
        }
    }

    private static void validateCsvContent(String csvContent) {
        if (String.isBlank(csvContent)) {
            throw new ConversionException('CSV content is empty.');
        }
        if (csvContent.length() > MAX_CSV_LENGTH) {
            throw new ConversionException(
                'CSV content exceeds the maximum allowed size (' +
                    MAX_CSV_LENGTH +
                    ' characters).'
            );
        }
    }

    private static void assertRowsMatchTargetType(
        List<SObject> rows,
        String targetObjectApiName
    ) {
        String sotName;

        for (SObject row : rows) {
            if (row == null) {
                throw new ConversionException(
                    'DataWeave script returned a null row in the result list.'
                );
            }

            if (sotName == null) {
                sotName = row.getSObjectType().getDescribe().getName();
            }

            if (sotName != targetObjectApiName) {
                throw new ConversionException(
                    'Script returned ' +
                        sotName +
                        ' but expected ' +
                        targetObjectApiName +
                        '.'
                );
            }
        }
    }

    public class ConversionException extends Exception {
    }
}
