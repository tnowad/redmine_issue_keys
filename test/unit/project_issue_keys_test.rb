# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueKeys
  class ProjectIssueKeysTest < ActiveSupport::TestCase
    def setup
      User.current = nil
    end

    def test_issue_key_prefix_is_normalized
      project = Project.generate!(:issue_key_prefix => 'auth')

      assert_equal 'AUTH', project.reload.issue_key_prefix
    end

    def test_issue_key_prefix_must_be_at_least_two_characters
      project = build_project

      project.issue_key_prefix = 'A'
      assert_not project.save
      assert_equal ['Prefix is invalid'], project.errors.full_messages
    end

    def test_issue_key_prefix_must_be_at_most_sixteen_characters
      project = build_project

      project.issue_key_prefix = 'A123456789012345'

      assert project.save

      project = build_project

      project.issue_key_prefix = 'A1234567890123456'

      assert_not project.save
      assert_equal ['Prefix is invalid'], project.errors.full_messages
    end

    def test_issue_key_prefix_must_start_with_a_letter
      project = build_project

      project.issue_key_prefix = '1AUTH'

      assert_not project.save
      assert_equal ['Prefix is invalid'], project.errors.full_messages
    end

    def test_issue_key_prefix_lowercase_normalizes_before_validation
      project = build_project

      project.issue_key_prefix = 'auth1'

      assert project.save
      assert_equal 'AUTH1', project.reload.issue_key_prefix
    end

    def test_issue_key_prefix_punctuation_is_invalid
      project = build_project

      project.issue_key_prefix = 'AU-TH'

      assert_not project.save
      assert_equal ['Prefix is invalid'], project.errors.full_messages
    end

    def test_issue_key_prefix_must_be_unique
      Project.generate!(:issue_key_prefix => 'AUTH')

      project =
        Project.new(
          :name => 'duplicate-prefix-project',
          :identifier => 'duplicate-prefix-project',
          :issue_key_prefix => 'auth'
      )

      assert_not project.save
      assert_equal ['Prefix has already been taken'], project.errors.full_messages
    end

    def test_issue_key_prefix_uniqueness_is_case_insensitive_after_normalization
      Project.generate!(:issue_key_prefix => 'AUTH')

      project = build_project
      project.issue_key_prefix = 'auth'

      assert_not project.save
      assert_equal ['Prefix has already been taken'], project.errors.full_messages
    end

    def test_issue_key_prefix_cannot_change_once_issues_exist
      project = Project.generate!(:issue_key_prefix => 'AUTH')
      Issue.generate!(:project => project, :subject => 'Prefixed issue')

      project.issue_key_prefix = 'BUG'

      assert_not project.save
      assert_equal ['Prefix cannot be changed because this project already has issues'], project.errors.full_messages
    end

    private

    def build_project
      @issue_key_prefix_project_seq ||= 0
      @issue_key_prefix_project_seq += 1
      suffix = "#{Process.pid}-#{@issue_key_prefix_project_seq}"

      Project.generate!(
        :name => "issue-key-prefix-#{suffix}",
        :identifier => "issue-key-prefix-#{suffix}"
      )
    end
  end
end
