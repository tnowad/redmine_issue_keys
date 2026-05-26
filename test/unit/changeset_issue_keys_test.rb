# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueKeys
  class ChangesetIssueKeysTest < ActiveSupport::TestCase
    def setup
      User.current = nil
    end

    def closed_status
      IssueStatus.find_by!(:name => 'Closed')
    end

    def test_bare_issue_key_is_detected_when_ref_keywords_are_wildcard
      project = Project.generate! do |p|
        p.parent = Project.find(1)
        p.issue_key_prefix = 'AUTH'
      end
      issue = Issue.generate!(:project => project, :subject => 'Bare key')

      with_settings(
        :commit_ref_keywords => '*',
        :commit_update_keywords => [{'keywords' => 'fixes', 'status_id' => closed_status.id.to_s}]
      ) do
        changeset =
          Changeset.new(
            :repository => Project.find(1).repository,
            :committed_on => Time.current,
            :comments => issue.issue_key,
            :revision => '12345'
          )

        assert changeset.save
        assert_equal [issue.id], changeset.issue_ids
      end
    end

    def test_lowercase_bare_issue_key_is_detected_when_ref_keywords_are_wildcard
      project = Project.generate! do |p|
        p.parent = Project.find(1)
        p.issue_key_prefix = 'AUTH'
      end
      issue = Issue.generate!(:project => project, :subject => 'Bare lowercase key')

      with_settings(
        :commit_ref_keywords => '*',
        :commit_update_keywords => [{'keywords' => 'fixes', 'status_id' => closed_status.id.to_s}]
      ) do
        changeset =
          Changeset.new(
            :repository => Project.find(1).repository,
            :committed_on => Time.current,
            :comments => issue.issue_key.downcase,
            :revision => '12345a'
          )

        assert changeset.save
        assert_equal [issue.id], changeset.issue_ids
      end
    end

    def test_issue_key_is_detected_with_ref_keyword
      project = Project.generate! do |p|
        p.parent = Project.find(1)
        p.issue_key_prefix = 'AUTH'
      end
      issue = Issue.generate!(:project => project, :subject => 'Refs key')

      with_settings :commit_ref_keywords => 'refs', :commit_update_keywords => [] do
        changeset =
          Changeset.new(
            :repository => Project.find(1).repository,
            :committed_on => Time.current,
            :comments => "Refs #{issue.issue_key}",
            :revision => '12346'
          )

        assert changeset.save
        assert_equal [issue.id], changeset.issue_ids
      end
    end

    def test_bare_issue_key_is_detected_without_ref_keyword_wildcard
      project = Project.generate! do |p|
        p.parent = Project.find(1)
        p.issue_key_prefix = 'AUTH'
      end
      issue = Issue.generate!(:project => project, :subject => 'Bare Jira-style key')

      with_settings :commit_ref_keywords => 'refs', :commit_update_keywords => [] do
        changeset =
          Changeset.new(
            :repository => Project.find(1).repository,
            :committed_on => Time.current,
            :comments => "Implement #{issue.issue_key}",
            :revision => '12345b'
          )

        assert changeset.save
        assert_equal [issue.id], changeset.issue_ids
      end
    end

    def test_bare_numeric_issue_id_still_requires_ref_keyword_or_wildcard
      with_settings :commit_ref_keywords => 'refs', :commit_update_keywords => [] do
        changeset =
          Changeset.new(
            :repository => Project.find(1).repository,
            :committed_on => Time.current,
            :comments => 'Implement #1',
            :revision => '12345c'
          )

        assert changeset.save
        assert_empty changeset.issue_ids
      end
    end

    def test_mixed_case_issue_key_is_detected_with_ref_keyword
      project = Project.generate! do |p|
        p.parent = Project.find(1)
        p.issue_key_prefix = 'AUTH'
      end
      issue = Issue.generate!(:project => project, :subject => 'Refs mixed case')

      with_settings :commit_ref_keywords => 'refs', :commit_update_keywords => [] do
        changeset =
          Changeset.new(
            :repository => Project.find(1).repository,
            :committed_on => Time.current,
            :comments => "refs Auth-1",
            :revision => '12346a'
          )

        assert changeset.save
        assert_equal [issue.id], changeset.issue_ids
      end
    end

    def test_issue_key_is_detected_with_fix_keyword
      project = Project.generate! do |p|
        p.parent = Project.find(1)
        p.issue_key_prefix = 'AUTH'
      end
      issue = Issue.generate!(:project => project, :subject => 'Fixes key')

      with_settings(
        :commit_ref_keywords => '',
        :commit_update_keywords => [{'keywords' => 'fixes', 'status_id' => closed_status.id.to_s}]
      ) do
        changeset =
          Changeset.new(
            :repository => Project.find(1).repository,
            :committed_on => Time.current,
            :comments => "Fixes #{issue.issue_key}",
            :revision => '12347'
          )

        assert changeset.save
        assert_equal [issue.id], changeset.issue_ids
        assert issue.reload.closed?
      end
    end

    def test_mixed_case_issue_key_is_detected_with_fix_keyword
      project = Project.generate! do |p|
        p.parent = Project.find(1)
        p.issue_key_prefix = 'AUTH'
      end
      issue = Issue.generate!(:project => project, :subject => 'Fixes mixed case')

      with_settings(
        :commit_ref_keywords => '',
        :commit_update_keywords => [{'keywords' => 'fixes', 'status_id' => closed_status.id.to_s}]
      ) do
        changeset =
          Changeset.new(
            :repository => Project.find(1).repository,
            :committed_on => Time.current,
            :comments => "fixes Auth-1",
            :revision => '12347a'
          )

        assert changeset.save
        assert_equal [issue.id], changeset.issue_ids
        assert issue.reload.closed?
      end
    end

    def test_numeric_issue_reference_still_works_next_to_issue_keys
      project = Project.generate! do |p|
        p.parent = Project.find(1)
        p.issue_key_prefix = 'AUTH'
      end
      issue = Issue.generate!(:project => project, :subject => 'Keyed alongside numeric')

      with_settings(
        :commit_ref_keywords => '*',
        :commit_update_keywords => [{'keywords' => 'fixes', 'status_id' => closed_status.id.to_s}]
      ) do
        changeset =
          Changeset.new(
            :repository => Project.find(1).repository,
            :committed_on => Time.current,
            :comments => "Refs #{issue.issue_key} and #1",
            :revision => '12348'
          )

        assert changeset.save
        assert_equal [1, issue.id].sort, changeset.issue_ids.sort
      end
    end
  end
end
