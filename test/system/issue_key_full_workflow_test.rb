# frozen_string_literal: true

require_relative '../application_system_test_case'

module RedmineIssueKeys
  class IssueKeyFullWorkflowSystemTest < ApplicationSystemTestCase
    setup do
      log_user('admin', 'admin')
      @project = Project.generate!
    end

    def test_admin_sets_project_prefix_on_project_settings_info_tab
      visit settings_project_path(@project, tab: 'info')

      fill_in 'project_issue_key_prefix', with: 'DEV'
      find('input[name=commit]').click

      assert_text 'Successful update'
      @project.reload
      assert_equal 'DEV', @project.issue_key_prefix
    end

    def test_create_issue_shows_heading_with_bug_dev_1
      @project.update_column(:issue_key_prefix, 'DEV')

      visit new_project_issue_path(@project)
      fill_in 'Subject', with: 'First issue with key'
      find('input[name=commit]').click

      assert_text 'Bug DEV-1'
      assert_text 'First issue with key'
    end

    def test_create_second_issue_shows_bug_dev_2
      @project.update_column(:issue_key_prefix, 'DEV')
      Issue.generate!(project: @project, subject: 'First', author: User.find(1))

      visit new_project_issue_path(@project)
      fill_in 'Subject', with: 'Second issue with key'
      find('input[name=commit]').click

      assert_text 'Bug DEV-2'
      assert_text 'Second issue with key'
    end

    def test_browse_by_key_redirects_to_issue_page_with_correct_heading
      @project.update_column(:issue_key_prefix, 'DEV')
      issue = Issue.generate!(project: @project, subject: 'Browse me', author: User.find(1))

      visit "/browse/#{issue.issue_key}"

      assert_current_path "/browse/#{issue.issue_key}", ignore_query: true
      assert_text issue.issue_key
      assert_text issue.subject
    end

    def test_browse_by_numeric_id_still_works
      issue = Issue.find(1)

      visit "/issues/#{issue.id}"

      assert_text 'Bug #1'
    end

    def test_search_redirect_to_issue_when_exact_issue_key_is_typed
      @project.update_column(:issue_key_prefix, 'DEV')
      issue = Issue.generate!(project: @project, subject: 'Search target', author: User.find(1))

      visit '/search'
      within('#search-form') do
        fill_in 'q', with: issue.issue_key
        find('input[type=submit]').click
      end

      assert_current_path issue_path(issue), ignore_query: true
    end

    def test_issue_list_shows_issue_key_column_when_project_has_prefix
      @project.update_column(:issue_key_prefix, 'DEV')
      issue = Issue.generate!(project: @project, subject: 'List test', author: User.find(1))

      visit project_issues_path(@project)

      assert_text issue.issue_key
      assert_text 'List test'
    end

    def test_case_insensitive_issue_key_in_url_also_resolves
      @project.update_column(:issue_key_prefix, 'DEV')
      issue = Issue.generate!(project: @project, subject: 'Case insensitive', author: User.find(1))

      visit "/browse/#{issue.issue_key.downcase}"

      assert_current_path "/browse/#{issue.issue_key.downcase}", ignore_query: true
      assert_text issue.issue_key
      assert_text issue.subject
    end

    def test_issue_show_page_uses_issue_key_in_heading_rather_than_hash_number
      @project.update_column(:issue_key_prefix, 'DEV')
      issue = Issue.generate!(project: @project, subject: 'Display key', author: User.find(1))

      visit issue_path(issue)

      assert_text "Bug #{issue.issue_key}"
      assert_no_text "Bug ##{issue.id}"
    end

    def test_paginated_issue_list_preserves_issue_key_column
      @project.update_column(:issue_key_prefix, 'DEV')
      5.times do |i|
        Issue.generate!(project: @project, subject: "Bulk #{i}", author: User.find(1))
      end

      visit project_issues_path(@project)

      assert_text 'DEV-1'
      assert_text 'DEV-5'
    end
  end
end
