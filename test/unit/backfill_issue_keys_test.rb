# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../db/migrate/002_backfill_issue_keys'

module RedmineIssueKeys
  class BackfillIssueKeysTest < ActiveSupport::TestCase
    class ProjectRecord < ActiveRecord::Base
      self.table_name = 'projects'
    end

    class IssueRecord < ActiveRecord::Base
      self.table_name = 'issues'
    end

    class CounterRecord < ActiveRecord::Base
      self.table_name = 'project_issue_counters'
    end

    def setup
      User.current = nil
    end

    def test_backfill_generates_unique_prefixes_and_sequential_numbers
      project_a = create_project(identifier: 'auth')
      project_b = create_project(identifier: 'auth!')
      project_digit = create_project(identifier: '1auth')
      project_one_char = create_project(identifier: 'a')
      project_invalid = create_project(identifier: '!@#')
      project_empty = create_project(identifier: 'empty')

      issue_a_1 = create_issue(project_a.id, 'Auth 1')
      issue_a_2 = create_issue(project_a.id, 'Auth 2')
      create_issue(project_b.id, 'Auth collision')
      create_issue(project_digit.id, 'Digit prefix')

      BackfillIssueKeys.new.up

      assert_equal 'AUTH', project_a.reload.issue_key_prefix
      assert_match(/\AAUTH\d+\z/, project_b.reload.issue_key_prefix)
      assert_equal 'P1AUTH', project_digit.reload.issue_key_prefix
      assert_equal 'AX', project_one_char.reload.issue_key_prefix
      assert_match(/\AP\d+\z/, project_invalid.reload.issue_key_prefix)
      assert_equal 'EMPTY', project_empty.reload.issue_key_prefix

      assert_equal 1, issue_a_1.reload.project_issue_number
      assert_equal 'AUTH-1', issue_a_1.issue_key
      assert_equal 2, issue_a_2.reload.project_issue_number
      assert_equal 'AUTH-2', issue_a_2.issue_key

      assert_equal 3, CounterRecord.find_by(project_id: project_a.id).next_value
      assert_equal 2, CounterRecord.find_by(project_id: project_b.id).next_value
      assert_equal 2, CounterRecord.find_by(project_id: project_digit.id).next_value
      assert_equal 1, CounterRecord.find_by(project_id: project_one_char.id).next_value
      assert_equal 1, CounterRecord.find_by(project_id: project_invalid.id).next_value
      assert_equal 1, CounterRecord.find_by(project_id: project_empty.id).next_value
    end

    def test_backfill_down_clears_backfilled_data
      project = create_project(identifier: 'auth')
      create_issue(project.id, 'Auth issue')

      migration = BackfillIssueKeys.new
      migration.up
      migration.down

      assert_nil project.reload.issue_key_prefix
      assert_nil IssueRecord.find_by(project_id: project.id).reload.project_issue_number
      assert_nil IssueRecord.find_by(project_id: project.id).issue_key
      assert_nil CounterRecord.find_by(project_id: project.id)
    end

    private

    def create_project(identifier:)
      ProjectRecord.create!(
        name: "Project #{identifier}",
        identifier: identifier,
        description: '',
        is_public: true
      )
    end

    def create_issue(project_id, subject)
      IssueRecord.create!(
        project_id: project_id,
        tracker_id: 1,
        status_id: 1,
        priority_id: 5,
        author_id: 1,
        subject: subject
      )
    end
  end
end
