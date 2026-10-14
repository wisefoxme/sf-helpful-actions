@isTest
private class RelatedListPicklistTest {
  private static RelatedListPicklist picklistFor(String entityName) {
    VisualEditor.DesignTimePageContext context = new VisualEditor.DesignTimePageContext();
    context.entityName = entityName;
    context.pageType = 'RecordPage';
    return new RelatedListPicklist(context);
  }

  @isTest
  static void listsChildRelationshipsOfThePageObject() {
    RelatedListPicklist picklist = picklistFor('Account');

    Set<Object> values = new Set<Object>();
    for (VisualEditor.DataRow row : picklist.getValues().getDataRows()) {
      values.add(row.getValue());
    }

    Assert.isTrue(values.contains('Contacts'), 'Contacts should be listed');
    Assert.isNull(picklist.getDefaultValue(), 'No default value');
    Assert.isTrue(picklist.isValid('Contacts'), 'Contacts is valid');
    Assert.isFalse(picklist.isValid('NotARelationship'), 'Unknown is invalid');
  }

  @isTest
  static void returnsNoRowsWithoutAnObject() {
    RelatedListPicklist picklist = picklistFor(null);

    Assert.areEqual(0, picklist.getValues().size(), 'No rows');
    Assert.isFalse(picklist.isValid('Contacts'), 'Nothing is valid');
  }
}
