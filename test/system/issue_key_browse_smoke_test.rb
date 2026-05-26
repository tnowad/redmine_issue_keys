# frozen_string_literal: true

require_relative '../application_system_test_case'

module RedmineIssueKeys
  class IssueKeyBrowseSmokeSystemTest < ApplicationSystemTestCase
    def test_browse_path_renders_issue_key_and_subject
      log_user('admin', 'admin')

      project = Project.generate!(:issue_key_prefix => 'SMK')
      issue = Issue.generate!(:project => project, :subject => 'Browser smoke issue')

      visit "/browse/#{issue.issue_key}"

      assert_current_path "/browse/#{issue.issue_key}", :ignore_query => true
      assert_text issue.issue_key
      assert_text issue.subject
    end
  end
end
