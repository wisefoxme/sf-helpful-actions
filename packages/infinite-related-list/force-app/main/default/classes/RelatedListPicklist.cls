/**
 * Design-time picklist for the infiniteRelatedList LWC. Lists the child
 * relationships of the record page's object. Each value is the relationship
 * name, which is the UI API relatedListId (for example Contacts or Cases__r).
 */
global class RelatedListPicklist extends VisualEditor.DynamicPickList {
  private final String entityName;

  global RelatedListPicklist(VisualEditor.DesignTimePageContext context) {
    this.entityName = context?.entityName;
  }

  global override VisualEditor.DataRow getDefaultValue() {
    return null;
  }

  global override VisualEditor.DynamicPickListRows getValues() {
    VisualEditor.DynamicPickListRows rows = new VisualEditor.DynamicPickListRows();
    Map<String, String> valueByLabel = getRelationships();
    List<String> labels = new List<String>(valueByLabel.keySet());
    labels.sort();
    for (String label : labels) {
      rows.addRow(new VisualEditor.DataRow(label, valueByLabel.get(label)));
    }
    return rows;
  }

  global override Boolean isValid(Object attributeValue) {
    return attributeValue instanceof String &&
      getRelationships().values().contains((String) attributeValue);
  }

  // Label -> relationship name. The label includes the lookup field and the
  // relationship name, so it is unique.
  private Map<String, String> getRelationships() {
    Map<String, String> valueByLabel = new Map<String, String>();
    Schema.SObjectType parentType = String.isBlank(entityName)
      ? null
      : Schema.getGlobalDescribe().get(entityName);
    if (parentType == null) {
      return valueByLabel;
    }
    for (
      Schema.ChildRelationship rel : parentType.getDescribe()
        .getChildRelationships()
    ) {
      String relationshipName = rel.getRelationshipName();
      if (relationshipName == null || rel.isDeprecatedAndHidden()) {
        continue;
      }
      Schema.DescribeSObjectResult child = rel.getChildSObject().getDescribe();
      if (!child.isAccessible() || !child.isQueryable()) {
        continue;
      }
      String label =
        child.getLabelPlural() +
        ' (' +
        rel.getField().getDescribe().getLabel() +
        ') - ' +
        relationshipName;
      valueByLabel.put(label, relationshipName);
    }
    return valueByLabel;
  }
}
