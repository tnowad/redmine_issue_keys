# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueKeys
  class IssueIssueKeysTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    def setup
      User.current = nil
    end

    def test_issue_keys_are_generated_per_project_in_sequence
      auth_project = Project.generate!(:issue_key_prefix => 'AUTH')
      bug_project = Project.generate!(:issue_key_prefix => 'BUG')

      auth_1 = Issue.generate!(:project => auth_project, :subject => 'Auth 1')
      auth_2 = Issue.generate!(:project => auth_project, :subject => 'Auth 2')
      bug_1 = Issue.generate!(:project => bug_project, :subject => 'Bug 1')

      assert_equal 'AUTH-1', auth_1.issue_key
      assert_equal 1, auth_1.project_issue_number
      assert_equal 'AUTH-2', auth_2.issue_key
      assert_equal 2, auth_2.project_issue_number
      assert_equal 'BUG-1', bug_1.issue_key
      assert_equal 1, bug_1.project_issue_number
    end

    def test_issue_keys_continue_from_an_existing_counter
      project = Project.generate!(:issue_key_prefix => 'SEQ')
      ProjectIssueCounter.create!(:project => project, :next_value => 3)

      issue_1 = Issue.generate!(:project => project, :subject => 'Sequence 1')
      issue_2 = Issue.generate!(:project => project, :subject => 'Sequence 2')

      assert_equal 'SEQ-3', issue_1.issue_key
      assert_equal 3, issue_1.project_issue_number
      assert_equal 'SEQ-4', issue_2.issue_key
      assert_equal 4, issue_2.project_issue_number
      assert_equal 5, ProjectIssueCounter.find_by!(project_id: project.id).next_value
    end

    def test_issue_key_allocation_retries_after_record_not_unique_on_counter_creation
      project = Project.generate!(:issue_key_prefix => 'RACE')
      issue =
        Issue.new(
          :project => project,
          :tracker_id => 1,
          :status_id => 1,
          :priority_id => 5,
          :author_id => 1,
          :subject => 'Race issue'
        )

      first_counter = Class.new do
        attr_accessor :next_value

        def initialize(next_value)
          @next_value = next_value
        end

        def new_record?
          true
        end

        def save!
          raise ActiveRecord::RecordNotUnique
        end
      end.new(1)

      second_counter = Class.new do
        attr_accessor :next_value

        def initialize(next_value)
          @next_value = next_value
        end

        def new_record?
          false
        end

        def save!
          true
        end
      end.new(2)

      calls = 0
      test_case = self
      relation = Object.new
      relation.define_singleton_method(:find_or_initialize_by) do |project_id:|
        calls += 1
        if calls == 1
          first_counter
        else
          test_case.assert_nil issue.project_issue_number
          test_case.assert_nil issue.issue_key
          second_counter
        end
      end

      singleton_class = class << ProjectIssueCounter; self; end
      original_lock = ProjectIssueCounter.method(:lock)
      singleton_class.define_method(:lock) { relation }

      begin
        issue.save!
      ensure
        singleton_class.define_method(:lock) { original_lock.call }
      end

      assert_equal 2, issue.project_issue_number
      assert_equal 'RACE-2', issue.issue_key
    end

    def test_find_by_issue_key_is_case_insensitive
      project = Project.generate!(:issue_key_prefix => 'AUTH')
      issue = Issue.generate!(:project => project, :subject => 'Lookup issue')

      assert_equal issue, Issue.find_by_issue_key(issue.issue_key.downcase)
      assert_equal issue, Issue.find_by_issue_key(issue.issue_key)
      assert_nil Issue.find_by_issue_key('not-a-key')
    end

    def test_issue_key_cannot_be_changed_after_creation
      project = Project.generate!(:issue_key_prefix => 'AUTH')
      issue = Issue.generate!(:project => project, :subject => 'Immutable key')
      original_id = issue.id
      original_issue_key = issue.issue_key

      issue.issue_key = 'AUTH-999'

      assert_not issue.valid?
      assert_includes issue.errors.details[:issue_key].map {|error| error[:error]}, :invalid
      assert_equal original_id, issue.id
      assert_equal original_issue_key, issue.reload.issue_key
      assert_equal original_id, issue.id
    end

    def test_project_issue_number_cannot_be_changed_after_creation
      project = Project.generate!(:issue_key_prefix => 'AUTH')
      issue = Issue.generate!(:project => project, :subject => 'Immutable number')
      original_id = issue.id
      original_issue_key = issue.issue_key
      original_project_issue_number = issue.project_issue_number

      issue.project_issue_number = original_project_issue_number + 10

      assert_not issue.valid?
      assert_includes issue.errors.details[:project_issue_number].map {|error| error[:error]}, :invalid
      assert_equal original_id, issue.id
      assert_equal original_issue_key, issue.issue_key
      assert_equal original_project_issue_number, issue.reload.project_issue_number
      assert_equal original_issue_key, issue.reload.issue_key
      assert_equal original_id, issue.id
    end

    def test_issue_keys_are_unique_under_concurrent_creation
      skip 'SQLite does not provide deterministic concurrent write behavior for this test' if sqlite?

      project = Project.generate!(:issue_key_prefix => 'CONC')
      threads = []
      created_issues = Queue.new
      errors = Queue.new
      create_count = 6

      create_count.times do |i|
        threads << Thread.new(i) do |index|
          ActiveRecord::Base.connection_pool.with_connection do
            begin
              issue =
                Issue.create!(
                  :project => project,
                  :tracker_id => 1,
                  :status_id => 1,
                  :priority_id => 5,
                  :author_id => 1,
                  :subject => "Concurrent issue #{index}"
                )
              created_issues << issue
            rescue => e
              errors << [index, e.class.name, e.message]
            end
          end
        end
      end

      threads.each(&:join)
      assert errors.empty?, errors.size.times.map { errors.pop }.inspect

      issues = Array.new(create_count) { created_issues.pop }
      issue_keys = issues.map(&:issue_key)

      assert_equal issue_keys.uniq, issue_keys
      assert_equal (1..create_count).map {|n| "CONC-#{n}"}, issue_keys.sort_by {|key| key.split('-').last.to_i }
      assert_equal (1..create_count).to_a, issues.map(&:project_issue_number).sort
      assert_equal create_count + 1, ProjectIssueCounter.find_by!(project_id: project.id).next_value
    end
  end
end
