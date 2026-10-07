@isTest
private class FindPossibleDuplicatesActionTest {
  // Matches the Standard Contact Duplicate Rule, which is active in the org.
  private static final String FIRST_NAME = 'Arch64';
  private static final String LAST_NAME = 'Duplicate';
  private static final String EMAIL = 'arch64.duplicate@example.com';

  @testSetup
  static void setup() {
    insert new Contact(
      FirstName = FIRST_NAME,
      LastName = LAST_NAME,
      Email = EMAIL
    );
  }

  // Real Datacloud.FindDuplicates calls

  @isTest
  static void findsDuplicateOfNewRecord() {
    Contact existing = [SELECT Id FROM Contact WHERE Email = :EMAIL];

    FindPossibleDuplicatesAction.Result result = run(
      new Contact(FirstName = FIRST_NAME, LastName = LAST_NAME, Email = EMAIL)
    );

    Assert.isTrue(result.hasDuplicates);
    Assert.areEqual(existing.Id, result.duplicateRecordId);
    Assert.areEqual(existing.Id, result.duplicateRecord.Id);
    Assert.areEqual(new List<Id>{ existing.Id }, result.duplicateRecordIds);
    Assert.isNotNull(result.duplicateRuleName);
    Assert.isNotNull(result.matchingRuleName);
    Assert.isNull(result.errorMessage);
  }

  @isTest
  static void savedRecordIsNotItsOwnDuplicate() {
    Contact existing = [
      SELECT Id, FirstName, LastName, Email
      FROM Contact
      WHERE Email = :EMAIL
    ];

    FindPossibleDuplicatesAction.Result result = run(existing);

    Assert.isFalse(result.hasDuplicates);
    Assert.isTrue(result.duplicateRecordIds.isEmpty());
    Assert.isNull(result.errorMessage);
  }

  @isTest
  static void uniqueRecordHasNoDuplicates() {
    FindPossibleDuplicatesAction.Result result = run(
      new Contact(
        FirstName = 'Someone',
        LastName = 'Else',
        Email = 'someone.else@example.com'
      )
    );

    Assert.isFalse(result.hasDuplicates);
    Assert.isNull(result.duplicateRecordId);
    Assert.isNull(result.errorMessage);
  }

  // Stubbed finder

  @isTest
  static void noActiveDuplicateRuleReturnsError() {
    StubFinder stub = new StubFinder();
    stub.exceptionToThrow = new HandledException(
      'No active duplicate rules are defined for the Contact object type.'
    );
    FindPossibleDuplicatesAction.finder = stub;

    FindPossibleDuplicatesAction.Result result = run(new Contact());

    Assert.isFalse(result.hasDuplicates);
    Assert.areEqual(stub.exceptionToThrow.getMessage(), result.errorMessage);
  }

  @isTest
  static void searchErrorIsReturned() {
    StubFinder stub = new StubFinder();
    stub.errorMessage = 'Search failed.';
    FindPossibleDuplicatesAction.finder = stub;

    FindPossibleDuplicatesAction.Result result = run(new Contact());

    Assert.isFalse(result.hasDuplicates);
    Assert.areEqual('Search failed.', result.errorMessage);
  }

  @isTest
  static void bestMatchHasHighestConfidenceAndIdsAreDeduped() {
    Id lowId = fakeId(Contact.SObjectType, 1);
    Id highId = fakeId(Contact.SObjectType, 2);
    StubFinder stub = new StubFinder();
    stub.matches = new List<FindPossibleDuplicatesAction.Match>{
      match(lowId, 70, 'Rule_A', 'Matching_A'),
      match(highId, 95, 'Rule_B', 'Matching_B'),
      match(lowId, 80, 'Rule_B', 'Matching_B')
    };
    FindPossibleDuplicatesAction.finder = stub;

    FindPossibleDuplicatesAction.Result result = run(new Contact());

    Assert.isTrue(result.hasDuplicates);
    Assert.areEqual(highId, result.duplicateRecordId);
    Assert.areEqual(95, result.matchConfidence);
    Assert.areEqual('Rule_B', result.duplicateRuleName);
    Assert.areEqual('Matching_B', result.matchingRuleName);
    Assert.areEqual(new List<Id>{ lowId, highId }, result.duplicateRecordIds);
    Assert.areEqual(2, result.duplicateRecords.size());
  }

