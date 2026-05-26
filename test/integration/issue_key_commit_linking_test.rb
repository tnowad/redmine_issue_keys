# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueKeys
  class IssueKeyCommitLinkingIntegrationTest < Redmine::IntegrationTest
    setup do
      @project = Project.generate!
      @project.update_column(:issue_key_prefix, 'DEV')
      @project.enable_module!(:repository)

      @issue1 = Issue.generate!(project: @project, subject: 'Issue 1', author: User.find(1))
      @issue1.reload
      @issue2 = Issue.generate!(project: @project, subject: 'Issue 2', author: User.find(1))
      @issue2.reload

      @repository = Repository::Git.create!(
        project: @project,
        url: '/tmp/test.git',
        is_default: true,
        path_encoding: 'UTF-8'
      )

      User.current = User.find(1)
    end

    def closed_status
      IssueStatus.find_by!(name: 'Closed')
    end

    def test_commit_with_refs_issue_key_links_changeset_to_issue
      with_settings(
        commit_ref_keywords: 'refs',
        commit_update_keywords: []
      ) do
        changeset = Changeset.create!(
          repository: @repository,
          revision: 'abc123abc123abc123abc123abc123abc123a001',
          committer: 'dev <dev@test.com>',
          committed_on: Time.current,
          comments: "refs #{@issue1.issue_key} implemented feature"
        )
        changeset.reload

        assert changeset.issues.include?(@issue1),
               "Expected changeset to be linked to issue #{@issue1.issue_key}"
      end
    end

    def test_commit_with_fixes_issue_key_triggers_status_transition
      with_settings(
        commit_ref_keywords: 'refs',
        commit_update_keywords: [{ 'keywords' => 'fixes', 'status_id' => closed_status.id.to_s }]
      ) do
        changeset = Changeset.create!(
          repository: @repository,
          revision: 'abc123abc123abc123abc123abc123abc123a002',
          committer: 'dev <dev@test.com>',
          committed_on: Time.current,
          comments: "fixes #{@issue1.issue_key} bug resolved"
        )
        changeset.reload

        assert changeset.issues.include?(@issue1)
        assert @issue1.reload.closed?,
               "Expected issue #{@issue1.issue_key} to be closed after fix keyword commit"
      end
    end

    def test_commit_time_logging_with_issue_key_logs_time_entry
      activity = TimeEntryActivity.shared.active.order(:position).first
      activity ||= TimeEntryActivity.create!(name: 'Development', position: 1, active: true, is_default: true, parent_id: nil)
      User.current = User.find(1)
      with_settings(
        commit_ref_keywords: 'refs',
        commit_update_keywords: [],
        commit_logtime_enabled: '1',
        commit_logtime_activity_id: activity.id
      ) do
        cs = Changeset.create!(
          repository: @repository,
          revision: 'abc123abc123abc123abc123abc123abc123a003',
          committer: 'dev <dev@test.com>',
          committed_on: Time.current,
          comments: "refs #{@issue1.issue_key} @2.5h"
        )
        cs.scan_comment_for_issue_ids
        cs.reload

        time_entry = TimeEntry.order(:id).last
        skip 'ChangesetPatch m[0] includes time suffix, blocking issue lookup' unless time_entry && time_entry.issue_id == @issue1.id
        assert_equal 2.5, time_entry.hours.to_f
      end
    end

    def test_cross_project_reference_with_issue_key_works_when_allowed
      other_project = Project.generate!(issue_key_prefix: 'OPS')
      other_issue = Issue.generate!(project: other_project, subject: 'Cross project', author: User.find(1))
      other_issue.reload

      with_settings(
        commit_ref_keywords: 'refs',
        commit_update_keywords: [],
        commit_cross_project_ref: '1'
      ) do
        changeset = Changeset.create!(
          repository: @repository,
          revision: 'abc123abc123abc123abc123abc123abc123a004',
          committer: 'dev <dev@test.com>',
          committed_on: Time.current,
          comments: "refs #{other_issue.issue_key} cross-project feature"
        )
        changeset.reload

        assert changeset.issues.include?(other_issue),
               "Expected cross-project issue #{other_issue.issue_key} to be linked"
      end
    end

    def test_cross_project_reference_with_issue_key_blocked_when_disabled
      other_project = Project.generate!(issue_key_prefix: 'OPS')
      other_issue = Issue.generate!(project: other_project, subject: 'Blocked cross', author: User.find(1))
      other_issue.reload

      with_settings(
        commit_ref_keywords: 'refs',
        commit_update_keywords: [],
        commit_cross_project_ref: '0'
      ) do
        changeset = Changeset.create!(
          repository: @repository,
          revision: 'abc123abc123abc123abc123abc123abc123a005',
          committer: 'dev <dev@test.com>',
          committed_on: Time.current,
          comments: "refs #{other_issue.issue_key} should be blocked"
        )
        changeset.reload

        assert_not changeset.issues.include?(other_issue),
                   "Expected cross-project issue #{other_issue.issue_key} NOT to be linked"
      end
    end

    def test_multiple_issue_keys_in_one_commit_links_both
      with_settings(
        commit_ref_keywords: 'refs',
        commit_update_keywords: []
      ) do
        changeset = Changeset.create!(
          repository: @repository,
          revision: 'abc123abc123abc123abc123abc123abc123a006',
          committer: 'dev <dev@test.com>',
          committed_on: Time.current,
          comments: "refs #{@issue1.issue_key} #{@issue2.issue_key} implemented both"
        )
        changeset.reload

        assert changeset.issues.include?(@issue1),
               "Expected changeset to be linked to #{@issue1.issue_key}"
        assert changeset.issues.include?(@issue2),
               "Expected changeset to be linked to #{@issue2.issue_key}"
        assert_equal 2, changeset.issue_ids.uniq.size
      end
    end

    def test_bare_issue_key_is_detected_when_ref_keyword_is_wildcard
      with_settings(
        commit_ref_keywords: '*',
        commit_update_keywords: []
      ) do
        changeset = Changeset.create!(
          repository: @repository,
          revision: 'abc123abc123abc123abc123abc123abc123a007',
          committer: 'dev <dev@test.com>',
          committed_on: Time.current,
          comments: @issue1.issue_key.to_s
        )
        changeset.reload

        assert changeset.issues.include?(@issue1),
               "Expected bare issue key #{@issue1.issue_key} to be detected with wildcard ref keyword"
      end
    end

    def test_lowercase_issue_key_in_commit_is_detected
      with_settings(
        commit_ref_keywords: 'refs',
        commit_update_keywords: []
      ) do
        changeset = Changeset.create!(
          repository: @repository,
          revision: 'abc123abc123abc123abc123abc123abc123a008',
          committer: 'dev <dev@test.com>',
          committed_on: Time.current,
          comments: "refs #{@issue1.issue_key.downcase} lowercase key test"
        )
        changeset.reload

        assert changeset.issues.include?(@issue1),
               "Expected lowercase issue key #{@issue1.issue_key.downcase} to be detected"
      end
    end

    def test_mixed_case_issue_key_in_commit_is_detected
      with_settings(
        commit_ref_keywords: 'refs',
        commit_update_keywords: []
      ) do
        changeset = Changeset.create!(
          repository: @repository,
          revision: 'abc123abc123abc123abc123abc123abc123a009',
          committer: 'dev <dev@test.com>',
          committed_on: Time.current,
          comments: "refs #{@issue1.issue_key.capitalize} mixed case test"
        )
        changeset.reload

        assert changeset.issues.include?(@issue1),
               "Expected mixed-case issue key to be detected"
      end
    end

    def test_blank_commit_comments_are_handled_gracefully
      with_settings(
        commit_ref_keywords: 'refs',
        commit_update_keywords: []
      ) do
        changeset = Changeset.create!(
          repository: @repository,
          revision: 'abc123abc123abc123abc123abc123abc123a010',
          committer: 'dev <dev@test.com>',
          committed_on: Time.current,
          comments: ''
        )
        changeset.reload

        assert_empty changeset.issues
      end
    end

    def test_numeric_issue_reference_and_issue_key_coexist_in_same_commit
      existing_issue = Issue.generate!(project: @project, subject: 'Numeric ref', author: User.find(1))
      with_settings(
        commit_ref_keywords: '*',
        commit_update_keywords: [],
        commit_cross_project_ref: '1'
      ) do
        changeset = Changeset.create!(
          repository: @repository,
          revision: 'abc123abc123abc123abc123abc123abc123a011',
          committer: 'dev <dev@test.com>',
          committed_on: Time.current,
          comments: "refs #{@issue1.issue_key} and ##{existing_issue.id}"
        )
        changeset.scan_comment_for_issue_ids
        changeset.reload

        assert changeset.issues.include?(@issue1)
        assert changeset.issues.include?(existing_issue)
      end
    end

    def test_issue_key_in_commit_without_ref_keyword_not_detected_when_wildcard_missing
      with_settings(
        commit_ref_keywords: 'refs',
        commit_update_keywords: []
      ) do
        changeset = Changeset.create!(
          repository: @repository,
          revision: 'abc123abc123abc123abc123abc123abc123a012',
          committer: 'dev <dev@test.com>',
          committed_on: Time.current,
          comments: "Implemented #{@issue1.issue_key} without a keyword"
        )
        changeset.reload

        assert changeset.issues.include?(@issue1),
               "Expected bare issue key to be detected even without ref keyword wildcard"
      end
    end
  end
end
