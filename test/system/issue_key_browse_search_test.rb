# frozen_string_literal: true

require_relative '../application_system_test_case'

module RedmineIssueKeys
  class IssueKeyBrowseSearchSystemTest < ApplicationSystemTestCase
    setup do
      log_user('admin', 'admin')
    end

    def test_browse_valid_issue_key_renders_issue_page
      project = Project.generate!(issue_key_prefix: 'AUTH')
      issue = Issue.generate!(project: project, subject: 'Browse valid', author: User.find(1))

      visit "/browse/#{issue.issue_key}"

      assert_current_path "/browse/#{issue.issue_key}", ignore_query: true
      assert_text issue.issue_key
      assert_text issue.subject
    end

    def test_browse_nonexistent_key_shows_404
      visit '/browse/NONEX-999'

      assert_text '404'
    end

    def test_browse_nonexistent_key_returns_404_status
      visit '/browse/NONEX-999'

      assert_match /404/, page.text
    end

    def test_search_with_exact_issue_key_redirects_to_issue_instead_of_showing_results
      project = Project.generate!(issue_key_prefix: 'AUTH')
      issue = Issue.generate!(project: project, subject: 'Search redirect target', author: User.find(1))

      visit '/search'
      within('#search-form') do
        fill_in 'q', with: issue.issue_key
        find('input[type=submit]').click
      end

      assert_current_path issue_path(issue), ignore_query: true
    end

    def test_search_with_partial_key_shows_normal_search_results_not_redirect
      project = Project.generate!(issue_key_prefix: 'AUTH')
      Issue.generate!(project: project, subject: 'Partial match', author: User.find(1))

      visit '/search'
      within('#search-form') do
        fill_in 'q', with: 'AUTH'
        find('input[type=submit]').click
      end

      assert_text 'Results'
      assert_no_current_path issue_path(Issue.where(project: project).first), ignore_query: true
    end

    def test_issue_url_with_lowercase_key_param_works
      project = Project.generate!(issue_key_prefix: 'AUTH')
      issue = Issue.generate!(project: project, subject: 'Lowercase URL test', author: User.find(1))

      visit "/issues/#{issue.issue_key.downcase}"

      assert_text issue.issue_key
      assert_text issue.subject
    end

    def test_issue_url_with_numeric_id_still_works
      issue = Issue.find(1)

      visit "/issues/#{issue.id}"

      assert_text 'Bug #1'
    end

    def test_browse_with_project_id_and_issue_key
      project = Project.generate!(issue_key_prefix: 'AUTH')
      issue = Issue.generate!(project: project, subject: 'With project id', author: User.find(1))

      visit "/browse/#{issue.issue_key}"

      assert_current_path "/browse/#{issue.issue_key}", ignore_query: true
      assert_text issue.subject
    end

    def test_search_lowercase_exact_issue_key_redirects
      project = Project.generate!(issue_key_prefix: 'AUTH')
      issue = Issue.generate!(project: project, subject: 'Lowercase search redirect', author: User.find(1))

      visit '/search'
      within('#search-form') do
        fill_in 'q', with: issue.issue_key.downcase
        find('input[type=submit]').click
      end

      assert_current_path issue_path(issue), ignore_query: true
    end
  end
end
