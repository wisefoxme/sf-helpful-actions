// Flow action that runs the active Duplicate Rules of a record's object through
// Datacloud.FindDuplicates and returns the possible duplicates it finds. The record can be saved or
// not; a saved record is never reported as a duplicate of itself.
//
// Datacloud.FindDuplicates takes at most 50 records per call, all of the same object, and throws a
// HandledException when the object has no active Duplicate Rule. That case returns no duplicates and
// an error message instead of failing the Flow.
public with sharing class FindPossibleDuplicatesAction {
  @TestVisible
  private static final Integer MAX_RECORDS_PER_CALL = 50;

  @TestVisible
  private static Finder finder = new DatacloudFinder();

  @InvocableMethod(
    label='Find Possible Duplicates'
    description='Runs the active duplicate rules of the record\'s object and returns the possible duplicates.'
    category='Duplicate Management'
  )
  public static List<Result> findDuplicates(List<Request> requests) {
    List<Result> results = new List<Result>();
    // SObjectType -> indexes of the requests with a record of that type
    Map<SObjectType, List<Integer>> indexesByType = new Map<SObjectType, List<Integer>>();
    for (Integer i = 0; i < requests.size(); i++) {
      Result result = new Result();
      results.add(result);
      SObject record = requests[i].record;
      if (record == null) {
        result.errorMessage = 'No record was given.';
        continue;
      }
      SObjectType type = record.getSObjectType();
      if (!indexesByType.containsKey(type)) {
        indexesByType.put(type, new List<Integer>());
      }
      indexesByType.get(type).add(i);
    }

    for (List<Integer> indexes : indexesByType.values()) {
      for (
        Integer start = 0; start < indexes.size(); start += MAX_RECORDS_PER_CALL
      ) {
        List<Integer> chunk = new List<Integer>();
        for (
          Integer i = start;
          i < Math.min(start + MAX_RECORDS_PER_CALL, indexes.size());
          i++
        ) {
          chunk.add(indexes[i]);
        }
        findChunk(requests, chunk, results);
      }
    }
    return results;
  }

  @TestVisible
  private static Set<String> normalizeMatchingRuleFilter(List<String> names) {
    if (names == null || names.isEmpty()) {
      return null;
    }
    Set<String> allowed = new Set<String>();
    for (String name : names) {
      if (String.isNotBlank(name)) {
        allowed.add(name);
      }
    }
    return allowed.isEmpty() ? null : allowed;
  }

  private static void findChunk(
    List<Request> requests,
    List<Integer> indexes,
    List<Result> results
  ) {
    List<SObject> records = new List<SObject>();
    for (Integer index : indexes) {
      records.add(requests[index].record);
    }
    List<FinderResult> found;
    try {
      found = finder.find(records);
    } catch (HandledException e) {
      // No active Duplicate Rule for the object
      for (Integer index : indexes) {
        results[index].errorMessage = e.getMessage();
      }
      return;
    }
    for (Integer i = 0; i < indexes.size(); i++) {
      fillResult(
        results[indexes[i]],
        records[i].Id,
        found[i],
        normalizeMatchingRuleFilter(requests[indexes[i]].matchingRuleApiNames)
      );
    }
  }

  private static void fillResult(
    Result result,
    Id inputId,
    FinderResult found,
    Set<String> allowedMatchingRules
  ) {
    if (found.errorMessage != null) {
      result.errorMessage = found.errorMessage;
      return;
    }
    Match best;
    Set<Id> seenIds = new Set<Id>();
    for (Match match : found.matches) {
      if (
        allowedMatchingRules != null &&
        !allowedMatchingRules.contains(match.matchingRule)
      ) {
        continue;
      }
      Id matchId = match.record.Id;
      if (matchId == inputId || seenIds.contains(matchId)) {
        continue;
      }
      seenIds.add(matchId);
      result.duplicateRecords.add(match.record);
      result.duplicateRecordIds.add(matchId);
      if (best == null || match.confidence > best.confidence) {
        best = match;
      }
    }
    if (best != null) {
      result.hasDuplicates = true;
      result.duplicateRecord = best.record;
      result.duplicateRecordId = best.record.Id;
      result.matchConfidence = best.confidence;
      result.duplicateRuleName = best.duplicateRule;
      result.matchingRuleName = best.matchingRule;
    }
  }

  public class Request {
    @InvocableVariable(
      label='Record'
      description='The record to find duplicates of. It can be saved or not.'
      required=true
    )
    public SObject record;

    @InvocableVariable(
      label='Matching Rule API Names'
      description='Optional. When set, only possible duplicates found by these matching rules (developer names) are returned. Leave empty to use all rules.'
    )
    public List<String> matchingRuleApiNames;
  }

  public class Result {
    @InvocableVariable(
      label='Has Duplicates'
      description='True when at least one possible duplicate was found.'
    )
    public Boolean hasDuplicates = false;

    @InvocableVariable(
      label='Duplicate Record'
      description='The possible duplicate with the highest match confidence. Contains standard fields only.'
    )
    public SObject duplicateRecord;

    @InvocableVariable(
      label='Duplicate Record ID'
      description='The ID of the possible duplicate with the highest match confidence.'
    )
    public Id duplicateRecordId;

    @InvocableVariable(
      label='Duplicate Records'
      description='All possible duplicates. Contain standard fields only.'
    )
    public List<SObject> duplicateRecords = new List<SObject>();

    @InvocableVariable(
      label='Duplicate Record IDs'
      description='The IDs of all possible duplicates.'
    )
    public List<Id> duplicateRecordIds = new List<Id>();

    @InvocableVariable(
      label='Match Confidence'
      description='The match confidence of the best possible duplicate, when the matching rule gives one.'
    )
    public Decimal matchConfidence;

    @InvocableVariable(
      label='Duplicate Rule Name'
      description='The API name of the duplicate rule that found the best possible duplicate.'
    )
    public String duplicateRuleName;

    @InvocableVariable(
      label='Matching Rule Name'
      description='The API name of the matching rule that found the best possible duplicate.'
    )
    public String matchingRuleName;

    @InvocableVariable(
      label='Error Message'
      description='Why the search could not run, for example when the object has no active duplicate rule.'
    )
    public String errorMessage;
  }

  // Datacloud result classes can't be built in tests, so the action works on these instead.
  @TestVisible
  private interface Finder {
    // One FinderResult per record, in the same order.
    List<FinderResult> find(List<SObject> records);
  }

  @TestVisible
  private class FinderResult {
    @TestVisible
    List<Match> matches = new List<Match>();
    @TestVisible
    String errorMessage;
  }

  @TestVisible
  private class Match {
    @TestVisible
    SObject record;
    @TestVisible
    Decimal confidence;
    @TestVisible
    String duplicateRule;
    @TestVisible
    String matchingRule;
  }

  private class DatacloudFinder implements Finder {
    public List<FinderResult> find(List<SObject> records) {
      List<FinderResult> results = new List<FinderResult>();
      for (
        Datacloud.FindDuplicatesResult found : Datacloud.FindDuplicates.findDuplicates(
          records
        )
      ) {
        FinderResult result = new FinderResult();
        results.add(result);
        if (!found.isSuccess()) {
          List<String> messages = new List<String>();
          for (Database.Error error : found.getErrors()) {
            messages.add(error.getMessage());
          }
          result.errorMessage = String.join(messages, ' ');
          continue;
        }
        for (
          Datacloud.DuplicateResult duplicate : found.getDuplicateResults()
        ) {
          for (
            Datacloud.MatchResult matchResult : duplicate.getMatchResults()
          ) {
            for (
              Datacloud.MatchRecord matchRecord : matchResult.getMatchRecords()
            ) {
              Match match = new Match();
              match.record = matchRecord.getRecord();
              match.confidence = matchRecord.getMatchConfidence();
              match.duplicateRule = duplicate.getDuplicateRule();
              match.matchingRule = matchResult.getRule();
              result.matches.add(match);
            }
          }
        }
      }
      return results;
    }
  }
}