  @isTest
  static void groupsByObjectAndChunksAndKeepsOrder() {
    StubFinder stub = new StubFinder();
    FindPossibleDuplicatesAction.finder = stub;
    List<FindPossibleDuplicatesAction.Request> requests = new List<FindPossibleDuplicatesAction.Request>();
    for (Integer i = 0; i < 70; i++) {
      SObject record = Math.mod(i, 7) == 0
        ? (SObject) new Lead(LastName = 'Lead ' + i)
        : (SObject) new Contact(LastName = 'Contact ' + i);
      requests.add(request(record));
    }
    requests.add(new FindPossibleDuplicatesAction.Request());

    List<FindPossibleDuplicatesAction.Result> results = FindPossibleDuplicatesAction.findDuplicates(
      requests
    );

    // 60 Contacts split into calls of 50 and 10, plus one call for the 10 Leads
    Assert.areEqual(3, stub.calls.size());
    for (List<SObject> call : stub.calls) {
      Assert.isTrue(
        call.size() <= FindPossibleDuplicatesAction.MAX_RECORDS_PER_CALL
      );
      for (SObject record : call) {
        Assert.areEqual(call[0].getSObjectType(), record.getSObjectType());
      }
    }
    Assert.areEqual(71, results.size());
    for (Integer i = 0; i < 70; i++) {
      // The stub reports the record's own LastName as its error, to check the order.
      Assert.areEqual(
        (String) requests[i].record.get('LastName'),
        results[i].errorMessage
      );
    }
    Assert.areEqual('No record was given.', results[70].errorMessage);
  }

  private static FindPossibleDuplicatesAction.Result run(SObject record) {
    return FindPossibleDuplicatesAction.findDuplicates(
      new List<FindPossibleDuplicatesAction.Request>{ request(record) }
    )[0];
  }

  private static FindPossibleDuplicatesAction.Request request(SObject record) {
    FindPossibleDuplicatesAction.Request request = new FindPossibleDuplicatesAction.Request();
    request.record = record;
    return request;
  }

  private static FindPossibleDuplicatesAction.Match match(
    Id recordId,
    Decimal confidence,
    String duplicateRule,
    String matchingRule
  ) {
    FindPossibleDuplicatesAction.Match match = new FindPossibleDuplicatesAction.Match();
    match.record = recordId.getSObjectType().newSObject(recordId);
    match.confidence = confidence;
    match.duplicateRule = duplicateRule;
    match.matchingRule = matchingRule;
    return match;
  }

  private static Id fakeId(SObjectType type, Integer n) {
    String suffix = String.valueOf(n);
    return Id.valueOf(
      type.getDescribe().getKeyPrefix() +
        '0'.repeat(12 - suffix.length()) +
        suffix
    );
  }

  private class StubFinder implements FindPossibleDuplicatesAction.Finder {
    HandledException exceptionToThrow;
    String errorMessage;
    List<FindPossibleDuplicatesAction.Match> matches;
    List<List<SObject>> calls = new List<List<SObject>>();

    public List<FindPossibleDuplicatesAction.FinderResult> find(
      List<SObject> records
    ) {
      calls.add(records);
      if (exceptionToThrow != null) {
        throw exceptionToThrow;
      }
      List<FindPossibleDuplicatesAction.FinderResult> results = new List<FindPossibleDuplicatesAction.FinderResult>();
      for (SObject record : records) {
        FindPossibleDuplicatesAction.FinderResult result = new FindPossibleDuplicatesAction.FinderResult();
        if (matches != null) {
          result.matches = matches;
        } else {
          result.errorMessage = errorMessage != null
            ? errorMessage
            : (String) record.get('LastName');
        }
        results.add(result);
      }
      return results;
    }
  }
}
